import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'app_notification_service.dart';

class LiveStreamRequestResult {
  final String requestId;
  final String status;
  final int queuePosition;
  final bool hasActiveStream;

  const LiveStreamRequestResult({
    required this.requestId,
    required this.status,
    required this.queuePosition,
    required this.hasActiveStream,
  });
}

class LiveStreamService {
  LiveStreamService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String nurseryMainStreamId = 'nursery_main_stream';

  static const int maxConcurrentViewers = 3;
  static const Duration normalViewingDuration = Duration(minutes: 10);
  static const Duration congestedViewingDuration = Duration(minutes: 5);
  static const Duration readyJoinTimeout = Duration(minutes: 2);
  static const Duration stationHeartbeatInterval = Duration(seconds: 15);
  static const Duration stationOfflineAfter = Duration(seconds: 45);
  static const Duration maintenanceInterval = Duration(seconds: 10);

  final FirebaseFirestore _firestore;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final Map<String, RTCPeerConnection> _hostPeerConnections = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _hostCandidateSubscriptions = {};

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _roomSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _queueSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _viewersSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _viewerDocSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _viewerEntitlementSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _viewerHostCandidatesSubscription;

  Timer? _stationHeartbeatTimer;
  Timer? _stationMaintenanceTimer;

  String? _currentRoomId;
  String? _currentViewerId;
  String? _currentRequestId;

  String _stationUid = '';
  String _stationName = '';
  String _stationRole = 'nursery_staff';

  bool _stationModeEnabled = false;
  bool _stationBroadcastActive = false;
  bool _stationMaintenanceRunning = false;
  bool _viewerClosing = false;
  bool _isDisposed = false;

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  String? get currentRoomId => _currentRoomId;
  String? get currentRequestId => _currentRequestId;
  bool get stationModeEnabled => _stationModeEnabled;
  bool get stationBroadcastActive => _stationBroadcastActive;

  DocumentReference<Map<String, dynamic>> get _mainRoomRef =>
      _firestore.collection('live_streams').doc(nurseryMainStreamId);

  CollectionReference<Map<String, dynamic>> get _queueRef =>
      _mainRoomRef.collection('queue');

  CollectionReference<Map<String, dynamic>> get _viewersRef =>
      _mainRoomRef.collection('viewers');

  final Map<String, dynamic> _rtcConfiguration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ],
      },
    ],
  };

  final Map<String, dynamic> _mediaConstraints = {
    'audio': true,
    'video': {
      'facingMode': 'environment',
      'width': {
        'ideal': 1280,
      },
      'height': {
        'ideal': 720,
      },
      'frameRate': {
        'ideal': 24,
      },
    },
  };

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _normalizeRole(String value) {
    final role = value.trim().toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }

    return role;
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isStationHeartbeatFresh(Map<String, dynamic> roomData) {
    final lastHeartbeatAt = _dateFromDynamic(roomData['lastHeartbeatAt']);
    if (lastHeartbeatAt == null) return false;

    return DateTime.now().difference(lastHeartbeatAt) <= stationOfflineAfter;
  }

  Future<void> _ensureMainRoomDocument() async {
    final snapshot = await _mainRoomRef.get();

    if (snapshot.exists) return;

    await _mainRoomRef.set({
      'roomId': nurseryMainStreamId,
      'title': 'البث المباشر من الحضانة',
      'scope': 'nursery',
      'status': 'idle',
      'isActive': false,
      'stationOnline': false,
      'stationUid': '',
      'stationName': '',
      'stationRole': 'nursery_staff',
      'maxViewers': maxConcurrentViewers,
      'allocatedSlotsCount': 0,
      'activeConnectionsCount': 0,
      'queueCount': 0,
      'startedAt': null,
      'endedAt': null,
      'lastHeartbeatAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<MediaStream> openUserMedia() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia(
        _mediaConstraints,
      );
      return _localStream!;
    } catch (e) {
      debugPrint('openUserMedia error: $e');
      rethrow;
    }
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final pc = await createPeerConnection(_rtcConfiguration);

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('ICE connection state: $state');
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('Peer connection state: $state');
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
      }
    };

    return pc;
  }

  int _readSdpMLineIndex(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  RTCIceCandidate? _buildIceCandidateFromData(Map<String, dynamic> data) {
    final candidateText = (data['candidate'] ?? '').toString().trim();

    if (candidateText.isEmpty) return null;

    return RTCIceCandidate(
      candidateText,
      (data['sdpMid'] ?? '').toString(),
      _readSdpMLineIndex(data['sdpMLineIndex']),
    );
  }

  Future<Map<String, dynamic>?> getNurseryStationState() async {
    await _ensureMainRoomDocument();

    final snapshot = await _mainRoomRef.get();
    final data = snapshot.data();

    if (data == null) return null;

    return {
      'id': snapshot.id,
      ...data,
      'stationOnlineNow': _isStationHeartbeatFresh(data),
    };
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchNurseryStationState() {
    return _mainRoomRef.snapshots();
  }

  Future<bool> isNurseryStationOnline() async {
    final state = await getNurseryStationState();
    if (state == null) return false;

    return state['stationOnline'] == true &&
        _isStationHeartbeatFresh(state);
  }

  Future<void> startNurseryStationMode({
    required String stationUid,
    required String stationName,
    String stationRole = 'nursery_staff',
  }) async {
    if (_isDisposed) return;

    _stationUid = stationUid.trim();
    _stationName = stationName.trim().isEmpty ? 'محطة البث' : stationName.trim();
    _stationRole = _normalizeRole(stationRole);
    _stationModeEnabled = true;

    await _ensureMainRoomDocument();
    await _writeStationHeartbeat();

    _stationHeartbeatTimer?.cancel();
    _stationHeartbeatTimer = Timer.periodic(
      stationHeartbeatInterval,
      (_) => _writeStationHeartbeat(),
    );

    _stationMaintenanceTimer?.cancel();
    _stationMaintenanceTimer = Timer.periodic(
      maintenanceInterval,
      (_) => runStationMaintenance(),
    );

    _roomSubscription?.cancel();
    _roomSubscription = _mainRoomRef.snapshots().listen(
      (snapshot) async {
        if (_isDisposed || !_stationModeEnabled || !snapshot.exists) return;

        final data = snapshot.data();
        if (data == null) return;

        final status = _cleanText(data['status']);
        final allocatedSlotsCount = _asInt(data['allocatedSlotsCount']);

        if ((status == 'starting' || status == 'active') &&
            allocatedSlotsCount > 0 &&
            !_stationBroadcastActive) {
          await startNurseryStationStream();
          return;
        }

        if ((status == 'idle' || status == 'offline') &&
            _stationBroadcastActive) {
          await _releaseStationBroadcastResources();
        }
      },
      onError: (Object error) {
        debugPrint('station room listener error: $error');
      },
    );

    _queueSubscription?.cancel();
    _queueSubscription = _queueRef.snapshots().listen(
      (_) => runStationMaintenance(),
      onError: (Object error) {
        debugPrint('station queue listener error: $error');
      },
    );

    await runStationMaintenance();
  }

  Future<void> stopNurseryStationMode() async {
    _stationModeEnabled = false;

    _stationHeartbeatTimer?.cancel();
    _stationMaintenanceTimer?.cancel();
    _stationHeartbeatTimer = null;
    _stationMaintenanceTimer = null;

    await _queueSubscription?.cancel();
    _queueSubscription = null;

    await _roomSubscription?.cancel();
    _roomSubscription = null;

    await _releaseStationBroadcastResources();

    try {
      await _mainRoomRef.set({
        'status': 'offline',
        'isActive': false,
        'stationOnline': false,
        'activeConnectionsCount': 0,
        'endedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('stop nursery station mode error: $e');
    }
  }

  Future<void> _writeStationHeartbeat() async {
    if (_isDisposed || !_stationModeEnabled) return;

    try {
      await _mainRoomRef.set({
        'roomId': nurseryMainStreamId,
        'scope': 'nursery',
        'stationUid': _stationUid,
        'stationName': _stationName,
        'stationRole': _stationRole,
        'stationOnline': true,
        'lastHeartbeatAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('station heartbeat error: $e');
    }
  }

  Future<void> startNurseryStationStream() async {
    if (_isDisposed || !_stationModeEnabled || _stationBroadcastActive) return;

    try {
      _localStream ??= await openUserMedia();
      _currentRoomId = nurseryMainStreamId;
      _stationBroadcastActive = true;

      await _mainRoomRef.set({
        'roomId': nurseryMainStreamId,
        'title': 'البث المباشر من الحضانة',
        'scope': 'nursery',
        'status': 'active',
        'isActive': true,
        'stationOnline': true,
        'stationUid': _stationUid,
        'stationName': _stationName,
        'stationRole': _stationRole,
        'maxViewers': maxConcurrentViewers,
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
        'lastHeartbeatAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _listenForViewers(_mainRoomRef);
    } catch (e) {
      _stationBroadcastActive = false;
      debugPrint('start nursery station stream error: $e');

      await _mainRoomRef.set({
        'status': 'idle',
        'isActive': false,
        'stationError': e.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      rethrow;
    }
  }

  Future<void> stopNurseryStationStream({
    String reason = 'no_viewers',
  }) async {
    try {
      await _releaseStationBroadcastResources();

      await _mainRoomRef.set({
        'status': 'idle',
        'isActive': false,
        'activeConnectionsCount': 0,
        'endedAt': FieldValue.serverTimestamp(),
        'endReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('stop nursery station stream error: $e');
    }
  }

  Future<void> runStationMaintenance() async {
    if (_isDisposed || !_stationModeEnabled || _stationMaintenanceRunning) {
      return;
    }

    _stationMaintenanceRunning = true;

    try {
      await _ensureMainRoomDocument();

      final now = DateTime.now();
      final queueSnapshot = await _queueRef.orderBy('requestedAt').get();

      final allocatedDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final queuedDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      for (final doc in queueSnapshot.docs) {
        final data = doc.data();
        final status = _cleanText(data['status']);

        if (status == 'ready') {
          final readyExpiresAt = _dateFromDynamic(data['readyExpiresAt']);

          if (readyExpiresAt != null && !readyExpiresAt.isAfter(now)) {
            await doc.reference.set({
              'status': 'expired',
              'expiredAt': FieldValue.serverTimestamp(),
              'expireReason': 'ready_timeout',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            continue;
          }

          allocatedDocs.add(doc);
          continue;
        }

        if (status == 'active') {
          final viewerExpiresAt = _dateFromDynamic(data['viewerExpiresAt']);

          if (viewerExpiresAt != null && !viewerExpiresAt.isAfter(now)) {
            await _expireActiveRequest(doc.reference);
            continue;
          }

          allocatedDocs.add(doc);
          continue;
        }

        if (status == 'queued' || status == 'waiting') {
          queuedDocs.add(doc);
        }
      }

      if (queuedDocs.isNotEmpty) {
        await _applyCongestedDurationLimit(allocatedDocs);
      }

      int availableSlots = maxConcurrentViewers - allocatedDocs.length;
      int promotedCount = 0;

      for (final doc in queuedDocs) {
        if (availableSlots <= 0) break;

        final data = doc.data();

        await doc.reference.set({
          'status': 'ready',
          'queuePosition': 0,
          'readyAt': FieldValue.serverTimestamp(),
          'readyExpiresAt': Timestamp.fromDate(
            DateTime.now().add(readyJoinTimeout),
          ),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        allocatedDocs.add(doc);
        availableSlots--;
        promotedCount++;

        await _sendAutomaticParentNotification(
          type: 'live_stream_request_ready',
          title: 'يمكنك الآن مشاهدة البث المباشر',
          body:
              'أصبح دورك متاحًا لمشاهدة البث المباشر للطفل ${_cleanText(data['childName']).isEmpty ? "الطفل" : _cleanText(data['childName'])}.',
          parentUid: _cleanText(data['parentUid']),
          parentUsername: _cleanText(data['parentUsername']),
          parentName: _cleanText(data['parentName']),
          childId: _cleanText(data['childId']),
          childName: _cleanText(data['childName']),
          requestId: doc.id,
        );
      }

      final refreshedSnapshot = await _queueRef.get();
      final refreshedAllocatedCount = refreshedSnapshot.docs.where((doc) {
        final status = _cleanText(doc.data()['status']);
        return status == 'ready' || status == 'active';
      }).length;
      final refreshedQueueCount = refreshedSnapshot.docs.where((doc) {
        final status = _cleanText(doc.data()['status']);
        return status == 'queued' || status == 'waiting';
      }).length;
      final activeConnectionsCount = refreshedSnapshot.docs.where((doc) {
        return _cleanText(doc.data()['status']) == 'active';
      }).length;

      final roomSnapshot = await _mainRoomRef.get();
      final roomData = roomSnapshot.data() ?? <String, dynamic>{};
      final roomStatus = _cleanText(roomData['status']);

      String nextRoomStatus = roomStatus;
      bool nextIsActive = roomData['isActive'] == true;

      if (refreshedAllocatedCount > 0 &&
          (roomStatus == 'idle' || roomStatus == 'offline')) {
        nextRoomStatus = 'starting';
        nextIsActive = false;
      }

      await _mainRoomRef.set({
        'allocatedSlotsCount': refreshedAllocatedCount,
        'activeConnectionsCount': activeConnectionsCount,
        'queueCount': refreshedQueueCount,
        'status': nextRoomStatus,
        'isActive': nextIsActive,
        'maxViewers': maxConcurrentViewers,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (refreshedAllocatedCount == 0 &&
          refreshedQueueCount == 0 &&
          _stationBroadcastActive) {
        await stopNurseryStationStream(reason: 'no_viewers_or_queue');
      }

      if (promotedCount > 0 && !_stationBroadcastActive) {
        await startNurseryStationStream();
      }
    } catch (e) {
      debugPrint('run station maintenance error: $e');
    } finally {
      _stationMaintenanceRunning = false;
    }
  }

  Future<void> _applyCongestedDurationLimit(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allocatedDocs,
  ) async {
    for (final doc in allocatedDocs) {
      final data = doc.data();
      final status = _cleanText(data['status']);

      if (status != 'active') continue;

      final joinedAt = _dateFromDynamic(data['viewerJoinedAt']);
      final currentExpiresAt = _dateFromDynamic(data['viewerExpiresAt']);

      if (joinedAt == null || currentExpiresAt == null) continue;

      final congestedExpiresAt = joinedAt.add(congestedViewingDuration);

      if (!currentExpiresAt.isAfter(congestedExpiresAt)) continue;

      await doc.reference.set({
        'viewerExpiresAt': Timestamp.fromDate(congestedExpiresAt),
        'durationMode': 'congested',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _expireActiveRequest(
    DocumentReference<Map<String, dynamic>> requestRef,
  ) async {
    final requestId = requestRef.id;

    await requestRef.set({
      'status': 'expired',
      'expiredAt': FieldValue.serverTimestamp(),
      'expireReason': 'viewing_timeout',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await _viewersRef.doc(requestId).set({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    await _closeHostViewerConnection(requestId);
  }

  Future<void> expireReadyRequestsIfNeeded() async {
    await runStationMaintenance();
  }

  Future<LiveStreamRequestResult> requestLiveStreamForChild({
    required String childId,
    required String childName,
    required String parentUid,
    required String parentUsername,
    required String parentName,
    String section = 'Nursery',
    String group = '',
    String note = '',
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('يجب تسجيل الدخول لفتح البث المباشر.');
    }

    final cleanChildId = childId.trim();
    final cleanChildName = childName.trim();
    final cleanParentUid = parentUid.trim();
    final cleanParentUsername = parentUsername.trim().toLowerCase();
    final cleanParentName = parentName.trim();

    if (cleanChildId.isEmpty) {
      throw Exception('تعذر تحديد الطفل للبث المباشر.');
    }

    await _ensureMainRoomDocument();

    final roomSnapshot = await _mainRoomRef.get();
    final roomData = roomSnapshot.data() ?? <String, dynamic>{};

    if (roomData['stationOnline'] != true ||
        !_isStationHeartbeatFresh(roomData)) {
      throw Exception('البث المباشر غير متاح الآن.');
    }

    final existingSnapshot = await _queueRef
        .where('requesterAuthUid', isEqualTo: currentUser.uid)
        .where('childId', isEqualTo: cleanChildId)
        .get();

    for (final doc in existingSnapshot.docs) {
      final data = doc.data();
      final status = _cleanText(data['status']);

      if (status == 'ready' ||
          status == 'active' ||
          status == 'queued' ||
          status == 'waiting') {
        return LiveStreamRequestResult(
          requestId: doc.id,
          status: status,
          queuePosition: _asInt(data['queuePosition']),
          hasActiveStream: roomData['status'] == 'active',
        );
      }
    }

    final requestRef = _queueRef.doc();
    final now = Timestamp.now();

    late String status;
    late int queuePosition;
    late bool hasActiveStream;

    await _firestore.runTransaction((transaction) async {
      final freshRoomSnapshot = await transaction.get(_mainRoomRef);
      final freshRoomData = freshRoomSnapshot.data() ?? <String, dynamic>{};

      if (freshRoomData['stationOnline'] != true ||
          !_isStationHeartbeatFresh(freshRoomData)) {
        throw Exception('البث المباشر غير متاح الآن.');
      }

      final allocatedSlotsCount = _asInt(freshRoomData['allocatedSlotsCount']);
      final currentQueueCount = _asInt(freshRoomData['queueCount']);
      final roomStatus = _cleanText(freshRoomData['status']);

      hasActiveStream = roomStatus == 'active';

      if (allocatedSlotsCount < maxConcurrentViewers) {
        status = 'ready';
        queuePosition = 0;

        transaction.set(requestRef, {
          'requestId': requestRef.id,
          'requestType': 'nursery_live_stream',
          'status': status,
          'queuePosition': 0,
          'requesterAuthUid': currentUser.uid,
          'requesterIsAnonymous': currentUser.isAnonymous,
          'childId': cleanChildId,
          'childName': cleanChildName.isEmpty ? 'الطفل' : cleanChildName,
          'parentUid': cleanParentUid,
          'parentUsername': cleanParentUsername,
          'parentName': cleanParentName,
          'section': section.trim().isEmpty ? 'Nursery' : section.trim(),
          'group': group.trim(),
          'note': note.trim(),
          'requestedAt': now,
          'createdAt': now,
          'updatedAt': now,
          'readyAt': now,
          'readyExpiresAt': Timestamp.fromDate(
            DateTime.now().add(readyJoinTimeout),
          ),
        });

        transaction.set(
          _mainRoomRef,
          {
            'allocatedSlotsCount': allocatedSlotsCount + 1,
            'status': roomStatus == 'idle' || roomStatus == 'offline'
                ? 'starting'
                : roomStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        status = 'queued';
        queuePosition = currentQueueCount + 1;

        transaction.set(requestRef, {
          'requestId': requestRef.id,
          'requestType': 'nursery_live_stream',
          'status': status,
          'queuePosition': queuePosition,
          'requesterAuthUid': currentUser.uid,
          'requesterIsAnonymous': currentUser.isAnonymous,
          'childId': cleanChildId,
          'childName': cleanChildName.isEmpty ? 'الطفل' : cleanChildName,
          'parentUid': cleanParentUid,
          'parentUsername': cleanParentUsername,
          'parentName': cleanParentName,
          'section': section.trim().isEmpty ? 'Nursery' : section.trim(),
          'group': group.trim(),
          'note': note.trim(),
          'requestedAt': now,
          'createdAt': now,
          'updatedAt': now,
        });

        transaction.set(
          _mainRoomRef,
          {
            'queueCount': currentQueueCount + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });

    return LiveStreamRequestResult(
      requestId: requestRef.id,
      status: status,
      queuePosition: queuePosition,
      hasActiveStream: hasActiveStream,
    );
  }

  Future<Map<String, dynamic>?> getActiveLiveStreamIfExists() async {
    await _ensureMainRoomDocument();

    final snapshot = await _mainRoomRef.get();
    final data = snapshot.data();

    if (data == null) return null;
    if (_cleanText(data['status']) != 'active') return null;
    if (data['isActive'] != true) return null;
    if (!_isStationHeartbeatFresh(data)) return null;

    return {
      'id': snapshot.id,
      ...data,
    };
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchLiveStreamRequests({
    List<String> statuses = const ['ready', 'queued', 'waiting', 'active'],
  }) {
    return _queueRef
        .where('status', whereIn: statuses)
        .orderBy('requestedAt', descending: false)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchLiveStreamRequest({
    required String requestId,
  }) {
    return _queueRef.doc(requestId).snapshots();
  }

  Future<void> cancelLiveStreamRequest({
    required String requestId,
    required String cancelledByUid,
    required String cancelledByRole,
  }) async {
    final requestRef = _queueRef.doc(requestId);
    final snapshot = await requestRef.get();

    if (!snapshot.exists) return;

    final data = snapshot.data() ?? <String, dynamic>{};
    final status = _cleanText(data['status']);

    if (status == 'completed' ||
        status == 'cancelled' ||
        status == 'rejected' ||
        status == 'expired') {
      return;
    }

    await requestRef.set({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledByUid': cancelledByUid.trim(),
      'cancelledByRole': _normalizeRole(cancelledByRole),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (status == 'active') {
      try {
        await _viewersRef.doc(requestId).set({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> rejectLiveStreamRequest({
    required String requestId,
    required String rejectedByUid,
    required String rejectedByName,
    required String rejectedByRole,
    String reason = '',
  }) async {
    final requestRef = _queueRef.doc(requestId);
    final snapshot = await requestRef.get();

    if (!snapshot.exists) return;

    await requestRef.set({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedByUid': rejectedByUid.trim(),
      'rejectedByName': rejectedByName.trim(),
      'rejectedByRole': _normalizeRole(rejectedByRole),
      'rejectReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> startLiveStream({
    required String title,
    required String startedByUid,
    required String startedByName,
    required String startedByRole,
    String? startedByPhotoUrl,
    String section = 'Nursery',
    String group = '',
    String allowedViewersType = 'all',
    bool notifyParents = true,
    String? requestId,
    String? childId,
    String? childName,
    String? parentUid,
    String? parentUsername,
    String? parentName,
    String liveStreamRequestId = '',
    String requestedChildId = '',
    String requestedChildName = '',
    String requestedParentUid = '',
    String requestedParentUsername = '',
  }) async {
    _stationUid = startedByUid.trim();
    _stationName = startedByName.trim().isEmpty
        ? 'محطة البث'
        : startedByName.trim();
    _stationRole = _normalizeRole(startedByRole);
    _stationModeEnabled = true;

    await _ensureMainRoomDocument();
    await startNurseryStationStream();

    return nurseryMainStreamId;
  }

  Future<void> joinLiveStream({
    required String roomId,
  }) async {
    try {
      _isDisposed = false;
      _currentRoomId = nurseryMainStreamId;

      if (roomId.trim().isNotEmpty && roomId.trim() != nurseryMainStreamId) {
        throw Exception('غرفة البث غير صحيحة.');
      }

      final roomSnapshot = await _mainRoomRef.get();
      final roomData = roomSnapshot.data();

      if (roomData == null ||
          _cleanText(roomData['status']) != 'active' ||
          roomData['isActive'] != true ||
          !_isStationHeartbeatFresh(roomData)) {
        throw Exception('البث غير نشط حاليًا.');
      }

      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول لمشاهدة البث.');
      }

      final entitlementSnapshot = await _queueRef
          .where('requesterAuthUid', isEqualTo: currentUser.uid)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? entitlementDoc;

      for (final doc in entitlementSnapshot.docs) {
        final status = _cleanText(doc.data()['status']);

        if (status == 'ready' || status == 'active') {
          entitlementDoc = doc;
          break;
        }
      }

      if (entitlementDoc == null) {
        throw Exception('لا يوجد دور متاح لك في البث المباشر.');
      }

      final entitlementData = entitlementDoc.data();
      final requestId = entitlementDoc.id;
      final queueCount = _asInt(roomData['queueCount']);
      final duration =
          queueCount > 0 ? congestedViewingDuration : normalViewingDuration;
      final viewerExpiresAt = DateTime.now().add(duration);

      _currentRequestId = requestId;
      _currentViewerId = requestId;

      _peerConnection = await _createPeerConnection();
      _remoteStream = await createLocalMediaStream('remoteStream');

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' || event.track.kind == 'audio') {
          _remoteStream?.addTrack(event.track);
        }
      };

      final viewerRef = _viewersRef.doc(requestId);
      final viewerCandidatesRef = viewerRef.collection('viewerCandidates');

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
        if (_isDisposed) return;

        await viewerCandidatesRef.add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'createdAt': FieldValue.serverTimestamp(),
        });
      };

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });

      await _peerConnection!.setLocalDescription(offer);

      await entitlementDoc.reference.set({
        'status': 'active',
        'viewerJoinedAt': FieldValue.serverTimestamp(),
        'viewerExpiresAt': Timestamp.fromDate(viewerExpiresAt),
        'durationMinutes': duration.inMinutes,
        'durationMode': queueCount > 0 ? 'congested' : 'normal',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await viewerRef.set({
        'viewerId': requestId,
        'requestId': requestId,
        'viewerUid': currentUser.uid,
        'viewerIsAnonymous': currentUser.isAnonymous,
        'parentUid': _cleanText(entitlementData['parentUid']),
        'parentUsername': _cleanText(entitlementData['parentUsername']),
        'childId': _cleanText(entitlementData['childId']),
        'childName': _cleanText(entitlementData['childName']),
        'status': 'waiting',
        'viewerExpiresAt': Timestamp.fromDate(viewerExpiresAt),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      }, SetOptions(merge: true));

      _listenForViewerAnswer(viewerRef);
      _listenForHostCandidates(viewerRef);
      _listenForRoomEnded(_mainRoomRef);
      _listenForViewerEntitlement(entitlementDoc.reference);
    } catch (e) {
      debugPrint('joinLiveStream error: $e');
      rethrow;
    }
  }

  void _listenForRoomEnded(DocumentReference<Map<String, dynamic>> roomRef) {
    _roomSubscription?.cancel();

    _roomSubscription = roomRef.snapshots().listen((snapshot) async {
      if (_isDisposed || !snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final status = _cleanText(data['status']);

      if (status == 'idle' || status == 'offline' || status == 'ended') {
        await close();
      }
    });
  }

  void _listenForViewerEntitlement(
    DocumentReference<Map<String, dynamic>> entitlementRef,
  ) {
    _viewerEntitlementSubscription?.cancel();

    _viewerEntitlementSubscription = entitlementRef.snapshots().listen(
      (snapshot) async {
        if (_isDisposed || !snapshot.exists) return;

        final status = _cleanText(snapshot.data()?['status']);

        if (status == 'expired' ||
            status == 'cancelled' ||
            status == 'completed' ||
            status == 'rejected') {
          await close(markRequestCompleted: false);
        }
      },
      onError: (Object error) {
        debugPrint('viewer entitlement listener error: $error');
      },
    );
  }

  void _listenForViewers(DocumentReference<Map<String, dynamic>> roomRef) {
    _viewersSubscription?.cancel();

    _viewersSubscription = roomRef.collection('viewers').snapshots().listen(
      (snapshot) async {
        if (_isDisposed || !_stationBroadcastActive) return;

        for (final change in snapshot.docChanges) {
          final viewerId = change.doc.id;
          final data = change.doc.data();

          if (data == null) continue;

          final status = _cleanText(data['status']);

          if (status == 'left' || status == 'ended') {
            await _closeHostViewerConnection(viewerId);
            continue;
          }

          if (change.type != DocumentChangeType.added &&
              change.type != DocumentChangeType.modified) {
            continue;
          }

          if (_hostPeerConnections.containsKey(viewerId)) continue;
          if (data['offer'] == null) continue;

          await _answerViewer(
            roomRef: roomRef,
            viewerId: viewerId,
            viewerData: data,
          );
        }
      },
      onError: (Object error) {
        debugPrint('station viewers listener error: $error');
      },
    );
  }

  Future<void> _answerViewer({
    required DocumentReference<Map<String, dynamic>> roomRef,
    required String viewerId,
    required Map<String, dynamic> viewerData,
  }) async {
    try {
      if (_localStream == null) return;

      final viewerRef = roomRef.collection('viewers').doc(viewerId);
      final pc = await _createPeerConnection();
      _hostPeerConnections[viewerId] = pc;

      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }

      final hostCandidatesRef = viewerRef.collection('hostCandidates');

      pc.onIceCandidate = (RTCIceCandidate candidate) async {
        if (_isDisposed) return;

        await hostCandidatesRef.add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'createdAt': FieldValue.serverTimestamp(),
        });
      };

      final offer = viewerData['offer'];
      final rtcOffer = RTCSessionDescription(
        offer['sdp']?.toString(),
        offer['type']?.toString(),
      );

      await pc.setRemoteDescription(rtcOffer);

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      await viewerRef.set({
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
        'status': 'connected',
        'hostAnsweredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _listenForViewerCandidates(
        viewerRef: viewerRef,
        viewerId: viewerId,
        peerConnection: pc,
      );
    } catch (e) {
      debugPrint('answer viewer error: $e');
    }
  }

  void _listenForViewerCandidates({
    required DocumentReference<Map<String, dynamic>> viewerRef,
    required String viewerId,
    required RTCPeerConnection peerConnection,
  }) {
    _hostCandidateSubscriptions[viewerId]?.cancel();

    _hostCandidateSubscriptions[viewerId] = viewerRef
        .collection('viewerCandidates')
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) async {
      if (_isDisposed) return;

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final data = change.doc.data();
        if (data == null) continue;

        final candidate = _buildIceCandidateFromData(data);
        if (candidate == null) continue;

        await peerConnection.addCandidate(candidate);
      }
    });
  }

  void _listenForViewerAnswer(
    DocumentReference<Map<String, dynamic>> viewerRef,
  ) {
    _viewerDocSubscription?.cancel();

    _viewerDocSubscription = viewerRef.snapshots().listen((snapshot) async {
      if (_isDisposed || !snapshot.exists || _peerConnection == null) return;

      final data = snapshot.data();
      if (data == null) return;

      final status = _cleanText(data['status']);

      if (status == 'ended' || status == 'left') {
        await close(markRequestCompleted: false);
        return;
      }

      final answer = data['answer'];
      if (answer == null) return;

      final currentRemoteDescription =
          await _peerConnection!.getRemoteDescription();

      if (currentRemoteDescription != null) return;

      final rtcAnswer = RTCSessionDescription(
        answer['sdp']?.toString(),
        answer['type']?.toString(),
      );

      await _peerConnection!.setRemoteDescription(rtcAnswer);
    });
  }

  void _listenForHostCandidates(
    DocumentReference<Map<String, dynamic>> viewerRef,
  ) {
    _viewerHostCandidatesSubscription?.cancel();

    _viewerHostCandidatesSubscription = viewerRef
        .collection('hostCandidates')
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) async {
      if (_isDisposed || _peerConnection == null) return;

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final data = change.doc.data();
        if (data == null) continue;

        final candidate = _buildIceCandidateFromData(data);
        if (candidate == null) continue;

        await _peerConnection!.addCandidate(candidate);
      }
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchActiveLiveStreams({
    String? section,
    String? group,
    String? parentUid,
    String? childId,
  }) {
    return _firestore
        .collection('live_streams')
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  Future<void> endLiveStream({
    required String roomId,
  }) async {
    await stopNurseryStationStream(reason: 'manual_stop');
  }

  Future<void> close({
    bool markRequestCompleted = true,
  }) async {
    if (_viewerClosing) return;
    _viewerClosing = true;

    final requestId = _currentRequestId;
    final viewerId = _currentViewerId;

    try {
      if (viewerId != null) {
        try {
          await _viewersRef.doc(viewerId).set({
            'status': 'left',
            'leftAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      if (markRequestCompleted && requestId != null) {
        try {
          final requestRef = _queueRef.doc(requestId);
          final requestSnapshot = await requestRef.get();
          final status = _cleanText(requestSnapshot.data()?['status']);

          if (status == 'active' || status == 'ready') {
            await requestRef.set({
              'status': 'completed',
              'endedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        } catch (_) {}
      }

      await _viewerDocSubscription?.cancel();
      await _viewerEntitlementSubscription?.cancel();
      await _viewerHostCandidatesSubscription?.cancel();

      _viewerDocSubscription = null;
      _viewerEntitlementSubscription = null;
      _viewerHostCandidatesSubscription = null;

      try {
        final senders = await _peerConnection?.getSenders();
        if (senders != null) {
          for (final sender in senders) {
            try {
              await _peerConnection?.removeTrack(sender);
            } catch (_) {}
          }
        }
      } catch (_) {}

      try {
        await _peerConnection?.close();
      } catch (_) {}

      try {
        for (final track in _remoteStream?.getTracks() ?? <MediaStreamTrack>[]) {
          track.stop();
        }
      } catch (_) {}

      try {
        await _remoteStream?.dispose();
      } catch (_) {}

      _peerConnection = null;
      _remoteStream = null;
      _currentViewerId = null;
      _currentRequestId = null;

      if (!_stationModeEnabled) {
        await _roomSubscription?.cancel();
        _roomSubscription = null;
        _currentRoomId = null;
      }
    } finally {
      _viewerClosing = false;
    }
  }

  Future<void> _releaseStationBroadcastResources() async {
    _stationBroadcastActive = false;

    await _viewersSubscription?.cancel();
    _viewersSubscription = null;

    for (final sub in _hostCandidateSubscriptions.values) {
      await sub.cancel();
    }
    _hostCandidateSubscriptions.clear();

    for (final pc in _hostPeerConnections.values) {
      try {
        final senders = await pc.getSenders();
        for (final sender in senders) {
          try {
            await pc.removeTrack(sender);
          } catch (_) {}
        }
      } catch (_) {}

      try {
        await pc.close();
      } catch (_) {}
    }

    _hostPeerConnections.clear();

    try {
      for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
        track.stop();
      }
    } catch (_) {}

    try {
      await _localStream?.dispose();
    } catch (_) {}

    _localStream = null;
  }

  Future<void> _closeHostViewerConnection(String viewerId) async {
    await _hostCandidateSubscriptions.remove(viewerId)?.cancel();

    final pc = _hostPeerConnections.remove(viewerId);
    if (pc == null) return;

    try {
      final senders = await pc.getSenders();
      for (final sender in senders) {
        try {
          await pc.removeTrack(sender);
        } catch (_) {}
      }
    } catch (_) {}

    try {
      await pc.close();
    } catch (_) {}
  }

  Future<void> _sendAutomaticParentNotification({
    required String type,
    required String title,
    required String body,
    required String parentUid,
    required String parentUsername,
    required String parentName,
    required String childId,
    required String childName,
    required String requestId,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userSnapshot =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userSnapshot.data() ?? <String, dynamic>{};

      final actorName = _cleanText(
        userData['displayName'] ??
            userData['name'] ??
            userData['username'] ??
            _stationName,
      );
      final actorRole = _normalizeRole(
        _cleanText(userData['role']).isEmpty
            ? _stationRole
            : _cleanText(userData['role']),
      );

      if (parentUid.trim().isEmpty &&
          parentUsername.trim().isEmpty &&
          childId.trim().isEmpty) {
        return;
      }

      await AppNotificationService.instance.notifyChildParent(
        parentUid: parentUid.trim(),
        parentUsername: parentUsername.trim().toLowerCase(),
        parentName: parentName.trim(),
        title: title,
        body: body,
        type: type,
        childId: childId.trim(),
        childName: childName.trim(),
        section: 'Nursery',
        priority: 'important',
        createdByUid: currentUser.uid,
        createdByName: actorName.isEmpty ? 'محطة البث' : actorName,
        createdByRole: actorRole.isEmpty ? 'nursery_staff' : actorRole,
        extraData: {
          'notificationType': type,
          'category': 'live_stream',
          'templateType': 'live_stream',
          'roomId': nurseryMainStreamId,
          'liveStreamId': nurseryMainStreamId,
          'requestId': requestId,
          'route': 'live_stream',
          'screen': 'live_stream',
        },
      );
    } catch (e) {
      debugPrint('send automatic live stream notification error: $e');
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;

    _stationHeartbeatTimer?.cancel();
    _stationMaintenanceTimer?.cancel();
    _stationHeartbeatTimer = null;
    _stationMaintenanceTimer = null;

    await _queueSubscription?.cancel();
    _queueSubscription = null;

    await close(markRequestCompleted: false);
    await _releaseStationBroadcastResources();

    await _roomSubscription?.cancel();
    _roomSubscription = null;
  }
}
