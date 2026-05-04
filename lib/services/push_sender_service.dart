import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushSenderService {
  PushSenderService._();

  static final PushSenderService instance = PushSenderService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  /// إرسال إشعار مباشر إلى توكن واحد
  Future<bool> sendToToken({
    required String token,
    required String title,
    required String body,
    String type = 'general',
    String screen = '',
    String childId = '',
    String parentUid = '',
  }) async {
    final cleanToken = token.trim();
    final cleanTitle = title.trim();
    final cleanBody = body.trim();

    if (cleanToken.isEmpty || cleanBody.isEmpty) {
      debugPrint('PushSenderService: token أو body فارغ');
      return false;
    }

    try {
      final response = await _supabase.functions.invoke(
        'send-fcm-notification',
        body: {
          'token': cleanToken,
          'title': cleanTitle.isNotEmpty ? cleanTitle : 'طمّني',
          'body': cleanBody,
          'type': type,
          'screen': screen,
          'childId': childId,
          'parentUid': parentUid,
        },
      );

      final data = response.data;

      debugPrint('PushSenderService response: $data');

      if (data is Map && data['success'] == true) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('PushSenderService sendToToken error: $e');
      return false;
    }
  }

  /// إرسال إشعار لكل أجهزة ولي الأمر حسب parentUid
  Future<int> sendToParent({
    required String parentUid,
    required String title,
    required String body,
    String type = 'general',
    String screen = '',
    String childId = '',
  }) async {
    final cleanParentUid = parentUid.trim();

    if (cleanParentUid.isEmpty) {
      debugPrint('PushSenderService: parentUid فارغ');
      return 0;
    }

    try {
      final userDoc =
          await _firestore.collection('users').doc(cleanParentUid).get();

      if (!userDoc.exists) {
        debugPrint('PushSenderService: لا يوجد users/$cleanParentUid');
        return 0;
      }

      final data = userDoc.data() ?? {};

      final rawTokens = data['fcmTokens'];

      if (rawTokens is! List || rawTokens.isEmpty) {
        debugPrint('PushSenderService: لا يوجد fcmTokens لولي الأمر');
        return 0;
      }

      final tokens = rawTokens
          .map((e) => e.toString().trim())
          .where((token) => token.isNotEmpty)
          .toSet()
          .toList();

      if (tokens.isEmpty) {
        debugPrint('PushSenderService: قائمة التوكنات فارغة بعد التنظيف');
        return 0;
      }

      int successCount = 0;

      for (final token in tokens) {
        final success = await sendToToken(
          token: token,
          title: title,
          body: body,
          type: type,
          screen: screen,
          childId: childId,
          parentUid: cleanParentUid,
        );

        if (success) {
          successCount++;
        }
      }

      debugPrint(
        'PushSenderService: تم إرسال $successCount من ${tokens.length} إشعار',
      );

      return successCount;
    } catch (e) {
      debugPrint('PushSenderService sendToParent error: $e');
      return 0;
    }
  }

  /// إرسال إشعار تحديث طفل
  Future<int> sendChildUpdateNotification({
    required String parentUid,
    required String childId,
    required String childName,
    String updateType = '',
  }) async {
    final title = 'تحديث جديد من طمّني';

    final body = childName.trim().isEmpty
        ? 'تمت إضافة تحديث جديد لطفلك'
        : 'تمت إضافة تحديث جديد للطفل $childName';

    return sendToParent(
      parentUid: parentUid,
      title: title,
      body: body,
      type: updateType.isNotEmpty ? updateType : 'child_update',
      screen: 'child_updates',
      childId: childId,
    );
  }

  /// إرسال إشعار رسالة جديدة
  Future<int> sendNewMessageNotification({
    required String receiverUid,
    required String senderName,
    required String messagePreview,
    String childId = '',
  }) async {
    final title = senderName.trim().isEmpty
        ? 'رسالة جديدة في طمّني'
        : 'رسالة جديدة من $senderName';

    final body = messagePreview.trim().isEmpty
        ? 'لديك رسالة جديدة'
        : messagePreview.trim();

    return sendToParent(
      parentUid: receiverUid,
      title: title,
      body: body,
      type: 'new_message',
      screen: 'messages',
      childId: childId,
    );
  }
}