enum UserRole {
  parent,
  nurseryStaff,
  admin,
}

UserRole roleFromString(String s) {
  final value = s.trim().toLowerCase();

  switch (value) {
    case 'parent':
      return UserRole.parent;

    case 'nursery_staff':
    case 'nursery staff':
    case 'nursery':
      return UserRole.nurseryStaff;

    case 'admin':
    default:
      return UserRole.admin;
  }
}

String roleToString(UserRole role) {
  switch (role) {
    case UserRole.parent:
      return 'parent';
    case UserRole.nurseryStaff:
      return 'nursery_staff';
    case UserRole.admin:
      return 'admin';
  }
}

String roleLabel(UserRole role) {
  switch (role) {
    case UserRole.parent:
      return 'ولي أمر';
    case UserRole.nurseryStaff:
      return 'موظف/ة حضانة';
    case UserRole.admin:
      return 'مدير النظام';
  }
}

bool isEmployeeRole(UserRole role) {
  return role == UserRole.nurseryStaff ||
      role == UserRole.admin;
}