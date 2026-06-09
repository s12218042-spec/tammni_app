import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String username;
  final bool isActive;
  final String accountStatus;

  final String archiveReason;
  final DateTime? archivedAt;
  final DateTime? reactivatedAt;

  final String phone;
  final String alternatePhone;
  final String nationalId;
  final String gender;
  final String address;
  final String city;

  final String relationship;

  final String jobTitle;
  final String qualification;
  final String university;
  final String college;
  final String specialization;
  final int? graduationYear;
  final int yearsOfExperience;
  final String employmentType;
  final DateTime? birthDate;
  final DateTime? hireDate;

  final String section;
  final String group;
  final String groupId;
  final String groupName;
  final List<String> assignedGroups;

  final String salaryCalculationType;
  final double hourlyRate;
  final double baseSalary;

  final List<String> responsibilities;
  final List<String> certifications;

  final String adminScope;
  final List<String> permissions;

  final List<String> fcmTokens;

  final bool isLiveStreamStation;

  final String cvNotes;
  final String adminNotes;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.username = '',
    this.isActive = true,
    this.accountStatus = 'active',
    this.archiveReason = '',
    this.archivedAt,
    this.reactivatedAt,
    this.phone = '',
    this.alternatePhone = '',
    this.nationalId = '',
    this.gender = '',
    this.address = '',
    this.city = '',
    this.relationship = '',
    this.jobTitle = '',
    this.qualification = '',
    this.university = '',
    this.college = '',
    this.specialization = '',
    this.graduationYear,
    this.yearsOfExperience = 0,
    this.employmentType = '',
    this.birthDate,
    this.hireDate,
    this.section = 'Nursery',
    this.group = '',
    this.groupId = '',
    this.groupName = '',
    this.assignedGroups = const [],
    this.salaryCalculationType = 'hourly',
    this.hourlyRate = 8,
    this.baseSalary = 0,
    this.responsibilities = const [],
    this.certifications = const [],
    this.adminScope = '',
    this.permissions = const [],
    this.fcmTokens = const [],
    this.isLiveStreamStation = false,
    this.cvNotes = '',
    this.adminNotes = '',
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  static String normalizeRole(dynamic value) {
    final role = (value ?? '').toString().trim().toLowerCase();

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

      case 'parent':
      case 'ولي امر':
      case 'ولي أمر':
      case 'ولي الامر':
      case 'ولي الأمر':
        return 'parent';

      default:
        return role.isEmpty ? 'parent' : role;
    }
  }

  static String normalizeAccountStatus(
    dynamic value, {
    required bool isActive,
  }) {
    final status = _string(value).toLowerCase();

    if (!isActive) return 'archived';

    switch (status) {
      case 'archived':
      case 'inactive':
      case 'deactivated':
      case 'disabled':
      case 'suspended':
      case 'pending_deletion':
      case 'deleted':
        return 'archived';

      case 'active':
      case '':
      default:
        return 'active';
    }
  }

  static String normalizeSection(dynamic value) {
    final section = _string(value);

    if (section.toLowerCase() == 'nursery' || section == 'حضانة') {
      return 'Nursery';
    }

    if (section.toLowerCase() == 'all') return 'all';

    return section.isEmpty ? 'Nursery' : section;
  }

  static String normalizeSalaryCalculationType(dynamic value) {
    final type = _string(value).toLowerCase();

    switch (type) {
      case 'hourly':
      case 'hours':
      case 'بالساعة':
        return 'hourly';

      // يبقى للقراءة من السجلات القديمة فقط.
      case 'monthly':
        return 'monthly';

      default:
        return type.isEmpty ? 'hourly' : type;
    }
  }

  static Map<String, dynamic> _mapField(
    Map<String, dynamic> map,
    String key,
  ) {
    final value = map[key];

    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);

    return <String, dynamic>{};
  }

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = _string(value);

      if (text.isNotEmpty) return text;
    }

    return '';
  }

  static bool _boolValue(dynamic value, {required bool defaultValue}) {
    if (value is bool) return value;

    final text = _string(value).toLowerCase();

    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;

    return defaultValue;
  }

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString().trim());
  }

  static int _intOrZero(dynamic value) {
    return _intOrNull(value) ?? 0;
  }

  static double _doubleOrZero(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString().trim()) ?? 0;
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    final text = value.toString().trim();

    if (text.isEmpty) return null;

    return DateTime.tryParse(text);
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    if (value is String) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    return <String>[];
  }

  static List<String> _mergedStringLists(List<dynamic> values) {
    final result = <String>{};

    for (final value in values) {
      result.addAll(_stringList(value));

      if (value is String && value.trim().isNotEmpty) {
        result.add(value.trim());
      }
    }

    return result.toList();
  }

  bool get isParent => normalizeRole(role) == 'parent';
  bool get isNurseryStaff => normalizeRole(role) == 'nursery_staff';
  bool get isAdmin => normalizeRole(role) == 'admin';
  bool get isEmployee => isNurseryStaff || isAdmin;
  bool get isStreamStation => isLiveStreamStation;

  bool get isArchived {
    return normalizeAccountStatus(accountStatus, isActive: isActive) ==
        'archived';
  }

  bool get canLogin {
    return !isArchived && username.trim().isNotEmpty && email.trim().isNotEmpty;
  }

  bool get hasGroup {
    return groupId.trim().isNotEmpty ||
        groupName.trim().isNotEmpty ||
        group.trim().isNotEmpty;
  }

  String get displayName {
    return name.trim().isNotEmpty ? name : username;
  }

  String get displayGroup {
    return groupName.trim().isNotEmpty
        ? groupName
        : group.trim().isNotEmpty
            ? group
            : 'بدون مجموعة';
  }

  String get roleLabel {
    switch (normalizeRole(role)) {
      case 'parent':
        return 'ولي أمر';

      case 'nursery_staff':
        return 'موظف حضانة';

      case 'admin':
        return 'مدير النظام';

      default:
        return role;
    }
  }

  String get accountStatusLabel {
    return isArchived ? 'مؤرشف' : 'نشط';
  }

  String get salaryCalculationTypeLabel {
    switch (salaryCalculationType) {
      case 'hourly':
        return 'بالساعة';

      case 'monthly':
        return 'شهري';

      default:
        return salaryCalculationType;
    }
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final parentInfo = _mapField(map, 'parentInfo');
    final personalInfo = _mapField(map, 'personalInfo');
    final professionalInfo = _mapField(map, 'professionalInfo');
    final adminNotesMap = _mapField(map, 'adminNotes');

    final normalizedRole = normalizeRole(map['role']);

    final name = _firstNonEmpty([
      map['displayName'],
      map['name'],
      map['fullName'],
      parentInfo['fullName'],
      personalInfo['fullName'],
    ]);

    final username = _firstNonEmpty([
      map['username'],
      parentInfo['username'],
    ]).toLowerCase();

    final email = _firstNonEmpty([
      map['email'],
      parentInfo['email'],
    ]).toLowerCase();

    final phone = _firstNonEmpty([
      map['phone'],
      map['phoneNumber'],
      map['mobile'],
      parentInfo['phone'],
      personalInfo['phone'],
    ]);

    final alternatePhone = _firstNonEmpty([
      parentInfo['alternatePhone'],
      parentInfo['alternativePhone'],
      personalInfo['alternativePhone'],
      personalInfo['alternatePhone'],
      map['alternatePhone'],
      map['alternativePhone'],
    ]);

    final nationalId = _firstNonEmpty([
      map['nationalId'],
      map['identityNumber'],
      parentInfo['identityNumber'],
      personalInfo['nationalId'],
    ]);

    final gender = _firstNonEmpty([
      parentInfo['gender'],
      personalInfo['gender'],
      map['gender'],
    ]);

    final address = _firstNonEmpty([
      parentInfo['address'],
      personalInfo['address'],
      map['address'],
    ]);

    final city = _firstNonEmpty([
      parentInfo['city'],
      personalInfo['city'],
      map['city'],
    ]);

    final resolvedSection = normalizeSection(
      _firstNonEmpty([
        map['section'],
        professionalInfo['section'],
        normalizedRole == 'admin' ? map['adminScope'] : '',
      ]),
    );

    final resolvedGroupName = _firstNonEmpty([
      map['groupName'],
      map['group'],
      professionalInfo['groupName'],
      professionalInfo['group'],
    ]);

    final resolvedHourlyRate = _doubleOrZero(
      _firstNonEmpty([
        map['hourlyRate'],
        professionalInfo['hourlyRate'],
      ]),
    );

    final resolvedBaseSalary = _doubleOrZero(
      _firstNonEmpty([
        map['baseSalary'],
        professionalInfo['baseSalary'],
        map['monthlySalary'],
        professionalInfo['monthlySalary'],
      ]),
    );

    final rawIsActive = _boolValue(
      map['isActive'],
      defaultValue: true,
    );

    final normalizedAccountStatus = normalizeAccountStatus(
      _firstNonEmpty([
        map['accountStatus'],
        map['status'],
      ]),
      isActive: rawIsActive,
    );

    final normalizedIsActive = normalizedAccountStatus == 'active';

    return UserModel(
      id: _firstNonEmpty([
        map['id'],
        map['uid'],
        docId,
      ]),
      name: name,
      email: email,
      role: normalizedRole,
      username: username,
      isActive: normalizedIsActive,
      accountStatus: normalizedAccountStatus,
      archiveReason: _string(map['archiveReason']),
      archivedAt: _date(map['archivedAt']),
      reactivatedAt: _date(map['reactivatedAt']),
      phone: phone,
      alternatePhone: alternatePhone,
      nationalId: nationalId,
      gender: gender,
      address: address,
      city: city,
      relationship: _string(parentInfo['relationship']),
      jobTitle: _firstNonEmpty([
        professionalInfo['jobTitle'],
        map['jobTitle'],
      ]),
      qualification: _firstNonEmpty([
        professionalInfo['qualification'],
        map['qualification'],
      ]),
      university: _firstNonEmpty([
        professionalInfo['university'],
        map['university'],
      ]),
      college: _firstNonEmpty([
        professionalInfo['college'],
        map['college'],
      ]),
      specialization: _firstNonEmpty([
        professionalInfo['specialization'],
        map['specialization'],
      ]),
      graduationYear: _intOrNull(
        professionalInfo['graduationYear'] ?? map['graduationYear'],
      ),
      yearsOfExperience: _intOrZero(
        professionalInfo['yearsOfExperience'] ?? map['yearsOfExperience'],
      ),
      employmentType: _firstNonEmpty([
        professionalInfo['employmentType'],
        map['employmentType'],
      ]),
      birthDate: _date(personalInfo['birthDate'] ?? map['birthDate']),
      hireDate: _date(professionalInfo['hireDate'] ?? map['hireDate']),
      section: resolvedSection,
      group: _firstNonEmpty([
        map['group'],
        map['groupName'],
        professionalInfo['group'],
        professionalInfo['groupName'],
      ]),
      groupId: _firstNonEmpty([
        map['groupId'],
        professionalInfo['groupId'],
      ]),
      groupName: resolvedGroupName,
      assignedGroups: _stringList(
        map['assignedGroups'] ?? professionalInfo['assignedGroups'],
      ),
      salaryCalculationType: normalizeSalaryCalculationType(
        _firstNonEmpty([
          map['salaryCalculationType'],
          professionalInfo['salaryCalculationType'],
          'hourly',
        ]),
      ),
      hourlyRate: resolvedHourlyRate > 0 ? resolvedHourlyRate : 8,
      baseSalary: resolvedBaseSalary,
      responsibilities: _stringList(
        professionalInfo['responsibilities'] ?? map['responsibilities'],
      ),
      certifications: _stringList(
        professionalInfo['certifications'] ?? map['certifications'],
      ),
      adminScope: _firstNonEmpty([
        map['adminScope'],
        professionalInfo['adminScope'],
        normalizedRole == 'admin' ? 'all' : '',
      ]),
      permissions: _stringList(
        professionalInfo['permissions'] ??
            adminNotesMap['extraPermissions'] ??
            map['permissions'],
      ),
      fcmTokens: _mergedStringLists([
        map['fcmTokens'],
        map['fcmToken'],
      ]),
      isLiveStreamStation:
          _boolValue(map['isLiveStreamStation'], defaultValue: false),
      cvNotes: _firstNonEmpty([
        professionalInfo['cvNotes'],
        map['cvNotes'],
      ]),
      adminNotes: _firstNonEmpty([
        adminNotesMap['internalNotes'],
        map['notes'],
      ]),
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      lastLoginAt: _date(map['lastLoginAt']),
    );
  }

  factory UserModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return UserModel.fromMap(
      doc.data() ?? <String, dynamic>{},
      docId: doc.id,
    );
  }

  Map<String, dynamic> toMap() {
    final normalizedRole = normalizeRole(role);

    final normalizedSection = normalizedRole == 'admin'
        ? (adminScope == 'nursery' ? 'Nursery' : 'all')
        : normalizeSection(section);

    final cleanUsername = username.trim().toLowerCase();
    final cleanEmail = email.trim().toLowerCase();

    final cleanAccountStatus = normalizeAccountStatus(
      accountStatus,
      isActive: isActive,
    );

    final normalizedIsActive = cleanAccountStatus == 'active';

    final resolvedGroupName = groupName.trim().isNotEmpty ? groupName : group;
    final resolvedGroup = group.trim().isNotEmpty ? group : resolvedGroupName;

    final cleanFcmTokens = fcmTokens
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final data = <String, dynamic>{
      'id': id,
      'uid': id,
      'name': name,
      'displayName': name,
      'email': cleanEmail,
      'role': normalizedRole,
      'username': cleanUsername,
      'isActive': normalizedIsActive,
      'accountStatus': cleanAccountStatus,
      'archiveReason': archiveReason,
      'phone': phone,
      'alternatePhone': alternatePhone,
      'alternativePhone': alternatePhone,
      'section': normalizedSection,
      'group': normalizedRole == 'nursery_staff' ? resolvedGroup : '',
      'groupId': normalizedRole == 'nursery_staff' ? groupId : '',
      'groupName': normalizedRole == 'nursery_staff' ? resolvedGroupName : '',
      'assignedGroups':
          normalizedRole == 'nursery_staff' ? assignedGroups : <String>[],
      'fcmTokens': cleanFcmTokens,
      'isLiveStreamStation': isLiveStreamStation,
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
    };

    if (createdAt != null) {
      data['createdAt'] = Timestamp.fromDate(createdAt!);
    }

    if (lastLoginAt != null) {
      data['lastLoginAt'] = Timestamp.fromDate(lastLoginAt!);
    }

    if (archivedAt != null) {
      data['archivedAt'] = Timestamp.fromDate(archivedAt!);
    }

    if (reactivatedAt != null) {
      data['reactivatedAt'] = Timestamp.fromDate(reactivatedAt!);
    }

    if (normalizedRole == 'parent') {
      data['parentInfo'] = {
        'fullName': name,
        'username': cleanUsername,
        'email': cleanEmail,
        'phone': phone,
        'alternatePhone': alternatePhone,
        'identityNumber': nationalId,
        'gender': gender,
        'relationship': relationship,
        'city': city,
        'address': address,
      };
    }

    if (normalizedRole == 'nursery_staff' || normalizedRole == 'admin') {
      final personalInfo = <String, dynamic>{
        'nationalId': nationalId,
        'gender': gender,
        'phone': phone,
        'alternativePhone': alternatePhone,
        'address': address,
        'city': city,
      };

      if (birthDate != null) {
        personalInfo['birthDate'] = Timestamp.fromDate(birthDate!);
      }

      final professionalInfo = <String, dynamic>{
        'jobTitle': jobTitle,
        'qualification': qualification,
        'university': university,
        'college': college,
        'specialization': specialization,
        'graduationYear': graduationYear,
        'yearsOfExperience': yearsOfExperience,
        'employmentType': employmentType,
        'cvNotes': cvNotes,
        'section': normalizedSection,
        'group': normalizedRole == 'nursery_staff' ? resolvedGroup : '',
        'groupId': normalizedRole == 'nursery_staff' ? groupId : '',
        'groupName': normalizedRole == 'nursery_staff' ? resolvedGroupName : '',
        'assignedGroups':
            normalizedRole == 'nursery_staff' ? assignedGroups : <String>[],
        'salaryCalculationType': normalizeSalaryCalculationType(
          salaryCalculationType,
        ),
        'hourlyRate': hourlyRate,
        'baseSalary': baseSalary,
      };

      if (hireDate != null) {
        professionalInfo['hireDate'] = Timestamp.fromDate(hireDate!);
      }

      if (normalizedRole == 'nursery_staff') {
        professionalInfo['responsibilities'] = responsibilities;
        professionalInfo['certifications'] = certifications;
      }

      if (normalizedRole == 'admin') {
        final resolvedAdminScope = adminScope.isEmpty ? 'all' : adminScope;

        data['adminScope'] = resolvedAdminScope;
        professionalInfo['adminScope'] = resolvedAdminScope;
        professionalInfo['permissions'] = permissions;
      }

      data['personalInfo'] = personalInfo;
      data['professionalInfo'] = professionalInfo;
    }

    data['adminNotes'] = {
      'internalNotes': adminNotes,
      if (permissions.isNotEmpty) 'extraPermissions': permissions,
    };

    return data;
  }

  Map<String, dynamic> toLoginUsernameMap() {
    final cleanAccountStatus = normalizeAccountStatus(
      accountStatus,
      isActive: isActive,
    );

    return {
      'uid': id,
      'username': username.trim().toLowerCase(),
      'email': email.trim().toLowerCase(),
      'role': normalizeRole(role),
      'isActive': cleanAccountStatus == 'active',
      'accountStatus': cleanAccountStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? username,
    bool? isActive,
    String? accountStatus,
    String? archiveReason,
    DateTime? archivedAt,
    DateTime? reactivatedAt,
    String? phone,
    String? alternatePhone,
    String? nationalId,
    String? gender,
    String? address,
    String? city,
    String? relationship,
    String? jobTitle,
    String? qualification,
    String? university,
    String? college,
    String? specialization,
    int? graduationYear,
    int? yearsOfExperience,
    String? employmentType,
    DateTime? birthDate,
    DateTime? hireDate,
    String? section,
    String? group,
    String? groupId,
    String? groupName,
    List<String>? assignedGroups,
    String? salaryCalculationType,
    double? hourlyRate,
    double? baseSalary,
    List<String>? responsibilities,
    List<String>? certifications,
    String? adminScope,
    List<String>? permissions,
    List<String>? fcmTokens,
    bool? isLiveStreamStation,
    String? cvNotes,
    String? adminNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role == null ? this.role : normalizeRole(role),
      username: username ?? this.username,
      isActive: isActive ?? this.isActive,
      accountStatus: accountStatus ?? this.accountStatus,
      archiveReason: archiveReason ?? this.archiveReason,
      archivedAt: archivedAt ?? this.archivedAt,
      reactivatedAt: reactivatedAt ?? this.reactivatedAt,
      phone: phone ?? this.phone,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      nationalId: nationalId ?? this.nationalId,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      city: city ?? this.city,
      relationship: relationship ?? this.relationship,
      jobTitle: jobTitle ?? this.jobTitle,
      qualification: qualification ?? this.qualification,
      university: university ?? this.university,
      college: college ?? this.college,
      specialization: specialization ?? this.specialization,
      graduationYear: graduationYear ?? this.graduationYear,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      employmentType: employmentType ?? this.employmentType,
      birthDate: birthDate ?? this.birthDate,
      hireDate: hireDate ?? this.hireDate,
      section: section ?? this.section,
      group: group ?? this.group,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      assignedGroups: assignedGroups ?? this.assignedGroups,
      salaryCalculationType: salaryCalculationType == null
          ? this.salaryCalculationType
          : normalizeSalaryCalculationType(salaryCalculationType),
      hourlyRate: hourlyRate ?? this.hourlyRate,
      baseSalary: baseSalary ?? this.baseSalary,
      responsibilities: responsibilities ?? this.responsibilities,
      certifications: certifications ?? this.certifications,
      adminScope: adminScope ?? this.adminScope,
      permissions: permissions ?? this.permissions,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      isLiveStreamStation:
          isLiveStreamStation ?? this.isLiveStreamStation,
      cvNotes: cvNotes ?? this.cvNotes,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
