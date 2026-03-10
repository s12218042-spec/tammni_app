class AccountModel {
  final String id;
  final String username;
  final String password;
  final String role; // parent / nursery / teacher / admin
  final String displayName;
  final String? email;
  final bool invitationVerified;

  AccountModel({
    required this.id,
    required this.username,
    required this.password,
    required this.role,
    required this.displayName,
    this.email,
    this.invitationVerified = false,
  });
}