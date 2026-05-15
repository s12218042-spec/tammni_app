import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushSenderService {
  PushSenderService._();

  static final PushSenderService instance = PushSenderService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _functionName = 'send-fcm-notification';

  String _clean(String value) => value.trim();

  String _normalizeUsername(String value) => value.trim().toLowerCase();

  String _normalizeRole(String value) {
    final role = value.trim().toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }

    return role;
  }

  List<String> _extractTokens(Map<String, dynamic> data) {
    final tokens = <String>{};

    final rawFcmTokens = data['fcmTokens'];
    if (rawFcmTokens is List) {
      for (final token in rawFcmTokens) {
        final cleanToken = token.toString().trim();
        if (cleanToken.isNotEmpty) {
          tokens.add(cleanToken);
        }
      }
    }

    final singleToken = (data['fcmToken'] ?? '').toString().trim();
    if (singleToken.isNotEmpty) {
      tokens.add(singleToken);
    }

    final notificationToken =
        (data['notificationToken'] ?? '').toString().trim();
    if (notificationToken.isNotEmpty) {
      tokens.add(notificationToken);
    }

    return tokens.toList();
  }

  String _screenForType(String type) {
    switch (type.trim().toLowerCase()) {
      case 'message':
      case 'message_reaction':
        return 'messages';

      case 'live_stream_started':
      case 'live_stream_ended':
        return 'live_stream';

     case 'update_notification':
     case 'group_update':
     case 'group_update_notification':
     case 'nursery_notification':
     case 'custom':
        return 'notifications';

      case 'entry':
      case 'exit':
        return 'entry_exit';

      case 'incident_report':
        return 'incident_report';

      case 'invoice':
      case 'invoice_status':
      case 'invoice_created':
      case 'invoice_updated':
        return 'invoices';

      case 'complaint_status':
      case 'complaint_reply':
        return 'complaints';

      case 'account_enabled':
      case 'account_disabled':
      case 'account_updated':
      case 'account_deleted':
        return 'account';

      default:
        return 'notifications';
    }
  }

  Future<bool> sendToToken({
    required String token,
    required String title,
    required String body,
    String type = 'general',
    String screen = '',
    String childId = '',
    String childName = '',
    String parentUid = '',
    String parentUsername = '',
    String targetUid = '',
    String targetRole = '',
    String notificationId = '',
    String roomId = '',
    String liveStreamId = '',
    Map<String, dynamic>? extraData,
  }) async {
    final cleanToken = _clean(token);
    final cleanTitle = _clean(title);
    final cleanBody = _clean(body);

    if (cleanToken.isEmpty || cleanBody.isEmpty) {
      debugPrint('PushSenderService: token أو body فارغ');
      return false;
    }

    try {
      final response = await _supabase.functions.invoke(
        _functionName,
        body: {
          'token': cleanToken,
          'title': cleanTitle.isNotEmpty ? cleanTitle : 'طمّني',
          'body': cleanBody,
          'data': {
            'type': type,
            'screen': screen.trim().isEmpty ? _screenForType(type) : screen,
            'childId': childId,
            'childName': childName,
            'parentUid': parentUid,
            'parentUsername': parentUsername,
            'targetUid': targetUid,
            'targetRole': targetRole,
            'notificationId': notificationId,
            'roomId': roomId,
            'liveStreamId': liveStreamId,
            ...?extraData,
          },
        },
      );

      final status = response.status;
      final isSuccess = status >= 200 && status < 300;

      if (!isSuccess) {
        debugPrint(
          'PushSenderService: فشل إرسال الإشعار. status=$status data=${response.data}',
        );
      }

      return isSuccess;
    } catch (e) {
      debugPrint('PushSenderService: خطأ أثناء sendToToken: $e');
      return false;
    }
  }

  Future<int> sendToTokens({
    required List<String> tokens,
    required String title,
    required String body,
    String type = 'general',
    String screen = '',
    String childId = '',
    String childName = '',
    String parentUid = '',
    String parentUsername = '',
    String targetUid = '',
    String targetRole = '',
    String notificationId = '',
    String roomId = '',
    String liveStreamId = '',
    Map<String, dynamic>? extraData,
  }) async {
    final uniqueTokens = tokens
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (uniqueTokens.isEmpty) {
      debugPrint('PushSenderService: لا يوجد tokens للإرسال');
      return 0;
    }

    int successCount = 0;

    for (final token in uniqueTokens) {
      final ok = await sendToToken(
        token: token,
        title: title,
        body: body,
        type: type,
        screen: screen,
        childId: childId,
        childName: childName,
        parentUid: parentUid,
        parentUsername: parentUsername,
        targetUid: targetUid,
        targetRole: targetRole,
        notificationId: notificationId,
        roomId: roomId,
        liveStreamId: liveStreamId,
        extraData: extraData,
      );

      if (ok) successCount++;
    }

    return successCount;
  }

  Future<List<String>> getUserTokensByUid(String uid) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return [];

    try {
      final doc = await _firestore.collection('users').doc(cleanUid).get();

      if (!doc.exists) return [];

      final data = doc.data() ?? <String, dynamic>{};
      final isActive = (data['isActive'] ?? true) == true;

      if (!isActive) return [];

      return _extractTokens(data);
    } catch (e) {
      debugPrint('PushSenderService: فشل جلب tokens حسب uid: $e');
      return [];
    }
  }

  Future<List<String>> getUserTokensByUsername(String username) async {
    final cleanUsername = _normalizeUsername(username);
    if (cleanUsername.isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return [];

      final data = snapshot.docs.first.data();
      final isActive = (data['isActive'] ?? true) == true;

      if (!isActive) return [];

      return _extractTokens(data);
    } catch (e) {
      debugPrint('PushSenderService: فشل جلب tokens حسب username: $e');
      return [];
    }
  }

  Future<List<String>> getUsersTokensByRole(String role) async {
    final cleanRole = _normalizeRole(role);
    if (cleanRole.isEmpty) return [];

    try {
      final tokens = <String>{};

      Future<void> collectRoleTokens(String roleValue) async {
        final snapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: roleValue)
            .where('isActive', isEqualTo: true)
            .get();

        for (final doc in snapshot.docs) {
          tokens.addAll(_extractTokens(doc.data()));
        }
      }

      await collectRoleTokens(cleanRole);

      if (cleanRole == 'nursery_staff') {
        await collectRoleTokens('nursery');
        await collectRoleTokens('nursery staff');
      }

      return tokens.toList();
    } catch (e) {
      debugPrint('PushSenderService: فشل جلب tokens حسب الدور: $e');
      return [];
    }
  }

  Future<int> sendToUser({
    required String uid,
    required String title,
    required String body,
    String type = 'general',
    String screen = '',
    String childId = '',
    String childName = '',
    String parentUid = '',
    String parentUsername = '',
    String targetRole = '',
    String notificationId = '',
    String roomId = '',
    String liveStreamId = '',
    Map<String, dynamic>? extraData,
  }) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return 0;

    final tokens = await getUserTokensByUid(cleanUid);

    return sendToTokens(
      tokens: tokens,
      title: title,
      body: body,
      type: type,
      screen: screen,
      childId: childId,
      childName: childName,
      parentUid: parentUid,
      parentUsername: parentUsername,
      targetUid: cleanUid,
      targetRole: targetRole,
      notificationId: notificationId,
      roomId: roomId,
      liveStreamId: liveStreamId,
      extraData: extraData,
    );
  }

  Future<int> sendToParent({
    required String parentUid,
    required String parentUsername,
    required String title,
    required String body,
    String type = 'general',
    String screen = '',
    String childId = '',
    String childName = '',
    String notificationId = '',
    String roomId = '',
    String liveStreamId = '',
    Map<String, dynamic>? extraData,
  }) async {
    final tokens = <String>{};

    final cleanParentUid = parentUid.trim();
    final cleanParentUsername = _normalizeUsername(parentUsername);

    if (cleanParentUid.isNotEmpty) {
      tokens.addAll(await getUserTokensByUid(cleanParentUid));
    }

    if (tokens.isEmpty && cleanParentUsername.isNotEmpty) {
      tokens.addAll(await getUserTokensByUsername(cleanParentUsername));
    }

    return sendToTokens(
      tokens: tokens.toList(),
      title: title,
      body: body,
      type: type,
      screen: screen,
      childId: childId,
      childName: childName,
      parentUid: cleanParentUid,
      parentUsername: cleanParentUsername,
      targetUid: cleanParentUid,
      targetRole: 'parent',
      notificationId: notificationId,
      roomId: roomId,
      liveStreamId: liveStreamId,
      extraData: extraData,
    );
  }

  Future<int> sendToRole({
    required String role,
    required String title,
    required String body,
    String type = 'general',
    String screen = '',
    String notificationId = '',
    Map<String, dynamic>? extraData,
  }) async {
    final cleanRole = _normalizeRole(role);
    final tokens = await getUsersTokensByRole(cleanRole);

    return sendToTokens(
      tokens: tokens,
      title: title,
      body: body,
      type: type,
      screen: screen,
      targetRole: cleanRole,
      notificationId: notificationId,
      extraData: extraData,
    );
  }

  Future<int> sendFromNotificationData({
    required String notificationId,
    required Map<String, dynamic> notificationData,
  }) async {
    final title = (notificationData['title'] ?? 'طمّني').toString().trim();

    final body = (notificationData['body'] ??
            notificationData['message'] ??
            notificationData['text'] ??
            '')
        .toString()
        .trim();

    if (body.isEmpty) {
      debugPrint('PushSenderService: notification body فارغ');
      return 0;
    }

    final type = (notificationData['type'] ?? 'general').toString().trim();

    final screen = _screenForType(type);

    final targetUid =
        (notificationData['targetUid'] ?? '').toString().trim();

    final targetRole = _normalizeRole(
      (notificationData['targetRole'] ??
              notificationData['notificationFor'] ??
              '')
          .toString(),
    );

    final parentUid =
        (notificationData['parentUid'] ?? '').toString().trim();

    final parentUsername =
        (notificationData['parentUsername'] ?? '').toString().trim();

    final childId = (notificationData['childId'] ?? '').toString().trim();
    final childName = (notificationData['childName'] ?? '').toString().trim();

    final roomId = (notificationData['roomId'] ??
            notificationData['liveStreamId'] ??
            '')
        .toString()
        .trim();

    final liveStreamId = (notificationData['liveStreamId'] ??
            notificationData['roomId'] ??
            '')
        .toString()
        .trim();

    final extraPayload = {
      'status': (notificationData['status'] ?? '').toString(),
      'priority': (notificationData['priority'] ??
              notificationData['importance'] ??
              '')
          .toString(),
      'createdByUid': (notificationData['createdByUid'] ?? '').toString(),
      'createdByName': (notificationData['createdByName'] ?? '').toString(),
      'createdByRole': (notificationData['createdByRole'] ?? '').toString(),
      'messageId': (notificationData['messageId'] ?? '').toString(),
      'conversationChildId':
          (notificationData['conversationChildId'] ?? '').toString(),
      'emoji': (notificationData['emoji'] ?? '').toString(),
    };

    if (targetUid.isNotEmpty) {
      return sendToUser(
        uid: targetUid,
        title: title,
        body: body,
        type: type,
        screen: screen,
        childId: childId,
        childName: childName,
        parentUid: parentUid,
        parentUsername: parentUsername,
        targetRole: targetRole,
        notificationId: notificationId,
        roomId: roomId,
        liveStreamId: liveStreamId,
        extraData: extraPayload,
      );
    }

    if (parentUid.isNotEmpty || parentUsername.isNotEmpty) {
      return sendToParent(
        parentUid: parentUid,
        parentUsername: parentUsername,
        title: title,
        body: body,
        type: type,
        screen: screen,
        childId: childId,
        childName: childName,
        notificationId: notificationId,
        roomId: roomId,
        liveStreamId: liveStreamId,
        extraData: extraPayload,
      );
    }

    if (targetRole.isNotEmpty) {
      return sendToRole(
        role: targetRole,
        title: title,
        body: body,
        type: type,
        screen: screen,
        notificationId: notificationId,
        extraData: extraPayload,
      );
    }

    debugPrint('PushSenderService: لا يوجد target واضح للإشعار');
    return 0;
  }
}