class ChildModel {
  final String id;
  final String name;
  final String section; // Nursery / Kindergarten
  final String group;   // حضانة كبار / KG1 ...
  final String parentName;
  final DateTime birthDate;
  final String parentUsername; // الحساب المرتبط بهذا الطفل

  ChildModel({
    required this.id,
    required this.name,
    required this.section,
    required this.group,
    required this.parentName,
    required this.birthDate,
    required this.parentUsername,
  });
}