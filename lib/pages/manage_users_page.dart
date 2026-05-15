import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final editDisplayNameCtrl = TextEditingController();
  final editUsernameCtrl = TextEditingController();
  final editPhoneCtrl = TextEditingController();
  final editAlternatePhoneCtrl = TextEditingController();
  final editNationalIdCtrl = TextEditingController();
  final editGenderCtrl = TextEditingController();
  final editRelationshipCtrl = TextEditingController();
  final editCityCtrl = TextEditingController();
  final editAddressCtrl = TextEditingController();

  final editJobTitleCtrl = TextEditingController();
  final editQualificationCtrl = TextEditingController();
  final editUniversityCtrl = TextEditingController();
  final editCollegeCtrl = TextEditingController();
  final editSpecializationCtrl = TextEditingController();
  final editGraduationYearCtrl = TextEditingController();
  final editYearsOfExperienceCtrl = TextEditingController();
  final editEmploymentTypeCtrl = TextEditingController();
  final editPermissionsCtrl = TextEditingController();
  final editResponsibilitiesCtrl = TextEditingController();
  final editCertificationsCtrl = TextEditingController();
  final editCvNotesCtrl = TextEditingController();

  final editNotesCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Set<String> selectedRoleFilters = {};
  final Set<String> selectedStatusFilters = {};
  String searchText = '';

  @override
  void dispose() {
    editDisplayNameCtrl.dispose();
    editUsernameCtrl.dispose();
    editPhoneCtrl.dispose();
    editAlternatePhoneCtrl.dispose();
    editNationalIdCtrl.dispose();
    editGenderCtrl.dispose();
    editRelationshipCtrl.dispose();
    editCityCtrl.dispose();
    editAddressCtrl.dispose();

    editJobTitleCtrl.dispose();
    editQualificationCtrl.dispose();
    editUniversityCtrl.dispose();
    editCollegeCtrl.dispose();
    editSpecializationCtrl.dispose();
    editGraduationYearCtrl.dispose();
    editYearsOfExperienceCtrl.dispose();
    editEmploymentTypeCtrl.dispose();
    editPermissionsCtrl.dispose();
    editResponsibilitiesCtrl.dispose();
    editCertificationsCtrl.dispose();
    editCvNotesCtrl.dispose();

    editNotesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String normalizeRole(String value) {
    final role = value.trim().toLowerCase();
    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }
    return role;
  }

  String roleLabel(String r) {
    switch (normalizeRole(r)) {
      case 'parent':
        return 'ولي أمر';
      case 'nursery_staff':
        return 'موظف/ة حضانة';
      case 'admin':
        return 'مدير النظام';
      default:
        return r;
    }
  }

  Color roleColor(String r) {
    switch (normalizeRole(r)) {
      case 'parent':
        return Colors.teal;
      case 'nursery_staff':
        return Colors.orange;
      case 'admin':
        return Colors.redAccent;
      default:
        return AppColors.primary;
    }
  }

  IconData roleIcon(String r) {
    switch (normalizeRole(r)) {
      case 'parent':
        return Icons.family_restroom;
      case 'nursery_staff':
        return Icons.child_friendly;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person_outline;
    }
  }

  String accountStatusLabel(Map<String, dynamic> data) {
    final raw = (data['accountStatus'] ?? '').toString().trim().toLowerCase();
    final isActive = (data['isActive'] ?? true) == true;
    final deletionRequested = (data['deletionRequested'] ?? false) == true;
    final deletionApproved = (data['deletionApproved'] ?? false) == true;

    if (raw == 'pending_deletion' || deletionApproved) return 'حذف مقبول';
    if (deletionRequested && raw != 'pending_deletion') {
      return 'طلب حذف قيد المراجعة';
    }
    if (raw == 'deactivated') return 'معطّل مؤقتًا';
    if (raw == 'inactive' || !isActive) return 'غير نشط';
    if (raw == 'suspended') return 'موقوف';
    if (raw == 'archived') return 'مؤرشف';
    if (raw == 'pending') return 'قيد المراجعة';

    return 'نشط';
  }

  Color accountStatusColor(Map<String, dynamic> data) {
    final raw = (data['accountStatus'] ?? '').toString().trim().toLowerCase();
    final isActive = (data['isActive'] ?? true) == true;
    final deletionRequested = (data['deletionRequested'] ?? false) == true;
    final deletionApproved = (data['deletionApproved'] ?? false) == true;

    if (raw == 'pending_deletion' || deletionApproved) return Colors.redAccent;
    if (deletionRequested && raw != 'pending_deletion') {
      return Colors.amber.shade800;
    }
    if (raw == 'deactivated') return Colors.orange;
    if (raw == 'inactive' || !isActive) return Colors.grey;
    if (raw == 'suspended') return Colors.deepOrange;
    if (raw == 'archived') return Colors.blueGrey;
    if (raw == 'pending') return Colors.amber.shade700;

    return Colors.green;
  }

  Map<String, dynamic> _mapField(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is Map<String, dynamic>) return value;
    return {};
  }

  String _fieldAsString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  List<String> _splitCommaValues(String value) {
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  String extractPhone(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');
    final personalInfo = _mapField(data, 'personalInfo');

    return _firstNonEmpty([
      _fieldAsString(data['phone']),
      _fieldAsString(parentInfo['phone']),
      _fieldAsString(personalInfo['phone']),
    ]);
  }

  String extractAlternatePhone(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');
    final personalInfo = _mapField(data, 'personalInfo');

    return _firstNonEmpty([
      _fieldAsString(parentInfo['alternatePhone']),
      _fieldAsString(parentInfo['alternativePhone']),
      _fieldAsString(personalInfo['alternativePhone']),
      _fieldAsString(personalInfo['alternatePhone']),
      _fieldAsString(data['alternativePhone']),
      _fieldAsString(data['alternatePhone']),
    ]);
  }

  String extractNotes(Map<String, dynamic> data) {
    final adminNotes = _mapField(data, 'adminNotes');

    return _firstNonEmpty([
      _fieldAsString(adminNotes['internalNotes']),
      _fieldAsString(data['notes']),
    ]);
  }

  String extractNationalId(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');
    final personalInfo = _mapField(data, 'personalInfo');

    return _firstNonEmpty([
      _fieldAsString(data['identityNumber']),
      _fieldAsString(data['nationalId']),
      _fieldAsString(parentInfo['identityNumber']),
      _fieldAsString(personalInfo['nationalId']),
    ]);
  }

  String extractAddress(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');
    final personalInfo = _mapField(data, 'personalInfo');

    return _firstNonEmpty([
      _fieldAsString(parentInfo['address']),
      _fieldAsString(personalInfo['address']),
      _fieldAsString(data['address']),
    ]);
  }

  String extractCity(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');

    return _firstNonEmpty([
      _fieldAsString(parentInfo['city']),
      _fieldAsString(data['city']),
    ]);
  }

  String extractRelationship(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');
    return _fieldAsString(parentInfo['relationship']);
  }

  String extractGender(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');
    final personalInfo = _mapField(data, 'personalInfo');

    return _firstNonEmpty([
      _fieldAsString(parentInfo['gender']),
      _fieldAsString(personalInfo['gender']),
      _fieldAsString(data['gender']),
    ]);
  }

  String extractBirthDate(Map<String, dynamic> data) {
    final personalInfo = _mapField(data, 'personalInfo');
    final raw = personalInfo['birthDate'] ?? data['birthDate'];

    return formatAnyDate(raw);
  }

  String extractJobTitle(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');

    return _firstNonEmpty([
      _fieldAsString(professionalInfo['jobTitle']),
      _fieldAsString(data['jobTitle']),
    ]);
  }

  String extractQualification(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    return _fieldAsString(professionalInfo['qualification']);
  }

  String extractSpecialization(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    return _fieldAsString(professionalInfo['specialization']);
  }

  String extractUniversity(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    return _fieldAsString(professionalInfo['university']);
  }

  String extractCollege(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    return _fieldAsString(professionalInfo['college']);
  }

  String extractGraduationYear(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    return _fieldAsString(professionalInfo['graduationYear']);
  }

  String extractYearsOfExperience(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    return _fieldAsString(professionalInfo['yearsOfExperience']);
  }

  String extractHireDate(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    return formatAnyDate(professionalInfo['hireDate']);
  }

  String extractEmploymentType(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    return _fieldAsString(professionalInfo['employmentType']);
  }

  String extractCvNotes(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    return _fieldAsString(professionalInfo['cvNotes']);
  }

  String extractAdminScope(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    return _firstNonEmpty([
      _fieldAsString(data['adminScope']),
      _fieldAsString(professionalInfo['adminScope']),
    ]);
  }

  List<String> extractPermissions(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    final adminNotes = _mapField(data, 'adminNotes');
    final raw = professionalInfo['permissions'] ?? adminNotes['extraPermissions'];

    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  List<String> extractResponsibilities(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    final raw = professionalInfo['responsibilities'];

    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  List<String> extractCertifications(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    final raw = professionalInfo['certifications'];

    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  String formatAnyDate(dynamic raw) {
    if (raw == null) return '';

    if (raw is Timestamp) {
      final date = raw.toDate();
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    }

    if (raw is DateTime) {
      return '${raw.year}/${raw.month.toString().padLeft(2, '0')}/${raw.day.toString().padLeft(2, '0')}';
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return '';
    return text;
  }

  String genderLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'female':
      case 'أنثى':
        return 'أنثى';
      case 'male':
      case 'ذكر':
        return 'ذكر';
      default:
        return value.isEmpty ? '-' : value;
    }
  }

  String relationshipLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'mother':
        return 'أم';
      case 'father':
        return 'أب';
      case 'guardian':
        return 'ولي أمر قانوني';
      default:
        return value.isEmpty ? '-' : value;
    }
  }

  String adminScopeLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'all':
        return 'كل النظام';
      case 'nursery':
        return 'الحضانة فقط';
      default:
        return value.isEmpty ? '-' : value;
    }
  }

  Future<bool> usernameExistsForAnotherUser({
    required String username,
    required String currentDocId,
  }) async {
    final cleanUsername = username.trim().toLowerCase();

    final usersResult = await _firestore
        .collection('users')
        .where('username', isEqualTo: cleanUsername)
        .get();

    final existsInUsers = usersResult.docs.any((doc) => doc.id != currentDocId);

    if (existsInUsers) return true;

    final loginDoc =
        await _firestore.collection('login_usernames').doc(cleanUsername).get();

    if (!loginDoc.exists) return false;

    final data = loginDoc.data() ?? {};
    final uid = (data['uid'] ?? '').toString();

    return uid.isNotEmpty && uid != currentDocId;
  }

  bool isValidUsername(String value) {
    return RegExp(r'^[a-z][a-z0-9._]{3,19}$').hasMatch(value.trim());
  }

  bool isValidPalestinianMobile(String value) {
    final clean = value.replaceAll(' ', '');
    return RegExp(r'^(059|056|052)\d{7}$').hasMatch(clean) ||
        RegExp(r'^(\+97059|\+97056|\+97052)\d{7}$').hasMatch(clean);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> usersStream() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void toggleRoleFilter(String value) {
    setState(() {
      if (selectedRoleFilters.contains(value)) {
        selectedRoleFilters.remove(value);
      } else {
        selectedRoleFilters.add(value);
      }
    });
  }

  void toggleStatusFilter(String value) {
    setState(() {
      if (selectedStatusFilters.contains(value)) {
        selectedStatusFilters.remove(value);
      } else {
        selectedStatusFilters.add(value);
      }
    });
  }

  void clearAllFilters() {
    setState(() {
      selectedRoleFilters.clear();
      selectedStatusFilters.clear();
      searchText = '';
      _searchCtrl.clear();
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();

      final userRole = normalizeRole((data['role'] ?? '').toString());
      final name =
          ((data['displayName'] ?? data['name'] ?? '').toString().toLowerCase())
              .trim();
      final username = (data['username'] ?? '').toString().toLowerCase().trim();
      final email = (data['email'] ?? '').toString().toLowerCase().trim();
      final phone = extractPhone(data).toLowerCase();
      final alternatePhone = extractAlternatePhone(data).toLowerCase();
      final nationalId = extractNationalId(data).toLowerCase();
      final statusLabelText = accountStatusLabel(data).toLowerCase();

      final matchesRole =
          selectedRoleFilters.isEmpty || selectedRoleFilters.contains(userRole);

      final matchesStatus = selectedStatusFilters.isEmpty ||
          selectedStatusFilters.contains(statusLabelText);

      final query = searchText.trim().toLowerCase();

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          username.contains(query) ||
          email.contains(query) ||
          phone.contains(query) ||
          alternatePhone.contains(query) ||
          nationalId.contains(query);

      return matchesRole && matchesStatus && matchesSearch;
    }).toList();
  }

  Widget buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? selectedColor,
  }) {
    final activeColor = selectedColor ?? AppColors.secondary;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: activeColor,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? activeColor : AppColors.primary.withOpacity(0.14),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Future<Map<String, String>> _currentAdminInfo() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    final actorUid = currentUser?.uid ?? '';
    String actorName = 'الإدارة';

    if (actorUid.trim().isNotEmpty) {
      try {
        final doc = await _firestore.collection('users').doc(actorUid).get();
        final data = doc.data();

        if (data != null) {
          actorName = _firstNonEmpty([
            _fieldAsString(data['displayName']),
            _fieldAsString(data['name']),
            _fieldAsString(data['username']),
          ]);

          if (actorName.isEmpty) {
            actorName = 'الإدارة';
          }
        }
      } catch (_) {
        actorName = 'الإدارة';
      }
    }

    return {
      'uid': actorUid,
      'name': actorName,
      'role': 'admin',
    };
  }

  Future<void> _logAccountAction({
    required String targetUid,
    required String action,
    required String title,
    required String message,
    String status = 'info',
  }) async {
    final actor = await _currentAdminInfo();

    await _firestore.collection('account_activity_logs').add({
      'targetUid': targetUid,
      'action': action,
      'title': title,
      'message': message,
      'status': status,
      'actorUid': actor['uid'] ?? '',
      'actorName': actor['name'] ?? 'الإدارة',
      'actorRole': actor['role'] ?? 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _notifyParentAccountChange({
    required String roleValue,
    required String parentUid,
    required String parentUsername,
    required String parentName,
    required String title,
    required String body,
    required String type,
    String priority = 'normal',
    Map<String, dynamic>? extraData,
  }) async {
    if (normalizeRole(roleValue) != 'parent') return;
    if (parentUid.trim().isEmpty && parentUsername.trim().isEmpty) return;

    final actor = await _currentAdminInfo();

    await AppNotificationService.instance.notifyParent(
      parentUid: parentUid,
      parentUsername: parentUsername,
      parentName: parentName,
      title: title,
      body: body,
      type: type,
      priority: priority,
      createdByUid: actor['uid'] ?? '',
      createdByName: actor['name'] ?? 'الإدارة',
      createdByRole: 'admin',
      extraData: extraData,
    );
  }

  Future<void> toggleUserActive({
    required String uid,
    required bool currentValue,
    required String userName,
    required String username,
    required String roleValue,
  }) async {
    final normalizedRole = normalizeRole(roleValue);

    if (!currentValue) {
      await _firestore.collection('users').doc(uid).update({
        'isActive': true,
        'accountStatus': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
        'deletionRequested': false,
        'deletionRequestType': '',
        'deletionApproved': false,
        'deactivationReason': '',
      });

      if (username.trim().isNotEmpty) {
        await _firestore.collection('login_usernames').doc(username).set({
          'uid': uid,
          'username': username.trim().toLowerCase(),
          'role': normalizedRole,
          'isActive': true,
          'accountStatus': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await _logAccountAction(
        targetUid: uid,
        action: 'account_reactivated_by_admin',
        title: 'تمت إعادة تفعيل الحساب',
        message: 'قامت الإدارة بإعادة تفعيل الحساب',
        status: 'success',
      );

      await _notifyParentAccountChange(
        roleValue: roleValue,
        parentUid: uid,
        parentUsername: username,
        parentName: userName,
        title: 'تم تفعيل الحساب',
        body: 'تم تفعيل حسابك ويمكنك استخدام التطبيق الآن.',
        type: 'account_enabled',
        priority: 'normal',
        extraData: {
          'accountAction': 'reactivated',
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تفعيل الحساب بنجاح ✅')),
      );
      return;
    }

    final reasonController = TextEditingController();

    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تعطيل الحساب'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'يمكنك إضافة سبب للتعطيل المؤقت:',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'سبب التعطيل (اختياري)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, reasonController.text.trim()),
                child: const Text('تعطيل'),
              ),
            ],
          ),
        ),
      );

      if (reason == null) return;

      await _firestore.collection('users').doc(uid).update({
        'isActive': false,
        'accountStatus': 'deactivated',
        'deactivationReason': reason,
        'deactivatedBy': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (username.trim().isNotEmpty) {
        await _firestore.collection('login_usernames').doc(username).set({
          'uid': uid,
          'username': username.trim().toLowerCase(),
          'role': normalizedRole,
          'isActive': false,
          'accountStatus': 'deactivated',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await _logAccountAction(
        targetUid: uid,
        action: 'account_deactivated_by_admin',
        title: 'تم تعطيل الحساب من الإدارة',
        message: reason.isNotEmpty
            ? 'قامت الإدارة بتعطيل الحساب. السبب: $reason'
            : 'قامت الإدارة بتعطيل الحساب مؤقتًا',
        status: 'warning',
      );

      await _notifyParentAccountChange(
        roleValue: roleValue,
        parentUid: uid,
        parentUsername: username,
        parentName: userName,
        title: 'تم تعطيل الحساب',
        body: reason.isNotEmpty
            ? 'تم تعطيل حسابك مؤقتًا من قبل الإدارة. السبب: $reason'
            : 'تم تعطيل حسابك مؤقتًا من قبل الإدارة. يمكنك التواصل مع الحضانة لمعرفة التفاصيل.',
        type: 'account_disabled',
        priority: 'important',
        extraData: {
          'accountAction': 'deactivated',
          'reason': reason,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعطيل الحساب بنجاح ✅')),
      );
    } finally {
      reasonController.dispose();
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _findChildrenLinkedToParent({
    required String username,
    required String uid,
  }) async {
    final byUsername = await _firestore
        .collection('children')
        .where('parentUsername', isEqualTo: username)
        .get();

    final byUid = await _firestore
        .collection('children')
        .where('parentUid', isEqualTo: uid)
        .get();

    final map = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    for (final doc in byUsername.docs) {
      map[doc.id] = doc;
    }

    for (final doc in byUid.docs) {
      map[doc.id] = doc;
    }

    return map.values.toList();
  }

  Future<void> openUserDetailsDialog({
    required String docId,
    required Map<String, dynamic> userData,
  }) async {
    final normalizedRole = normalizeRole((userData['role'] ?? '').toString());
    final username = (userData['username'] ?? '').toString();

    final linkedChildren = normalizedRole == 'parent'
        ? await _findChildrenLinkedToParent(
            username: username,
            uid: docId,
          )
        : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'تفاصيل المستخدم',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailsSection(
                    title: 'البيانات الأساسية',
                    children: [
                      _DetailItem(
                        label: 'الاسم',
                        value: _firstNonEmpty([
                          _fieldAsString(userData['displayName']),
                          _fieldAsString(userData['name']),
                        ]),
                      ),
                      _DetailItem(
                        label: 'اسم المستخدم',
                        value: _fieldAsString(userData['username']),
                      ),
                      _DetailItem(
                        label: 'البريد الإلكتروني',
                        value: _fieldAsString(userData['email']),
                      ),
                      _DetailItem(
                        label: 'الدور',
                        value: roleLabel(_fieldAsString(userData['role'])),
                      ),
                      _DetailItem(
                        label: 'حالة الحساب',
                        value: accountStatusLabel(userData),
                      ),
                      _DetailItem(
                        label: 'سبب التعطيل',
                        value: _fieldAsString(userData['deactivationReason']),
                      ),
                    ],
                  ),
                  _DetailsSection(
                    title: 'البيانات الشخصية',
                    children: [
                      _DetailItem(
                        label: 'رقم الهوية',
                        value: extractNationalId(userData),
                      ),
                      _DetailItem(
                        label: 'الجنس',
                        value: genderLabel(extractGender(userData)),
                      ),
                      if (normalizedRole != 'parent')
                        _DetailItem(
                          label: 'تاريخ الميلاد',
                          value: extractBirthDate(userData),
                        ),
                      _DetailItem(
                        label: 'رقم الجوال',
                        value: extractPhone(userData),
                      ),
                      _DetailItem(
                        label: 'رقم جوال بديل',
                        value: extractAlternatePhone(userData),
                      ),
                      _DetailItem(
                        label: 'المدينة / المنطقة',
                        value: extractCity(userData),
                      ),
                      _DetailItem(
                        label: 'العنوان',
                        value: extractAddress(userData),
                      ),
                    ],
                  ),
                  if (normalizedRole == 'parent')
                    _DetailsSection(
                      title: 'بيانات ولي الأمر',
                      children: [
                        _DetailItem(
                          label: 'صلة القرابة',
                          value: relationshipLabel(
                            extractRelationship(userData),
                          ),
                        ),
                      ],
                    ),
                  if (normalizedRole == 'nursery_staff' ||
                      normalizedRole == 'admin')
                    _DetailsSection(
                      title: 'البيانات المهنية والتعليمية',
                      children: [
                        _DetailItem(
                          label: 'المسمى الوظيفي',
                          value: extractJobTitle(userData),
                        ),
                        _DetailItem(
                          label: 'المؤهل العلمي',
                          value: extractQualification(userData),
                        ),
                        _DetailItem(
                          label: 'الجامعة',
                          value: extractUniversity(userData),
                        ),
                        _DetailItem(
                          label: 'الكلية',
                          value: extractCollege(userData),
                        ),
                        _DetailItem(
                          label: 'التخصص',
                          value: extractSpecialization(userData),
                        ),
                        _DetailItem(
                          label: 'سنة التخرج',
                          value: extractGraduationYear(userData),
                        ),
                        _DetailItem(
                          label: 'سنوات الخبرة',
                          value: extractYearsOfExperience(userData),
                        ),
                        _DetailItem(
                          label: 'نوع الدوام',
                          value: extractEmploymentType(userData),
                        ),
                        _DetailItem(
                          label: 'تاريخ التعيين',
                          value: extractHireDate(userData),
                        ),
                        if (normalizedRole == 'nursery_staff')
                          _DetailItem(
                            label: 'المسؤوليات / المهام',
                            value:
                                extractResponsibilities(userData).join(' • '),
                          ),
                        if (normalizedRole == 'nursery_staff')
                          _DetailItem(
                            label: 'الدورات / الشهادات',
                            value: extractCertifications(userData).join(' • '),
                          ),
                        if (normalizedRole == 'admin')
                          _DetailItem(
                            label: 'نطاق الإدارة',
                            value: adminScopeLabel(
                              extractAdminScope(userData),
                            ),
                          ),
                        if (normalizedRole == 'admin')
                          _DetailItem(
                            label: 'الصلاحيات',
                            value: extractPermissions(userData).join(' • '),
                          ),
                        _DetailItem(
                          label: 'ملاحظات CV',
                          value: extractCvNotes(userData),
                        ),
                      ],
                    ),
                  if (normalizedRole == 'parent')
                    _DetailsSection(
                      title: 'الأطفال المرتبطون',
                      children: [
                        _DetailItem(
                          label: 'عدد الأطفال',
                          value: '${linkedChildren.length}',
                        ),
                        if (linkedChildren.isNotEmpty)
                          _DetailItem(
                            label: 'الأسماء',
                            value: linkedChildren
                                .map((e) => (e.data()['name'] ?? '').toString())
                                .where((e) => e.isNotEmpty)
                                .join(' • '),
                          ),
                      ],
                    ),
                  _DetailsSection(
                    title: 'ملاحظات',
                    children: [
                      _DetailItem(
                        label: 'ملاحظات إدارية',
                        value: extractNotes(userData),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> openEditDialog({
    required String docId,
    required Map<String, dynamic> userData,
  }) async {
    final originalRole = normalizeRole((userData['role'] ?? '').toString());
    final originalUsername =
        (userData['username'] ?? '').toString().trim().toLowerCase();
    final emailText = (userData['email'] ?? '').toString();

    editDisplayNameCtrl.text =
        (userData['displayName'] ?? userData['name'] ?? '').toString();
    editUsernameCtrl.text = originalUsername;
    editPhoneCtrl.text = extractPhone(userData);
    editAlternatePhoneCtrl.text = extractAlternatePhone(userData);
    editNationalIdCtrl.text = extractNationalId(userData);
    editGenderCtrl.text =
        extractGender(userData).isEmpty ? 'female' : extractGender(userData);
    editRelationshipCtrl.text = extractRelationship(userData).isEmpty
        ? 'mother'
        : extractRelationship(userData);
    editCityCtrl.text = extractCity(userData);
    editAddressCtrl.text = extractAddress(userData);

    editJobTitleCtrl.text = extractJobTitle(userData);
    editQualificationCtrl.text = extractQualification(userData).isEmpty
        ? 'بكالوريوس'
        : extractQualification(userData);
    editUniversityCtrl.text = extractUniversity(userData);
    editCollegeCtrl.text = extractCollege(userData);
    editSpecializationCtrl.text = extractSpecialization(userData);
    editGraduationYearCtrl.text = extractGraduationYear(userData);
    editYearsOfExperienceCtrl.text = extractYearsOfExperience(userData);
    editEmploymentTypeCtrl.text = extractEmploymentType(userData).isEmpty
        ? 'دوام كامل'
        : extractEmploymentType(userData);
    editPermissionsCtrl.text = extractPermissions(userData).join(', ');
    editResponsibilitiesCtrl.text = extractResponsibilities(userData).join(', ');
    editCertificationsCtrl.text = extractCertifications(userData).join(', ');
    editCvNotesCtrl.text = extractCvNotes(userData);
    editNotesCtrl.text = extractNotes(userData);

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget textField({
            required TextEditingController controller,
            required String label,
            required IconData icon,
            TextInputType? keyboardType,
            int maxLines = 1,
            bool enabled = true,
          }) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: controller,
                enabled: enabled && !isSaving,
                keyboardType: keyboardType,
                maxLines: maxLines,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(icon),
                ),
              ),
            );
          }

          Widget disabledTextField({
            required String initialValue,
            required String label,
            required IconData icon,
          }) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                initialValue: initialValue,
                enabled: false,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(icon),
                ),
              ),
            );
          }

          Widget dropdownField({
            required String label,
            required IconData icon,
            required String value,
            required List<DropdownMenuItem<String>> items,
            required ValueChanged<String?> onChanged,
          }) {
            final allowedValues = items.map((e) => e.value).toSet();
            final safeValue =
                allowedValues.contains(value) ? value : items.first.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                value: safeValue,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(icon),
                ),
                items: items,
                onChanged: isSaving ? null : onChanged,
              ),
            );
          }

          final isParent = originalRole == 'parent';
          final isStaff = originalRole == 'nursery_staff';
          final isAdmin = originalRole == 'admin';

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text('تعديل ${roleLabel(originalRole)}'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      textField(
                        controller: editDisplayNameCtrl,
                        label: 'الاسم الكامل',
                        icon: Icons.badge_outlined,
                      ),
                      textField(
                        controller: editUsernameCtrl,
                        label: 'اسم المستخدم',
                        icon: Icons.person_outline,
                      ),
                      disabledTextField(
                        initialValue: emailText,
                        label: 'الإيميل',
                        icon: Icons.email_outlined,
                      ),
                      disabledTextField(
                        initialValue: roleLabel(originalRole),
                        label: 'الدور',
                        icon: Icons.assignment_ind_outlined,
                      ),
                      textField(
                        controller: editNationalIdCtrl,
                        label: 'رقم الهوية',
                        icon: Icons.credit_card_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      dropdownField(
                        label: 'الجنس',
                        icon: Icons.wc_rounded,
                        value: editGenderCtrl.text,
                        items: const [
                          DropdownMenuItem(value: 'female', child: Text('أنثى')),
                          DropdownMenuItem(value: 'male', child: Text('ذكر')),
                          DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                          DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            editGenderCtrl.text = value ?? 'female';
                          });
                        },
                      ),
                      textField(
                        controller: editPhoneCtrl,
                        label: 'رقم الجوال',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      textField(
                        controller: editAlternatePhoneCtrl,
                        label: 'رقم جوال بديل',
                        icon: Icons.phone_callback_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      if (isParent) ...[
                        dropdownField(
                          label: 'صلة القرابة',
                          icon: Icons.family_restroom_rounded,
                          value: editRelationshipCtrl.text,
                          items: const [
                            DropdownMenuItem(value: 'mother', child: Text('أم')),
                            DropdownMenuItem(value: 'father', child: Text('أب')),
                            DropdownMenuItem(
                              value: 'guardian',
                              child: Text('ولي أمر قانوني'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              editRelationshipCtrl.text = value ?? 'mother';
                            });
                          },
                        ),
                        textField(
                          controller: editCityCtrl,
                          label: 'المدينة / المنطقة',
                          icon: Icons.location_city_outlined,
                        ),
                        textField(
                          controller: editAddressCtrl,
                          label: 'العنوان التفصيلي',
                          icon: Icons.home_outlined,
                          maxLines: 2,
                        ),
                      ],
                      if (isStaff || isAdmin) ...[
                        textField(
                          controller: editAddressCtrl,
                          label: 'العنوان',
                          icon: Icons.home_outlined,
                          maxLines: 2,
                        ),
                        textField(
                          controller: editJobTitleCtrl,
                          label: 'المسمى الوظيفي',
                          icon: Icons.work_outline_rounded,
                        ),
                        dropdownField(
                          label: 'المؤهل العلمي',
                          icon: Icons.school_outlined,
                          value: editQualificationCtrl.text.isEmpty
                              ? 'بكالوريوس'
                              : editQualificationCtrl.text,
                          items: [
                            if (isStaff)
                              const DropdownMenuItem(
                                value: 'ثانوية عامة',
                                child: Text('ثانوية عامة'),
                              ),
                            const DropdownMenuItem(
                              value: 'دبلوم',
                              child: Text('دبلوم'),
                            ),
                            const DropdownMenuItem(
                              value: 'بكالوريوس',
                              child: Text('بكالوريوس'),
                            ),
                            const DropdownMenuItem(
                              value: 'ماجستير',
                              child: Text('ماجستير'),
                            ),
                            if (isAdmin)
                              const DropdownMenuItem(
                                value: 'دكتوراه',
                                child: Text('دكتوراه'),
                              ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              editQualificationCtrl.text =
                                  value ?? 'بكالوريوس';
                            });
                          },
                        ),
                        textField(
                          controller: editUniversityCtrl,
                          label: 'الجامعة',
                          icon: Icons.account_balance_outlined,
                        ),
                        textField(
                          controller: editCollegeCtrl,
                          label: 'الكلية',
                          icon: Icons.apartment_outlined,
                        ),
                        textField(
                          controller: editSpecializationCtrl,
                          label: 'التخصص',
                          icon: Icons.auto_stories_outlined,
                        ),
                        textField(
                          controller: editGraduationYearCtrl,
                          label: 'سنة التخرج',
                          icon: Icons.calendar_today_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        textField(
                          controller: editYearsOfExperienceCtrl,
                          label: 'سنوات الخبرة',
                          icon: Icons.workspace_premium_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        dropdownField(
                          label: 'نوع الدوام',
                          icon: Icons.schedule_outlined,
                          value: editEmploymentTypeCtrl.text.isEmpty
                              ? 'دوام كامل'
                              : editEmploymentTypeCtrl.text,
                          items: const [
                            DropdownMenuItem(
                              value: 'دوام كامل',
                              child: Text('دوام كامل'),
                            ),
                            DropdownMenuItem(
                              value: 'دوام جزئي',
                              child: Text('دوام جزئي'),
                            ),
                            DropdownMenuItem(
                              value: 'دوام صباحي',
                              child: Text('دوام صباحي'),
                            ),
                            DropdownMenuItem(
                              value: 'دوام مسائي',
                              child: Text('دوام مسائي'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              editEmploymentTypeCtrl.text =
                                  value ?? 'دوام كامل';
                            });
                          },
                        ),
                        if (isStaff) ...[
                          textField(
                            controller: editResponsibilitiesCtrl,
                            label: 'المسؤوليات / المهام',
                            icon: Icons.checklist_outlined,
                            maxLines: 2,
                          ),
                          textField(
                            controller: editCertificationsCtrl,
                            label: 'الدورات / الشهادات',
                            icon: Icons.card_membership_outlined,
                            maxLines: 2,
                          ),
                        ],
                        if (isAdmin)
                          textField(
                            controller: editPermissionsCtrl,
                            label: 'الصلاحيات الإدارية',
                            icon: Icons.security_outlined,
                            maxLines: 2,
                          ),
                        textField(
                          controller: editCvNotesCtrl,
                          label: 'ملاحظات CV',
                          icon: Icons.description_outlined,
                          maxLines: 2,
                        ),
                      ],
                      textField(
                        controller: editNotesCtrl,
                        label: 'ملاحظات إدارية',
                        icon: Icons.notes_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'لا يمكن تغيير الدور أو البريد الإلكتروني من هنا.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.black54,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newDisplayName =
                              editDisplayNameCtrl.text.trim();
                          final newUsername =
                              editUsernameCtrl.text.trim().toLowerCase();
                          final newPhone = editPhoneCtrl.text.trim();
                          final newAltPhone =
                              editAlternatePhoneCtrl.text.trim();
                          final newNotes = editNotesCtrl.text.trim();

                          if (newDisplayName.isEmpty || newUsername.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('الاسم واسم المستخدم مطلوبان'),
                              ),
                            );
                            return;
                          }

                          if (!isValidUsername(newUsername)) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'اسم المستخدم يجب أن يبدأ بحرف صغير ويحتوي فقط على حروف صغيرة أو أرقام أو . أو _',
                                ),
                              ),
                            );
                            return;
                          }

                          if (newPhone.isNotEmpty &&
                              !isValidPalestinianMobile(newPhone)) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('رقم الجوال الفلسطيني غير صالح'),
                              ),
                            );
                            return;
                          }

                          if (newAltPhone.isNotEmpty &&
                              !isValidPalestinianMobile(newAltPhone)) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('رقم الجوال البديل غير صالح'),
                              ),
                            );
                            return;
                          }

                          if (newAltPhone.isNotEmpty &&
                              newAltPhone == newPhone) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'رقم الجوال البديل يجب أن يختلف عن الرقم الأساسي',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            final exists = await usernameExistsForAnotherUser(
                              username: newUsername,
                              currentDocId: docId,
                            );

                            if (exists) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('اسم المستخدم مستخدم مسبقًا'),
                                ),
                              );
                              setDialogState(() {
                                isSaving = false;
                              });
                              return;
                            }

                            final batch = _firestore.batch();
                            final userRef =
                                _firestore.collection('users').doc(docId);

                            final updateData = <String, dynamic>{
                              'displayName': newDisplayName,
                              'name': newDisplayName,
                              'username': newUsername,
                              'updatedAt': FieldValue.serverTimestamp(),
                              'phone': newPhone,
                              'notes': newNotes,
                              'adminNotes.internalNotes': newNotes,
                            };

                            if (isParent) {
                              updateData.addAll({
                                'parentInfo.fullName': newDisplayName,
                                'parentInfo.username': newUsername,
                                'parentInfo.phone': newPhone,
                                'parentInfo.alternatePhone': newAltPhone,
                                'parentInfo.identityNumber':
                                    editNationalIdCtrl.text.trim(),
                                'parentInfo.gender': editGenderCtrl.text.trim(),
                                'parentInfo.relationship':
                                    editRelationshipCtrl.text.trim(),
                                'parentInfo.city': editCityCtrl.text.trim(),
                                'parentInfo.address':
                                    editAddressCtrl.text.trim(),
                              });
                            }

                            if (isStaff || isAdmin) {
                              updateData.addAll({
                                'personalInfo.nationalId':
                                    editNationalIdCtrl.text.trim(),
                                'personalInfo.gender':
                                    editGenderCtrl.text.trim(),
                                'personalInfo.phone': newPhone,
                                'personalInfo.alternativePhone': newAltPhone,
                                'personalInfo.address':
                                    editAddressCtrl.text.trim(),
                                'professionalInfo.jobTitle':
                                    editJobTitleCtrl.text.trim(),
                                'professionalInfo.qualification':
                                    editQualificationCtrl.text.trim(),
                                'professionalInfo.university':
                                    editUniversityCtrl.text.trim(),
                                'professionalInfo.college':
                                    editCollegeCtrl.text.trim(),
                                'professionalInfo.specialization':
                                    editSpecializationCtrl.text.trim(),
                                'professionalInfo.graduationYear': int.tryParse(
                                  editGraduationYearCtrl.text.trim(),
                                ),
                                'professionalInfo.yearsOfExperience':
                                    int.tryParse(
                                          editYearsOfExperienceCtrl.text.trim(),
                                        ) ??
                                        0,
                                'professionalInfo.employmentType':
                                    editEmploymentTypeCtrl.text.trim(),
                                'professionalInfo.cvNotes':
                                    editCvNotesCtrl.text.trim(),
                              });
                            }

                            if (isStaff) {
                              updateData.addAll({
                                'professionalInfo.responsibilities':
                                    _splitCommaValues(
                                  editResponsibilitiesCtrl.text,
                                ),
                                'professionalInfo.certifications':
                                    _splitCommaValues(
                                  editCertificationsCtrl.text,
                                ),
                              });
                            }

                            if (isAdmin) {
                              updateData.addAll({
                                'professionalInfo.permissions':
                                    _splitCommaValues(
                                  editPermissionsCtrl.text,
                                ),
                              });
                            }

                            batch.update(userRef, updateData);

                            if (originalUsername.isNotEmpty &&
                                originalUsername != newUsername) {
                              batch.delete(
                                _firestore
                                    .collection('login_usernames')
                                    .doc(originalUsername),
                              );
                            }

                            batch.set(
                              _firestore
                                  .collection('login_usernames')
                                  .doc(newUsername),
                              {
                                'uid': docId,
                                'username': newUsername,
                                'email': emailText,
                                'role': originalRole,
                                'isActive': userData['isActive'] ?? true,
                                'accountStatus':
                                    userData['accountStatus'] ?? 'active',
                                'updatedAt': FieldValue.serverTimestamp(),
                              },
                              SetOptions(merge: true),
                            );

                            await batch.commit();

                            await _logAccountAction(
                              targetUid: docId,
                              action: 'account_updated_by_admin',
                              title: 'تم تعديل بيانات الحساب',
                              message: 'قامت الإدارة بتعديل بيانات الحساب',
                              status: 'success',
                            );

                            await _notifyParentAccountChange(
                              roleValue: originalRole,
                              parentUid: docId,
                              parentUsername: newUsername,
                              parentName: newDisplayName,
                              title: 'تم تحديث بيانات الحساب',
                              body:
                                  'تم تحديث بعض بيانات حسابك من قبل الإدارة.',
                              type: 'account_updated',
                              priority: 'normal',
                              extraData: {
                                'accountAction': 'updated',
                                'oldUsername': originalUsername,
                                'newUsername': newUsername,
                              },
                            );

                            if (!mounted) return;

                            Navigator.pop(context);

                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تعديل المستخدم بنجاح ✅'),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('حدث خطأ: $e')),
                            );
                            setDialogState(() {
                              isSaving = false;
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('حفظ التعديلات'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _unlinkChildrenFromParent(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> childDocs,
  ) async {
    final batch = _firestore.batch();

    for (final doc in childDocs) {
      batch.update(doc.reference, {
        'parentUsername': FieldValue.delete(),
        'parentUid': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> _archiveAndUnlinkChildren(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> childDocs,
  ) async {
    final batch = _firestore.batch();

    for (final doc in childDocs) {
      batch.update(doc.reference, {
        'parentUsername': FieldValue.delete(),
        'parentUid': FieldValue.delete(),
        'isActive': false,
        'status': 'archived',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<String?> _showParentDeleteOptionsDialog({
    required String parentName,
    required int childrenCount,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('حذف ولي الأمر'),
          content: Text(
            'الحساب "$parentName" مرتبط بـ $childrenCount طفل/أطفال.\n\n'
            'ماذا تريدين أن تفعلي بالأطفال المرتبطين؟',
            style: const TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete_only'),
              child: const Text('حذف الحساب فقط'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'archive_children'),
              child: const Text('حذف الحساب وأرشفة الأطفال'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showNormalDeleteConfirmDialog(String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنتِ متأكدة من حذف المستخدم "$name"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    return result == true;
  }

  Future<void> _deleteUsernameLoginMapping(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) return;

    await _firestore.collection('login_usernames').doc(cleanUsername).delete();
  }

  Future<void> handleDeleteUser({
    required String uid,
    required String roleValue,
    required String name,
    required String username,
  }) async {
    final normalizedRole = normalizeRole(roleValue);

    if (normalizedRole != 'parent') {
      final confirmed = await _showNormalDeleteConfirmDialog(name);
      if (!confirmed) return;

      await _firestore.collection('users').doc(uid).delete();
      await _deleteUsernameLoginMapping(username);

      await _logAccountAction(
        targetUid: uid,
        action: 'account_deleted_by_admin',
        title: 'تم حذف الحساب',
        message: 'قامت الإدارة بحذف الحساب من النظام',
        status: 'danger',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المستخدم من النظام ✅'),
        ),
      );
      return;
    }

    final linkedChildren = await _findChildrenLinkedToParent(
      username: username,
      uid: uid,
    );

    if (linkedChildren.isEmpty) {
      final confirmed = await _showNormalDeleteConfirmDialog(name);
      if (!confirmed) return;

      await _firestore.collection('users').doc(uid).delete();
      await _deleteUsernameLoginMapping(username);

      await _logAccountAction(
        targetUid: uid,
        action: 'parent_account_deleted_by_admin',
        title: 'تم حذف حساب ولي الأمر',
        message: 'قامت الإدارة بحذف حساب ولي الأمر من النظام',
        status: 'danger',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف ولي الأمر من النظام ✅'),
        ),
      );
      return;
    }

    final action = await _showParentDeleteOptionsDialog(
      parentName: name,
      childrenCount: linkedChildren.length,
    );

    if (action == null || action == 'cancel') return;

    if (action == 'delete_only') {
      await _unlinkChildrenFromParent(linkedChildren);
      await _firestore.collection('users').doc(uid).delete();
      await _deleteUsernameLoginMapping(username);

      await _logAccountAction(
        targetUid: uid,
        action: 'parent_deleted_children_unlinked',
        title: 'تم حذف ولي الأمر وفك ربط الأطفال',
        message: 'قامت الإدارة بحذف ولي الأمر وفك ربط الأطفال المرتبطين به',
        status: 'danger',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف ولي الأمر وفك ربط الأطفال المرتبطين به ✅'),
        ),
      );
      return;
    }

    if (action == 'archive_children') {
      await _archiveAndUnlinkChildren(linkedChildren);
      await _firestore.collection('users').doc(uid).delete();
      await _deleteUsernameLoginMapping(username);

      await _logAccountAction(
        targetUid: uid,
        action: 'parent_deleted_children_archived',
        title: 'تم حذف ولي الأمر وأرشفة الأطفال',
        message: 'قامت الإدارة بحذف ولي الأمر وأرشفة الأطفال المرتبطين به',
        status: 'danger',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف ولي الأمر وأرشفة الأطفال المرتبطين به ✅'),
        ),
      );
    }
  }

  Widget buildFiltersCard() {
    final hasCustomFilters = selectedRoleFilters.isNotEmpty ||
        selectedStatusFilters.isNotEmpty ||
        searchText.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchCtrl,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText:
                    'ابحثي بالاسم أو اسم المستخدم أو الإيميل أو الجوال أو الهوية',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchText.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            searchText = '';
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'الدور',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildFilterChip(
                  label: 'أولياء الأمور',
                  selected: selectedRoleFilters.contains('parent'),
                  onTap: () => toggleRoleFilter('parent'),
                  selectedColor: Colors.teal,
                ),
                buildFilterChip(
                  label: 'موظفات الحضانة',
                  selected: selectedRoleFilters.contains('nursery_staff'),
                  onTap: () => toggleRoleFilter('nursery_staff'),
                  selectedColor: Colors.orange,
                ),
                buildFilterChip(
                  label: 'الإدارة',
                  selected: selectedRoleFilters.contains('admin'),
                  onTap: () => toggleRoleFilter('admin'),
                  selectedColor: Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'حالة الحساب',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildFilterChip(
                  label: 'نشط',
                  selected: selectedStatusFilters.contains('نشط'.toLowerCase()),
                  onTap: () => toggleStatusFilter('نشط'.toLowerCase()),
                  selectedColor: Colors.green,
                ),
                buildFilterChip(
                  label: 'غير نشط',
                  selected:
                      selectedStatusFilters.contains('غير نشط'.toLowerCase()),
                  onTap: () => toggleStatusFilter('غير نشط'.toLowerCase()),
                  selectedColor: Colors.grey,
                ),
                buildFilterChip(
                  label: 'معطّل مؤقتًا',
                  selected: selectedStatusFilters
                      .contains('معطّل مؤقتًا'.toLowerCase()),
                  onTap: () => toggleStatusFilter('معطّل مؤقتًا'.toLowerCase()),
                  selectedColor: Colors.orange,
                ),
                buildFilterChip(
                  label: 'طلب حذف قيد المراجعة',
                  selected: selectedStatusFilters
                      .contains('طلب حذف قيد المراجعة'.toLowerCase()),
                  onTap: () =>
                      toggleStatusFilter('طلب حذف قيد المراجعة'.toLowerCase()),
                  selectedColor: Colors.amber.shade800,
                ),
                buildFilterChip(
                  label: 'حذف مقبول',
                  selected:
                      selectedStatusFilters.contains('حذف مقبول'.toLowerCase()),
                  onTap: () => toggleStatusFilter('حذف مقبول'.toLowerCase()),
                  selectedColor: Colors.redAccent,
                ),
                buildFilterChip(
                  label: 'موقوف',
                  selected:
                      selectedStatusFilters.contains('موقوف'.toLowerCase()),
                  onTap: () => toggleStatusFilter('موقوف'.toLowerCase()),
                  selectedColor: Colors.deepOrange,
                ),
                buildFilterChip(
                  label: 'مؤرشف',
                  selected:
                      selectedStatusFilters.contains('مؤرشف'.toLowerCase()),
                  onTap: () => toggleStatusFilter('مؤرشف'.toLowerCase()),
                  selectedColor: Colors.blueGrey,
                ),
                buildFilterChip(
                  label: 'قيد المراجعة',
                  selected: selectedStatusFilters
                      .contains('قيد المراجعة'.toLowerCase()),
                  onTap: () => toggleStatusFilter('قيد المراجعة'.toLowerCase()),
                  selectedColor: Colors.amber.shade700,
                ),
              ],
            ),
            if (hasCustomFilters) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: clearAllFilters,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('إعادة تعيين الفلاتر'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إدارة المستخدمين',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: usersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = applyFilters(docs);

          return ListView(
            children: [
              Text(
                'إدارة الحسابات',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'مراجعة وتعديل وتنظيم الحسابات الحالية داخل النظام دون إنشاء حسابات جديدة من هنا.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'ملاحظة: إنشاء الحسابات الجديدة لم يعد من هذه الصفحة. الموظفون يتم إنشاؤهم من قسم إنشاء حسابات الموظفين، وأولياء الأمور عبر طلبات التسجيل وموافقة الإدارة.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              buildFiltersCard(),
              const SizedBox(height: 20),
              if (filteredDocs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'لا توجد نتائج مطابقة حاليًا.',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              else
                ...filteredDocs.map((doc) {
                  final u = doc.data();
                  final userRole = (u['role'] ?? '').toString();
                  final name =
                      (u['displayName'] ?? u['name'] ?? 'بدون اسم').toString();
                  final username =
                      (u['username'] ?? '').toString().trim().toLowerCase();
                  final email = (u['email'] ?? '').toString();
                  final phone = extractPhone(u);
                  final statusText = accountStatusLabel(u);
                  final isActive = (u['isActive'] ?? true) == true;
                  final rawStatus =
                      (u['accountStatus'] ?? '').toString().trim().toLowerCase();

                  return _UserCard(
                    name: name,
                    email: email,
                    roleText: roleLabel(userRole),
                    roleColor: roleColor(userRole),
                    icon: roleIcon(userRole),
                    username: username,
                    phone: phone,
                    statusText: statusText,
                    statusColor: accountStatusColor(u),
                    isActive: isActive,
                    rawStatus: rawStatus,
                    onViewDetails: () async {
                      await openUserDetailsDialog(
                        docId: doc.id,
                        userData: u,
                      );
                    },
                    onToggleActive: () async {
                      await toggleUserActive(
                        uid: doc.id,
                        currentValue: isActive,
                        userName: name,
                        username: username,
                        roleValue: userRole,
                      );
                    },
                    onDelete: () async {
                      await handleDeleteUser(
                        uid: doc.id,
                        roleValue: userRole,
                        name: name,
                        username: username,
                      );
                    },
                    onEdit: () async {
                      await openEditDialog(
                        docId: doc.id,
                        userData: u,
                      );
                    },
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String name;
  final String username;
  final String email;
  final String roleText;
  final Color roleColor;
  final IconData icon;
  final String phone;
  final String statusText;
  final Color statusColor;
  final bool isActive;
  final String rawStatus;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onViewDetails;

  const _UserCard({
    required this.name,
    required this.username,
    required this.email,
    required this.roleText,
    required this.roleColor,
    required this.icon,
    required this.phone,
    required this.statusText,
    required this.statusColor,
    required this.isActive,
    required this.rawStatus,
    required this.onDelete,
    required this.onEdit,
    required this.onToggleActive,
    required this.onViewDetails,
  });

  Widget buildChip({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: roleColor.withOpacity(0.15),
                  child: Icon(icon, color: roleColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'اسم المستخدم: $username',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildChip(label: roleText, color: roleColor),
                buildChip(label: statusText, color: statusColor),
              ],
            ),
            const SizedBox(height: 12),
            if (phone.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 17,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      phone,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13.2,
                      ),
                    ),
                  ),
                ],
              ),
            if (phone.isNotEmpty) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('تفاصيل'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onToggleActive,
                    icon: Icon(
                      isActive
                          ? Icons.block_outlined
                          : Icons.check_circle_outline,
                    ),
                    label: Text(
                      isActive
                          ? 'تعطيل'
                          : rawStatus == 'deactivated'
                              ? 'إعادة تفعيل'
                              : rawStatus == 'pending_deletion'
                                  ? 'إعادة تفعيل'
                                  : 'تفعيل',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('تعديل'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'حذف',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final visibleChildren = children.where((widget) {
      if (widget is _DetailItem) {
        return widget.value.trim().isNotEmpty && widget.value.trim() != '-';
      }
      return true;
    }).toList();

    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 10),
          ...visibleChildren,
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty || value.trim() == '-') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textLight,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}