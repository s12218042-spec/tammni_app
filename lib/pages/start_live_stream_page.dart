import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/live_stream_service.dart';

class StartLiveStreamPage extends StatefulWidget {
  const StartLiveStreamPage({super.key});

  @override
  State<StartLiveStreamPage> createState() => _StartLiveStreamPageState();
}

class _StartLiveStreamPageState extends State<StartLiveStreamPage> {
  final LiveStreamService _liveStreamService = LiveStreamService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  final TextEditingController _titleController = TextEditingController(
    text: 'بث مباشر من الحضانة',
  );

  bool _isInitializing = true;
  bool _isStarting = false;
  bool _isEnding = false;
  bool _isLive = false;

  String? _roomId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _localRenderer.initialize();

      final localStream = await _liveStreamService.openUserMedia();
      _localRenderer.srcObject = localStream;

      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = null;
      });
   } catch (e) {
  if (!mounted) return;

  final errorText = e.toString();

  String friendlyMessage =
      'تعذر فتح الكاميرا أو الميكروفون. تأكدي من السماح بالصلاحيات.';

  if (errorText.contains('NotFoundError') ||
      errorText.contains('Requested device not found')) {
    friendlyMessage =
        'لم يتم العثور على كاميرا أو ميكروفون على هذا الجهاز. جرّبي من جهاز يحتوي على كاميرا، أو تأكدي أن الكاميرا موصولة ومفعّلة.';
  } else if (errorText.contains('NotAllowedError') ||
      errorText.contains('Permission denied')) {
    friendlyMessage =
        'تم رفض صلاحية الكاميرا أو الميكروفون. اسمحي بالصلاحيات من المتصفح ثم أعيدي تحميل الصفحة.';
  } else if (errorText.contains('NotReadableError')) {
    friendlyMessage =
        'الكاميرا مستخدمة من تطبيق آخر. أغلقي أي برنامج يستخدم الكاميرا ثم حاولي مرة أخرى.';
  }

  setState(() {
    _isInitializing = false;
    _errorMessage = friendlyMessage;
  });
}
  }

  Future<Map<String, dynamic>> _getCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولًا.');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = userDoc.data() ?? {};

    return {
      'uid': user.uid,
      'name': (data['fullName'] ??
              data['name'] ??
              data['displayName'] ??
              user.displayName ??
              'مستخدم')
          .toString(),
      'role': (data['role'] ?? '').toString(),
      'photoUrl': (data['photoUrl'] ?? data['profileImageUrl'] ?? '').toString(),
      'section': (data['section'] ?? 'Nursery').toString(),
      'group': (data['group'] ?? '').toString(),
    };
  }

  Future<Map<String, dynamic>?> _getActiveLiveStreamIfExists() async {
  final snapshot = await FirebaseFirestore.instance
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

  Future<void> _startLiveStream() async {
    if (_isStarting || _isLive) return;

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
        (activeStream['startedByName'] ?? '').toString();

    if (!mounted) return;

    setState(() {
      _isStarting = false;
      _errorMessage = startedByName.trim().isEmpty
          ? 'يوجد بث مباشر نشط حاليًا: $activeTitle. يجب إنهاؤه قبل بدء بث جديد.'
          : 'يوجد بث مباشر نشط حاليًا بواسطة $startedByName. يجب إنهاؤه قبل بدء بث جديد.';
    });

    return;
  }
} catch (e) {
  debugPrint('check active live stream error: $e');
}

    try {
      final userData = await _getCurrentUserData();

      final role = userData['role'].toString();

      final canStart = role == 'admin' ||
          role == 'nursery_staff' ||
          role == 'nursery' ||
          role == 'teacher';

      if (!canStart) {
        throw Exception('لا تملكين صلاحية بدء بث مباشر.');
      }

      final roomId = await _liveStreamService.startLiveStream(
        title: _titleController.text.trim().isEmpty
            ? 'بث مباشر من الحضانة'
            : _titleController.text.trim(),
        startedByUid: userData['uid'].toString(),
        startedByName: userData['name'].toString(),
        startedByRole: role,
        startedByPhotoUrl: userData['photoUrl'].toString(),
        section: userData['section'].toString().isEmpty
            ? 'Nursery'
            : userData['section'].toString(),
        group: userData['group'].toString(),
        allowedViewersType: 'all',
        notifyParents: true,
      );

      if (!mounted) return;
      setState(() {
        _roomId = roomId;
        _isLive = true;
        _isStarting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم بدء البث المباشر بنجاح'),
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

    setState(() {
      _isEnding = true;
      _errorMessage = null;
    });

    try {
      final roomId = _roomId ?? _liveStreamService.currentRoomId;

      if (roomId != null && roomId.isNotEmpty) {
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

  @override
  void dispose() {
    _titleController.dispose();

    if (_isLive) {
      final roomId = _roomId;
      if (roomId != null && roomId.isNotEmpty) {
        _liveStreamService.endLiveStream(roomId: roomId);
      } else {
        _liveStreamService.close();
      }
    } else {
      _liveStreamService.close();
    }

    _localRenderer.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_isLive) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إنهاء البث؟'),
          content: const Text(
            'يوجد بث مباشر نشط. هل تريدين إنهاء البث والخروج؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إنهاء البث'),
            ),
          ],
        );
      },
    );

    if (shouldLeave == true) {
      await _endLiveStream();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('البث المباشر'),
            centerTitle: true,
          ),
          body: SafeArea(
            child: _isInitializing
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 360,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _localRenderer.srcObject == null
                                    ? const Center(
                                        child: Text(
                                          'لا توجد معاينة للكاميرا',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      )
                                    : RTCVideoView(
                                        _localRenderer,
                                        mirror: true,
                                        objectFit: RTCVideoViewObjectFit
                                            .RTCVideoViewObjectFitCover,
                                      ),
                              ),
                              if (_isLive)
                                Positioned(
                                  top: 14,
                                  left: 14,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          color: Colors.white,
                                          size: 10,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'LIVE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        TextField(
                          controller: _titleController,
                          enabled: !_isLive && !_isStarting,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            labelText: 'عنوان البث',
                            hintText: 'مثال: نشاط صباحي',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (_roomId != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.25),
                              ),
                            ),
                            child: Text(
                              'رقم غرفة البث:\n$_roomId',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        if (!_isLive)
                          FilledButton.icon(
                            onPressed: _isStarting ? null : _startLiveStream,
                            icon: _isStarting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.wifi_tethering),
                            label: Text(
                              _isStarting
                                  ? 'جارٍ بدء البث...'
                                  : 'بدء البث المباشر',
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          )
                        else
                          FilledButton.icon(
                            onPressed: _isEnding ? null : _endLiveStream,
                            icon: _isEnding
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.stop_circle),
                            label: Text(
                              _isEnding
                                  ? 'جارٍ إنهاء البث...'
                                  : 'إنهاء البث المباشر',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),

                        const SizedBox(height: 12),

                        Text(
                          'هذه نسخة تجريبية أولى للبث المباشر المجاني. بعد نجاح تشغيل البث، سنضيف صفحة المشاهدة لولي الأمر ثم شكل LIVE في الصفحة الرئيسية.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}