class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // parent / nursery / teacher / admin

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
}