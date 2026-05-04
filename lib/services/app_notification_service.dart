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

    final normalizedCreatedByRole = _normalizeRole(createdByRole);
    final normalizedTargetRole = _normalizeRole(targetRole);
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

      'notificationFor': _cleanText(notificationFor),
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

    if (extraData != null && extraData.isNotEmpty) {
      data.addAll(extraData);
      data['notificationId'] = notificationRef.id;
    }

    await notificationRef.set(data);

    try {
      final sentCount = await PushSenderService.instance
          .sendFromNotificationData(
        notificationId: notificationRef.id,
        notificationData: data,
      );

      await notificationRef.set({
        'pushSent': sentCount > 0,
        'pushSentCount': sentCount,
        'pushSentAt': sentCount > 0 ? FieldValue.serverTimestamp() : null,
        'pushError': '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('AppNotificationService: فشل إرسال Push: $e');

      await notificationRef.set({
        'pushSent': false,
        'pushSentCount': 0,
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