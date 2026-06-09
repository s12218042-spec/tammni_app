import 'package:cloud_firestore/cloud_firestore.dart';

class AccountModel {
  final String id;
  final String uid;

  final String username;
  final String email;
  final String pendingEmail;
  final String role;
  final String displayName;
  final String name;

  final bool isActive;
  final String accountStatus;
  final bool invitationVerified;
  final bool isProfileCompleted;
  final bool mustChangePassword;
  final bool isFirstLogin;
  final bool isLiveStreamStation;

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
    this.pendingEmail = '',
    this.name = '',
    this.isActive = true,
    this.accountStatus = 'active',
    this.invitationVerified = false,
    this.isProfileCompleted = true,
    this.mustChangePassword = false,
    this.isFirstLogin = false,
    this.isLiveStreamStation = false,
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

  static bool _boolValue(dynamic value, {required bool defaultValue}) {
    if (value is bool) return value;

    final text = _string(value).toLowerCase();

    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;

    return defaultValue;
  }

  static String normalizeRole(dynamic value) {
    final role = _string(value).toLowerCase();

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

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

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
    if (value is Map) return Map<String, dynamic>.from(value);

    return <String, dynamic>{};
  }

  bool get isParent => normalizeRole(role) == 'parent';
  bool get isNurseryStaff => normalizeRole(role) == 'nursery_staff';
  bool get isAdmin => normalizeRole(role) == 'admin';
  bool get isEmployee => isNurseryStaff || isAdmin;
  bool get isStreamStation => isLiveStreamStation;

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

  factory AccountModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    final parentInfo = _mapField(map, 'parentInfo');
    final personalInfo = _mapField(map, 'personalInfo');

    final resolvedName = _firstNonEmpty([
      map['displayName'],
      map['name'],
      map['fullName'],
      parentInfo['fullName'],
      personalInfo['fullName'],
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
      map['phoneNumber'],
      map['mobile'],
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

    final isActive = _boolValue(
      map['isActive'],
      defaultValue: true,
    );

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
      pendingEmail: _string(map['pendingEmail']).toLowerCase(),
      role: normalizeRole(map['role']),
      displayName: resolvedName,
      name: resolvedName,
      isActive: isActive,
      accountStatus: _firstNonEmpty([
        map['accountStatus'],
        map['status'],
        isActive ? 'active' : 'inactive',
      ]),
      invitationVerified: _boolValue(
        map['invitationVerified'] ?? map['emailVerified'],
        defaultValue: false,
      ),
      isProfileCompleted: _boolValue(
        map['isProfileCompleted'],
        defaultValue: true,
      ),
      mustChangePassword: _boolValue(
        map['mustChangePassword'],
        defaultValue: false,
      ),
      isFirstLogin: _boolValue(
        map['isFirstLogin'],
        defaultValue: false,
      ),
      isLiveStreamStation: _boolValue(
        map['isLiveStreamStation'],
        defaultValue: false,
      ),
      password: _firstNonEmpty([
        map['temporaryPasswordPlain'],
        map['password'],
      ]),
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

    final cleanUsername = username.trim().toLowerCase();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPendingEmail = pendingEmail.trim().toLowerCase();

    final data = <String, dynamic>{
      'id': resolvedId,
      'uid': resolvedId,
      'username': cleanUsername,
      'email': cleanEmail,
      'role': normalizedRole,
      'displayName': resolvedName,
      'name': resolvedName,
      'isActive': isActive,
      'accountStatus': accountStatus.trim().isEmpty
          ? (isActive ? 'active' : 'inactive')
          : accountStatus.trim(),
      'invitationVerified': invitationVerified,
      'isProfileCompleted': isProfileCompleted,
      'mustChangePassword': mustChangePassword,
      'isFirstLogin': isFirstLogin,
      'isLiveStreamStation': isLiveStreamStation,
      'phone': phone.trim(),
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
    };

    if (cleanPendingEmail.isNotEmpty) {
      data['pendingEmail'] = cleanPendingEmail;
    }

    if (createdAt != null) {
      data['createdAt'] = Timestamp.fromDate(createdAt!);
    }

    if (alternatePhone.trim().isNotEmpty) {
      data['alternatePhone'] = alternatePhone.trim();
      data['alternativePhone'] = alternatePhone.trim();
    }

    if (normalizedRole == 'parent') {
      data['parentInfo'] = {
        'fullName': resolvedName,
        'username': cleanUsername,
        'email': cleanEmail,
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

    final data = <String, dynamic>{
      'uid': resolvedId,
      'username': username.trim().toLowerCase(),
      'email': email.trim().toLowerCase(),
      'role': normalizeRole(role),
      'isActive': isActive,
      'accountStatus': accountStatus.trim().isEmpty
          ? (isActive ? 'active' : 'inactive')
          : accountStatus.trim(),
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
    };

    final cleanPendingEmail = pendingEmail.trim().toLowerCase();

    if (cleanPendingEmail.isNotEmpty) {
      data['pendingEmail'] = cleanPendingEmail;
    }

    return data;
  }

  AccountModel copyWith({
    String? id,
    String? uid,
    String? username,
    String? email,
    String? pendingEmail,
    String? role,
    String? displayName,
    String? name,
    bool? isActive,
    String? accountStatus,
    bool? invitationVerified,
    bool? isProfileCompleted,
    bool? mustChangePassword,
    bool? isFirstLogin,
    bool? isLiveStreamStation,
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
      pendingEmail: pendingEmail ?? this.pendingEmail,
      role: role == null ? this.role : normalizeRole(role),
      displayName: displayName ?? this.displayName,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      accountStatus: accountStatus ?? this.accountStatus,
      invitationVerified: invitationVerified ?? this.invitationVerified,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      isLiveStreamStation:
          isLiveStreamStation ?? this.isLiveStreamStation,
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
