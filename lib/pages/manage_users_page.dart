import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final editSectionCtrl = TextEditingController();
  final editNotesCtrl = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedRoleFilter = 'all';
  String selectedStatusFilter = 'all';
  String searchText = '';

  @override
  void dispose() {
    editDisplayNameCtrl.dispose();
    editUsernameCtrl.dispose();
    editPhoneCtrl.dispose();
    editSectionCtrl.dispose();
    editNotesCtrl.dispose();
    super.dispose();
  }

  String normalizeRole(String value) {
    final role = value.trim().toLowerCase();
    if (role == 'nursery' || role == 'nursery staff') return 'nursery_staff';
    return role;
  }

  String roleLabel(String r) {
    switch (normalizeRole(r)) {
      case 'parent':
        return 'ولي أمر';
      case 'nursery_staff':
        return 'موظف/ة حضانة';
      case 'teacher':
        return 'معلمة روضة';
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
      case 'teacher':
        return Colors.indigo;
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
      case 'teacher':
        return Icons.school;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person_outline;
    }
  }

  String accountStatusLabel(Map<String, dynamic> data) {
    final raw = (data['accountStatus'] ?? '').toString().trim().toLowerCase();
    final isActive = (data['isActive'] ?? true) == true;

    if (raw == 'inactive' || !isActive) return 'غير نشط';
    if (raw == 'suspended') return 'موقوف';
    if (raw == 'archived') return 'مؤرشف';
    if (raw == 'pending') return 'قيد المراجعة';
    return 'نشط';
  }

  Color accountStatusColor(Map<String, dynamic> data) {
    final raw = (data['accountStatus'] ?? '').toString().trim().toLowerCase();
    final isActive = (data['isActive'] ?? true) == true;

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

    return _firstNonEmpty([
      _fieldAsString(parentInfo['alternatePhone']),
    ]);
  }

  String extractSection(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');

    return _firstNonEmpty([
      _fieldAsString(data['section']),
      _fieldAsString(professionalInfo['section']),
    ]);
  }

  String extractNotes(Map<String, dynamic> data) {
    final adminNotes = _mapField(data, 'adminNotes');
    final parentInfo = _mapField(data, 'parentInfo');

    return _firstNonEmpty([
      _fieldAsString(adminNotes['internalNotes']),
      _fieldAsString(data['notes']),
      _fieldAsString(parentInfo['notes']),
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

  String extractMaritalStatus(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');
    final personalInfo = _mapField(data, 'personalInfo');

    return _firstNonEmpty([
      _fieldAsString(parentInfo['maritalStatus']),
      _fieldAsString(personalInfo['maritalStatus']),
    ]);
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
    final parentInfo = _mapField(data, 'parentInfo');
    final personalInfo = _mapField(data, 'personalInfo');

    final raw = parentInfo['birthDate'] ??
        personalInfo['birthDate'] ??
        data['birthDate'];

    return formatAnyDate(raw);
  }

  String extractJobTitle(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');
    final professionalInfo = _mapField(data, 'professionalInfo');

    return _firstNonEmpty([
      _fieldAsString(parentInfo['jobTitle']),
      _fieldAsString(professionalInfo['jobTitle']),
      _fieldAsString(data['jobTitle']),
    ]);
  }

  String extractWorkPlace(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');

    return _firstNonEmpty([
      _fieldAsString(parentInfo['workplace']),
      _fieldAsString(data['workplace']),
    ]);
  }

  String extractWorkPhone(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');

    return _firstNonEmpty([
      _fieldAsString(parentInfo['workPhone']),
      _fieldAsString(data['workPhone']),
    ]);
  }

  String extractPreferredContactTime(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');

    return _firstNonEmpty([
      _fieldAsString(parentInfo['bestContactTime']),
      _fieldAsString(data['preferredContactTime']),
    ]);
  }

  String extractEmploymentStatus(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');
    final professionalInfo = _mapField(data, 'professionalInfo');

    return _firstNonEmpty([
      _fieldAsString(parentInfo['employmentStatus']),
      _fieldAsString(professionalInfo['employmentStatus']),
    ]);
  }

  String extractEmergencyName(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');
    final emergency = _mapField(data, 'emergencyContact');

    return _firstNonEmpty([
      _fieldAsString(parentInfo['emergencyContactName']),
      _fieldAsString(emergency['name']),
    ]);
  }

  String extractEmergencyRelation(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');
    final emergency = _mapField(data, 'emergencyContact');

    return _firstNonEmpty([
      _fieldAsString(parentInfo['emergencyContactRelation']),
      _fieldAsString(emergency['relation']),
    ]);
  }

  String extractEmergencyPhone(Map<String, dynamic> data) {
    final parentInfo = _mapField(data, 'parentInfo');
    final emergency = _mapField(data, 'emergencyContact');

    return _firstNonEmpty([
      _fieldAsString(parentInfo['emergencyContactPhone']),
      _fieldAsString(emergency['phone']),
    ]);
  }

  List<String> extractAssignedGroups(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    final raw = professionalInfo['assignedGroups'] ?? data['assignedGroups'];

    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  List<String> extractSubjects(Map<String, dynamic> data) {
    final professionalInfo = _mapField(data, 'professionalInfo');
    final raw = professionalInfo['subjects'] ?? data['subjects'];

    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
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
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
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
      case 'other':
        return 'أخرى';
      default:
        return value.isEmpty ? '-' : value;
    }
  }

  String maritalStatusLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'married':
        return 'متزوج/ة';
      case 'single':
        return 'أعزب/عزباء';
      case 'divorced':
        return 'مطلق/ة';
      case 'widowed':
        return 'أرمل/ة';
      default:
        return value.isEmpty ? '-' : value;
    }
  }

  String employmentStatusLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'working':
        return 'يعمل/تعمل';
      case 'not_working':
        return 'لا يعمل/لا تعمل';
      case 'active':
        return 'نشط';
      case 'inactive':
        return 'غير نشط';
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
      case 'kindergarten':
        return 'الروضة فقط';
      default:
        return value.isEmpty ? '-' : value;
    }
  }

  Future<bool> usernameExistsForAnotherUser({
    required String username,
    required String currentDocId,
  }) async {
    final result = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .get();

    return result.docs.any((doc) => doc.id != currentDocId);
  }

  bool isValidUsername(String value) {
    return RegExp(r'^[a-z][a-z0-9._]{3,19}$').hasMatch(value.trim());
  }

  bool isValidPalestinianMobile(String value) {
    final clean = value.replaceAll(' ', '');
    return RegExp(r'^(059|056)\d{7}$').hasMatch(clean) ||
        RegExp(r'^(\+97059|\+97056)\d{7}$').hasMatch(clean);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> usersStream() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();

      final userRole = normalizeRole((data['role'] ?? '').toString());
      final name = ((data['displayName'] ?? data['name'] ?? '')
              .toString()
              .toLowerCase())
          .trim();
      final username = (data['username'] ?? '').toString().toLowerCase().trim();
      final email = (data['email'] ?? '').toString().toLowerCase().trim();
      final section = extractSection(data).toLowerCase();
      final phone = extractPhone(data).toLowerCase();
      final statusLabel = accountStatusLabel(data).toLowerCase();

      final normalizedFilter = normalizeRole(selectedRoleFilter);
      final matchesRole =
          normalizedFilter == 'all' || userRole == normalizedFilter;

      final statusFilter = selectedStatusFilter.trim().toLowerCase();
      final matchesStatus =
          statusFilter == 'all' || statusLabel == statusFilter;

      final query = searchText.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          username.contains(query) ||
          email.contains(query) ||
          section.contains(query) ||
          phone.contains(query);

      return matchesRole && matchesStatus && matchesSearch;
    }).toList();
  }

  Future<void> toggleUserActive({
    required String uid,
    required bool currentValue,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': !currentValue,
      'accountStatus': !currentValue ? 'active' : 'inactive',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !currentValue
              ? 'تم تفعيل الحساب بنجاح ✅'
              : 'تم تعطيل الحساب بنجاح ✅',
        ),
      ),
    );
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
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailsSection(
                    title: 'البيانات الأساسية',
                    children: [
                      _DetailItem(label: 'الاسم', value: _firstNonEmpty([
                        _fieldAsString(userData['displayName']),
                        _fieldAsString(userData['name']),
                      ])),
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
                        label: 'القسم',
                        value: extractSection(userData),
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
                      _DetailItem(
                        label: 'تاريخ الميلاد',
                        value: extractBirthDate(userData),
                      ),
                      _DetailItem(
                        label: 'الحالة الاجتماعية',
                        value: maritalStatusLabel(
                          extractMaritalStatus(userData),
                        ),
                      ),
                      _DetailItem(
                        label: 'رقم الجوال',
                        value: extractPhone(userData),
                      ),
                      _DetailItem(
                        label: 'رقم بديل',
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
                        _DetailItem(
                          label: 'حالة العمل',
                          value: employmentStatusLabel(
                            extractEmploymentStatus(userData),
                          ),
                        ),
                        _DetailItem(
                          label: 'المهنة',
                          value: extractJobTitle(userData),
                        ),
                        _DetailItem(
                          label: 'جهة العمل',
                          value: extractWorkPlace(userData),
                        ),
                        _DetailItem(
                          label: 'هاتف العمل',
                          value: extractWorkPhone(userData),
                        ),
                        _DetailItem(
                          label: 'أفضل وقت للتواصل',
                          value: extractPreferredContactTime(userData),
                        ),
                      ],
                    ),
                  if (normalizedRole == 'teacher' ||
                      normalizedRole == 'nursery_staff' ||
                      normalizedRole == 'admin')
                    _DetailsSection(
                      title: 'البيانات المهنية',
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
                          label: 'التخصص',
                          value: extractSpecialization(userData),
                        ),
                        _DetailItem(
                          label: 'الجامعة / الكلية',
                          value: extractUniversity(userData),
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
                          label: 'تاريخ التعيين',
                          value: extractHireDate(userData),
                        ),
                        if (normalizedRole == 'teacher')
                          _DetailItem(
                            label: 'المواد',
                            value: extractSubjects(userData).join(' • '),
                          ),
                        if (normalizedRole == 'teacher')
                          _DetailItem(
                            label: 'المجموعات',
                            value: extractAssignedGroups(userData).join(' • '),
                          ),
                        if (normalizedRole == 'nursery_staff')
                          _DetailItem(
                            label: 'المجموعة',
                            value: _fieldAsString(userData['group']),
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
                      ],
                    ),
                  _DetailsSection(
                    title: 'بيانات الطوارئ',
                    children: [
                      _DetailItem(
                        label: 'اسم شخص الطوارئ',
                        value: extractEmergencyName(userData),
                      ),
                      _DetailItem(
                        label: 'صلة العلاقة',
                        value: extractEmergencyRelation(userData),
                      ),
                      _DetailItem(
                        label: 'رقم الطوارئ',
                        value: extractEmergencyPhone(userData),
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
                        label: 'ملاحظات',
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
    editDisplayNameCtrl.text =
        (userData['displayName'] ?? userData['name'] ?? '').toString();
    editUsernameCtrl.text = (userData['username'] ?? '').toString();
    editPhoneCtrl.text = extractPhone(userData);
    editSectionCtrl.text = extractSection(userData);
    editNotesCtrl.text = extractNotes(userData);

    bool isSaving = false;
    final originalRole = normalizeRole((userData['role'] ?? '').toString());

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('تعديل المستخدم'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: editDisplayNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editUsernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      enabled: false,
                      controller: TextEditingController(
                        text: (userData['email'] ?? '').toString(),
                      ),
                      decoration: const InputDecoration(
                        labelText: 'الإيميل',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editPhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم الجوال',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editSectionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'القسم',
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: roleLabel(originalRole),
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'الدور',
                        prefixIcon: Icon(Icons.assignment_ind_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editNotesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات إدارية',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'ملاحظة: هذه الصفحة للمراجعة والتعديل فقط. لا يمكن تغيير الدور من هنا، وإنشاء الحسابات الجديدة يتم من قسم إنشاء الموظفين أو من طلبات التسجيل.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
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
                          final newSection = editSectionCtrl.text.trim();
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

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            final exists =
                                await usernameExistsForAnotherUser(
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

                            final updates = <String, dynamic>{
                              'displayName': newDisplayName,
                              'name': newDisplayName,
                              'username': newUsername,
                              'section': newSection,
                              'updatedAt': FieldValue.serverTimestamp(),
                              'phone': newPhone,
                              'notes': newNotes,
                              'adminNotes.internalNotes': newNotes,
                              'personalInfo.phone': newPhone,
                              'professionalInfo.section': newSection,
                              'parentInfo.phone': newPhone,
                            };

                            await _firestore
                                .collection('users')
                                .doc(docId)
                                .update(updates);

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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حذف ولي الأمر وفك ربط الأطفال المرتبطين به ✅',
          ),
        ),
      );
      return;
    }

    if (action == 'archive_children') {
      await _archiveAndUnlinkChildren(linkedChildren);
      await _firestore.collection('users').doc(uid).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حذف ولي الأمر وأرشفة الأطفال المرتبطين به ✅',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إدارة المستخدمين',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: usersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ: ${snapshot.error}'),
            );
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
                  'ملاحظة: إنشاء الحسابات الجديدة لم يعد من هذه الصفحة. الموظفون يتم إنشاؤهم من قسم "إنشاء حسابات الموظفين"، وأولياء الأمور عبر طلبات التسجيل وموافقة الإدارة.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      TextField(
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText:
                              'ابحثي بالاسم أو اسم المستخدم أو الإيميل أو الجوال أو القسم',
                          prefixIcon: const Icon(Icons.search_rounded),
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
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRoleFilter,
                        decoration: InputDecoration(
                          labelText: 'فلترة حسب الدور',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('كل المستخدمين'),
                          ),
                          DropdownMenuItem(
                            value: 'parent',
                            child: Text('أولياء الأمور'),
                          ),
                          DropdownMenuItem(
                            value: 'teacher',
                            child: Text('المعلمات'),
                          ),
                          DropdownMenuItem(
                            value: 'nursery_staff',
                            child: Text('موظفات الحضانة'),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('الإدارة'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedRoleFilter = value ?? 'all';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedStatusFilter,
                        decoration: InputDecoration(
                          labelText: 'فلترة حسب حالة الحساب',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('كل الحالات'),
                          ),
                          DropdownMenuItem(
                            value: 'نشط',
                            child: Text('نشط'),
                          ),
                          DropdownMenuItem(
                            value: 'غير نشط',
                            child: Text('غير نشط'),
                          ),
                          DropdownMenuItem(
                            value: 'موقوف',
                            child: Text('موقوف'),
                          ),
                          DropdownMenuItem(
                            value: 'مؤرشف',
                            child: Text('مؤرشف'),
                          ),
                          DropdownMenuItem(
                            value: 'قيد المراجعة',
                            child: Text('قيد المراجعة'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedStatusFilter = value ?? 'all';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
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
                  final username = (u['username'] ?? '').toString();
                  final email = (u['email'] ?? '').toString();
                  final section = extractSection(u);
                  final phone = extractPhone(u);
                  final statusText = accountStatusLabel(u);
                  final isActive = (u['isActive'] ?? true) == true;

                  return _UserCard(
                    name: name,
                    email: email,
                    roleText: roleLabel(userRole),
                    roleColor: roleColor(userRole),
                    icon: roleIcon(userRole),
                    username: username,
                    section: section,
                    phone: phone,
                    statusText: statusText,
                    statusColor: accountStatusColor(u),
                    isActive: isActive,
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
  final String section;
  final String phone;
  final String statusText;
  final Color statusColor;
  final bool isActive;
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
    required this.section,
    required this.phone,
    required this.statusText,
    required this.statusColor,
    required this.isActive,
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
                if (section.isNotEmpty)
                  buildChip(label: 'القسم: $section', color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 12),
            if (phone.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 17, color: Colors.black54),
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
                      isActive ? Icons.block_outlined : Icons.check_circle_outline,
                    ),
                    label: Text(
                      isActive ? 'تعطيل' : 'تفعيل',
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
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
        return widget.value.trim().isNotEmpty;
      }
      return true;
    }).toList();

    if (visibleChildren.isEmpty) {
      return const SizedBox.shrink();
    }

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
    if (value.trim().isEmpty) return const SizedBox.shrink();

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