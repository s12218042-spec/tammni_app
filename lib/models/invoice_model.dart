class InvoiceModel {
  final String id;

  final String childId;
  final String childName;

  final String parentUid;
  final String parentUsername;
  final String parentName;

  final String section;
  final String group;

  final String invoiceCategory;
  // nursery_fee / registration_fee / late_fee

  final String billingType;
  // daily / weekly / monthly / registration / late_fee

  final String title;
  final String description;

  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? dueDate;
  final DateTime? paidAt;

  final double baseAmount;
  final double transportFee;
  final double mealsFee;
  final double registrationFee;
  final double lateFee;
  final double totalAmount;

  final String status;
  // pending / paid / overdue / cancelled

  final String paymentMethod;
  // cash / manual / online

  final String createdByUid;
  final String createdByName;

  final String notes;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InvoiceModel({
    required this.id,
    required this.childId,
    required this.childName,
    required this.parentUid,
    required this.parentUsername,
    required this.parentName,
    required this.section,
    required this.group,
    required this.invoiceCategory,
    required this.billingType,
    required this.title,
    required this.description,
    this.startDate,
    this.endDate,
    this.dueDate,
    this.paidAt,
    this.baseAmount = 0,
    this.transportFee = 0,
    this.mealsFee = 0,
    this.registrationFee = 0,
    this.lateFee = 0,
    this.totalAmount = 0,
    this.status = 'pending',
    this.paymentMethod = '',
    required this.createdByUid,
    required this.createdByName,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  factory InvoiceModel.fromMap(Map<String, dynamic> data, {String? docId}) {
    return InvoiceModel(
      id: (data['id'] ?? docId ?? '').toString(),
      childId: (data['childId'] ?? '').toString(),
      childName: (data['childName'] ?? '').toString(),
      parentUid: (data['parentUid'] ?? '').toString(),
      parentUsername: (data['parentUsername'] ?? '').toString(),
      parentName: (data['parentName'] ?? '').toString(),
      section: (data['section'] ?? '').toString(),
      group: (data['group'] ?? '').toString(),
      invoiceCategory: (data['invoiceCategory'] ?? '').toString(),
      billingType: (data['billingType'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      dueDate: _parseDate(data['dueDate']),
      paidAt: _parseDate(data['paidAt']),
      baseAmount: _toDouble(data['baseAmount']),
      transportFee: _toDouble(data['transportFee']),
      mealsFee: _toDouble(data['mealsFee']),
      registrationFee: _toDouble(data['registrationFee']),
      lateFee: _toDouble(data['lateFee']),
      totalAmount: _toDouble(data['totalAmount']),
      status: (data['status'] ?? 'pending').toString(),
      paymentMethod: (data['paymentMethod'] ?? '').toString(),
      createdByUid: (data['createdByUid'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      notes: (data['notes'] ?? '').toString(),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'childId': childId,
      'childName': childName,
      'parentUid': parentUid,
      'parentUsername': parentUsername,
      'parentName': parentName,
      'section': section,
      'group': group,
      'invoiceCategory': invoiceCategory,
      'billingType': billingType,
      'title': title,
      'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'dueDate': dueDate,
      'paidAt': paidAt,
      'baseAmount': baseAmount,
      'transportFee': transportFee,
      'mealsFee': mealsFee,
      'registrationFee': registrationFee,
      'lateFee': lateFee,
      'totalAmount': totalAmount,
      'status': status,
      'paymentMethod': paymentMethod,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  InvoiceModel copyWith({
    String? id,
    String? childId,
    String? childName,
    String? parentUid,
    String? parentUsername,
    String? parentName,
    String? section,
    String? group,
    String? invoiceCategory,
    String? billingType,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? dueDate,
    DateTime? paidAt,
    double? baseAmount,
    double? transportFee,
    double? mealsFee,
    double? registrationFee,
    double? lateFee,
    double? totalAmount,
    String? status,
    String? paymentMethod,
    String? createdByUid,
    String? createdByName,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      parentUid: parentUid ?? this.parentUid,
      parentUsername: parentUsername ?? this.parentUsername,
      parentName: parentName ?? this.parentName,
      section: section ?? this.section,
      group: group ?? this.group,
      invoiceCategory: invoiceCategory ?? this.invoiceCategory,
      billingType: billingType ?? this.billingType,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      dueDate: dueDate ?? this.dueDate,
      paidAt: paidAt ?? this.paidAt,
      baseAmount: baseAmount ?? this.baseAmount,
      transportFee: transportFee ?? this.transportFee,
      mealsFee: mealsFee ?? this.mealsFee,
      registrationFee: registrationFee ?? this.registrationFee,
      lateFee: lateFee ?? this.lateFee,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) return value;

  try {
    return value.toDate();
  } catch (_) {
    return null;
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0;

  if (value is int) return value.toDouble();
  if (value is double) return value;

  return double.tryParse(value.toString()) ?? 0;
}
