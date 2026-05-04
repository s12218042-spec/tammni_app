class UpdateModel {
  final String id;
  final String childId;
  final String childName;
  final String type; 
  final String note;
  final DateTime time;
  final String byRole; 

  // محتوى كاميرا
  final String? mediaPath; 
  final String? mediaType; 

  UpdateModel({
    required this.id,
    required this.childId,
    required this.childName,
    required this.type,
    required this.note,
    required this.time,
    required this.byRole,
    this.mediaPath,
    this.mediaType,
  });
}