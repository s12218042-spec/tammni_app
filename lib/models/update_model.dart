import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateModel {
  final String id;

  final String childId;
  final String childName;

  final String parentUid;
  final String parentUsername;

  final String type;
  final String updateType;
  final String category;
  final String note;
  final String description;

  final DateTime time;
  final DateTime? eventAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String byRole;
  final String createdByUid;
  final String createdByName;
  final String createdByRole;

  // بيانات المجموعة
  final String groupId;
  final String groupName;
  final String group;

  // التحديث الجماعي
  final bool isGroupUpdate;
  final String groupUpdateId;
  final String targetScope;
  final String targetScopeLabel;

  // الوسائط
  final String mediaUrl;
  final String mediaPath;
  final String mediaType;
  final String mimeType;
  final String bucket;
  final String storageProvider;
  final int sizeBytes;

  // حقول إضافية مستخدمة ببعض الصفحات
  final String importance;
  final String mood;
  final String energy;
  final String locationLabel;
  final List<String> tags;

  const UpdateModel({
    required this.id,
    required this.childId,
    required this.childName,
    required this.type,
    required this.note,
    required this.time,
    required this.byRole,
    this.parentUid = '',
    this.parentUsername = '',
    this.updateType = '',
    this.category = '',
    this.description = '',
    this.eventAt,
    this.createdAt,
    this.updatedAt,
    this.createdByUid = '',
    this.createdByName = '',
    this.createdByRole = '',
    this.groupId = '',
    this.groupName = '',
    this.group = '',
    this.isGroupUpdate = false,
    this.groupUpdateId = '',
    this.targetScope = '',
    this.targetScopeLabel = '',
    this.mediaUrl = '',
    this.mediaPath = '',
    this.mediaType = '',
    this.mimeType = '',
    this.bucket = '',
    this.storageProvider = '',
    this.sizeBytes = 0,
    this.importance = '',
    this.mood = '',
    this.energy = '',
    this.locationLabel = '',
    this.tags = const [],
  });

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = _string(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static DateTime? _dateOrNull(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    return DateTime.tryParse(text);
  }

  static DateTime _dateOrNow(dynamic value) {
    return _dateOrNull(value) ?? DateTime.now();
  }

  static int _intOrZero(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString().trim()) ?? 0;
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;

    final text = value.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    if (value is String) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    return <String>[];
  }

  static String normalizeRole(dynamic value) {
    final role = _string(value).toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }

    return role;
  }

  static bool detectGroupUpdate(Map<String, dynamic> map) {
    final type = _string(map['type']).toLowerCase();
    final source = _string(map['source']).toLowerCase();
    final updateSource = _string(map['updateSource']).toLowerCase();

    return _bool(map['isGroupUpdate']) ||
        type == 'group_update' ||
        source == 'group_update' ||
        updateSource == 'group_update' ||
        _string(map['groupUpdateId']).isNotEmpty;
  }

  factory UpdateModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    final resolvedType = _firstNonEmpty([
      map['type'],
      map['updateType'],
      map['category'],
      'ملاحظة',
    ]);

    final resolvedNote = _firstNonEmpty([
      map['note'],
      map['notes'],
      map['description'],
      map['text'],
      map['message'],
      map['body'],
    ]);

    final resolvedTime = _dateOrNow(
      map['eventAt'] ??
          map['time'] ??
          map['createdAt'] ??
          map['timestamp'] ??
          map['updatedAt'],
    );

    final groupUpdate = detectGroupUpdate(map);

    final resolvedTargetScope = _firstNonEmpty([
      map['targetScope'],
      map['scope'],
    ]);

    final resolvedTargetScopeLabel = _firstNonEmpty([
      map['targetScopeLabel'],
      resolvedTargetScope == 'all_nursery'
          ? 'كل أطفال الحضانة'
          : resolvedTargetScope == 'my_group'
              ? 'مجموعتي فقط'
              : '',
    ]);

    return UpdateModel(
      id: _firstNonEmpty([
        map['id'],
        map['updateId'],
        docId,
      ]),
      childId: _string(map['childId']),
      childName: _firstNonEmpty([
        map['childName'],
        map['name'],
      ]),
      parentUid: _string(map['parentUid']),
      parentUsername: _string(map['parentUsername']),
      type: resolvedType,
      updateType: _string(map['updateType']),
      category: _string(map['category']),
      note: resolvedNote,
      description: _firstNonEmpty([
        map['description'],
        resolvedNote,
      ]),
      time: resolvedTime,
      eventAt: _dateOrNull(map['eventAt']),
      createdAt: _dateOrNull(map['createdAt']),
      updatedAt: _dateOrNull(map['updatedAt']),
      byRole: normalizeRole(
        _firstNonEmpty([
          map['byRole'],
          map['createdByRole'],
        ]),
      ),
      createdByUid: _string(map['createdByUid']),
      createdByName: _string(map['createdByName']),
      createdByRole: normalizeRole(map['createdByRole']),
      groupId: _string(map['groupId']),
      groupName: _firstNonEmpty([
        map['groupName'],
        map['group'],
      ]),
      group: _firstNonEmpty([
        map['group'],
        map['groupName'],
      ]),
      isGroupUpdate: groupUpdate,
      groupUpdateId: _string(map['groupUpdateId']),
      targetScope: resolvedTargetScope,
      targetScopeLabel: resolvedTargetScopeLabel,
      mediaUrl: _firstNonEmpty([
        map['mediaUrl'],
        map['url'],
        map['signedUrl'],
      ]),
      mediaPath: _firstNonEmpty([
        map['mediaPath'],
        map['path'],
      ]),
      mediaType: _firstNonEmpty([
        map['mediaType'],
        map['typeOfMedia'],
      ]),
      mimeType: _string(map['mimeType']),
      bucket: _string(map['bucket']),
      storageProvider: _string(map['storageProvider']),
      sizeBytes: _intOrZero(map['sizeBytes']),
      importance: _string(map['importance']),
      mood: _string(map['mood']),
      energy: _string(map['energy']),
      locationLabel: _string(map['locationLabel']),
      tags: _stringList(map['tags']),
    );
  }

  factory UpdateModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return UpdateModel.fromMap(
      doc.data() ?? <String, dynamic>{},
      docId: doc.id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'updateId': id,

      'childId': childId,
      'childName': childName,

      'parentUid': parentUid,
      'parentUsername': parentUsername,

      'type': type,
      'updateType': updateType,
      'category': category,
      'note': note,
      'description': description,

      'time': Timestamp.fromDate(time),
      'eventAt': eventAt == null ? Timestamp.fromDate(time) : Timestamp.fromDate(eventAt!),
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),

      'byRole': normalizeRole(byRole),
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdByRole': normalizeRole(createdByRole),

      'groupId': groupId,
      'groupName': groupName,
      'group': group.isNotEmpty ? group : groupName,

      'isGroupUpdate': isGroupUpdate,
      'groupUpdateId': groupUpdateId,
      'targetScope': targetScope,
      'targetScopeLabel': targetScopeLabel,

      'mediaUrl': mediaUrl,
      'mediaPath': mediaPath,
      'mediaType': mediaType,
      'mimeType': mimeType,
      'bucket': bucket,
      'storageProvider': storageProvider,
      'sizeBytes': sizeBytes,

      'importance': importance,
      'mood': mood,
      'energy': energy,
      'locationLabel': locationLabel,
      'tags': tags,
    };
  }

  bool get hasMedia {
    return mediaUrl.trim().isNotEmpty || mediaPath.trim().isNotEmpty;
  }

  bool get isVideo {
    final lowerMediaType = mediaType.toLowerCase();
    final lowerMime = mimeType.toLowerCase();

    return lowerMediaType == 'video' || lowerMime.startsWith('video/');
  }

  bool get isImage {
    final lowerMediaType = mediaType.toLowerCase();
    final lowerMime = mimeType.toLowerCase();

    return lowerMediaType == 'image' || lowerMime.startsWith('image/');
  }

  String get displayType {
    if (isGroupUpdate) return 'تحديث جماعي';
    return type.trim().isEmpty ? 'ملاحظة' : type;
  }

  String get displayGroup {
    return groupName.trim().isNotEmpty ? groupName : group;
  }

  UpdateModel copyWith({
    String? id,
    String? childId,
    String? childName,
    String? parentUid,
    String? parentUsername,
    String? type,
    String? updateType,
    String? category,
    String? note,
    String? description,
    DateTime? time,
    DateTime? eventAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? byRole,
    String? createdByUid,
    String? createdByName,
    String? createdByRole,
    String? groupId,
    String? groupName,
    String? group,
    bool? isGroupUpdate,
    String? groupUpdateId,
    String? targetScope,
    String? targetScopeLabel,
    String? mediaUrl,
    String? mediaPath,
    String? mediaType,
    String? mimeType,
    String? bucket,
    String? storageProvider,
    int? sizeBytes,
    String? importance,
    String? mood,
    String? energy,
    String? locationLabel,
    List<String>? tags,
  }) {
    return UpdateModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      parentUid: parentUid ?? this.parentUid,
      parentUsername: parentUsername ?? this.parentUsername,
      type: type ?? this.type,
      updateType: updateType ?? this.updateType,
      category: category ?? this.category,
      note: note ?? this.note,
      description: description ?? this.description,
      time: time ?? this.time,
      eventAt: eventAt ?? this.eventAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      byRole: byRole ?? this.byRole,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      createdByRole: createdByRole ?? this.createdByRole,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      group: group ?? this.group,
      isGroupUpdate: isGroupUpdate ?? this.isGroupUpdate,
      groupUpdateId: groupUpdateId ?? this.groupUpdateId,
      targetScope: targetScope ?? this.targetScope,
      targetScopeLabel: targetScopeLabel ?? this.targetScopeLabel,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaType: mediaType ?? this.mediaType,
      mimeType: mimeType ?? this.mimeType,
      bucket: bucket ?? this.bucket,
      storageProvider: storageProvider ?? this.storageProvider,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      importance: importance ?? this.importance,
      mood: mood ?? this.mood,
      energy: energy ?? this.energy,
      locationLabel: locationLabel ?? this.locationLabel,
      tags: tags ?? this.tags,
    );
  }
}