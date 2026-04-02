class ChildHistoryItem {
  final String section;
  final String group;
  final DateTime? from;
  final DateTime? to;

  const ChildHistoryItem({
    required this.section,
    required this.group,
    this.from,
    this.to,
  });

  factory ChildHistoryItem.fromMap(Map<String, dynamic> data) {
    return ChildHistoryItem(
      section: (data['section'] ?? '').toString(),
      group: (data['group'] ?? '').toString(),
      from: _parseDate(data['from']),
      to: _parseDate(data['to']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'section': section,
      'group': group,
      'from': from,
      'to': to,
    };
  }
}

class ChildModel {
  final String id;
  final String name;
  final String fullName;
  final String gender;
  final String section;
  final String group;

  final String parentUid;
  final String parentName;
  final String parentUsername;

  final DateTime? birthDate;

  final bool isActive;
  final String status;

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
    this.birthDate,
    this.isActive = true,
    this.status = 'active',
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

  factory ChildModel.fromMap(Map<String, dynamic> data, {String? docId}) {
    final rawHistory = (data['history'] as List<dynamic>?) ?? const [];

    return ChildModel(
      id: (data['id'] ?? docId ?? '').toString(),
      name: (data['name'] ?? data['fullName'] ?? '').toString(),
      fullName: (data['fullName'] ?? data['name'] ?? '').toString(),
      gender: (data['gender'] ?? '').toString(),
      section: (data['section'] ?? '').toString(),
      group: (data['group'] ?? '').toString(),
      parentUid: (data['parentUid'] ?? '').toString(),
      parentName: (data['parentName'] ?? '').toString(),
      parentUsername: (data['parentUsername'] ?? '').toString(),
      birthDate: _parseDate(data['birthDate']),
      isActive: (data['isActive'] ?? true) == true,
      status: (data['status'] ?? 'active').toString(),
      allergies: (data['allergies'] ?? '').toString(),
      chronicDiseases: (data['chronicDiseases'] ?? '').toString(),
      medications: (data['medications'] ?? '').toString(),
      healthNotes: (data['healthNotes'] ?? '').toString(),
      bloodType: (data['bloodType'] ?? '').toString(),
      dietInstructions: (data['dietInstructions'] ?? '').toString(),
      specialInstructions: (data['specialInstructions'] ?? '').toString(),
      authorizedPickupContacts:
          ((data['authorizedPickupContacts'] as List<dynamic>?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      history: rawHistory
          .map((e) => ChildHistoryItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'fullName': fullName,
      'gender': gender,
      'section': section,
      'group': group,
      'parentUid': parentUid,
      'parentName': parentName,
      'parentUsername': parentUsername,
      'birthDate': birthDate,
      'isActive': isActive,
      'status': status,
      'allergies': allergies,
      'chronicDiseases': chronicDiseases,
      'medications': medications,
      'healthNotes': healthNotes,
      'bloodType': bloodType,
      'dietInstructions': dietInstructions,
      'specialInstructions': specialInstructions,
      'authorizedPickupContacts': authorizedPickupContacts,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'history': history.map((e) => e.toMap()).toList(),
    };
  }

  ChildModel copyWith({
    String? id,
    String? name,
    String? fullName,
    String? gender,
    String? section,
    String? group,
    String? parentUid,
    String? parentName,
    String? parentUsername,
    DateTime? birthDate,
    bool? isActive,
    String? status,
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
      parentUid: parentUid ?? this.parentUid,
      parentName: parentName ?? this.parentName,
      parentUsername: parentUsername ?? this.parentUsername,
      birthDate: birthDate ?? this.birthDate,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
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

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) return value;

  try {
    if (value.toDate != null) {
      return value.toDate();
    }
  } catch (_) {}

  return null;
}