import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/live_stream_service.dart';
import '../theme/app_theme.dart';

class LiveStreamViewerPage extends StatefulWidget {
  final String roomId;
  final String title;
  final String startedByName;

  const LiveStreamViewerPage({
    super.key,
    required this.roomId,
    required this.title,
    required this.startedByName,
  });

  @override
  State<LiveStreamViewerPage> createState() => _LiveStreamViewerPageState();
}

class _LiveStreamViewerPageState extends State<LiveStreamViewerPage> {
  final LiveStreamService _liveStreamService = LiveStreamService();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isLoading = true;
  bool _hasJoined = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _joinLiveStream();
  }

  Future<void> _joinLiveStream() async {
    try {
      await _remoteRenderer.initialize();

      await _liveStreamService.joinLiveStream(
        roomId: widget.roomId,
      );

      _remoteRenderer.srcObject = _liveStreamService.remoteStream;

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasJoined = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasJoined = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _liveStreamService.close();
    super.dispose();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text(
            'جارٍ الاتصال بالبث المباشر...',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.withOpacity(0.25)),
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
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _joinLiveStream();
              },
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
                            style: TextStyle(color: Colors.white),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_isLoading) {
      body = _buildLoadingState();
    } else if (_errorMessage != null) {
      body = _buildErrorState();
    } else if (_hasJoined) {
      body = _buildVideoView();
    } else {
      body = _buildErrorState();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مشاهدة البث المباشر'),
          centerTitle: true,
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}