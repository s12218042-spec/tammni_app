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
  final FirebaseFirestore _firestore;

  LiveStreamService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final Map<String, RTCPeerConnection> _hostPeerConnections = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _hostCandidateSubscriptions = {};

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _roomSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _viewersSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _viewerDocSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _viewerHostCandidatesSubscription;

  String? _currentRoomId;
  String? _currentViewerId;
  bool _isDisposed = false;

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  String? get currentRoomId => _currentRoomId;

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
      'facingMode': 'user',
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

    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed ?? 0;
  }

  RTCIceCandidate? _buildIceCandidateFromData(Map<String, dynamic> data) {
    final candidateText = (data['candidate'] ?? '').toString().trim();

    if (candidateText.isEmpty) {
      return null;
    }

    return RTCIceCandidate(
      candidateText,
      (data['sdpMid'] ?? '').toString(),
      _readSdpMLineIndex(data['sdpMLineIndex']),
    );
  }

  Future<Map<String, dynamic>?> getActiveLiveStreamIfExists() async {
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

  Future<int> _nextQueuePosition() async {
    final snapshot = await _firestore
        .collection('live_stream_requests')
        .where('status', whereIn: ['queued', 'waiting'])
        .get();

    return snapshot.docs.length + 1;
  }

  Future<bool> _hasActiveOrReadyLiveStreamRequest() async {
    final snapshot = await _firestore
        .collection('live_stream_requests')
        .where('status', whereIn: ['active', 'ready'])
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Future<void> expireReadyRequestsIfNeeded() async {
    try {
      final now = DateTime.now();

      final snapshot = await _firestore
          .collection('live_stream_requests')
          .where('status', isEqualTo: 'ready')
          .limit(20)
          .get();

      bool expiredAnyRequest = false;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final expiresAt = _dateFromDynamic(data['readyExpiresAt']);

        if (expiresAt == null) continue;
        if (expiresAt.isAfter(now)) continue;

        await doc.reference.update({
          'status': 'expired',
          'expiredAt': FieldValue.serverTimestamp(),
          'expireReason': 'ready_timeout',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        expiredAnyRequest = true;

        await _sendNotificationToParent(
          type: 'live_stream_request_expired',
          title: 'انتهت مهلة البث المباشر',
          body:
              'انتهت مهلة استخدام البث المباشر للطفل ${(data['childName'] ?? 'الطفل').toString()}، وتم الانتقال للطلب التالي.',
          parentUid: (data['parentUid'] ?? '').toString(),
          parentUsername: (data['parentUsername'] ?? '').toString(),
          parentName: (data['parentName'] ?? '').toString(),
          childId: (data['childId'] ?? '').toString(),
          childName: (data['childName'] ?? '').toString(),
          roomId: '',
          requestId: doc.id,
          actorUid: 'system',
          actorName: 'النظام',
          actorRole: 'admin',
        );
      }

      if (expiredAnyRequest) {
        await _promoteNextQueuedRequest();
      }
    } catch (e) {
      debugPrint('expire ready live stream requests error: $e');
    }
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
    final cleanParentUid = parentUid.trim();
    final cleanParentUsername = parentUsername.trim().toLowerCase();
    final cleanChildId = childId.trim();
    final cleanChildName = childName.trim();
    final cleanParentName = parentName.trim();

    if (cleanChildId.isEmpty) {
      throw Exception('تعذر تحديد الطفل للبث المباشر.');
    }

    if (cleanParentUid.isEmpty) {
      throw Exception('تعذر تحديد ولي الأمر للبث المباشر.');
    }

    if (cleanParentUsername.isEmpty) {
      throw Exception('تعذر تحديد اسم مستخدم ولي الأمر.');
    }

    await expireReadyRequestsIfNeeded();

    final existingSnapshot = await _firestore
        .collection('live_stream_requests')
        .where('parentUid', isEqualTo: cleanParentUid)
        .where('childId', isEqualTo: cleanChildId)
        .where('status', whereIn: ['ready', 'queued', 'waiting', 'active'])
        .limit(1)
        .get();

    if (existingSnapshot.docs.isNotEmpty) {
      final doc = existingSnapshot.docs.first;
      final data = doc.data();

      return LiveStreamRequestResult(
        requestId: doc.id,
        status: (data['status'] ?? 'queued').toString(),
        queuePosition: (data['queuePosition'] is int)
            ? data['queuePosition'] as int
            : 0,
        hasActiveStream: (data['status'] ?? '').toString() == 'active',
      );
    }

    final hasActiveOrReady = await _hasActiveOrReadyLiveStreamRequest();

    final status = hasActiveOrReady ? 'queued' : 'ready';
    final queuePosition = hasActiveOrReady ? await _nextQueuePosition() : 0;

    final now = Timestamp.now();
    final requestRef = _firestore.collection('live_stream_requests').doc();

    await requestRef.set({
      'requestId': requestRef.id,
      'requestType': 'live_stream_direct',
      'status': status,
      'queuePosition': queuePosition,
      'childId': cleanChildId,
      'childName': cleanChildName.isEmpty ? 'الطفل' : cleanChildName,
      'parentUid': cleanParentUid,
      'parentUsername': cleanParentUsername,
      'parentName': cleanParentName,
      'requestedByUid': cleanParentUid,
      'requestedByRole': 'parent',
      'requestedByUsername': cleanParentUsername,
      'section': section.trim().isEmpty ? 'Nursery' : section.trim(),
      'group': group.trim(),
      'note': note.trim(),
      'activeStreamAtRequest': hasActiveOrReady,
      'activeRoomIdAtRequest': '',
      'requestedAt': now,
      'createdAt': now,
      'updatedAt': now,
      'readyAt': status == 'ready' ? now : null,
      'readyExpiresAt': status == 'ready'
          ? Timestamp.fromDate(
              DateTime.now().add(const Duration(minutes: 10)),
            )
          : null,
      'approvedAt': null,
      'startedAt': null,
      'endedAt': null,
      'approvedByUid': '',
      'approvedByName': '',
      'approvedByRole': '',
      'startedRoomId': '',
      'cancelledAt': null,
      'cancelledByUid': '',
      'cancelledByRole': '',
    });

    if (status == 'ready') {
      await _sendNotificationToAdmins(
        type: 'live_stream_request_ready',
        title: 'ولي أمر جاهز للبث المباشر',
        body:
            'ولي الأمر يريد فتح بث مباشر الآن للطفل ${cleanChildName.isEmpty ? "الطفل" : cleanChildName}.',
        childId: cleanChildId,
        childName: cleanChildName,
        requestId: requestRef.id,
        parentUid: cleanParentUid,
        parentUsername: cleanParentUsername,
        parentName: cleanParentName,
      );

      await _sendNotificationToParent(
        type: 'live_stream_request_ready',
        title: 'يمكنك الآن استخدام البث المباشر',
        body:
            'طلب البث المباشر للطفل ${cleanChildName.isEmpty ? "الطفل" : cleanChildName} أصبح جاهزًا. لديك 10 دقائق للبدء.',
        parentUid: cleanParentUid,
        parentUsername: cleanParentUsername,
        parentName: cleanParentName,
        childId: cleanChildId,
        childName: cleanChildName,
        roomId: '',
        requestId: requestRef.id,
        actorUid: 'system',
        actorName: 'النظام',
        actorRole: 'admin',
      );
    } else {
      await _sendNotificationToParent(
        type: 'live_stream_queued',
        title: 'تمت إضافتك إلى قائمة انتظار البث',
        body:
            'يوجد بث مباشر قائم حاليًا. تم وضعك في قائمة الانتظار، ورقمك: $queuePosition.',
        parentUid: cleanParentUid,
        parentUsername: cleanParentUsername,
        parentName: cleanParentName,
        childId: cleanChildId,
        childName: cleanChildName,
        roomId: '',
        requestId: requestRef.id,
        actorUid: 'system',
        actorName: 'النظام',
        actorRole: 'admin',
      );
    }

    return LiveStreamRequestResult(
      requestId: requestRef.id,
      status: status,
      queuePosition: queuePosition,
      hasActiveStream: hasActiveOrReady,
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchLiveStreamRequests({
    List<String> statuses = const ['ready', 'queued', 'waiting', 'active'],
  }) {
    return _firestore
        .collection('live_stream_requests')
        .where('status', whereIn: statuses)
        .orderBy('requestedAt', descending: false)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchLiveStreamRequest({
    required String requestId,
  }) {
    return _firestore
        .collection('live_stream_requests')
        .doc(requestId)
        .snapshots();
  }

  Future<void> cancelLiveStreamRequest({
    required String requestId,
    required String cancelledByUid,
    required String cancelledByRole,
  }) async {
    final requestRef =
        _firestore.collection('live_stream_requests').doc(requestId);

    final snapshot = await requestRef.get();

    if (!snapshot.exists) return;

    final data = snapshot.data() ?? <String, dynamic>{};
    final status = (data['status'] ?? '').toString();

    if (status == 'active') {
      throw Exception('لا يمكن إلغاء بث بدأ بالفعل.');
    }

    if (status == 'completed' ||
        status == 'cancelled' ||
        status == 'rejected' ||
        status == 'expired') {
      return;
    }

    await requestRef.update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledByUid': cancelledByUid,
      'cancelledByRole': _normalizeRole(cancelledByRole),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectLiveStreamRequest({
    required String requestId,
    required String rejectedByUid,
    required String rejectedByName,
    required String rejectedByRole,
    String reason = '',
  }) async {
    final requestRef =
        _firestore.collection('live_stream_requests').doc(requestId);

    final snapshot = await requestRef.get();

    if (!snapshot.exists) return;

    final data = snapshot.data() ?? <String, dynamic>{};

    await requestRef.update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedByUid': rejectedByUid,
      'rejectedByName': rejectedByName,
      'rejectedByRole': _normalizeRole(rejectedByRole),
      'rejectReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _sendNotificationToParent(
      type: 'live_stream_request_rejected',
      title: 'تعذر بدء البث المباشر',
      body: reason.trim().isEmpty
          ? 'تم رفض طلب البث المباشر حاليًا.'
          : 'تم رفض طلب البث المباشر: ${reason.trim()}',
      parentUid: (data['parentUid'] ?? '').toString(),
      parentUsername: (data['parentUsername'] ?? '').toString(),
      parentName: (data['parentName'] ?? '').toString(),
      childId: (data['childId'] ?? '').toString(),
      childName: (data['childName'] ?? '').toString(),
      roomId: '',
      requestId: requestId,
      actorUid: rejectedByUid,
      actorName: rejectedByName,
      actorRole: _normalizeRole(rejectedByRole),
    );
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
    try {
      _isDisposed = false;

      _localStream ??= await openUserMedia();

      final cleanRequestId = liveStreamRequestId.trim().isNotEmpty
          ? liveStreamRequestId.trim()
          : (requestId?.trim() ?? '');

      final cleanParentUid = requestedParentUid.trim().isNotEmpty
          ? requestedParentUid.trim()
          : (parentUid?.trim() ?? '');

      final cleanParentUsername = requestedParentUsername.trim().isNotEmpty
          ? requestedParentUsername.trim().toLowerCase()
          : (parentUsername?.trim().toLowerCase() ?? '');

      final cleanChildId = requestedChildId.trim().isNotEmpty
          ? requestedChildId.trim()
          : (childId?.trim() ?? '');

      final cleanChildName = requestedChildName.trim().isNotEmpty
          ? requestedChildName.trim()
          : (childName?.trim() ?? '');

      final isIndividualStream = cleanRequestId.isNotEmpty ||
          cleanParentUid.isNotEmpty ||
          cleanParentUsername.isNotEmpty ||
          cleanChildId.isNotEmpty;

      final cleanAllowedViewersType = cleanChildId.isNotEmpty
          ? 'specific_child'
          : isIndividualStream
              ? 'individual_parent'
              : allowedViewersType.trim().isEmpty
                  ? 'all'
                  : allowedViewersType.trim();

      final roomRef = _firestore.collection('live_streams').doc();
      final roomId = roomRef.id;
      _currentRoomId = roomId;

      final cleanTitle =
          title.trim().isEmpty ? 'بث مباشر من الحضانة' : title.trim();

      await roomRef.set({
        'title': cleanTitle,
        'status': 'active',
        'roomId': roomId,
        'requestId': cleanRequestId,
        'childId': cleanChildId,
        'childName': cleanChildName,
        'parentUid': cleanParentUid,
        'parentUsername': cleanParentUsername,
        'liveStreamRequestId': cleanRequestId,
        'requestedChildId': cleanChildId,
        'requestedChildName': cleanChildName,
        'requestedParentUid': cleanParentUid,
        'requestedParentUsername': cleanParentUsername,
        'parentName': parentName?.trim() ?? '',
        'startedByUid': startedByUid,
        'startedByName': startedByName,
        'startedByRole': _normalizeRole(startedByRole),
        'startedByPhotoUrl': startedByPhotoUrl ?? '',
        'section': section.trim().isEmpty ? 'Nursery' : section.trim(),
        'group': group.trim(),
        'allowedViewersType': cleanAllowedViewersType,
        'targetParentUid': cleanParentUid,
        'targetParentUsername': cleanParentUsername,
        'targetChildId': cleanChildId,
        'maxViewers': cleanChildId.isNotEmpty || isIndividualStream ? 1 : 3,
        'notifyParents': notifyParents,
        'isIndividualStream': isIndividualStream,
        'isChildSpecificStream': cleanChildId.isNotEmpty,
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (cleanRequestId.isNotEmpty) {
        await _firestore
            .collection('live_stream_requests')
            .doc(cleanRequestId)
            .set({
          'status': 'active',
          'startedRoomId': roomId,
          'startedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (notifyParents) {
        if (isIndividualStream) {
          await _sendNotificationToParent(
            type: 'live_stream_started',
            title: 'بدأ البث المباشر لطفلك الآن',
            body:
                'تم بدء البث المباشر للطفل ${cleanChildName.isEmpty ? "الطفل" : cleanChildName}. اضغطي للمشاهدة.',
            parentUid: cleanParentUid,
            parentUsername: cleanParentUsername,
            parentName: parentName?.trim() ?? '',
            childId: cleanChildId,
            childName: cleanChildName,
            roomId: roomId,
            requestId: cleanRequestId,
            actorUid: startedByUid,
            actorName: startedByName,
            actorRole: _normalizeRole(startedByRole),
          );
        } else {
          await _sendLiveStreamNotificationToParents(
            type: 'live_stream_started',
            title: 'بدأ بث مباشر الآن',
            body:
                '${startedByName.trim().isEmpty ? "الحضانة" : startedByName} بدأ بثًا مباشرًا. اضغطي للمشاهدة.',
            roomId: roomId,
            streamTitle: cleanTitle,
            actorUid: startedByUid,
            actorName: startedByName,
            actorRole: _normalizeRole(startedByRole),
          );
        }
      }

      _listenForRoomEnded(roomRef);
      _listenForViewers(roomRef);

      return roomId;
    } catch (e) {
      debugPrint('startLiveStream error: $e');
      rethrow;
    }
  }

  void _listenForRoomEnded(DocumentReference<Map<String, dynamic>> roomRef) {
    _roomSubscription?.cancel();

    _roomSubscription = roomRef.snapshots().listen((snapshot) async {
      if (_isDisposed) return;
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      if (data['status'] == 'ended') {
        await close();
      }
    });
  }

  void _listenForViewers(DocumentReference<Map<String, dynamic>> roomRef) {
    _viewersSubscription?.cancel();

    _viewersSubscription = roomRef
        .collection('viewers')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((snapshot) async {
      if (_isDisposed) return;

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added &&
            change.type != DocumentChangeType.modified) {
          continue;
        }

        final viewerId = change.doc.id;
        final data = change.doc.data();

        if (data == null) continue;
        if (_hostPeerConnections.containsKey(viewerId)) continue;

        final offer = data['offer'];
        if (offer == null) continue;

        await _answerViewer(
          roomRef: roomRef,
          viewerId: viewerId,
          viewerData: data,
        );
      }
    });
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

      await viewerRef.update({
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
        'status': 'connected',
        'hostAnsweredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

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

  Future<void> joinLiveStream({
    required String roomId,
  }) async {
    try {
      _isDisposed = false;
      _currentRoomId = roomId;

      final roomRef = _firestore.collection('live_streams').doc(roomId);
      final roomSnapshot = await roomRef.get();

      if (!roomSnapshot.exists) {
        throw Exception('البث غير موجود.');
      }

      final roomData = roomSnapshot.data();
      if (roomData == null) {
        throw Exception('بيانات البث غير متوفرة.');
      }

      if (roomData['status'] != 'active') {
        throw Exception('البث غير نشط حاليًا.');
      }

      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول لمشاهدة البث.');
      }

      final allowedViewersType =
          (roomData['allowedViewersType'] ?? '').toString().trim();

      if (allowedViewersType == 'individual_parent') {
        final targetParentUid =
            (roomData['targetParentUid'] ?? roomData['parentUid'] ?? '')
                .toString()
                .trim();

        if (targetParentUid.isNotEmpty && targetParentUid != currentUser.uid) {
          throw Exception('هذا البث مخصص لولي أمر آخر.');
        }
      }

      if (allowedViewersType == 'specific_child') {
        final targetChildId = _cleanText(
          roomData['childId'] ?? roomData['requestedChildId'],
        );

        if (targetChildId.isEmpty) {
          throw Exception('بيانات الطفل غير متوفرة لهذا البث.');
        }

        if (currentUser.isAnonymous) {
          final deviceSnapshot = await _firestore
              .collection('temporary_parent_devices')
              .where('authUid', isEqualTo: currentUser.uid)
              .where('childId', isEqualTo: targetChildId)
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();

          if (deviceSnapshot.docs.isEmpty) {
            throw Exception('هذا البث مخصص لطفل آخر.');
          }
        } else {
          final targetParentUid =
              (roomData['targetParentUid'] ?? roomData['parentUid'] ?? '')
                  .toString()
                  .trim();

          if (targetParentUid.isNotEmpty && targetParentUid != currentUser.uid) {
            throw Exception('هذا البث مخصص لولي أمر آخر.');
          }
        }
      }

      final viewerRef = roomRef.collection('viewers').doc();
      final viewerId = viewerRef.id;

      _currentViewerId = viewerId;

      _peerConnection = await _createPeerConnection();
      _remoteStream = await createLocalMediaStream('remoteStream');

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' || event.track.kind == 'audio') {
          _remoteStream?.addTrack(event.track);
        }
      };

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

      await viewerRef.set({
        'viewerId': viewerId,
        'viewerUid': currentUser.uid,
        'viewerIsAnonymous': currentUser.isAnonymous,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      });

      _listenForViewerAnswer(viewerRef);
      _listenForHostCandidates(viewerRef);
      _listenForRoomEnded(roomRef);
    } catch (e) {
      debugPrint('joinLiveStream error: $e');
      rethrow;
    }
  }

  void _listenForViewerAnswer(
    DocumentReference<Map<String, dynamic>> viewerRef,
  ) {
    _viewerDocSubscription?.cancel();

    _viewerDocSubscription = viewerRef.snapshots().listen((snapshot) async {
      if (_isDisposed) return;
      if (!snapshot.exists) return;
      if (_peerConnection == null) return;

      final data = snapshot.data();
      if (data == null) return;

      final status = data['status']?.toString();
      if (status == 'ended') {
        await close();
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
      if (_isDisposed) return;
      if (_peerConnection == null) return;

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
    Query<Map<String, dynamic>> query = _firestore
        .collection('live_streams')
        .where('status', isEqualTo: 'active')
        .orderBy('startedAt', descending: true);

    if (section != null && section.trim().isNotEmpty) {
      query = query.where('section', isEqualTo: section.trim());
    }

    if (group != null && group.trim().isNotEmpty) {
      query = query.where('group', isEqualTo: group.trim());
    }

    if (parentUid != null && parentUid.trim().isNotEmpty) {
      query = query.where('parentUid', isEqualTo: parentUid.trim());
    }

    if (childId != null && childId.trim().isNotEmpty) {
      query = query.where('childId', isEqualTo: childId.trim());
    }

    return query.snapshots();
  }

  Future<void> _sendNotificationToAdmins({
    required String type,
    required String title,
    required String body,
    required String childId,
    required String childName,
    required String requestId,
    required String parentUid,
    required String parentUsername,
    required String parentName,
  }) async {
    try {
      await AppNotificationService.instance.notifyAdmin(
        title: title,
        body: body,
        type: type,
        priority: 'important',
        parentUid: parentUid,
        parentUsername: parentUsername,
        parentName: parentName,
        childId: childId,
        childName: childName,
        section: 'Nursery',
        createdByUid: parentUid,
        createdByName: parentName.isEmpty ? 'ولي الأمر' : parentName,
        createdByRole: 'parent',
        extraData: {
          'notificationType': type,
          'category': 'live_stream',
          'templateType': 'live_stream_request',
          'requestId': requestId,
          'liveStreamRequestId': requestId,
          'route': 'live_stream_requests',
          'screen': 'live_stream',
        },
      );
    } catch (e) {
      debugPrint('send admin live stream request notification error: $e');
    }
  }

  Future<void> _sendNotificationToParent({
    required String type,
    required String title,
    required String body,
    required String parentUid,
    required String parentUsername,
    required String parentName,
    required String childId,
    required String childName,
    required String roomId,
    required String requestId,
    required String actorUid,
    required String actorName,
    required String actorRole,
  }) async {
    try {
      final cleanParentUid = parentUid.trim();
      final cleanParentUsername = parentUsername.trim().toLowerCase();
      final cleanChildId = childId.trim();
      final cleanChildName = childName.trim();

      if (cleanParentUid.isEmpty &&
          cleanParentUsername.isEmpty &&
          cleanChildId.isEmpty) {
        debugPrint(
          'live stream notification skipped: no parentUid, parentUsername, or childId',
        );
        return;
      }

      await AppNotificationService.instance.notifyChildParent(
        parentUid: cleanParentUid,
        parentUsername: cleanParentUsername,
        parentName: parentName.trim(),
        title: title,
        body: body,
        type: type,
        childId: cleanChildId,
        childName: cleanChildName,
        section: 'Nursery',
        priority: type == 'live_stream_request_rejected' ||
                type == 'live_stream_started'
            ? 'important'
            : 'normal',
        createdByUid: actorUid,
        createdByName: actorName,
        createdByRole: actorRole,
        extraData: {
          'notificationType': type,
          'category': 'live_stream',
          'templateType': 'live_stream',
          'roomId': roomId,
          'liveStreamId': roomId,
          'requestId': requestId,
          'liveStreamRequestId': requestId,
          'route': 'live_stream',
          'screen': 'live_stream',
        },
      );
    } catch (e) {
      debugPrint('send parent live stream notification error: $e');
    }
  }

  Future<void> _sendLiveStreamNotificationToParents({
    required String type,
    required String title,
    required String body,
    required String roomId,
    required String streamTitle,
    required String actorUid,
    required String actorName,
    required String actorRole,
  }) async {
    try {
      final parentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .where('isActive', isEqualTo: true)
          .get();

      if (parentsSnapshot.docs.isEmpty) return;

      for (final parentDoc in parentsSnapshot.docs) {
        final parentData = parentDoc.data();

        final parentUid = parentDoc.id;
        final parentUsername =
            (parentData['username'] ?? '').toString().trim().toLowerCase();

        final parentName = (parentData['displayName'] ??
                parentData['name'] ??
                parentData['fullName'] ??
                parentData['username'] ??
                '')
            .toString()
            .trim();

        try {
          await AppNotificationService.instance.notifyParent(
            parentUid: parentUid,
            parentUsername: parentUsername,
            parentName: parentName,
            title: title,
            body: body,
            type: type,
            section: 'Nursery',
            priority: 'normal',
            createdByUid: actorUid,
            createdByName: actorName,
            createdByRole: actorRole,
            extraData: {
              'notificationType': type,
              'category': 'live_stream',
              'templateType': 'live_stream',
              'roomId': roomId,
              'liveStreamId': roomId,
              'streamTitle': streamTitle,
              'route': 'live_stream',
              'screen': 'live_stream',
            },
          );
        } catch (e) {
          debugPrint(
            'send live stream notification to parent $parentUid error: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('send live stream notifications error: $e');
    }
  }

  Future<void> _promoteNextQueuedRequest() async {
    try {
      final snapshot = await _firestore
          .collection('live_stream_requests')
          .where('status', isEqualTo: 'queued')
          .orderBy('requestedAt', descending: false)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return;

      final doc = snapshot.docs.first;
      final data = doc.data();

      await doc.reference.update({
        'status': 'ready',
        'queuePosition': 0,
        'readyAt': FieldValue.serverTimestamp(),
        'readyExpiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 10)),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _sendNotificationToAdmins(
        type: 'live_stream_request_ready',
        title: 'طلب بث مباشر جاهز الآن',
        body:
            'انتهى البث السابق، وأصبح طلب بث الطفل ${(data['childName'] ?? 'الطفل').toString()} جاهزًا للبدء.',
        childId: (data['childId'] ?? '').toString(),
        childName: (data['childName'] ?? '').toString(),
        requestId: doc.id,
        parentUid: (data['parentUid'] ?? '').toString(),
        parentUsername: (data['parentUsername'] ?? '').toString(),
        parentName: (data['parentName'] ?? '').toString(),
      );

      await _sendNotificationToParent(
        type: 'live_stream_request_ready',
        title: 'يمكنك الآن استخدام البث المباشر',
        body:
            'يمكنك الآن استخدام البث المباشر للطفل ${(data['childName'] ?? 'الطفل').toString()}. لديك 10 دقائق للبدء.',
        parentUid: (data['parentUid'] ?? '').toString(),
        parentUsername: (data['parentUsername'] ?? '').toString(),
        parentName: (data['parentName'] ?? '').toString(),
        childId: (data['childId'] ?? '').toString(),
        childName: (data['childName'] ?? '').toString(),
        roomId: '',
        requestId: doc.id,
        actorUid: 'system',
        actorName: 'النظام',
        actorRole: 'admin',
      );
    } catch (e) {
      debugPrint('promote next queued request error: $e');
    }
  }

  Future<void> endLiveStream({
    required String roomId,
  }) async {
    try {
      final roomRef = _firestore.collection('live_streams').doc(roomId);
      final roomSnapshot = await roomRef.get();
      final roomData = roomSnapshot.data();

      await roomRef.update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final viewersSnapshot = await roomRef.collection('viewers').get();

      WriteBatch batch = _firestore.batch();
      int counter = 0;

      for (final viewerDoc in viewersSnapshot.docs) {
        batch.update(viewerDoc.reference, {
          'status': 'ended',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        counter++;

        if (counter >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          counter = 0;
        }
      }

      if (counter > 0) {
        await batch.commit();
      }

      if (roomData != null) {
        final requestId = (roomData['requestId'] ?? '').toString().trim();
        final isIndividualStream = roomData['isIndividualStream'] == true;
        final isChildSpecificStream =
            roomData['isChildSpecificStream'] == true ||
                (roomData['allowedViewersType'] ?? '').toString() ==
                    'specific_child';
        final notifyParents = roomData['notifyParents'] == true;

        if (requestId.isNotEmpty) {
          await _firestore
              .collection('live_stream_requests')
              .doc(requestId)
              .set({
            'status': 'completed',
            'endedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        if (notifyParents) {
          if (isIndividualStream || isChildSpecificStream) {
            await _sendNotificationToParent(
              type: 'live_stream_ended',
              title: 'انتهى البث المباشر',
              body: 'تم إنهاء البث المباشر الخاص بطفلك.',
              parentUid: (roomData['parentUid'] ?? '').toString(),
              parentUsername: (roomData['parentUsername'] ?? '').toString(),
              parentName: (roomData['parentName'] ?? '').toString(),
              childId: (roomData['childId'] ?? '').toString(),
              childName: (roomData['childName'] ?? '').toString(),
              roomId: roomId,
              requestId: requestId,
              actorUid: (roomData['startedByUid'] ?? '').toString(),
              actorName: (roomData['startedByName'] ?? '').toString(),
              actorRole: (roomData['startedByRole'] ?? '').toString(),
            );
          } else {
            await _sendLiveStreamNotificationToParents(
              type: 'live_stream_ended',
              title: 'انتهى البث المباشر',
              body: 'تم إنهاء البث المباشر من الحضانة.',
              roomId: roomId,
              streamTitle:
                  (roomData['title'] ?? 'بث مباشر من الحضانة').toString(),
              actorUid: (roomData['startedByUid'] ?? '').toString(),
              actorName: (roomData['startedByName'] ?? '').toString(),
              actorRole: (roomData['startedByRole'] ?? '').toString(),
            );
          }
        }
      }

      await _promoteNextQueuedRequest();

      await close();
    } catch (e) {
      debugPrint('endLiveStream error: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    _isDisposed = true;

    final roomId = _currentRoomId;
    final viewerId = _currentViewerId;

    if (roomId != null && viewerId != null) {
      try {
        await _firestore
            .collection('live_streams')
            .doc(roomId)
            .collection('viewers')
            .doc(viewerId)
            .update({
          'status': 'left',
          'leftAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    await _roomSubscription?.cancel();
    await _viewersSubscription?.cancel();
    await _viewerDocSubscription?.cancel();
    await _viewerHostCandidatesSubscription?.cancel();

    for (final sub in _hostCandidateSubscriptions.values) {
      await sub.cancel();
    }

    _roomSubscription = null;
    _viewersSubscription = null;
    _viewerDocSubscription = null;
    _viewerHostCandidatesSubscription = null;
    _hostCandidateSubscriptions.clear();

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
      for (final track in _remoteStream?.getTracks() ?? <MediaStreamTrack>[]) {
        track.stop();
      }
    } catch (_) {}

    try {
      await _localStream?.dispose();
    } catch (_) {}

    try {
      await _remoteStream?.dispose();
    } catch (_) {}

    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    _currentRoomId = null;
    _currentViewerId = null;
  }

  Future<void> dispose() async {
    await close();
  }
}