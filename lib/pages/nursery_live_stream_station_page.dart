import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/live_stream_service.dart';
import '../widgets/app_page_scaffold.dart';

class NurseryLiveStreamStationPage extends StatefulWidget {
  const NurseryLiveStreamStationPage({super.key});

  @override
  State<NurseryLiveStreamStationPage> createState() =>
      _NurseryLiveStreamStationPageState();
}

class _NurseryLiveStreamStationPageState
    extends State<NurseryLiveStreamStationPage> {
  final LiveStreamService _liveStreamService = LiveStreamService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  bool _isInitializing = true;
  bool _isStreaming = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeStation();
  }

  @override
  void dispose() {
    unawaited(_stopStation(silent: true));
    unawaited(_localRenderer.dispose());
    super.dispose();
  }

  Future<void> _initializeStation() async {
    try {
      await _localRenderer.initialize();
      await _startStation();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _isStreaming = false;
        _errorMessage = 'تعذر تشغيل محطة البث';
      });
    }
  }

  Future<void> _startStation() async {
  if (!mounted) return;

  setState(() {
    _isInitializing = true;
    _errorMessage = '';
  });

  try {
    final user = FirebaseAuth.instance.currentUser;

    await _liveStreamService.startNurseryStationMode(
      stationUid: user?.uid ?? '',
      stationName: user?.displayName ?? 'محطة البث',
      stationRole: 'nursery_staff',
    );

    _localRenderer.srcObject = _liveStreamService.localStream;

    if (!mounted) return;

    setState(() {
      _isInitializing = false;
      _isStreaming = true;
    });
  } catch (_) {
    if (!mounted) return;

    setState(() {
      _isInitializing = false;
      _isStreaming = false;
      _errorMessage = 'تعذر تشغيل البث';
    });
  }
}

  Future<void> _stopStation({bool silent = false}) async {
  try {
    await _liveStreamService.stopNurseryStationMode();
    await _liveStreamService.dispose();
  } catch (_) {}

  if (!mounted || silent) return;

  setState(() {
    _isStreaming = false;
    _isInitializing = false;
  });
}

  Widget _buildStatusCard() {
    final color = _isStreaming ? Colors.green : Colors.orange;
    final title = _isStreaming ? 'البث مباشر الآن' : 'البث غير فعال';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                _isStreaming
                    ? Icons.wifi_tethering_rounded
                    : Icons.wifi_tethering_off_rounded,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          color: Colors.black,
          child: _isStreaming
              ? RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : const Center(
                  child: Icon(
                    Icons.videocam_off_outlined,
                    color: Colors.white70,
                    size: 46,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildErrorBox() {
    if (_errorMessage.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (_isInitializing) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (!_isStreaming)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startStation,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('تشغيل البث'),
            ),
          ),
        if (_isStreaming)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _stopStation,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('إيقاف البث'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'محطة البث المباشر',
      child: ListView(
        children: [
          _buildStatusCard(),
          const SizedBox(height: 12),
          _buildVideoPreview(),
          const SizedBox(height: 12),
          _buildErrorBox(),
          const SizedBox(height: 12),
          _buildActions(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}