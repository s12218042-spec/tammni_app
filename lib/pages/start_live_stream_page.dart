import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/live_stream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class StartLiveStreamPage extends StatefulWidget {
  const StartLiveStreamPage({super.key});

  @override
  State<StartLiveStreamPage> createState() => _StartLiveStreamPageState();
}

class _StartLiveStreamPageState extends State<StartLiveStreamPage>
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LiveStreamService _liveStreamService = LiveStreamService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _stationStateSubscription;

  Timer? _previewSyncTimer;

  bool _isInitializing = true;
  bool _isStopping = false;
  bool _isStationOnline = false;
  bool _isBroadcastActive = false;
  bool _rendererInitialized = false;

  int _activeConnectionsCount = 0;
  int _allocatedSlotsCount = 0;
  int _queueCount = 0;

  String _stationStatus = 'offline';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeStation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_liveStreamService.runStationMaintenance());
      _syncPreview();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _previewSyncTimer?.cancel();
    unawaited(_stationStateSubscription?.cancel());
    unawaited(_liveStreamService.stopNurseryStationMode());
    unawaited(_localRenderer.dispose());
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

  bool _canUseStation(String role) {
    final normalizedRole = _normalizeRole(role);

    return normalizedRole == 'admin' ||
        normalizedRole == 'nursery_staff';
  }

  Future<Map<String, dynamic>> _getCurrentUserData() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولًا.');
    }

    final userSnapshot =
        await _firestore.collection('users').doc(user.uid).get();

    final data = userSnapshot.data() ?? <String, dynamic>{};
    final role = _normalizeRole((data['role'] ?? '').toString());

    if (!_canUseStation(role)) {
      throw Exception('لا تملكين صلاحية تشغيل محطة البث.');
    }

    return {
      'uid': user.uid,
      'name': (data['displayName'] ??
              data['name'] ??
              data['fullName'] ??
              data['username'] ??
              user.displayName ??
              'محطة البث')
          .toString()
          .trim(),
      'role': role,
    };
  }

  Future<void> _initializeStation() async {
    try {
      await _localRenderer.initialize();
      _rendererInitialized = true;

      final userData = await _getCurrentUserData();

      await _liveStreamService.startNurseryStationMode(
        stationUid: userData['uid'].toString(),
        stationName: userData['name'].toString(),
        stationRole: userData['role'].toString(),
      );

      _listenToStationState();

      _previewSyncTimer?.cancel();

      _previewSyncTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _syncPreview(),
      );

      await _liveStreamService.runStationMaintenance();
      _syncPreview();

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _listenToStationState() {
    unawaited(_stationStateSubscription?.cancel());

    _stationStateSubscription =
        _liveStreamService.watchNurseryStationState().listen(
      (snapshot) {
        if (!mounted || !snapshot.exists) return;

        final data = snapshot.data() ?? <String, dynamic>{};

        setState(() {
          _stationStatus = (data['status'] ?? 'offline').toString();
          _isStationOnline = data['stationOnline'] == true;

          _isBroadcastActive = data['isActive'] == true &&
              (_stationStatus == 'active' ||
                  _liveStreamService.stationBroadcastActive);

          _activeConnectionsCount = _asInt(
            data['activeConnectionsCount'],
          );

          _allocatedSlotsCount = _asInt(
            data['allocatedSlotsCount'],
          );

          _queueCount = _asInt(
            data['queueCount'],
          );
        });

        _syncPreview();
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          _errorMessage = 'تعذر متابعة حالة محطة البث.';
        });
      },
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _syncPreview() {
    if (!mounted || !_rendererInitialized) return;

    final stream = _liveStreamService.localStream;

    if (identical(_localRenderer.srcObject, stream)) return;

    setState(() {
      _localRenderer.srcObject = stream;

      _isBroadcastActive = stream != null &&
          (_stationStatus == 'active' ||
              _liveStreamService.stationBroadcastActive);
    });
  }

  Future<void> _retryStation() async {
    if (_isInitializing) return;

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      await _liveStreamService.runStationMaintenance();
      _syncPreview();

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _stopCurrentBroadcast() async {
    if (_isStopping || !_isBroadcastActive) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إيقاف البث؟'),
            content: const Text(
              'سيتم إيقاف البث الحالي للمشاهدين.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('إيقاف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isStopping = true;
      _errorMessage = null;
    });

    try {
      await _liveStreamService.stopNurseryStationStream(
        reason: 'manual_stop_from_station_page',
      );

      _syncPreview();

      if (!mounted) return;

      setState(() {
        _isStopping = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isStopping = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Color _statusColor() {
    if (!_isStationOnline) return Colors.orange;
    if (_isBroadcastActive) return Colors.red;

    return Colors.green;
  }

  String _statusTitle() {
    if (!_isStationOnline) return 'المحطة غير متصلة';
    if (_isBroadcastActive) return 'البث مباشر الآن';
    if (_stationStatus == 'starting') return 'جارٍ تشغيل البث';

    return 'محطة البث جاهزة';
  }

  String _statusSubtitle() {
    if (!_isStationOnline) return 'أعيدي تشغيل المحطة.';

    if (_isBroadcastActive) {
      return 'الكاميرا تعمل للمشاهدين الحاليين.';
    }

    if (_stationStatus == 'starting') {
      return 'سيتم تشغيل الكاميرا تلقائيًا.';
    }

    return 'ستعمل الكاميرا تلقائيًا عند وجود طلب مشاهدة.';
  }

  Widget _buildPreviewCard() {
    return Container(
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
                    child: Icon(
                      Icons.videocam_off_rounded,
                      color: Colors.white70,
                      size: 54,
                    ),
                  )
                : RTCVideoView(
                    _localRenderer,
                    mirror: false,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: _isBroadcastActive
                    ? Colors.red
                    : Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _isBroadcastActive ? 'LIVE' : 'جاهزة',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final color = _statusColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(
              _isBroadcastActive
                  ? Icons.wifi_tethering_rounded
                  : Icons.check_circle_outline_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusTitle(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusSubtitle(),
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'يشاهدون الآن',
              _activeConnectionsCount,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: AppColors.border,
          ),
          Expanded(
            child: _buildStatItem(
              'محجوزة',
              _allocatedSlotsCount,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: AppColors.border,
          ),
          Expanded(
            child: _buildStatItem(
              'بالانتظار',
              _queueCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    if (_errorMessage == null || _errorMessage!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        _errorMessage!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AppPageScaffold(
        title: 'محطة البث المباشر',
        actions: [
          IconButton(
            onPressed: _isInitializing ? null : _retryStation,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
        child: _isInitializing
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : ListView(
                children: [
                  _buildPreviewCard(),
                  const SizedBox(height: 16),
                  _buildStatusCard(),
                  const SizedBox(height: 14),
                  _buildStatsCard(),
                  if (_errorMessage != null) const SizedBox(height: 14),
                  _buildErrorCard(),
                  if (_isBroadcastActive) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed:
                          _isStopping ? null : _stopCurrentBroadcast,
                      icon: _isStopping
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.stop_circle_outlined,
                            ),
                      label: Text(
                        _isStopping
                            ? 'جارٍ الإيقاف...'
                            : 'إيقاف البث الحالي',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          52,
                        ),
                        foregroundColor: Colors.red,
                        side: const BorderSide(
                          color: Colors.red,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
      ),
    );
  }
}

