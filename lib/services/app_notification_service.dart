import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'push_sender_service.dart';

class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _cleanUsername(dynamic value) {
    return _cleanText(value).toLowerCase();
  }

  String _normalizeRole(dynamic value) {
    final role = _cleanText(value).toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }

    return role;
  }

  bool _hasText(dynamic value) {
    return _cleanText(value).isNotEmpty;
  }

  Map<String, dynamic> _safeExtraData(Map<String, dynamic>? extraData) {
    if (extraData == null || extraData.isEmpty) return <String, dynamic>{};

    final cleaned = <String, dynamic>{};

    extraData.forEach((key, value) {
      final cleanKey = _cleanText(key);
      if (cleanKey.isEmpty) return;

      final isCriticalField = cleanKey == 'notificationId' ||
          cleanKey == 'title' ||
          cleanKey == 'body' ||
          cleanKey == 'message' ||
          cleanKey == 'type' ||
          cleanKey == 'notificationFor' ||
          cleanKey == 'parentUid' ||
          cleanKey == 'parentUsername' ||
          cleanKey == 'parentName' ||
          cleanKey == 'targetUid' ||
          cleanKey == 'targetUsername' ||
          cleanKey == 'targetRole' ||
          cleanKey == 'childId' ||
          cleanKey == 'childName' ||
          cleanKey == 'section' ||
          cleanKey == 'group' ||
          cleanKey == 'createdByUid' ||
          cleanKey == 'createdByName' ||
          cleanKey == 'createdByRole' ||
          cleanKey == 'byRole' ||
          cleanKey == 'pushSent' ||
          cleanKey == 'pushSentCount' ||
          cleanKey == 'pushSentAt' ||
          cleanKey == 'pushError' ||
          cleanKey == 'isRead' ||
          cleanKey == 'read' ||
          cleanKey == 'seen' ||
          cleanKey == 'createdAt' ||
          cleanKey == 'time' ||
          cleanKey == 'updatedAt';

      if (isCriticalField) {
        if (!_hasText(value)) return;
      }

      cleaned[cleanKey] = value;
    });

    return cleaned;
  }

  String roleLabel(dynamic value) {
    final role = _normalizeRole(value);

    switch (role) {
      case 'parent':
        return 'وليّ الأمر';
      case 'nursery_staff':
        return 'موظفة الحضانة';
      case 'admin':
        return 'الإدارة';
      default:
        return role.isEmpty ? 'النظام' : role;
    }
  }

  Future<void> createNotification({
    required String title,
    required String body,
    required String type,
    String notificationFor = 'parent',
    String parentUid = '',
    String parentUsername = '',
    String parentName = '',
    String targetUid = '',
    String targetUsername = '',
    String targetRole = '',
    String childId = '',
    String childName = '',
    String section = '',
    String group = '',
    String priority = 'normal',
    String createdByUid = '',
    String createdByName = '',
    String createdByRole = '',
    Map<String, dynamic>? extraData,
  }) async {
    final cleanTitle = _cleanText(title);
    final cleanBody = _cleanText(body);

    if (cleanTitle.isEmpty && cleanBody.isEmpty) return;

    final cleanNotificationFor = _normalizeRole(notificationFor).isEmpty
        ? 'parent'
        : _normalizeRole(notificationFor);

    final normalizedCreatedByRole = _normalizeRole(createdByRole);
    final normalizedTargetRole = _normalizeRole(targetRole).isEmpty
        ? cleanNotificationFor
        : _normalizeRole(targetRole);

    final cleanType = _cleanText(type).isEmpty ? 'general' : _cleanText(type);
    final cleanPriority =
        _cleanText(priority).isEmpty ? 'normal' : _cleanText(priority);

    final notificationRef = _firestore.collection('notifications').doc();

    final data = <String, dynamic>{
      'notificationId': notificationRef.id,
      'title': cleanTitle.isEmpty ? 'إشعار جديد' : cleanTitle,
      'body': cleanBody,
      'message': cleanBody,
      'type': cleanType,
      'notificationFor': cleanNotificationFor,
      'priority': cleanPriority,
      'parentUid': _cleanText(parentUid),
      'parentUsername': _cleanUsername(parentUsername),
      'parentName': _cleanText(parentName),
      'targetUid': _cleanText(targetUid),
      'targetUsername': _cleanUsername(targetUsername),
      'targetRole': normalizedTargetRole,
      'childId': _cleanText(childId),
      'childName': _cleanText(childName),
      'section': _cleanText(section),
      'group': _cleanText(group),
      'createdByUid': _cleanText(createdByUid),
      'createdByName': _cleanText(createdByName),
      'createdByRole': normalizedCreatedByRole,
      'byRole': normalizedCreatedByRole,
      'pushSent': false,
      'pushSentCount': 0,
      'pushSentAt': null,
      'pushError': '',
      'isRead': false,
      'read': false,
      'seen': false,
      'createdAt': FieldValue.serverTimestamp(),
      'time': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final safeExtra = _safeExtraData(extraData);
    if (safeExtra.isNotEmpty) {
      data.addAll(safeExtra);
    }

    data['notificationId'] = notificationRef.id;

    if (_hasText(title)) {
      data['title'] = cleanTitle;
    }

    if (_hasText(body)) {
      data['body'] = cleanBody;
      data['message'] = cleanBody;
    }

    if (_hasText(type)) {
      data['type'] = cleanType;
    }

    if (_hasText(notificationFor)) {
      data['notificationFor'] = cleanNotificationFor;
    }

    if (_hasText(targetRole)) {
      data['targetRole'] = normalizedTargetRole;
    } else if (!_hasText(data['targetRole'])) {
      data['targetRole'] = cleanNotificationFor;
    }

    if (_hasText(parentUid)) data['parentUid'] = _cleanText(parentUid);
    if (_hasText(parentUsername)) {
      data['parentUsername'] = _cleanUsername(parentUsername);
    }
    if (_hasText(parentName)) data['parentName'] = _cleanText(parentName);

    if (_hasText(targetUid)) data['targetUid'] = _cleanText(targetUid);
    if (_hasText(targetUsername)) {
      data['targetUsername'] = _cleanUsername(targetUsername);
    }

    if (_hasText(childId)) data['childId'] = _cleanText(childId);
    if (_hasText(childName)) data['childName'] = _cleanText(childName);

    if (_hasText(section)) data['section'] = _cleanText(section);
    if (_hasText(group)) data['group'] = _cleanText(group);

    if (_hasText(createdByUid)) {
      data['createdByUid'] = _cleanText(createdByUid);
    }
    if (_hasText(createdByName)) {
      data['createdByName'] = _cleanText(createdByName);
    }
    if (_hasText(createdByRole)) {
      data['createdByRole'] = normalizedCreatedByRole;
      data['byRole'] = normalizedCreatedByRole;
    }

    await notificationRef.set(data);

    try {
      final sentCount =
          await PushSenderService.instance.sendFromNotificationData(
        notificationId: notificationRef.id,
        notificationData: data,
      );

      final pushError = sentCount > 0
          ? ''
          : PushSenderService.instance.lastError.isNotEmpty
              ? PushSenderService.instance.lastError
              : 'لم يتم العثور على جهاز يستقبل الإشعار';

      await notificationRef.set({
        'pushSent': sentCount > 0,
        'pushSentCount': sentCount,
        'pushSentAt': sentCount > 0 ? FieldValue.serverTimestamp() : null,
        'pushError': pushError,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('AppNotificationService: فشل إرسال Push: $e');

      await notificationRef.set({
        'pushSent': false,
        'pushSentCount': 0,
        'pushSentAt': null,
        'pushError': e.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> notifyParent({
    required String parentUid,
    required String parentUsername,
    required String title,
    required String body,
    required String type,
    String parentName = '',
    String childId = '',
    String childName = '',
    String section = '',
    String group = '',
    String priority = 'normal',
    String createdByUid = '',
    String createdByName = '',
    String createdByRole = '',
    Map<String, dynamic>? extraData,
  }) async {
    await createNotification(
      title: title,
      body: body,
      type: type,
      notificationFor: 'parent',
      parentUid: parentUid,
      parentUsername: parentUsername,
      parentName: parentName,
      targetUid: parentUid,
      targetUsername: parentUsername,
      targetRole: 'parent',
      childId: childId,
      childName: childName,
      section: section,
      group: group,
      priority: priority,
      createdByUid: createdByUid,
      createdByName: createdByName,
      createdByRole: createdByRole,
      extraData: extraData,
    );
  }

  Future<void> notifyChildParent({
    required String childId,
    required String childName,
    required String title,
    required String body,
    required String type,
    String parentUid = '',
    String parentUsername = '',
    String parentName = '',
    String section = '',
    String group = '',
    String priority = 'normal',
    String createdByUid = '',
    String createdByName = '',
    String createdByRole = '',
    Map<String, dynamic>? extraData,
  }) async {
    await createNotification(
      title: title,
      body: body,
      type: type,
      notificationFor: 'parent',
      parentUid: parentUid,
      parentUsername: parentUsername,
      parentName: parentName,
      targetUid: parentUid,
      targetUsername: parentUsername,
      targetRole: 'parent',
      childId: childId,
      childName: childName,
      section: section,
      group: group,
      priority: priority,
      createdByUid: createdByUid,
      createdByName: createdByName,
      createdByRole: createdByRole,
      extraData: extraData,
    );
  }

  Future<void> notifyAdmin({
    required String title,
    required String body,
    required String type,
    String priority = 'normal',
    String parentUid = '',
    String parentUsername = '',
    String parentName = '',
    String childId = '',
    String childName = '',
    String section = '',
    String group = '',
    String createdByUid = '',
    String createdByName = '',
    String createdByRole = '',
    Map<String, dynamic>? extraData,
  }) async {
    await createNotification(
      title: title,
      body: body,
      type: type,
      notificationFor: 'admin',
      parentUid: parentUid,
      parentUsername: parentUsername,
      parentName: parentName,
      childId: childId,
      childName: childName,
      section: section,
      group: group,
      priority: priority,
      createdByUid: createdByUid,
      createdByName: createdByName,
      createdByRole: createdByRole,
      targetRole: 'admin',
      extraData: extraData,
    );
  }

  Future<void> notifyUser({
    required String targetUid,
    required String targetRole,
    required String title,
    required String body,
    required String type,
    String targetUsername = '',
    String priority = 'normal',
    String parentUid = '',
    String parentUsername = '',
    String parentName = '',
    String childId = '',
    String childName = '',
    String section = '',
    String group = '',
    String createdByUid = '',
    String createdByName = '',
    String createdByRole = '',
    Map<String, dynamic>? extraData,
  }) async {
    await createNotification(
      title: title,
      body: body,
      type: type,
      notificationFor: _normalizeRole(targetRole),
      targetUid: targetUid,
      targetUsername: targetUsername,
      targetRole: targetRole,
      parentUid: parentUid,
      parentUsername: parentUsername,
      parentName: parentName,
      childId: childId,
      childName: childName,
      section: section,
      group: group,
      priority: priority,
      createdByUid: createdByUid,
      createdByName: createdByName,
      createdByRole: createdByRole,
      extraData: extraData,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;

    await _firestore.collection('notifications').doc(notificationId).set({
      'isRead': true,
      'read': true,
      'seen': true,
      'readAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markManyAsRead(List<String> notificationIds) async {
    final ids = notificationIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (ids.isEmpty) return;

    final batch = _firestore.batch();

    for (final id in ids) {
      final ref = _firestore.collection('notifications').doc(id);
      batch.set(
        ref,
        {
          'isRead': true,
          'read': true,
          'seen': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}