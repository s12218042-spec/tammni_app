enum UserRole { parent, nursery, teacher, admin }

UserRole roleFromString(String s) {
  switch (s) {
    case 'parent':
      return UserRole.parent;
    case 'nursery':
      return UserRole.nursery;
    case 'teacher':
      return UserRole.teacher;
    default:
      return UserRole.admin;
  }
}

String roleLabel(UserRole role) {
  switch (role) {
    case UserRole.parent:
      return 'ولي أمر';
    case UserRole.nursery:
      return 'موظف/ة حضانة';
    case UserRole.teacher:
      return 'معلمة روضة';
    case UserRole.admin:
      return 'مدير النظام';
  }
}