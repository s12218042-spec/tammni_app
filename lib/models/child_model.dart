import 'package:cloud_firestore/cloud_firestore.dart';

class ChildHistoryItem {
  final String section;
  final String group;
  final String groupId;
  final String groupName;
  final String assignedStaffUid;
  final String assignedStaffName;
  final String assignedStaffUsername;
  final DateTime? from;
  final DateTime? to;

  const ChildHistoryItem({
    required this.section,
    required this.group,
    this.groupId = '',
    this.groupName = '',
    this.assignedStaffUid = '',
    this.assignedStaffName = '',
    this.assignedStaffUsername = '',
    this.from,
    this.to,
  });

  factory ChildHistoryItem.fromMap(Map<String, dynamic> data) {
    return ChildHistoryItem(
      section: _string(data['section']),
      group: _firstNonEmpty([
        data['group'],
        data['groupName'],
      ]),
      groupId: _string(data['groupId']),
      groupName: _firstNonEmpty([
        data['groupName'],
        data['group'],
      ]),
      assignedStaffUid: _string(data['assignedStaffUid']),
      assignedStaffName: _string(data['assignedStaffName']),
      assignedStaffUsername: _string(data['assignedStaffUsername']),
      from: _parseDate(data['from']),
      to: _parseDate(data['to']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'section': section,
      'group': group,
      'groupId': groupId,
      'groupName': groupName,
      'assignedStaffUid': assignedStaffUid,
      'assignedStaffName': assignedStaffName,
      'assignedStaffUsername': assignedStaffUsername,
      'from': from == null ? null : Timestamp.fromDate(from!),
      'to': to == null ? null : Timestamp.fromDate(to!),
    };
  }

  ChildHistoryItem copyWith({
    String? section,
    String? group,
    String? groupId,
    String? groupName,
    String? assignedStaffUid,
    String? assignedStaffName,
    String? assignedStaffUsername,
    DateTime? from,
    DateTime? to,
  }) {
    return ChildHistoryItem(
      section: section ?? this.section,
      group: group ?? this.group,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      assignedStaffUid: assignedStaffUid ?? this.assignedStaffUid,
      assignedStaffName: assignedStaffName ?? this.assignedStaffName,
      assignedStaffUsername:
          assignedStaffUsername ?? this.assignedStaffUsername,
      from: from ?? this.from,
      to: to ?? this.to,
    );
  }
}

class ChildModel {
  final String id;

  final String name;
  final String fullName;
  final String gender;

  // الحضانة فقط، لكن نبقيها للتوافق مع الصفحات والرولز
  final String section;

  // للتوافق القديم + النظام الجديد
  final String group;
  final String groupId;
  final String groupName;

  // الموظفة المسؤولة عن المجموعة/الطفل
  final String assignedStaffUid;
  final String assignedStaffName;
  final String assignedStaffUsername;

  final String parentUid;
  final String parentName;
  final String parentUsername;

  final DateTime? birthDate;

  final bool isActive;

  /// status قديم
  /// childStatus جديد
  /// القيم المتوقعة:
  /// pending / trial / active / rejected_after_trial / withdrawn / archived
  final String status;
  final String childStatus;

  // فترة التجربة
  final DateTime? trialStartAt;
  final DateTime? trialEndAt;
  final DateTime? trialDecisionAt;
  final String trialDecision;
  final String trialNote;

  // بيانات صحية
  final String allergies;
  final String chronicDiseases;
  final String medications;
  final String healthNotes;
  final String bloodType;
  final String dietInstructions;
  final String specialInstructions;

  final List<Map<String, dynamic>> authorizedPickupContacts;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final List<ChildHistoryItem> history;

  const ChildModel({
    required this.id,
    required this.name,
    required this.fullName,
    required this.gender,
    required this.section,
    required this.group,
    required this.parentUid,
    required this.parentName,
    required this.parentUsername,
    this.groupId = '',
    this.groupName = '',
    this.assignedStaffUid = '',
    this.assignedStaffName = '',
    this.assignedStaffUsername = '',
    this.birthDate,
    this.isActive = true,
    this.status = 'active',
    this.childStatus = 'active',
    this.trialStartAt,
    this.trialEndAt,
    this.trialDecisionAt,
    this.trialDecision = '',
    this.trialNote = '',
    this.allergies = '',
    this.chronicDiseases = '',
    this.medications = '',
    this.healthNotes = '',
    this.bloodType = '',
    this.dietInstructions = '',
    this.specialInstructions = '',
    this.authorizedPickupContacts = const [],
    this.createdAt,
    this.updatedAt,
    this.history = const [],
  });

  static String normalizeSection(dynamic value) {
    final section = _string(value).trim();

    if (section.toLowerCase() == 'nursery' || section == 'حضانة') {
      return 'Nursery';
    }

    return section.isEmpty ? 'Nursery' : section;
  }

  static String normalizeChildStatus(dynamic value) {
    final status = _string(value).toLowerCase();

    switch (status) {
      case 'pending':
      case 'trial':
      case 'active':
      case 'rejected_after_trial':
      case 'withdrawn':
      case 'archived':
        return status;
      default:
        return status.isEmpty ? 'active' : status;
    }
  }

  factory ChildModel.fromMap(Map<String, dynamic> data, {String? docId}) {
    final rawHistory = data['history'];

    final historyList = rawHistory is List
        ? rawHistory
            .whereType<Map>()
            .map((e) => ChildHistoryItem.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <ChildHistoryItem>[];

    final resolvedGroupName = _firstNonEmpty([
      data['groupName'],
      data['group'],
    ]);

    final resolvedStatus = normalizeChildStatus(
      _firstNonEmpty([
        data['childStatus'],
        data['status'],
      ]),
    );

    return ChildModel(
      id: _firstNonEmpty([
        data['id'],
        docId,
      ]),
      name: _firstNonEmpty([
        data['name'],
        data['fullName'],
      ]),
      fullName: _firstNonEmpty([
        data['fullName'],
        data['name'],
      ]),
      gender: _string(data['gender']),
      section: normalizeSection(data['section']),
      group: _firstNonEmpty([
        data['group'],
        data['groupName'],
      ]),
      groupId: _string(data['groupId']),
      groupName: resolvedGroupName,
      assignedStaffUid: _string(data['assignedStaffUid']),
      assignedStaffName: _string(data['assignedStaffName']),
      assignedStaffUsername: _string(data['assignedStaffUsername']),
      parentUid: _string(data['parentUid']),
      parentName: _string(data['parentName']),
      parentUsername: _string(data['parentUsername']),
      birthDate: _parseDate(data['birthDate']),
      isActive: (data['isActive'] ?? true) == true,
      status: resolvedStatus,
      childStatus: resolvedStatus,
      trialStartAt: _parseDate(data['trialStartAt']),
      trialEndAt: _parseDate(data['trialEndAt']),
      trialDecisionAt: _parseDate(data['trialDecisionAt']),
      trialDecision: _string(data['trialDecision']),
      trialNote: _string(data['trialNote']),
      allergies: _string(data['allergies']),
      chronicDiseases: _string(data['chronicDiseases']),
      medications: _string(data['medications']),
      healthNotes: _string(data['healthNotes']),
      bloodType: _string(data['bloodType']),
      dietInstructions: _string(data['dietInstructions']),
      specialInstructions: _string(data['specialInstructions']),
      authorizedPickupContacts: _parseMapList(data['authorizedPickupContacts']),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      history: historyList,
    );
  }

  factory ChildModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ChildModel.fromMap(
      doc.data() ?? <String, dynamic>{},
      docId: doc.id,
    );
  }

  Map<String, dynamic> toMap() {
    final resolvedGroupName = groupName.trim().isNotEmpty ? groupName : group;
    final resolvedGroup = group.trim().isNotEmpty ? group : resolvedGroupName;
    final resolvedStatus = normalizeChildStatus(
      childStatus.trim().isNotEmpty ? childStatus : status,
    );

    return {
      'id': id,
      'name': name,
      'fullName': fullName,
      'gender': gender,

      'section': normalizeSection(section),

      // توافق قديم وجديد
      'group': resolvedGroup,
      'groupId': groupId,
      'groupName': resolvedGroupName,

      'assignedStaffUid': assignedStaffUid,
      'assignedStaffName': assignedStaffName,
      'assignedStaffUsername': assignedStaffUsername,

      'parentUid': parentUid,
      'parentName': parentName,
      'parentUsername': parentUsername,

      'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),

      'isActive': isActive,
      'status': resolvedStatus,
      'childStatus': resolvedStatus,

      'trialStartAt':
          trialStartAt == null ? null : Timestamp.fromDate(trialStartAt!),
      'trialEndAt': trialEndAt == null ? null : Timestamp.fromDate(trialEndAt!),
      'trialDecisionAt':
          trialDecisionAt == null ? null : Timestamp.fromDate(trialDecisionAt!),
      'trialDecision': trialDecision,
      'trialNote': trialNote,

      'allergies': allergies,
      'chronicDiseases': chronicDiseases,
      'medications': medications,
      'healthNotes': healthNotes,
      'bloodType': bloodType,
      'dietInstructions': dietInstructions,
      'specialInstructions': specialInstructions,

      'authorizedPickupContacts': authorizedPickupContacts,

      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),

      'history': history.map((e) => e.toMap()).toList(),
    };
  }

  bool get isNurseryChild {
    return normalizeSection(section) == 'Nursery';
  }

  bool get isTrial {
    return childStatus == 'trial' || status == 'trial';
  }

  bool get isActiveChild {
    final resolvedStatus = normalizeChildStatus(
      childStatus.trim().isNotEmpty ? childStatus : status,
    );

    return isActive && resolvedStatus == 'active';
  }

  bool get isPending {
    return childStatus == 'pending' || status == 'pending';
  }

  bool get isWithdrawn {
    return childStatus == 'withdrawn' || status == 'withdrawn';
  }

  bool get isArchived {
    return childStatus == 'archived' || status == 'archived';
  }

  bool get hasGroup {
    return groupId.trim().isNotEmpty ||
        groupName.trim().isNotEmpty ||
        group.trim().isNotEmpty;
  }

  bool get hasAssignedStaff {
    return assignedStaffUid.trim().isNotEmpty ||
        assignedStaffUsername.trim().isNotEmpty ||
        assignedStaffName.trim().isNotEmpty;
  }

  String get displayName {
    return name.trim().isNotEmpty ? name : fullName;
  }

  String get displayGroup {
    return groupName.trim().isNotEmpty
        ? groupName
        : group.trim().isNotEmpty
            ? group
            : 'بدون مجموعة';
  }

  String get displayStatus {
    final resolvedStatus = normalizeChildStatus(
      childStatus.trim().isNotEmpty ? childStatus : status,
    );

    switch (resolvedStatus) {
      case 'pending':
        return 'قيد المراجعة';
      case 'trial':
        return 'فترة تجربة';
      case 'active':
        return 'نشط';
      case 'rejected_after_trial':
        return 'مرفوض بعد التجربة';
      case 'withdrawn':
        return 'منسحب';
      case 'archived':
        return 'مؤرشف';
      default:
        return resolvedStatus;
    }
  }

  ChildModel copyWith({
    String? id,
    String? name,
    String? fullName,
    String? gender,
    String? section,
    String? group,
    String? groupId,
    String? groupName,
    String? assignedStaffUid,
    String? assignedStaffName,
    String? assignedStaffUsername,
    String? parentUid,
    String? parentName,
    String? parentUsername,
    DateTime? birthDate,
    bool? isActive,
    String? status,
    String? childStatus,
    DateTime? trialStartAt,
    DateTime? trialEndAt,
    DateTime? trialDecisionAt,
    String? trialDecision,
    String? trialNote,
    String? allergies,
    String? chronicDiseases,
    String? medications,
    String? healthNotes,
    String? bloodType,
    String? dietInstructions,
    String? specialInstructions,
    List<Map<String, dynamic>>? authorizedPickupContacts,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChildHistoryItem>? history,
  }) {
    return ChildModel(
      id: id ?? this.id,
      name: name ?? this.name,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      section: section ?? this.section,
      group: group ?? this.group,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      assignedStaffUid: assignedStaffUid ?? this.assignedStaffUid,
      assignedStaffName: assignedStaffName ?? this.assignedStaffName,
      assignedStaffUsername:
          assignedStaffUsername ?? this.assignedStaffUsername,
      parentUid: parentUid ?? this.parentUid,
      parentName: parentName ?? this.parentName,
      parentUsername: parentUsername ?? this.parentUsername,
      birthDate: birthDate ?? this.birthDate,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      childStatus: childStatus ?? this.childStatus,
      trialStartAt: trialStartAt ?? this.trialStartAt,
      trialEndAt: trialEndAt ?? this.trialEndAt,
      trialDecisionAt: trialDecisionAt ?? this.trialDecisionAt,
      trialDecision: trialDecision ?? this.trialDecision,
      trialNote: trialNote ?? this.trialNote,
      allergies: allergies ?? this.allergies,
      chronicDiseases: chronicDiseases ?? this.chronicDiseases,
      medications: medications ?? this.medications,
      healthNotes: healthNotes ?? this.healthNotes,
      bloodType: bloodType ?? this.bloodType,
      dietInstructions: dietInstructions ?? this.dietInstructions,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      authorizedPickupContacts:
          authorizedPickupContacts ?? this.authorizedPickupContacts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? this.history,
    );
  }
}

String _string(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = _string(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;

  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  final text = value.toString().trim();
  if (text.isEmpty) return null;

  return DateTime.tryParse(text);
}

List<Map<String, dynamic>> _parseMapList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  return <Map<String, dynamic>>[];
}