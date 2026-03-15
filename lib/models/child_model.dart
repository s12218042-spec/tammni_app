class ChildHistoryItem {
  final String section;
  final String group;
  final DateTime? from;
  final DateTime? to;

  ChildHistoryItem({
    required this.section,
    required this.group,
    this.from,
    this.to,
  });

  factory ChildHistoryItem.fromMap(Map<String, dynamic> data) {
    return ChildHistoryItem(
      section: data['section'] ?? '',
      group: data['group'] ?? '',
      from: data['from']?.toDate(),
      to: data['to']?.toDate(),
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
  final String section;
  final String group;
  final String parentName;
  final DateTime birthDate;
  final String parentUsername;

  final bool isActive;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ChildHistoryItem> history;

  ChildModel({
    required this.id,
    required this.name,
    required this.section,
    required this.group,
    required this.parentName,
    required this.birthDate,
    required this.parentUsername,
    this.isActive = true,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.history = const [],
  });
}
