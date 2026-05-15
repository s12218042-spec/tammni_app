import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String username;
  final bool isActive;
  final String accountStatus;

  // بيانات تواصل عامة
  final String phone;
  final String alternatePhone;
  final String nationalId;
  final String gender;
  final String address;
  final String city;

  // بيانات ولي الأمر
  final String relationship;

  // بيانات مهنية / تعليمية للموظفة والأدمن
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

  // بيانات خاصة بالموظفة
  final List<String> responsibilities;
  final List<String> certifications;

  // بيانات خاصة بالأدمن
  final String adminScope;
  final List<String> permissions;

  // ملاحظات
  final String cvNotes;
  final String adminNotes;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.username = '',
    this.isActive = true,
    this.accountStatus = 'active',
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
    this.responsibilities = const [],
    this.certifications = const [],
    this.adminScope = '',
    this.permissions = const [],
    this.cvNotes = '',
    this.adminNotes = '',
  });

  static String normalizeRole(dynamic value) {
    final role = (value ?? '').toString().trim().toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }

    if (role == 'parent') return 'parent';
    if (role == 'admin') return 'admin';

    return role.isEmpty ? 'parent' : role;
  }

  static Map<String, dynamic> _mapField(
    Map<String, dynamic> map,
    String key,
  ) {
    final value = map[key];
    if (value is Map<String, dynamic>) return value;
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

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString().trim());
  }

  static int _intOrZero(dynamic value) {
    return _intOrNull(value) ?? 0;
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

  bool get isParent => role == 'parent';
  bool get isNurseryStaff => role == 'nursery_staff';
  bool get isAdmin => role == 'admin';
  bool get isEmployee => isNurseryStaff || isAdmin;

  String get roleLabel {
    switch (role) {
      case 'parent':
        return 'ولي أمر';
      case 'nursery_staff':
        return 'موظفة حضانة';
      case 'admin':
        return 'مدير النظام';
      default:
        return role;
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
      parentInfo['fullName'],
    ]);

    final username = _firstNonEmpty([
      map['username'],
      parentInfo['username'],
    ]);

    final email = _firstNonEmpty([
      map['email'],
      parentInfo['email'],
    ]);

    final phone = _firstNonEmpty([
      map['phone'],
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
      map['city'],
    ]);

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
      isActive: (map['isActive'] ?? true) == true,
      accountStatus: _firstNonEmpty([
        map['accountStatus'],
        'active',
      ]),
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
      qualification: _string(professionalInfo['qualification']),
      university: _string(professionalInfo['university']),
      college: _string(professionalInfo['college']),
      specialization: _string(professionalInfo['specialization']),
      graduationYear: _intOrNull(professionalInfo['graduationYear']),
      yearsOfExperience: _intOrZero(professionalInfo['yearsOfExperience']),
      employmentType: _string(professionalInfo['employmentType']),
      birthDate: _date(personalInfo['birthDate'] ?? map['birthDate']),
      hireDate: _date(professionalInfo['hireDate']),
      responsibilities: _stringList(professionalInfo['responsibilities']),
      certifications: _stringList(professionalInfo['certifications']),
      adminScope: _firstNonEmpty([
        map['adminScope'],
        professionalInfo['adminScope'],
      ]),
      permissions: _stringList(
        professionalInfo['permissions'] ?? adminNotesMap['extraPermissions'],
      ),
      cvNotes: _string(professionalInfo['cvNotes']),
      adminNotes: _firstNonEmpty([
        adminNotesMap['internalNotes'],
        map['notes'],
      ]),
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
    final data = <String, dynamic>{
      'id': id,
      'uid': id,
      'name': name,
      'displayName': name,
      'email': email,
      'role': normalizeRole(role),
      'username': username,
      'isActive': isActive,
      'accountStatus': accountStatus,
    };

    if (isParent) {
      data['phone'] = phone;
      data['parentInfo'] = {
        'fullName': name,
        'username': username,
        'email': email,
        'phone': phone,
        'alternatePhone': alternatePhone,
        'identityNumber': nationalId,
        'gender': gender,
        'relationship': relationship,
        'city': city,
        'address': address,
      };
    }

    if (isNurseryStaff || isAdmin) {
      data['phone'] = phone;
      data['personalInfo'] = {
        'nationalId': nationalId,
        'gender': gender,
        'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),
        'phone': phone,
        'alternativePhone': alternatePhone,
        'address': address,
      };

      data['professionalInfo'] = {
        'jobTitle': jobTitle,
        'qualification': qualification,
        'university': university,
        'college': college,
        'specialization': specialization,
        'graduationYear': graduationYear,
        'yearsOfExperience': yearsOfExperience,
        'employmentType': employmentType,
        'hireDate': hireDate == null ? null : Timestamp.fromDate(hireDate!),
        'cvNotes': cvNotes,
      };

      if (isNurseryStaff) {
        data['section'] = 'Nursery';
        data['group'] = '';
        data['groupId'] = '';
        data['groupName'] = '';
        data['assignedGroups'] = [];
        data['professionalInfo']['section'] = 'Nursery';
        data['professionalInfo']['responsibilities'] = responsibilities;
        data['professionalInfo']['certifications'] = certifications;
      }

      if (isAdmin) {
        data['adminScope'] = adminScope.isEmpty ? 'all' : adminScope;
        data['section'] = adminScope == 'nursery' ? 'Nursery' : 'all';
        data['professionalInfo']['adminScope'] =
            adminScope.isEmpty ? 'all' : adminScope;
        data['professionalInfo']['permissions'] = permissions;
      }
    }

    data['adminNotes'] = {
      'internalNotes': adminNotes,
      if (permissions.isNotEmpty) 'extraPermissions': permissions,
    };

    return data;
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? username,
    bool? isActive,
    String? accountStatus,
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
    List<String>? responsibilities,
    List<String>? certifications,
    String? adminScope,
    List<String>? permissions,
    String? cvNotes,
    String? adminNotes,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role == null ? this.role : normalizeRole(role),
      username: username ?? this.username,
      isActive: isActive ?? this.isActive,
      accountStatus: accountStatus ?? this.accountStatus,
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
      responsibilities: responsibilities ?? this.responsibilities,
      certifications: certifications ?? this.certifications,
      adminScope: adminScope ?? this.adminScope,
      permissions: permissions ?? this.permissions,
      cvNotes: cvNotes ?? this.cvNotes,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }
}