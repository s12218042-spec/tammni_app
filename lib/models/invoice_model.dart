import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceLineItem {
  final String id;
  final String type;
  // subscription / discount / extra_hours / consultation / registration / meals / other

  final String title;
  final String description;

  final double quantity;
  final double unitPrice;
  final double amount;

  final String referenceId;
  final DateTime? createdAt;

  const InvoiceLineItem({
    required this.id,
    required this.type,
    required this.title,
    this.description = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.amount = 0,
    this.referenceId = '',
    this.createdAt,
  });

  factory InvoiceLineItem.fromMap(Map<String, dynamic> data) {
    return InvoiceLineItem(
      id: _string(data['id']),
      type: _string(data['type']),
      title: _string(data['title']),
      description: _string(data['description']),
      quantity: _toDouble(data['quantity'], fallback: 1),
      unitPrice: _toDouble(data['unitPrice']),
      amount: _toDouble(data['amount']),
      referenceId: _string(data['referenceId']),
      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'amount': amount,
      'referenceId': referenceId,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    };
  }

  InvoiceLineItem copyWith({
    String? id,
    String? type,
    String? title,
    String? description,
    double? quantity,
    double? unitPrice,
    double? amount,
    String? referenceId,
    DateTime? createdAt,
  }) {
    return InvoiceLineItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      amount: amount ?? this.amount,
      referenceId: referenceId ?? this.referenceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class InvoiceModel {
  final String id;

  final String childId;
  final String childName;

  final String parentUid;
  final String parentUsername;
  final String parentName;

  final String section;
  final String group;
  final String groupId;
  final String groupName;

  final String invoiceCategory;
  // nursery_fee / registration_fee / late_fee / extra_hours / consultation / mixed

  final String billingType;
  // daily / weekly / monthly / registration / late_fee / one_time

  final String title;
  final String description;

  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? dueDate;
  final DateTime? paidAt;

  // مبالغ أساسية
  final double baseAmount;
  final double transportFee;
  final double mealsFee;
  final double registrationFee;
  final double lateFee;

  // متطلبات Let’s Go
  final double subscriptionAmount;
  final double discountAmount;
  final double offerDiscountAmount;
  final double extraHoursAmount;
  final double consultationAmount;
  final double otherFeesAmount;

  final double subtotalAmount;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;

  final String offerId;
  final String offerName;
  final String offerType;
  // monthly_600 / two_children_1100 / custom

  final bool hasOffer;
  final bool includesMeals;
  final bool includesSaturday;

  final double extraHours;
  final double extraHourRate;

  final String consultationId;
  final String consultationType;
  final double consultationHours;
  final double consultationHourlyRate;

  final List<InvoiceLineItem> items;

  final String status;
  // pending / paid / partially_paid / overdue / cancelled

  final String paymentMethod;
  // cash / manual / online / bank_transfer

  final String createdByUid;
  final String createdByName;
  final String createdByRole;

  final String notes;
  final String internalNotes;

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
    this.groupId = '',
    this.groupName = '',
    this.startDate,
    this.endDate,
    this.dueDate,
    this.paidAt,
    this.baseAmount = 0,
    this.transportFee = 0,
    this.mealsFee = 0,
    this.registrationFee = 0,
    this.lateFee = 0,
    this.subscriptionAmount = 0,
    this.discountAmount = 0,
    this.offerDiscountAmount = 0,
    this.extraHoursAmount = 0,
    this.consultationAmount = 0,
    this.otherFeesAmount = 0,
    this.subtotalAmount = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.remainingAmount = 0,
    this.offerId = '',
    this.offerName = '',
    this.offerType = '',
    this.hasOffer = false,
    this.includesMeals = false,
    this.includesSaturday = false,
    this.extraHours = 0,
    this.extraHourRate = 10,
    this.consultationId = '',
    this.consultationType = '',
    this.consultationHours = 0,
    this.consultationHourlyRate = 50,
    this.items = const [],
    this.status = 'pending',
    this.paymentMethod = '',
    required this.createdByUid,
    required this.createdByName,
    this.createdByRole = 'admin',
    this.notes = '',
    this.internalNotes = '',
    this.createdAt,
    this.updatedAt,
  });

  factory InvoiceModel.fromMap(Map<String, dynamic> data, {String? docId}) {
    final rawItems = data['items'];
    final parsedItems = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => InvoiceLineItem.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <InvoiceLineItem>[];

    final resolvedGroupName = _firstNonEmpty([
      data['groupName'],
      data['group'],
    ]);

    final resolvedSubtotal = _toDouble(
      data['subtotalAmount'],
      fallback: _calculateSubtotalFromData(data),
    );

    final resolvedTotal = _toDouble(
      data['totalAmount'],
      fallback: resolvedSubtotal,
    );

    final resolvedPaidAmount = _toDouble(data['paidAmount']);

    return InvoiceModel(
      id: _firstNonEmpty([
        data['id'],
        docId,
      ]),
      childId: _string(data['childId']),
      childName: _string(data['childName']),
      parentUid: _string(data['parentUid']),
      parentUsername: _string(data['parentUsername']),
      parentName: _string(data['parentName']),
      section: _firstNonEmpty([
        data['section'],
        'Nursery',
      ]),
      group: _firstNonEmpty([
        data['group'],
        data['groupName'],
      ]),
      groupId: _string(data['groupId']),
      groupName: resolvedGroupName,
      invoiceCategory: _firstNonEmpty([
        data['invoiceCategory'],
        data['category'],
        'nursery_fee',
      ]),
      billingType: _firstNonEmpty([
        data['billingType'],
        'monthly',
      ]),
      title: _string(data['title']),
      description: _string(data['description']),
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      dueDate: _parseDate(data['dueDate']),
      paidAt: _parseDate(data['paidAt']),
      baseAmount: _toDouble(data['baseAmount']),
      transportFee: _toDouble(data['transportFee']),
      mealsFee: _toDouble(data['mealsFee']),
      registrationFee: _toDouble(data['registrationFee']),
      lateFee: _toDouble(data['lateFee']),
      subscriptionAmount: _toDouble(data['subscriptionAmount']),
      discountAmount: _toDouble(data['discountAmount']),
      offerDiscountAmount: _toDouble(data['offerDiscountAmount']),
      extraHoursAmount: _toDouble(data['extraHoursAmount']),
      consultationAmount: _toDouble(data['consultationAmount']),
      otherFeesAmount: _toDouble(data['otherFeesAmount']),
      subtotalAmount: resolvedSubtotal,
      totalAmount: resolvedTotal,
      paidAmount: resolvedPaidAmount,
      remainingAmount: _toDouble(
        data['remainingAmount'],
        fallback: (resolvedTotal - resolvedPaidAmount).clamp(0, double.infinity),
      ),
      offerId: _string(data['offerId']),
      offerName: _string(data['offerName']),
      offerType: _string(data['offerType']),
      hasOffer: _bool(data['hasOffer']) ||
          _string(data['offerId']).isNotEmpty ||
          _string(data['offerName']).isNotEmpty ||
          _toDouble(data['offerDiscountAmount']) > 0,
      includesMeals: _bool(data['includesMeals']),
      includesSaturday: _bool(data['includesSaturday']),
      extraHours: _toDouble(data['extraHours']),
      extraHourRate: _toDouble(data['extraHourRate'], fallback: 10),
      consultationId: _string(data['consultationId']),
      consultationType: _string(data['consultationType']),
      consultationHours: _toDouble(data['consultationHours']),
      consultationHourlyRate:
          _toDouble(data['consultationHourlyRate'], fallback: 50),
      items: parsedItems,
      status: _firstNonEmpty([
        data['status'],
        'pending',
      ]),
      paymentMethod: _string(data['paymentMethod']),
      createdByUid: _string(data['createdByUid']),
      createdByName: _string(data['createdByName']),
      createdByRole: _firstNonEmpty([
        data['createdByRole'],
        'admin',
      ]),
      notes: _string(data['notes']),
      internalNotes: _string(data['internalNotes']),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  factory InvoiceModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return InvoiceModel.fromMap(
      doc.data() ?? <String, dynamic>{},
      docId: doc.id,
    );
  }

  Map<String, dynamic> toMap() {
    final resolvedGroupName = groupName.trim().isNotEmpty ? groupName : group;
    final resolvedGroup = group.trim().isNotEmpty ? group : resolvedGroupName;

    final calculatedSubtotal = subtotalAmount > 0
        ? subtotalAmount
        : baseAmount +
            transportFee +
            mealsFee +
            registrationFee +
            lateFee +
            subscriptionAmount +
            extraHoursAmount +
            consultationAmount +
            otherFeesAmount;

    final calculatedDiscount = discountAmount + offerDiscountAmount;

    final calculatedTotal = totalAmount > 0
        ? totalAmount
        : (calculatedSubtotal - calculatedDiscount).clamp(0, double.infinity);

    final calculatedRemaining =
        remainingAmount > 0 ? remainingAmount : calculatedTotal - paidAmount;

    return {
      'id': id,
      'childId': childId,
      'childName': childName,
      'parentUid': parentUid,
      'parentUsername': parentUsername,
      'parentName': parentName,
      'section': section.trim().isEmpty ? 'Nursery' : section,
      'group': resolvedGroup,
      'groupId': groupId,
      'groupName': resolvedGroupName,
      'invoiceCategory': invoiceCategory,
      'billingType': billingType,
      'title': title,
      'description': description,
      'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
      'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
      'paidAt': paidAt == null ? null : Timestamp.fromDate(paidAt!),

      'baseAmount': baseAmount,
      'transportFee': transportFee,
      'mealsFee': mealsFee,
      'registrationFee': registrationFee,
      'lateFee': lateFee,

      'subscriptionAmount': subscriptionAmount,
      'discountAmount': discountAmount,
      'offerDiscountAmount': offerDiscountAmount,
      'extraHoursAmount': extraHoursAmount,
      'consultationAmount': consultationAmount,
      'otherFeesAmount': otherFeesAmount,

      'subtotalAmount': calculatedSubtotal,
      'totalAmount': calculatedTotal,
      'paidAmount': paidAmount,
      'remainingAmount': calculatedRemaining.clamp(0, double.infinity),

      'offerId': offerId,
      'offerName': offerName,
      'offerType': offerType,
      'hasOffer': hasOffer,
      'includesMeals': includesMeals,
      'includesSaturday': includesSaturday,

      'extraHours': extraHours,
      'extraHourRate': extraHourRate,

      'consultationId': consultationId,
      'consultationType': consultationType,
      'consultationHours': consultationHours,
      'consultationHourlyRate': consultationHourlyRate,

      'items': items.map((e) => e.toMap()).toList(),

      'status': status,
      'paymentMethod': paymentMethod,

      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdByRole': createdByRole,

      'notes': notes,
      'internalNotes': internalNotes,

      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isOverdue => status == 'overdue';
  bool get isCancelled => status == 'cancelled';
  bool get isPartiallyPaid => status == 'partially_paid';

  bool get hasRemainingAmount {
    return effectiveRemainingAmount > 0;
  }

  double get effectiveSubtotal {
    if (subtotalAmount > 0) return subtotalAmount;

    return baseAmount +
        transportFee +
        mealsFee +
        registrationFee +
        lateFee +
        subscriptionAmount +
        extraHoursAmount +
        consultationAmount +
        otherFeesAmount;
  }

  double get effectiveDiscount {
    return discountAmount + offerDiscountAmount;
  }

  double get effectiveTotalAmount {
    if (totalAmount > 0) return totalAmount;
    return (effectiveSubtotal - effectiveDiscount).clamp(0, double.infinity);
  }

  double get effectiveRemainingAmount {
    if (remainingAmount > 0) return remainingAmount;
    return (effectiveTotalAmount - paidAmount).clamp(0, double.infinity);
  }

  String get displayGroup {
    return groupName.trim().isNotEmpty
        ? groupName
        : group.trim().isNotEmpty
            ? group
            : 'بدون مجموعة';
  }

  String get statusLabel {
    switch (status) {
      case 'paid':
        return 'مدفوعة';
      case 'partially_paid':
        return 'مدفوعة جزئيًا';
      case 'overdue':
        return 'متأخرة';
      case 'cancelled':
        return 'ملغاة';
      case 'pending':
      default:
        return 'بانتظار الدفع';
    }
  }

  String get billingTypeLabel {
    switch (billingType) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      case 'registration':
        return 'تسجيل';
      case 'late_fee':
        return 'غرامة تأخير';
      case 'one_time':
        return 'مرة واحدة';
      default:
        return billingType;
    }
  }

  String get categoryLabel {
    switch (invoiceCategory) {
      case 'nursery_fee':
        return 'رسوم حضانة';
      case 'registration_fee':
        return 'رسوم تسجيل';
      case 'late_fee':
        return 'غرامة تأخير';
      case 'extra_hours':
        return 'ساعات إضافية';
      case 'consultation':
        return 'استشارة';
      case 'mixed':
        return 'فاتورة شاملة';
      default:
        return invoiceCategory;
    }
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
    String? groupId,
    String? groupName,
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
    double? subscriptionAmount,
    double? discountAmount,
    double? offerDiscountAmount,
    double? extraHoursAmount,
    double? consultationAmount,
    double? otherFeesAmount,
    double? subtotalAmount,
    double? totalAmount,
    double? paidAmount,
    double? remainingAmount,
    String? offerId,
    String? offerName,
    String? offerType,
    bool? hasOffer,
    bool? includesMeals,
    bool? includesSaturday,
    double? extraHours,
    double? extraHourRate,
    String? consultationId,
    String? consultationType,
    double? consultationHours,
    double? consultationHourlyRate,
    List<InvoiceLineItem>? items,
    String? status,
    String? paymentMethod,
    String? createdByUid,
    String? createdByName,
    String? createdByRole,
    String? notes,
    String? internalNotes,
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
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
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
      subscriptionAmount: subscriptionAmount ?? this.subscriptionAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      offerDiscountAmount: offerDiscountAmount ?? this.offerDiscountAmount,
      extraHoursAmount: extraHoursAmount ?? this.extraHoursAmount,
      consultationAmount: consultationAmount ?? this.consultationAmount,
      otherFeesAmount: otherFeesAmount ?? this.otherFeesAmount,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      offerId: offerId ?? this.offerId,
      offerName: offerName ?? this.offerName,
      offerType: offerType ?? this.offerType,
      hasOffer: hasOffer ?? this.hasOffer,
      includesMeals: includesMeals ?? this.includesMeals,
      includesSaturday: includesSaturday ?? this.includesSaturday,
      extraHours: extraHours ?? this.extraHours,
      extraHourRate: extraHourRate ?? this.extraHourRate,
      consultationId: consultationId ?? this.consultationId,
      consultationType: consultationType ?? this.consultationType,
      consultationHours: consultationHours ?? this.consultationHours,
      consultationHourlyRate:
          consultationHourlyRate ?? this.consultationHourlyRate,
      items: items ?? this.items,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      createdByRole: createdByRole ?? this.createdByRole,
      notes: notes ?? this.notes,
      internalNotes: internalNotes ?? this.internalNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;

  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is num) return value.toDouble();

  return double.tryParse(value.toString().trim()) ?? fallback;
}

bool _bool(dynamic value) {
  if (value is bool) return value;

  final text = value.toString().trim().toLowerCase();

  return text == 'true' || text == '1' || text == 'yes';
}

double _calculateSubtotalFromData(Map<String, dynamic> data) {
  return _toDouble(data['baseAmount']) +
      _toDouble(data['transportFee']) +
      _toDouble(data['mealsFee']) +
      _toDouble(data['registrationFee']) +
      _toDouble(data['lateFee']) +
      _toDouble(data['subscriptionAmount']) +
      _toDouble(data['extraHoursAmount']) +
      _toDouble(data['consultationAmount']) +
      _toDouble(data['otherFeesAmount']);
}