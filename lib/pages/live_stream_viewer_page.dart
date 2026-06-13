import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/live_stream_service.dart';
import '../theme/app_theme.dart';

class LiveStreamViewerPage extends StatefulWidget {
  final String roomId;
  final String title;
  final String startedByName;
  final String liveStreamRequestId;

  const LiveStreamViewerPage({
    super.key,
    required this.roomId,
    required this.title,
    required this.startedByName,
    required this.liveStreamRequestId,
  });

  @override
  State<LiveStreamViewerPage> createState() => _LiveStreamViewerPageState();
}

class _LiveStreamViewerPageState extends State<LiveStreamViewerPage> {
  final LiveStreamService _liveStreamService = LiveStreamService();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _requestSubscription;

  Timer? _clockTimer;
  Timer? _joinRetryTimer;

  bool _isJoining = false;
  bool _hasJoined = false;
  bool _isEnding = false;
  bool _isCancelling = false;
  bool _didFinishRequest = false;

  String _requestStatus = 'loading';
  String? _errorMessage;
  String? _finishedMessage;

  int _queuePosition = 0;
  DateTime? _deadline;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _joinRetryTimer?.cancel();

    _liveStreamService.onRemoteStream = null;

    unawaited(_requestSubscription?.cancel());
    unawaited(_cleanupOnExit());
    unawaited(_remoteRenderer.dispose());

    super.dispose();
  }

  Future<void> _handleRemoteStream(MediaStream stream) async {
    if (!mounted) return;

    final videoTracks = stream.getVideoTracks();

  
    if (videoTracks.isEmpty) return;

    final videoTrack = videoTracks.first;
    videoTrack.enabled = true;

    try {
 
      _remoteRenderer.srcObject = null;
      await Future<void>.delayed(
        const Duration(milliseconds: 80),
      );

      if (!mounted) return;

      _remoteRenderer.srcObject = stream;

      debugPrint(
        'Viewer renderer attached: '
        'stream=${stream.id}, '
        'videoTrack=${videoTrack.id}, '
        'videoTracks=${videoTracks.length}',
      );

      setState(() {});
    } catch (e) {
      debugPrint('Viewer renderer attach error: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'تعذر عرض فيديو البث على الجهاز.';
      });
    }
  }

  Future<void> _initializePage() async {
    try {
      await _remoteRenderer.initialize();

      _liveStreamService.onRemoteStream = (stream) {
        unawaited(_handleRemoteStream(stream));
      };

      _listenToRequest();

      _clockTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tickClock(),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _listenToRequest() {
    unawaited(_requestSubscription?.cancel());

    _requestSubscription = _liveStreamService
        .watchLiveStreamRequest(
          requestId: widget.liveStreamRequestId,
        )
        .listen(
      (snapshot) {
        if (!mounted) return;

        if (!snapshot.exists) {
          setState(() {
            _errorMessage = 'تعذر العثور على طلب البث المباشر.';
          });
          return;
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        final status = (data['status'] ?? '').toString().trim().toLowerCase();
        final queuePosition = _asInt(data['queuePosition']);

        DateTime? deadline;

        if (status == 'ready') {
          deadline = _dateFromDynamic(data['readyExpiresAt']);
        } else if (status == 'active') {
          deadline = _dateFromDynamic(data['viewerExpiresAt']);
        }

        setState(() {
          _requestStatus = status;
          _queuePosition = queuePosition;
          _deadline = deadline;
          _errorMessage = null;
        });

        if ((status == 'ready' || status == 'active') &&
            !_hasJoined &&
            !_isJoining) {
          unawaited(_joinLiveStream());
        }

        if (_isTerminalStatus(status)) {
          unawaited(_finishFromStatus(status));
        }
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          _errorMessage = 'تعذر متابعة حالة طلب البث المباشر.';
        });
      },
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);

    return null;
  }

  bool _isOpenRequestStatus(String status) {
    return status == 'ready' ||
        status == 'queued' ||
        status == 'waiting' ||
        status == 'active';
  }

  bool _isTerminalStatus(String status) {
    return status == 'completed' ||
        status == 'cancelled' ||
        status == 'expired' ||
        status == 'rejected';
  }

  String _finishedMessageForStatus(String status) {
    switch (status) {
      case 'completed':
        return 'تم إنهاء المشاهدة.';
      case 'cancelled':
        return 'تم إلغاء طلب البث المباشر.';
      case 'expired':
        return 'انتهت مدة المشاهدة أو انتهت مهلة فتح البث.';
      case 'rejected':
        return 'تعذر فتح البث المباشر حاليًا.';
      default:
        return 'انتهى البث المباشر.';
    }
  }

  Future<void> _finishFromStatus(String status) async {
    if (_didFinishRequest) return;

    _didFinishRequest = true;

    try {
      await _liveStreamService.close(
        markRequestCompleted: false,
      );
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _hasJoined = false;
      _isJoining = false;
      _finishedMessage = _finishedMessageForStatus(status);
    });
  }

  void _tickClock() {
    if (!mounted) return;

    final deadline = _deadline;

    setState(() {
      _now = DateTime.now();
    });

    if (deadline == null) return;
    if (deadline.isAfter(_now)) return;
    if (_didFinishRequest) return;

    if (_requestStatus == 'ready') {
      unawaited(_liveStreamService.expireReadyRequestsIfNeeded());
    }

    _didFinishRequest = true;

    unawaited(
      _liveStreamService.close(
        markRequestCompleted: false,
      ),
    );

    setState(() {
      _hasJoined = false;
      _finishedMessage = _requestStatus == 'ready'
          ? 'انتهت مهلة فتح البث المباشر.'
          : 'انتهت مدة المشاهدة.';
    });
  }

  Duration _remainingDuration() {
    final deadline = _deadline;

    if (deadline == null) return Duration.zero;

    final remaining = deadline.difference(_now);

    if (remaining.isNegative) return Duration.zero;

    return remaining;
  }

  String _remainingTimeText() {
    final remaining = _remainingDuration();

    final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        remaining.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  Future<void> _joinLiveStream() async {
    if (_isJoining || _hasJoined || _didFinishRequest) return;

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      await _liveStreamService.joinLiveStream(
        roomId: widget.roomId,
      );

      final remoteStream = _liveStreamService.remoteStream;

      if (remoteStream != null) {
        await _handleRemoteStream(remoteStream);
      }

      if (!mounted) return;

      setState(() {
        _isJoining = false;
        _hasJoined = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isJoining = false;
      });

      final message = e.toString().replaceFirst('Exception: ', '');

      if (_requestStatus == 'ready' || _requestStatus == 'active') {
        _scheduleJoinRetry();
        return;
      }

      setState(() {
        _errorMessage = message;
      });
    }
  }

  void _scheduleJoinRetry() {
    _joinRetryTimer?.cancel();

    _joinRetryTimer = Timer(
      const Duration(seconds: 2),
      () {
        if (!mounted || _didFinishRequest || _hasJoined) return;

        unawaited(_joinLiveStream());
      },
    );
  }

  Future<void> _retryJoinLiveStream() async {
    _joinRetryTimer?.cancel();

    try {
      await _liveStreamService.close(
        markRequestCompleted: false,
      );
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _hasJoined = false;
      _isJoining = false;
      _errorMessage = null;
      _didFinishRequest = false;
    });

    await _joinLiveStream();
  }

  Future<void> _endViewing() async {
    if (_isEnding) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إنهاء المشاهدة'),
            content: const Text(
              'هل تريد إنهاء مشاهدة البث المباشر؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('إنهاء'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isEnding = true;
    });

    try {
      await _liveStreamService.close();
    } catch (_) {}

    _didFinishRequest = true;

    if (!mounted) return;

    Navigator.pop(context);
  }

  Future<void> _cancelWaitingRequest() async {
    if (_isCancelling) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إلغاء الطلب'),
            content: const Text(
              'هل تريد إلغاء طلب البث المباشر؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('رجوع'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('إلغاء الطلب'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      await _liveStreamService.cancelLiveStreamRequest(
        requestId: widget.liveStreamRequestId,
        cancelledByUid: currentUser.uid,
        cancelledByRole:
            currentUser.isAnonymous ? 'temporary_parent' : 'parent',
      );

      await _liveStreamService.close(
        markRequestCompleted: false,
      );

      _didFinishRequest = true;

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCancelling = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _cleanupOnExit() async {
    if (_didFinishRequest) return;

    final currentUser = FirebaseAuth.instance.currentUser;

    if (_hasJoined || _requestStatus == 'active') {
      try {
        await _liveStreamService.close();
      } catch (_) {}

      return;
    }

    if (_isOpenRequestStatus(_requestStatus) && currentUser != null) {
      try {
        await _liveStreamService.cancelLiveStreamRequest(
          requestId: widget.liveStreamRequestId,
          cancelledByUid: currentUser.uid,
          cancelledByRole:
              currentUser.isAnonymous ? 'temporary_parent' : 'parent',
        );
      } catch (_) {}
    }

    try {
      await _liveStreamService.close(
        markRequestCompleted: false,
      );
    } catch (_) {}
  }

  Widget _buildLoadingState() {
    final message = _requestStatus == 'ready'
        ? 'جارٍ تجهيز البث المباشر...'
        : 'جارٍ تحميل حالة البث المباشر...';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingState() {
    final isReady = _requestStatus == 'ready';

    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Icon(
                isReady
                    ? Icons.play_circle_outline_rounded
                    : Icons.hourglass_top_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isReady
                  ? 'دورك متاح الآن'
                  : 'أنت في قائمة الانتظار',
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            if (!isReady)
              Text(
                _queuePosition > 0
                    ? 'رقم دورك: $_queuePosition'
                    : 'سيتم فتح البث تلقائيًا عند توفر مكان.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            if (isReady) ...[
              const Text(
                'جارٍ فتح البث المباشر تلقائيًا...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _buildRemainingTimeCard(
                title: 'الوقت المتاح للدخول',
              ),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed:
                  _isCancelling ? null : _cancelWaitingRequest,
              icon: _isCancelling
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.close_rounded),
              label: Text(
                _isCancelling
                    ? 'جارٍ الإلغاء...'
                    : 'إلغاء الطلب',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemainingTimeCard({
    String title = 'الوقت المتبقي',
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            _remainingTimeText(),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishedState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.primary,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              _finishedMessage ?? 'انتهى البث المباشر.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'تعذر فتح البث المباشر',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'حدث خطأ غير معروف.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _retryJoinLiveStream,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _remoteRenderer.srcObject == null
                      ? const Center(
                          child: Text(
                            'بانتظار ظهور البث...',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        )
                      : RTCVideoView(
                          _remoteRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                ),
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
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _buildRemainingTimeCard(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title.trim().isEmpty
                      ? 'بث مباشر من الحضانة'
                      : widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.startedByName.trim().isEmpty
                      ? 'يتم البث الآن'
                      : 'بواسطة: ${widget.startedByName}',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isEnding ? null : _endViewing,
              icon: _isEnding
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.stop_circle_outlined,
                    ),
              label: Text(
                _isEnding
                    ? 'جارٍ إنهاء المشاهدة...'
                    : 'إنهاء المشاهدة',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(
                  color: Colors.red,
                ),
                minimumSize: const Size(
                  double.infinity,
                  50,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_finishedMessage != null) {
      body = _buildFinishedState();
    } else if (_errorMessage != null) {
      body = _buildErrorState();
    } else if (_hasJoined) {
      body = _buildVideoView();
    } else if (_requestStatus == 'queued' ||
        _requestStatus == 'waiting' ||
        _requestStatus == 'ready') {
      body = _buildWaitingState();
    } else {
      body = _buildLoadingState();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مشاهدة البث المباشر'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: body,
        ),
      ),
    );
  }
}

