class AccountModel {
  final String id;
  final String uid;

  final String username;
  final String email;
  final String role;
  final String displayName;
  final String name;

  final bool isActive;
  final String accountStatus;
  final bool invitationVerified;

  // توافق قديم فقط، لا يُنصح بحفظ كلمة المرور في Firestore
  final String password;

  final String phone;
  final String alternatePhone;

  final String createdByUid;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AccountModel({
    required this.id,
    required this.username,
    required this.role,
    required this.displayName,
    this.uid = '',
    this.email = '',
    this.name = '',
    this.isActive = true,
    this.accountStatus = 'active',
    this.invitationVerified = false,
    this.password = '',
    this.phone = '',
    this.alternatePhone = '',
    this.createdByUid = '',
    this.createdByName = '',
    this.createdAt,
    this.updatedAt,
  });

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

  static String normalizeRole(dynamic value) {
    final role = _string(value).toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }

    if (role == 'parent') return 'parent';
    if (role == 'admin') return 'admin';

    return role.isEmpty ? 'parent' : role;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    try {
      final dynamic dynamicValue = value;
      final converted = dynamicValue.toDate();
      if (converted is DateTime) return converted;
    } catch (_) {}

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    return DateTime.tryParse(text);
  }

  static Map<String, dynamic> _mapField(
    Map<String, dynamic> data,
    String key,
  ) {
    final value = data[key];
    if (value is Map<String, dynamic>) return value;
    return <String, dynamic>{};
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

  factory AccountModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    final parentInfo = _mapField(map, 'parentInfo');
    final personalInfo = _mapField(map, 'personalInfo');

    final resolvedName = _firstNonEmpty([
      map['displayName'],
      map['name'],
      parentInfo['fullName'],
    ]);

    final resolvedUsername = _firstNonEmpty([
      map['username'],
      parentInfo['username'],
    ]).toLowerCase();

    final resolvedEmail = _firstNonEmpty([
      map['email'],
      parentInfo['email'],
    ]).toLowerCase();

    final resolvedPhone = _firstNonEmpty([
      map['phone'],
      parentInfo['phone'],
      personalInfo['phone'],
    ]);

    final resolvedAlternatePhone = _firstNonEmpty([
      parentInfo['alternatePhone'],
      parentInfo['alternativePhone'],
      personalInfo['alternatePhone'],
      personalInfo['alternativePhone'],
      map['alternatePhone'],
      map['alternativePhone'],
    ]);

    return AccountModel(
      id: _firstNonEmpty([
        map['id'],
        map['uid'],
        docId,
      ]),
      uid: _firstNonEmpty([
        map['uid'],
        map['id'],
        docId,
      ]),
      username: resolvedUsername,
      email: resolvedEmail,
      role: normalizeRole(map['role']),
      displayName: resolvedName,
      name: resolvedName,
      isActive: (map['isActive'] ?? true) == true,
      accountStatus: _firstNonEmpty([
        map['accountStatus'],
        'active',
      ]),
      invitationVerified: (map['invitationVerified'] ?? false) == true,
      password: _string(map['password']),
      phone: resolvedPhone,
      alternatePhone: resolvedAlternatePhone,
      createdByUid: _string(map['createdByUid']),
      createdByName: _string(map['createdByName']),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final normalizedRole = normalizeRole(role);
    final resolvedId = uid.trim().isNotEmpty ? uid.trim() : id.trim();
    final resolvedName =
        displayName.trim().isNotEmpty ? displayName.trim() : name.trim();

    final data = <String, dynamic>{
      'id': resolvedId,
      'uid': resolvedId,
      'username': username.trim().toLowerCase(),
      'email': email.trim().toLowerCase(),
      'role': normalizedRole,
      'displayName': resolvedName,
      'name': resolvedName,
      'isActive': isActive,
      'accountStatus': accountStatus.trim().isEmpty ? 'active' : accountStatus,
      'invitationVerified': invitationVerified,
      'phone': phone.trim(),
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };

    if (alternatePhone.trim().isNotEmpty) {
      data['alternatePhone'] = alternatePhone.trim();
    }

    // للتوافق فقط، لا تحفظي كلمة المرور في Firestore إلا إذا كان عندك كود legacy مؤقت
    if (password.trim().isNotEmpty) {
      data['password'] = password.trim();
    }

    if (normalizedRole == 'parent') {
      data['parentInfo'] = {
        'fullName': resolvedName,
        'username': username.trim().toLowerCase(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'alternatePhone': alternatePhone.trim(),
      };
    }

    if (normalizedRole == 'nursery_staff' || normalizedRole == 'admin') {
      data['personalInfo'] = {
        'phone': phone.trim(),
        'alternativePhone': alternatePhone.trim(),
      };
    }

    return data;
  }

  Map<String, dynamic> toLoginUsernameMap() {
    final resolvedId = uid.trim().isNotEmpty ? uid.trim() : id.trim();

    return {
      'uid': resolvedId,
      'username': username.trim().toLowerCase(),
      'email': email.trim().toLowerCase(),
      'role': normalizeRole(role),
      'isActive': isActive,
      'accountStatus': accountStatus.trim().isEmpty ? 'active' : accountStatus,
      'updatedAt': updatedAt,
    };
  }

  AccountModel copyWith({
    String? id,
    String? uid,
    String? username,
    String? email,
    String? role,
    String? displayName,
    String? name,
    bool? isActive,
    String? accountStatus,
    bool? invitationVerified,
    String? password,
    String? phone,
    String? alternatePhone,
    String? createdByUid,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role == null ? this.role : normalizeRole(role),
      displayName: displayName ?? this.displayName,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      accountStatus: accountStatus ?? this.accountStatus,
      invitationVerified: invitationVerified ?? this.invitationVerified,
      password: password ?? this.password,
      phone: phone ?? this.phone,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}