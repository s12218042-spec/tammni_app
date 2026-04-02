class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // parent / nursery_staff / teacher / admin

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawRole = (map['role'] ?? '').toString().trim().toLowerCase();

    final normalizedRole =
        rawRole == 'nursery' || rawRole == 'nursery staff'
            ? 'nursery_staff'
            : rawRole;

    return UserModel(
      id: (map['id'] ?? map['uid'] ?? docId ?? '').toString(),
      name: (map['name'] ?? map['displayName'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      role: normalizedRole,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': id,
      'name': name,
      'displayName': name,
      'email': email,
      'role': role,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }
}