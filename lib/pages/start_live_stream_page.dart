import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/live_stream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class StartLiveStreamPage extends StatefulWidget {
  final String? liveStreamRequestId;
  final String? requestedChildId;
  final String? requestedChildName;
  final String? requestedParentUid;
  final String? requestedParentUsername;

  const StartLiveStreamPage({
    super.key,
    this.liveStreamRequestId,
    this.requestedChildId,
    this.requestedChildName,
    this.requestedParentUid,
    this.requestedParentUsername,
  });

  bool get isRequestBasedStream =>
      liveStreamRequestId != null && liveStreamRequestId!.trim().isNotEmpty;

  @override
  State<StartLiveStreamPage> createState() => _StartLiveStreamPageState();
}

class _StartLiveStreamPageState extends State<StartLiveStreamPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final LiveStreamService _liveStreamService = LiveStreamService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  late final TextEditingController _titleController;

  bool _isInitializing = true;
  bool _isStarting = false;
  bool _isEnding = false;
  bool _isLive = false;
  bool _hasCameraPreview = false;

  String? _roomId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.isRequestBasedStream
          ? 'بث مباشر للطفل ${widget.requestedChildName ?? ''}'
          : 'بث مباشر من الحضانة',
    );

    _initializeCamera();
  }

  @override
  void dispose() {
    _titleController.dispose();

    if (_isLive) {
      final roomId = _roomId ?? _liveStreamService.currentRoomId;

      if (roomId != null && roomId.trim().isNotEmpty) {
        unawaited(_liveStreamService.endLiveStream(roomId: roomId));
      } else {
        unawaited(_liveStreamService.close());
      }
    } else {
      unawaited(_liveStreamService.close());
    }

    _localRenderer.dispose();
    super.dispose();
  }

  String _normalizeRole(String role) {
    final value = role.trim().toLowerCase();

    if (value == 'nursery' ||
        value == 'nursery staff' ||
        value == 'nursery_staff') {
      return 'nursery_staff';
    }

    return value;
  }

  bool _canStartLiveStream(String role) {
    final normalized = _normalizeRole(role);
    return normalized == 'admin' || normalized == 'nursery_staff';
  }

  String _friendlyCameraError(Object error) {
    final errorText = error.toString();

    if (errorText.contains('NotFoundError') ||
        errorText.contains('Requested device not found')) {
      return 'لم يتم العثور على كاميرا أو ميكروفون على هذا الجهاز. جرّبي من جهاز يحتوي على كاميرا، أو تأكدي أن الكاميرا موصولة ومفعّلة.';
    }

    if (errorText.contains('NotAllowedError') ||
        errorText.contains('Permission denied')) {
      return 'تم رفض صلاحية الكاميرا أو الميكروفون. اسمحي بالصلاحيات من المتصفح ثم أعيدي تحميل الصفحة.';
    }

    if (errorText.contains('NotReadableError')) {
      return 'الكاميرا مستخدمة من تطبيق آخر. أغلقي أي برنامج يستخدم الكاميرا ثم حاولي مرة أخرى.';
    }

    if (errorText.contains('OverconstrainedError')) {
      return 'إعدادات الكاميرا المطلوبة غير متاحة على هذا الجهاز. جرّبي كاميرا أخرى أو أعيدي تحميل الصفحة.';
    }

    return 'تعذر فتح الكاميرا أو الميكروفون. تأكدي من السماح بالصلاحيات ثم أعيدي المحاولة.';
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _hasCameraPreview = false;
    });

    try {
      await _localRenderer.initialize();

      final localStream = await _liveStreamService.openUserMedia();
      _localRenderer.srcObject = localStream;

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _hasCameraPreview = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _hasCameraPreview = false;
        _errorMessage = _friendlyCameraError(e);
      });
    }
  }

  Future<Map<String, dynamic>> _getCurrentUserData() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولًا.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? <String, dynamic>{};

    final role = _normalizeRole((data['role'] ?? '').toString());

    return {
      'uid': user.uid,
      'name': (data['fullName'] ??
              data['name'] ??
              data['displayName'] ??
              data['username'] ??
              user.displayName ??
              'مستخدم')
          .toString()
          .trim(),
      'role': role,
      'photoUrl': (data['photoUrl'] ?? data['profileImageUrl'] ?? '').toString(),
      'section': (data['section'] ?? 'Nursery').toString().trim(),
      'group': (data['group'] ?? '').toString().trim(),
    };
  }

  Future<Map<String, dynamic>?> _getActiveLiveStreamIfExists() async {
    final snapshot = await _firestore
        .collection('live_streams')
        .where('status', isEqualTo: 'active')
        .orderBy('startedAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;

    return {
      'id': doc.id,
      ...doc.data(),
    };
  }

  Future<bool> _confirmStartLiveStream() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('بدء بث مباشر؟'),
            content: Text(
              widget.isRequestBasedStream
                  ? 'سيتم بدء بث مباشر خاص بولي أمر الطفل ${widget.requestedChildName ?? ''}. تأكدي أن الكاميرا تظهر بشكل صحيح قبل البدء.'
                  : 'سيتم بدء بث مباشر وإرسال إشعار لأولياء الأمور حسب إعدادات خدمة البث. تأكدي أن الكاميرا تظهر بشكل صحيح قبل البدء.',
              style: const TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.wifi_tethering_rounded),
                label: const Text('بدء البث'),
              ),
            ],
          ),
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _startLiveStream() async {
    if (_isStarting || _isLive) return;

    if (!_hasCameraPreview || _localRenderer.srcObject == null) {
      setState(() {
        _errorMessage =
            'لا يمكن بدء البث قبل تشغيل معاينة الكاميرا. أعيدي تشغيل الكاميرا أولًا.';
      });
      return;
    }

    final confirmed = await _confirmStartLiveStream();
    if (!confirmed) return;

    setState(() {
      _isStarting = true;
      _errorMessage = null;
    });

    try {
      final activeStream = await _getActiveLiveStreamIfExists();

      if (activeStream != null) {
        final activeTitle =
            (activeStream['title'] ?? 'بث مباشر نشط حاليًا').toString();
        final startedByName =
            (activeStream['startedByName'] ?? '').toString().trim();

        if (!mounted) return;

        setState(() {
          _isStarting = false;
          _errorMessage = startedByName.isEmpty
              ? 'يوجد بث مباشر نشط حاليًا: $activeTitle. يجب إنهاؤه قبل بدء بث جديد.'
              : 'يوجد بث مباشر نشط حاليًا بواسطة $startedByName. يجب إنهاؤه قبل بدء بث جديد.';
        });

        return;
      }

      final userData = await _getCurrentUserData();
      final role = userData['role'].toString();

      if (!_canStartLiveStream(role)) {
        throw Exception('لا تملكين صلاحية بدء بث مباشر.');
      }

      final title = _titleController.text.trim().isEmpty
          ? 'بث مباشر من الحضانة'
          : _titleController.text.trim();

      final section = userData['section'].toString().trim().isEmpty
          ? 'Nursery'
          : userData['section'].toString().trim();

      final roomId = await _liveStreamService.startLiveStream(
        title: title,
        startedByUid: userData['uid'].toString(),
        startedByName: userData['name'].toString(),
        startedByRole: role,
        startedByPhotoUrl: userData['photoUrl'].toString(),
        section: section,
        group: userData['group'].toString(),
        allowedViewersType:
            widget.isRequestBasedStream ? 'specific_parent' : 'all',
        notifyParents: true,
        liveStreamRequestId: widget.liveStreamRequestId ?? '',
        requestedChildId: widget.requestedChildId ?? '',
        requestedChildName: widget.requestedChildName ?? '',
        requestedParentUid: widget.requestedParentUid ?? '',
        requestedParentUsername: widget.requestedParentUsername ?? '',
      );

      if (!mounted) return;

      setState(() {
        _roomId = roomId;
        _isLive = true;
        _isStarting = false;
        _errorMessage = null;
      });

      if (widget.isRequestBasedStream) {
        await _firestore
            .collection('live_stream_requests')
            .doc(widget.liveStreamRequestId)
            .set({
          'status': 'live',
          'liveStreamId': roomId,
          'roomId': roomId,
          'startedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isRequestBasedStream
                ? 'تم بدء البث الخاص بنجاح'
                : 'تم بدء البث المباشر بنجاح',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isStarting = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _endLiveStream() async {
    if (_isEnding) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إنهاء البث؟'),
            content: const Text(
              'هل أنتِ متأكدة من إنهاء البث المباشر؟ سيتم تحديث حالة البث وإشعار الأهل بانتهائه إذا كانت الخدمة مفعلة.',
              style: TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('إنهاء البث'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    await _endLiveStreamWithoutDialog();
  }

  Future<void> _endLiveStreamWithoutDialog() async {
    if (_isEnding) return;

    setState(() {
      _isEnding = true;
      _errorMessage = null;
    });

    try {
      final roomId = _roomId ?? _liveStreamService.currentRoomId;

      if (roomId != null && roomId.trim().isNotEmpty) {
        await _liveStreamService.endLiveStream(roomId: roomId);
      } else {
        await _liveStreamService.close();
      }

      if (!mounted) return;

      setState(() {
        _roomId = null;
        _isLive = false;
        _isEnding = false;
      });

      if (widget.isRequestBasedStream) {
        await _firestore
            .collection('live_stream_requests')
            .doc(widget.liveStreamRequestId)
            .set({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنهاء البث المباشر'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isEnding = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isLive) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إنهاء البث؟'),
            content: const Text(
              'يوجد بث مباشر نشط. هل تريدين إنهاء البث والخروج؟',
              style: TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('إنهاء البث'),
              ),
            ],
          ),
        );
      },
    );

    if (shouldLeave == true) {
      await _endLiveStreamWithoutDialog();
      return true;
    }

    return false;
  }

  Widget _buildRequestInfoCard() {
    if (!widget.isRequestBasedStream) return const SizedBox.shrink();

    final childName = (widget.requestedChildName ?? '').trim();
    final parentUsername = (widget.requestedParentUsername ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: const Icon(
              Icons.person_pin_circle_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              childName.isEmpty
                  ? 'هذا بث مباشر خاص بناءً على طلب ولي أمر.'
                  : 'هذا بث مباشر خاص للطفل $childName${parentUsername.isEmpty ? '' : ' - ولي الأمر: $parentUsername'}',
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: _localRenderer.srcObject == null
                ? const Center(
                    child: Text(
                      'لا توجد معاينة للكاميرا',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _isLive ? Colors.red : Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isLive
                        ? Icons.circle
                        : _hasCameraPreview
                            ? Icons.videocam_rounded
                            : Icons.videocam_off_rounded,
                    color: Colors.white,
                    size: _isLive ? 10 : 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isLive
                        ? 'LIVE'
                        : _hasCameraPreview
                            ? 'معاينة'
                            : 'غير متصل',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_isLive)
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'راجعي زاوية الكاميرا قبل بدء البث.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: TextField(
          controller: _titleController,
          enabled: !_isLive && !_isStarting,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            labelText: 'عنوان البث',
            hintText: 'مثال: نشاط صباحي',
            prefixIcon: const Icon(Icons.title_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final color = _isLive
        ? Colors.red
        : _hasCameraPreview
            ? Colors.green
            : Colors.orange;

    final title = _isLive
        ? 'البث مباشر الآن'
        : _hasCameraPreview
            ? 'الكاميرا جاهزة'
            : 'الكاميرا غير جاهزة';

    final subtitle = _isLive
        ? widget.isRequestBasedStream
            ? 'ولي الأمر المحدد يستطيع مشاهدة هذا البث الخاص من الإشعار أو صفحة المشاهدة.'
            : 'الأهل يستطيعون مشاهدة البث من إشعار البث أو صفحة المشاهدة.'
        : _hasCameraPreview
            ? 'يمكنك بدء البث بعد التأكد من العنوان والمعاينة.'
            : 'أعيدي محاولة تشغيل الكاميرا أو راجعي الصلاحيات.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.14),
            child: Icon(
              _isLive
                  ? Icons.wifi_tethering_rounded
                  : _hasCameraPreview
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard() {
    if (_roomId == null || _roomId!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(0.25),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'رقم غرفة البث',
            style: TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            _roomId!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    if (_errorMessage == null || _errorMessage!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.25),
        ),
      ),
      child: Text(
        _errorMessage!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (!_isLive) {
      return FilledButton.icon(
        onPressed: _isStarting || _isInitializing ? null : _startLiveStream,
        icon: _isStarting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.wifi_tethering_rounded),
        label: Text(
          _isStarting
              ? 'جارٍ بدء البث...'
              : widget.isRequestBasedStream
                  ? 'بدء البث الخاص'
                  : 'بدء البث المباشر',
        ),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: _isEnding ? null : _endLiveStream,
      icon: _isEnding
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.stop_circle_outlined),
      label: Text(
        _isEnding ? 'جارٍ إنهاء البث...' : 'إنهاء البث المباشر',
      ),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.red,
        minimumSize: const Size(double.infinity, 54),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildRetryCameraButton() {
    if (_hasCameraPreview || _isInitializing || _isLive) {
      return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      onPressed: _initializeCamera,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('إعادة تشغيل الكاميرا'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.isRequestBasedStream
                  ? 'هذا البث خاص بطلب ولي أمر محدد، وسيتم ربطه بالطلب والطفل حتى لا يصبح بثًا عامًا لكل الأهل.'
                  : 'هذه نسخة بث مباشر مجانية وتجريبية. عند بدء البث يتم إنشاء غرفة نشطة، وعند الإنهاء يتم تحديث حالتها حتى لا تبقى ظاهرة للأهل كبث نشط.',
              style: const TextStyle(
                color: AppColors.textDark,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AppPageScaffold(
          title: widget.isRequestBasedStream ? 'بث خاص للطفل' : 'البث المباشر',
          actions: [
            if (!_isLive)
              IconButton(
                onPressed: _isInitializing ? null : _initializeCamera,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'إعادة تشغيل الكاميرا',
              ),
          ],
          child: _isInitializing
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : ListView(
                  children: [
                    _buildRequestInfoCard(),
                    if (widget.isRequestBasedStream)
                      const SizedBox(height: 14),
                    _buildPreviewCard(),
                    const SizedBox(height: 18),
                    _buildStatusCard(),
                    const SizedBox(height: 14),
                    _buildTitleCard(),
                    const SizedBox(height: 14),
                    _buildRoomCard(),
                    if (_roomId != null) const SizedBox(height: 14),
                    _buildErrorCard(),
                    if (_errorMessage != null) const SizedBox(height: 14),
                    _buildActionButton(),
                    const SizedBox(height: 12),
                    _buildRetryCameraButton(),
                    const SizedBox(height: 16),
                    _buildHelpCard(),
                    const SizedBox(height: 12),
                  ],
                ),
        ),
      ),
    );
  }
}