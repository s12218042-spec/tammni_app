import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_webrtc/flutter_webrtc.dart';

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
  }) async {
    try {
      _isDisposed = false;

      _localStream ??= await openUserMedia();

      final roomRef = _firestore.collection('live_streams').doc();
      final roomId = roomRef.id;
      _currentRoomId = roomId;

      final cleanTitle =
          title.trim().isEmpty ? 'بث مباشر من الحضانة' : title.trim();

      await roomRef.set({
        'title': cleanTitle,
        'status': 'active',
        'roomId': roomId,
        'startedByUid': startedByUid,
        'startedByName': startedByName,
        'startedByRole': startedByRole,
        'startedByPhotoUrl': startedByPhotoUrl ?? '',
        'section': section,
        'group': group,
        'allowedViewersType': allowedViewersType,
        'notifyParents': notifyParents,
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (notifyParents) {
        await _sendLiveStreamNotificationToParents(
          type: 'live_stream_started',
          title: 'بدأ بث مباشر الآن',
          body:
              '${startedByName.trim().isEmpty ? "الحضانة" : startedByName} بدأ بثًا مباشرًا. اضغطي للمشاهدة.',
          roomId: roomId,
          streamTitle: cleanTitle,
          actorUid: startedByUid,
          actorName: startedByName,
          actorRole: startedByRole,
        );
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
        'viewerUid': currentUser?.uid ?? '',
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

    return query.snapshots();
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

      WriteBatch batch = _firestore.batch();
      int counter = 0;

      for (final parentDoc in parentsSnapshot.docs) {
        final parentData = parentDoc.data();

        final parentUid = parentDoc.id;
        final parentUsername =
            (parentData['username'] ?? '').toString().trim().toLowerCase();

        final notificationRef = _firestore.collection('notifications').doc();

        batch.set(notificationRef, {
          'type': type,
          'title': title,
          'body': body,
          'message': body,
          'isRead': false,
          'targetUid': parentUid,
          'uid': parentUid,
          'parentUid': parentUid,
          'parentUsername': parentUsername,
          'roomId': roomId,
          'liveStreamId': roomId,
          'streamTitle': streamTitle,
          'createdByUid': actorUid,
          'createdByName': actorName,
          'createdByRole': actorRole,
          'byRole': actorRole,
          'createdAt': FieldValue.serverTimestamp(),
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
    } catch (e) {
      debugPrint('send live stream notifications error: $e');
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
        final notifyParents = roomData['notifyParents'] == true;

        if (notifyParents) {
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