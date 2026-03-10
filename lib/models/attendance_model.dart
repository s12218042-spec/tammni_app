class AttendanceModel {
  final String childId;
  final DateTime date;
  bool present;

  AttendanceModel({
    required this.childId,
    required this.date,
    required this.present,
  });
}