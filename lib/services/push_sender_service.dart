import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushSenderService {
  PushSenderService._();

  static final PushSenderService instance = PushSenderService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _functionName = 'send-fcm-notification';

  String lastError = '';

  String _clean(String value) => value.trim();

  String _normalizeUsername(String value) => value.trim().toLowerCase();

  String _normalizeRole(String value) {
    final role = value.trim().toLowerCase();

    switch (role) {
      case 'nursery':
      case 'nursery staff':
      case 'nursery_staff':
      case 'staff':
      case 'employee':
      case 'teacher':
        return 'nursery_staff';

      case 'temporary parent':
      case 'temporary_parent':
      case 'temp_parent':
        return 'temporary_parent';

      default:
        return role;
    }
  }

  bool _isInactiveAccount(Map<String, dynamic> data) {
    if (data['isActive'] == false) return true;

    final accountStatus =
        (data['accountStatus'] ?? 'active').toString().trim().toLowerCase();

    return accountStatus == 'archived' ||
        accountStatus == 'inactive' ||
        accountStatus == 'expired' ||
        accountStatus == 'disabled';
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
      case 'messages':
        return 'messages';

      case 'live_stream':
      case 'live_stream_started':
      case 'live_stream_ended':
      case 'live_stream_request':
      case 'live_stream_request_ready':
      case 'live_stream_queued':
      case 'live_stream_request_approved':
      case 'live_stream_request_rejected':
        return 'live_stream';

      case 'update':
      case 'update_notification':
      case 'group_update':
      case 'group_update_notification':
      case 'supplies':
      case 'nursery':
      case 'nursery_notification':
      case 'custom':
      case 'notifications':
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
      case 'extra_hours':
        return 'invoices';

      case 'consultation_created':
      case 'consultation_updated':
      case 'consultation_approved':
      case 'consultation_rejected':
        return 'consultations';

      case 'add_child_request':
      case 'registration_request':
      case 'parent_registration_request':
        return 'requests';

      case 'complaint_created':
      case 'complaint_status':
      case 'complaint_reply':
      case 'complaint_update':
        return 'complaints';

      case 'account_enabled':
      case 'account_reactivated':
      case 'account_disabled':
      case 'account_archived':
      case 'account_updated':
      case 'account_deleted':
        return 'account';

      case 'weekly_duty':
        return 'weekly_duty';

      case 'staff_daily_tasks':
        return 'staff_tasks';

      case 'staff_payroll':
      case 'staff_salary':
        return 'staff_payroll';

      case 'staff_evaluation':
      case 'staff_evaluations':
        return 'staff_evaluations';

      case 'child_handoff':
      case 'child_handoff_updated':
        return 'notifications';

      default:
        return 'notifications';
    }
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _isExpired(dynamic value) {
    final date = _dateFromDynamic(value);
    if (date == null) return false;
    return !date.isAfter(DateTime.now());
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
      lastError = 'token أو body فارغ';
      debugPrint('PushSenderService: $lastError');
      return false;
    }

    try {
      final response = await _supabase.functions.invoke(
        _functionName,
        body: {
          'token': cleanToken,
          'title': cleanTitle.isNotEmpty ? cleanTitle : 'حضانتي',
          'body': cleanBody,
          'data': {
            ...?extraData,
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
          },
        },
      );

      final status = response.status;
      final isSuccess = status >= 200 && status < 300;

      if (!isSuccess) {
        lastError =
            'فشل Supabase Function. status=$status data=${response.data}';
        debugPrint('PushSenderService: $lastError');
        return false;
      }

      lastError = '';
      return true;
    } catch (e) {
      lastError = 'خطأ أثناء sendToToken: $e';
      debugPrint('PushSenderService: $lastError');
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
      lastError = 'لا يوجد tokens للإرسال';
      debugPrint('PushSenderService: $lastError');
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

    if (successCount == 0 && lastError.isEmpty) {
      lastError = 'فشل إرسال الإشعار لكل التوكنات';
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

      if (_isInactiveAccount(data)) return [];

      return _extractTokens(data);
    } catch (e) {
      lastError = 'فشل جلب tokens حسب uid: $e';
      debugPrint('PushSenderService: $lastError');
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

      if (_isInactiveAccount(data)) return [];

      return _extractTokens(data);
    } catch (e) {
      lastError = 'فشل جلب tokens حسب username: $e';
      debugPrint('PushSenderService: $lastError');
      return [];
    }
  }

  Future<List<String>> getTemporaryParentDeviceTokensByChildId(
    String childId,
  ) async {
    final cleanChildId = childId.trim();

    if (cleanChildId.isEmpty) {
      lastError = 'childId فارغ، لا يمكن جلب أجهزة الطفل المؤقت';
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('temporary_parent_devices')
          .where('childId', isEqualTo: cleanChildId)
          .get();

      if (snapshot.docs.isEmpty) {
        lastError =
            'لا توجد مستندات في temporary_parent_devices لهذا الطفل childId=$cleanChildId';
        debugPrint('PushSenderService: $lastError');
        return [];
      }

      final tokens = <String>{};

      int inactiveCount = 0;
      int expiredCount = 0;
      int noPushSupportCount = 0;
      int emptyTokenCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final isActive = data['isActive'] == true;
        final accountStatus =
            (data['accountStatus'] ?? '').toString().trim().toLowerCase();

        if (!isActive || accountStatus != 'active') {
          inactiveCount++;
          continue;
        }

        if (_isExpired(data['accessEndAt'])) {
          expiredCount++;
          continue;
        }

        if (data['supportsPush'] == false) {
          noPushSupportCount++;
          continue;
        }

        final deviceTokens = _extractTokens(data);

        if (deviceTokens.isEmpty) {
          emptyTokenCount++;
          continue;
        }

        tokens.addAll(deviceTokens);
      }

      if (tokens.isEmpty) {
        lastError =
            'تم العثور على أجهزة مؤقتة لكن بدون token صالح. '
            'inactive=$inactiveCount expired=$expiredCount '
            'noPush=$noPushSupportCount emptyToken=$emptyTokenCount '
            'childId=$cleanChildId';

        debugPrint('PushSenderService: $lastError');
      } else {
        lastError = '';
      }

      return tokens.toList();
    } catch (e) {
      lastError =
          'فشل جلب temporary_parent_devices حسب childId=$cleanChildId: $e';
      debugPrint('PushSenderService: $lastError');
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
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();

          // ندعم السجلات القديمة التي لا تحتوي isActive:
          // الغياب يُعامل كنشط، والقيمة false فقط تمنع الإرسال.
          if (_isInactiveAccount(data)) continue;

          tokens.addAll(_extractTokens(data));
        }
      }

      await collectRoleTokens(cleanRole);

      if (cleanRole == 'nursery_staff') {
        await collectRoleTokens('nursery');
        await collectRoleTokens('nursery staff');
        await collectRoleTokens('staff');
        await collectRoleTokens('employee');
        await collectRoleTokens('teacher');
      }

      if (tokens.isEmpty) {
        lastError = 'لا يوجد tokens للدور $cleanRole';
      } else {
        lastError = '';
      }

      return tokens.toList();
    } catch (e) {
      lastError = 'فشل جلب tokens حسب الدور: $e';
      debugPrint('PushSenderService: $lastError');
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

    if (cleanUid.isEmpty) {
      lastError = 'uid فارغ';
      return 0;
    }

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

    if (tokens.isEmpty) {
      lastError =
          'لا يوجد tokens لحساب ولي الأمر parentUid=$cleanParentUid parentUsername=$cleanParentUsername';
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

  Future<int> sendToTemporaryParentDevices({
    required String childId,
    required String title,
    required String body,
    String type = 'general',
    String screen = '',
    String childName = '',
    String notificationId = '',
    String roomId = '',
    String liveStreamId = '',
    Map<String, dynamic>? extraData,
  }) async {
    final cleanChildId = childId.trim();

    if (cleanChildId.isEmpty) {
      lastError = 'childId فارغ، لا يمكن الإرسال لأجهزة الطفل المؤقت';
      return 0;
    }

    final tokens = await getTemporaryParentDeviceTokensByChildId(cleanChildId);

    if (tokens.isEmpty) {
      if (lastError.isEmpty) {
        lastError =
            'لا توجد أجهزة مؤقتة مسجلة للطفل childId=$cleanChildId';
      }

      debugPrint('PushSenderService: $lastError');
      return 0;
    }

    return sendToTokens(
      tokens: tokens,
      title: title,
      body: body,
      type: type,
      screen: screen,
      childId: cleanChildId,
      childName: childName,
      targetRole: 'temporary_parent',
      notificationId: notificationId,
      roomId: roomId,
      liveStreamId: liveStreamId,
      extraData: {
        'isTemporaryParentDevice': 'true',
        ...?extraData,
      },
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
    lastError = '';

    final title = (notificationData['title'] ?? 'حضانتي').toString().trim();

    final body = (notificationData['body'] ??
            notificationData['message'] ??
            notificationData['text'] ??
            '')
        .toString()
        .trim();

    if (body.isEmpty) {
      lastError = 'notification body فارغ';
      debugPrint('PushSenderService: $lastError');
      return 0;
    }

    final type = (notificationData['type'] ?? 'general').toString().trim();

    final requestedScreen =
        (notificationData['screen'] ?? '').toString().trim();

    final screen =
        requestedScreen.isEmpty ? _screenForType(type) : requestedScreen;

    final targetUid = (notificationData['targetUid'] ?? '').toString().trim();

    final targetRole = _normalizeRole(
      (notificationData['targetRole'] ??
              notificationData['notificationFor'] ??
              '')
          .toString(),
    );

    final parentUid = (notificationData['parentUid'] ?? '').toString().trim();

    final parentUsername = _normalizeUsername(
      (notificationData['parentUsername'] ?? '').toString(),
    );

    final childId = (notificationData['childId'] ?? '').toString().trim();
    final childName = (notificationData['childName'] ?? '').toString().trim();

    final roomId =
        (notificationData['roomId'] ?? notificationData['liveStreamId'] ?? '')
            .toString()
            .trim();

    final liveStreamId =
        (notificationData['liveStreamId'] ?? notificationData['roomId'] ?? '')
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
      'invoiceId': (notificationData['invoiceId'] ?? '').toString(),
      'invoiceStatus': (notificationData['invoiceStatus'] ?? '').toString(),
      'paymentStatus': (notificationData['paymentStatus'] ?? '').toString(),
      'updateId': (notificationData['updateId'] ?? '').toString(),
      'category': (notificationData['category'] ?? '').toString(),
      'templateType': (notificationData['templateType'] ?? '').toString(),
      'importanceLabel':
          (notificationData['importanceLabel'] ?? '').toString(),
      'groupId': (notificationData['groupId'] ?? '').toString(),
      'groupName': (notificationData['groupName'] ?? '').toString(),
      'childType': (notificationData['childType'] ?? '').toString(),
      'consultationId':
          (notificationData['consultationId'] ?? '').toString(),
      'consultationStatus':
          (notificationData['consultationStatus'] ?? '').toString(),
      'parentApprovalStatus':
          (notificationData['parentApprovalStatus'] ?? '').toString(),
      'route': (notificationData['route'] ?? '').toString(),
      'relatedCollection':
          (notificationData['relatedCollection'] ?? '').toString(),
      'relatedDocId': (notificationData['relatedDocId'] ?? '').toString(),
    };

    int sentCount = 0;

    final explicitlyTemporaryParent = targetRole == 'temporary_parent';

    final roleBroadcastTarget = targetRole.isNotEmpty &&
        targetRole != 'parent' &&
        targetRole != 'temporary_parent';

    if (explicitlyTemporaryParent) {
      if (childId.isEmpty) {
        lastError =
            'targetRole=temporary_parent لكن childId فارغ notificationId=$notificationId';
        debugPrint('PushSenderService: $lastError');
        return 0;
      }

      return sendToTemporaryParentDevices(
        childId: childId,
        title: title,
        body: body,
        type: type,
        screen: screen,
        childName: childName,
        notificationId: notificationId,
        roomId: roomId,
        liveStreamId: liveStreamId,
        extraData: extraPayload,
      );
    }

    if (targetUid.isNotEmpty) {
      sentCount = await sendToUser(
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

      if (sentCount > 0) return sentCount;

      debugPrint(
        'PushSenderService: لم يتم العثور على token عبر targetUid=$targetUid',
      );

      // الإشعار الفردي الخاص بموظفة أو أدمن لا يتحول إلى إشعار جماعي
      // إذا لم يكن جهاز المستلم المحدد مسجلًا أو لا يحتوي token صالحًا.
      if (roleBroadcastTarget) {
        if (lastError.isEmpty) {
          lastError =
              'تعذر إرسال الإشعار للمستخدم المحدد targetUid=$targetUid '
              'targetRole=$targetRole notificationId=$notificationId';
        }

        debugPrint('PushSenderService: $lastError');
        return 0;
      }
    }

    // الإرسال حسب الدور يستخدم فقط عندما لا يوجد targetUid محدد.
    // هذا مناسب للتنبيهات الجماعية للإدارة أو لجميع الموظفات.
    // وجود parentUid داخل إشعار الإدارة لا يعني أن ولي الأمر هو المستلم.
    if (roleBroadcastTarget) {
      sentCount = await sendToRole(
        role: targetRole,
        title: title,
        body: body,
        type: type,
        screen: screen,
        notificationId: notificationId,
        extraData: extraPayload,
      );

      if (sentCount > 0) return sentCount;

      if (lastError.isEmpty) {
        lastError =
            'لا يوجد token صالح للدور $targetRole notificationId=$notificationId';
      }

      debugPrint('PushSenderService: $lastError');
      return 0;
    }

    if (parentUid.isNotEmpty || parentUsername.isNotEmpty) {
      sentCount = await sendToParent(
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

      if (sentCount > 0) return sentCount;

      debugPrint(
        'PushSenderService: لم يتم العثور على token عبر parentUid/parentUsername، سيتم تجربة أجهزة الطفل المؤقت',
      );
    }

    if (childId.isNotEmpty) {
      sentCount = await sendToTemporaryParentDevices(
        childId: childId,
        title: title,
        body: body,
        type: type,
        screen: screen,
        childName: childName,
        notificationId: notificationId,
        roomId: roomId,
        liveStreamId: liveStreamId,
        extraData: extraPayload,
      );

      if (sentCount > 0) return sentCount;
    }

    if (lastError.isEmpty) {
      lastError =
          'لا يوجد token صالح للإشعار notificationId=$notificationId '
          'targetUid=$targetUid parentUid=$parentUid '
          'parentUsername=$parentUsername targetRole=$targetRole '
          'childId=$childId';
    }

    debugPrint('PushSenderService: $lastError');

    return 0;
  }
}
