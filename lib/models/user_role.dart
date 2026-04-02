enum UserRole {
  parent,
  nurseryStaff,
  teacher,
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

    case 'teacher':
      return UserRole.teacher;

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
    case UserRole.teacher:
      return 'teacher';
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
    case UserRole.teacher:
      return 'معلمة روضة';
    case UserRole.admin:
      return 'مدير النظام';
  }
}

bool isEmployeeRole(UserRole role) {
  return role == UserRole.teacher ||
      role == UserRole.nurseryStaff ||
      role == UserRole.admin;
}