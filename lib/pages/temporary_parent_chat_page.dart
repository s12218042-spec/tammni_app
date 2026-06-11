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

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff' ||
        role == 'staff' ||
        role == 'employee' ||
        role == 'teacher') {
      return 'nursery_staff';
    }

    if (role == 'admin' || role == 'manager') return 'admin';

    return role;
  }

  @override
  Widget build(BuildContext context) {
    final normalizedTargetRole = _normalizeRole(targetRole);
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    final targetDisplayName = normalizedTargetRole == 'nursery_staff'
        ? (targetName.trim().isEmpty ? 'موظف الحضانة' : targetName.trim())
        : 'الإدارة';

    return TemporaryChatCorePage(
      accessCodeId: accessCodeId,
      accessCode: accessCode,
      childId: childId,
      childName: childName,
      parentName: parentName,
      parentPhone: parentPhone,
      groupId: groupId,
      groupName: groupName,
      currentRole: 'temporary_parent',
      currentUid: currentUid,
      currentName: parentName.trim().isEmpty ? 'ولي أمر زائر' : parentName,
      targetRole: normalizedTargetRole,
      targetUid: targetUid,
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
