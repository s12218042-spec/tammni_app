import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'temporary_chat_core_page.dart';

class TemporaryStaffChatPage extends StatefulWidget {
  final String accessCodeId;
  final String accessCode;
  final String childId;
  final String childName;
  final String parentName;
  final String parentPhone;
  final String groupId;
  final String groupName;

  const TemporaryStaffChatPage({
    super.key,
    required this.accessCodeId,
    required this.accessCode,
    required this.childId,
    required this.childName,
    required this.parentName,
    required this.parentPhone,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<TemporaryStaffChatPage> createState() =>
      _TemporaryStaffChatPageState();
}

class _TemporaryStaffChatPageState extends State<TemporaryStaffChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool isLoadingIdentity = true;
  String currentActorRole = '';
  String currentActorName = '';

  String get _currentUid => _auth.currentUser?.uid.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _loadCurrentActorInfo();
  }

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _normalizeRole(dynamic value) {
    final role = _cleanText(value).toLowerCase();

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

  bool get _isAllowedActor {
    return currentActorRole == 'admin' ||
        currentActorRole == 'nursery_staff';
  }

  Future<void> _loadCurrentActorInfo() async {
    final uid = _currentUid;

    if (uid.isEmpty) {
      if (!mounted) return;

      setState(() {
        isLoadingIdentity = false;
      });

      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? <String, dynamic>{};
      final role = _normalizeRole(data['role']);

      final rawName = _cleanText(
        data['displayName'] ??
            data['name'] ??
            data['fullName'] ??
            data['username'],
      );

      if (!mounted) return;

      setState(() {
        currentActorRole = role;
        currentActorName = rawName.isEmpty
            ? (role == 'admin' ? 'الإدارة' : 'موظف الحضانة')
            : rawName;
        isLoadingIdentity = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoadingIdentity = false;
      });
    }
  }

  Widget _buildIdentityError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          _currentUid.isEmpty
              ? 'تعذر تحميل هوية المستخدم'
              : 'هذه الصفحة متاحة للإدارة وموظفي الحضانة فقط',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingIdentity) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (!_isAllowedActor) {
      return AppPageScaffold(
        title: 'المحادثة',
        child: _buildIdentityError(),
      );
    }

    final parentDisplayName = widget.parentName.trim().isEmpty
        ? 'ولي أمر زائر'
        : widget.parentName.trim();

    return TemporaryChatCorePage(
      accessCodeId: widget.accessCodeId,
      accessCode: widget.accessCode,
      childId: widget.childId,
      childName: widget.childName,
      parentName: widget.parentName,
      parentPhone: widget.parentPhone,
      groupId: widget.groupId,
      groupName: widget.groupName,
      currentRole: currentActorRole,
      currentUid: _currentUid,
      currentName: currentActorName,
      targetRole: 'temporary_parent',
      targetUid: '',
      targetName: parentDisplayName,
      headerSubtitle: 'ولي أمر زائر',
      headerIcon: Icons.person_outline_rounded,
      headerColor: const Color(0xFFEFA7C8),
    );
  }
}
