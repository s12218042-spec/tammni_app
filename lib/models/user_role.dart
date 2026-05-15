enum UserRole {
  parent,
  nurseryStaff,
  admin,
}

UserRole roleFromString(String value) {
  final role = value.trim().toLowerCase();

  switch (role) {
    case 'parent':
      return UserRole.parent;

    case 'nursery':
    case 'nursery_staff':
    case 'nursery staff':
      return UserRole.nurseryStaff;

    case 'admin':
      return UserRole.admin;

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
      return 'موظفة حضانة';
    case UserRole.admin:
      return 'مدير النظام';
  }
}

String roleLabelFromString(String value) {
  return roleLabel(roleFromString(value));
}

bool isParentRole(UserRole role) {
  return role == UserRole.parent;
}

bool isNurseryStaffRole(UserRole role) {
  return role == UserRole.nurseryStaff;
}

bool isAdminRole(UserRole role) {
  return role == UserRole.admin;
}

bool isEmployeeRole(UserRole role) {
  return role == UserRole.nurseryStaff || role == UserRole.admin;
}

bool isNurseryStaffRoleString(String value) {
  return roleFromString(value) == UserRole.nurseryStaff;
}

bool isAdminRoleString(String value) {
  return roleFromString(value) == UserRole.admin;
}

bool isParentRoleString(String value) {
  return roleFromString(value) == UserRole.parent;
}

bool isEmployeeRoleString(String value) {
  return isEmployeeRole(roleFromString(value));
}