class ClassModel {
  final String id;
  final String section; // Nursery / Kindergarten
  final String name;    // مثال: حضانة كبار / KG1
  int childrenCount;

  ClassModel({
    required this.id,
    required this.section,
    required this.name,
    required this.childrenCount,
  });
}