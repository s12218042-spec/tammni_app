class UpdateModel {
  final String id;
  final String childId;
  final String childName;
  final String type; // أكل / نوم / نشاط / صحة / واجب / ملاحظة / كاميرا
  final String note;
  final DateTime time;
  final String byRole; // nursery / teacher

  // محتوى كاميرا
  final String? mediaPath; // مسار ملف صورة/فيديو محلي 
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