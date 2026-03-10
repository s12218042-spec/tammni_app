import '../models/child_model.dart';
import '../models/update_model.dart';
import '../models/attendance_model.dart';
import '../models/account_model.dart';

class DummyData {
  // ================= الحسابات =================
  static final List<AccountModel> accounts = [
    AccountModel(
      id: 'a1',
      username: 'parent1',
      password: 'Parent123',
      role: 'parent',
      displayName: 'مجد',
      email: 'parent1@gmail.com',
    ),
    AccountModel(
      id: 'a2',
      username: 'nursery1',
      password: 'Nursery123',
      role: 'nursery',
      displayName: 'سارة',
      email: 'nursery@gmail.com',
      invitationVerified: true,
    ),
    AccountModel(
      id: 'a3',
      username: 'teacher1',
      password: 'Teacher123',
      role: 'teacher',
      displayName: 'هبة',
      email: 'teacher@gmail.com',
      invitationVerified: true,
    ),
    AccountModel(
      id: 'a4',
      username: 'admin',
      password: 'Admin123',
      role: 'admin',
      displayName: 'Admin',
      email: 'admin@gmail.com',
      invitationVerified: true,
    ),
  ];

  // ================= الصفوف/المجموعات =================
  static final List<Map<String, dynamic>> classes = [
    {
      'id': 'cl1',
      'section': 'Nursery',
      'name': 'حضانة صغار',
      'childrenCount': 8,
    },
    {
      'id': 'cl2',
      'section': 'Nursery',
      'name': 'حضانة كبار',
      'childrenCount': 10,
    },
    {
      'id': 'cl3',
      'section': 'Kindergarten',
      'name': 'KG1',
      'childrenCount': 12,
    },
    {
      'id': 'cl4',
      'section': 'Kindergarten',
      'name': 'KG2',
      'childrenCount': 11,
    },
  ];

  static void addClass(Map<String, dynamic> newClass) {
    classes.add(newClass);
  }

  static void deleteClass(String id) {
    classes.removeWhere((c) => c['id'] == id);
  }
  
  // ================= الأطفال =================
  static final List<ChildModel> children = [
    ChildModel(
      id: 'c1',
      name: 'محمد أحمد',
      section: 'Nursery',
      group: 'حضانة كبار',
      parentName: 'مجد',
      birthDate: DateTime(2023, 5, 12),
      parentUsername: 'parent1',
    ),
    ChildModel(
      id: 'c2',
      name: 'ليان خالد',
      section: 'Nursery',
      group: 'حضانة صغار',
      parentName: 'مجد',
      birthDate: DateTime(2024, 1, 7),
      parentUsername: 'parent1',
    ),
    ChildModel(
      id: 'c3',
      name: 'يوسف علي',
      section: 'Kindergarten',
      group: 'KG1',
      parentName: 'مجد',
      birthDate: DateTime(2021, 3, 10),
      parentUsername: 'parent1',
    ),
  ];

  // ================= التحديثات =================
  static final List<UpdateModel> updates = [
    UpdateModel(
      id: 'u1',
      childId: 'c1',
      childName: 'محمد أحمد',
      type: 'وجبة',
      note: 'تناول وجبة الفطور 🍎',
      time: DateTime.now().subtract(const Duration(minutes: 20)),
      byRole: 'nursery',
    ),
    UpdateModel(
      id: 'u2',
      childId: 'c1',
      childName: 'محمد أحمد',
      type: 'نشاط',
      note: 'نشاط رسم وتلوين 🎨',
      time: DateTime.now().subtract(const Duration(minutes: 10)),
      byRole: 'nursery',
    ),
  ];

  // ================= الحضور =================
  static final List<AttendanceModel> attendance = [
    AttendanceModel(childId: 'c1', date: DateTime.now(), present: true),
    AttendanceModel(childId: 'c2', date: DateTime.now(), present: true),
    AttendanceModel(childId: 'c3', date: DateTime.now(), present: false),
  ];

  // ================= Invitation Codes =================
  static const String nurseryInvitationCode = 'NURSERY2026';
  static const String teacherInvitationCode = 'TEACHER2026';

  static String newId(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}';

  // ================= أعمار وأقسام =================
  static int ageInYears(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  static String sectionFromBirthDate(DateTime birthDate) {
    final age = ageInYears(birthDate);
    if (age < 3) return 'Nursery';
    return 'Kindergarten';
  }

  static String defaultGroupForSection(String section) {
    if (section == 'Nursery') return 'حضانة صغار';
    return 'KG1';
  }

  // ================= الحسابات =================
  static bool usernameExists(String username) {
    return accounts.any((a) => a.username.trim() == username.trim());
  }

  static void addAccount(AccountModel account) {
    accounts.add(account);
  }

  static AccountModel? login(String username, String password) {
    try {
      return accounts.firstWhere(
        (a) => a.username.trim() == username.trim() && a.password == password,
      );
    } catch (_) {
      return null;
    }
  }

  // ================= الأطفال المرتبطين بولي الأمر =================
  static List<ChildModel> childrenForParent(String parentUsername) {
    return children.where((c) => c.parentUsername == parentUsername).toList();
  }

  static void addChild(ChildModel child) {
    children.add(child);
  }

  static void deleteChild(String id) {
    children.removeWhere((c) => c.id == id);
  }

  static void updateChild(ChildModel updated) {
    final idx = children.indexWhere((c) => c.id == updated.id);
    if (idx != -1) children[idx] = updated;
  }

  // ================= التحديثات =================
  static List<UpdateModel> updatesForChild(String childId) {
    final list = updates.where((u) => u.childId == childId).toList();
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  // ================= الحضور =================
  static bool isPresentToday(String childId) {
    final today = DateTime.now();
    final item = attendance.where((a) =>
        a.childId == childId &&
        a.date.year == today.year &&
        a.date.month == today.month &&
        a.date.day == today.day);
    if (item.isEmpty) return false;
    return item.first.present;
  }

  static void setPresentToday(String childId, bool present) {
    final today = DateTime.now();
    final idx = attendance.indexWhere((a) =>
        a.childId == childId &&
        a.date.year == today.year &&
        a.date.month == today.month &&
        a.date.day == today.day);

    if (idx == -1) {
      attendance.add(
        AttendanceModel(childId: childId, date: today, present: present),
      );
    } else {
      attendance[idx].present = present;
    }
  }
}