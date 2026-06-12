import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'temporary_chat_core_page.dart';

class TemporaryParentChatPage extends StatelessWidget {
  final String accessCodeId;
  final String accessCode;
  final String childId;
  final String childName;
  final String parentName;
  final String parentPhone;
  final String groupId;
  final String groupName;
  final String targetRole;
  final String targetUid;
  final String targetName;

  const TemporaryParentChatPage({
    super.key,
    required this.accessCodeId,
    required this.accessCode,
    required this.childId,
    required this.childName,
    required this.parentName,
    required this.parentPhone,
    required this.groupId,
    required this.groupName,
    required this.targetRole,
    required this.targetUid,
    required this.targetName,
  });

  String _normalizeRole(String value) {
    final role = value.trim().toLowerCase();

    switch (role) {
      case 'nursery':
      case 'nursery staff':
      case 'nursery_staff':
      case 'staff':
      case 'employee':
      case 'teacher':
      case 'موظفة':
      case 'موظفة حضانة':
      case 'حضانة':
        return 'nursery_staff';

      case 'admin':
      case 'manager':
      case 'مدير':
      case 'مدير النظام':
      case 'ادمن':
      case 'أدمن':
        return 'admin';

      default:
        return role;
    }
  }

  Widget _buildErrorPage(String message) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المحادثة'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedTargetRole = _normalizeRole(targetRole);
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    if (currentUid.isEmpty) {
      return _buildErrorPage(
        'تعذر تحميل هوية وليّ الأمر الزائر. سجّل الدخول بالكود مرة أخرى.',
      );
    }

    if (normalizedTargetRole != 'admin' &&
        normalizedTargetRole != 'nursery_staff') {
      return _buildErrorPage(
        'تعذر تحديد جهة المحادثة.',
      );
    }

    final resolvedTargetUid = normalizedTargetRole == 'admin'
        ? 'admin'
        : targetUid.trim();

    if (normalizedTargetRole == 'nursery_staff' &&
        resolvedTargetUid.isEmpty) {
      return _buildErrorPage(
        'تعذر تحديد موظف الحضانة المستهدف.',
      );
    }

    final targetDisplayName = normalizedTargetRole == 'nursery_staff'
        ? (targetName.trim().isEmpty ? 'موظف الحضانة' : targetName.trim())
        : 'الإدارة';

    return TemporaryChatCorePage(
      accessCodeId: accessCodeId.trim(),
      accessCode: accessCode.trim(),
      childId: childId.trim(),
      childName: childName.trim(),
      parentName: parentName.trim(),
      parentPhone: parentPhone.trim(),
      groupId: groupId.trim(),
      groupName: groupName.trim(),
      currentRole: 'temporary_parent',
      currentUid: currentUid,
      currentName:
          parentName.trim().isEmpty ? 'ولي أمر زائر' : parentName.trim(),
      targetRole: normalizedTargetRole,
      targetUid: resolvedTargetUid,
      targetName: targetDisplayName,
      headerSubtitle:
          normalizedTargetRole == 'nursery_staff' ? 'موظف حضانة' : 'الإدارة',
      headerIcon: normalizedTargetRole == 'nursery_staff'
          ? Icons.child_care_outlined
          : Icons.admin_panel_settings_outlined,
      headerColor: normalizedTargetRole == 'nursery_staff'
          ? const Color(0xFFEFA7C8)
          : const Color(0xFF6A67CE),
    );
  }
}