import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceLineItem {
  final String id;
  final String type;
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
    final data = <String, dynamic>{
      'id': id,
      'type': type,
      'title': title,
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'amount': amount,
      'referenceId': referenceId,
    };

    if (createdAt != null) {
      data['createdAt'] = Timestamp.fromDate(createdAt!);
    }

    return data;
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

class InvoiceChildItem {
  final String childId;
  final String childName;
  final String group;
  final String groupId;
  final String groupName;
  final String section;
  final String parentUid;
  final String parentUsername;
  final String childType;
  final String enrollmentType;
  final String childStatus;
  final bool isTemporaryChild;
  final bool isTrialChild;
  final bool isBillable;
  final bool excludeFromMonthlyInvoice;

  const InvoiceChildItem({
    required this.childId,
    required this.childName,
    this.group = '',
    this.groupId = '',
    this.groupName = '',
    this.section = 'Nursery',
    this.parentUid = '',
    this.parentUsername = '',
    this.childType = '',
    this.enrollmentType = '',
    this.childStatus = '',
    this.isTemporaryChild = false,
    this.isTrialChild = false,
    this.isBillable = true,
    this.excludeFromMonthlyInvoice = false,
  });

  factory InvoiceChildItem.fromMap(Map<String, dynamic> data) {
    final rawType = _firstNonEmpty([
      data['childType'],
      data['enrollmentType'],
      data['type'],
    ]);

    final normalizedType = _normalizeChildType(rawType);

    final rawStatus = _firstNonEmpty([
      data['childStatus'],
      data['status'],
    ]);

    final normalizedStatus = rawStatus.toLowerCase();

    final isTrial = data['isTrialChild'] == true ||
        normalizedType == 'trial' ||
        normalizedStatus == 'trial';

    final isTemporary = data['isTemporaryChild'] == true ||
        normalizedType == 'temporary' ||
        normalizedStatus == 'temporary';

    final isBillable =
        data['isBillable'] == null ? true : data['isBillable'] == true;

    final excludeFromMonthlyInvoice =
        data['excludeFromMonthlyInvoice'] == true || !isBillable;

    return InvoiceChildItem(
      childId: _firstNonEmpty([
        data['childId'],
        data['id'],
      ]),
      childName: _firstNonEmpty([
        data['childName'],
        data['name'],
        data['fullName'],
      ]),
      group: _firstNonEmpty([
        data['group'],
        data['groupName'],
      ]),
      groupId: _string(data['groupId']),
      groupName: _firstNonEmpty([
        data['groupName'],
        data['group'],
      ]),
      section: _firstNonEmpty([
        data['section'],
        'Nursery',
      ]),
      parentUid: _string(data['parentUid']),
      parentUsername: _string(data['parentUsername']).toLowerCase(),
      childType: normalizedType,
      enrollmentType: normalizedType,
      childStatus: normalizedStatus,
      isTemporaryChild: isTemporary,
      isTrialChild: isTrial,
      isBillable: isBillable,
      excludeFromMonthlyInvoice: excludeFromMonthlyInvoice,
    );
  }

  Map<String, dynamic> toMap() {
    final resolvedGroupName = groupName.trim().isNotEmpty ? groupName : group;
    final resolvedGroup = group.trim().isNotEmpty ? group : resolvedGroupName;
    final resolvedType = _normalizeChildType(
      childType.trim().isNotEmpty ? childType : enrollmentType,
    );

    final resolvedStatus = childStatus.trim().isNotEmpty
        ? childStatus.trim().toLowerCase()
        : resolvedType == 'temporary'
            ? 'temporary'
            : resolvedType == 'trial'
                ? 'trial'
                : 'active';

    final resolvedIsTrial = isTrialChild || resolvedType == 'trial';
    final resolvedIsTemporary = isTemporaryChild || resolvedType == 'temporary';
    final resolvedIsBillable = isBillable && !resolvedIsTrial;

    return {
      'childId': childId,
      'childName': childName,
      'group': resolvedGroup,
      'groupId': groupId,
      'groupName': resolvedGroupName,
      'section': section.trim().isEmpty ? 'Nursery' : section,
      'parentUid': parentUid,
      'parentUsername': parentUsername.trim().toLowerCase(),
      'childType': resolvedType,
      'enrollmentType': resolvedType,
      'childStatus': resolvedStatus,
      'isTemporaryChild': resolvedIsTemporary,
      'isTrialChild': resolvedIsTrial,
      'isBillable': resolvedIsBillable,
      'excludeFromMonthlyInvoice':
          excludeFromMonthlyInvoice || resolvedIsTemporary || resolvedIsTrial,
    };
  }
}

class InvoiceModel {
  final String id;

  final String childId;
  final String childName;

  final int childrenCount;
  final List<String> childrenIds;
  final List<String> childrenNames;
  final List<InvoiceChildItem> children;

  final String parentUid;
  final String parentUsername;
  final String parentName;
  final String parentPhone;

  final String temporaryParentName;
  final String temporaryParentPhone;

  final String childType;
  final String enrollmentType;
  final String childStatus;
  final bool isTemporaryChild;
  final bool isTrialChild;
  final bool isBillable;
  final bool excludeFromMonthlyInvoice;

  final String section;
  final String group;
  final String groupId;
  final String groupName;

  final String invoiceCategory;
  final String billingType;
  final String billingMonthKey;
  final int billingYear;
  final int billingMonth;

  final String title;
  final String description;

  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? dueDate;
  final DateTime? paidAt;

  final double baseAmount;
  final double baseAmountPerChild;
  final double childrenBaseAmount;

  final double transportFee;
  final double mealsFee;
  final double registrationFee;
  final double lateFee;

  final double subscriptionAmount;
  final double discountAmount;
  final double manualDiscount;
  final double offerDiscount;
  final double totalDiscount;

  final double extraHoursAmount;
  final double extraHoursTotal;
  final List<String> extraHoursIds;

  final double consultationsAmount;
  final List<String> consultationIds;
  final List<Map<String, dynamic>> consultations;

  final double otherFeesAmount;

  final double subtotalAmount;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;

  final String offerId;
  final String offerTitle;
  final String offerName;
  final String offerType;
  final String offerCollectionName;
  final bool isDefaultOffer;
  final bool isTwoChildrenOffer;
  final bool hasOffer;
  final bool includesMeals;
  final bool includesSaturday;

  final double extraHours;
  final double extraHourRate;

  final double hoursCount;
  final double hourlyRate;
  final double daysCount;
  final double dailyRate;
  final double finalAmount;

  final DateTime? accessStartAt;
  final DateTime? accessEndAt;

  final String consultationId;
  final String consultationType;
  final double consultationHours;
  final double consultationHourlyRate;

  final List<InvoiceLineItem> items;

  final String status;
  final String paymentStatus;
  final String invoiceStatus;

  final String paymentMethod;
  final String paymentMethodLabel;

  final String createdByUid;
  final String createdByName;
  final String createdByRole;

  final String updatedByUid;
  final String updatedByName;
  final String updatedByRole;

  final String notes;
  final String internalNotes;
  final String discountNotes;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InvoiceModel({
    required this.id,
    required this.childId,
    required this.childName,
    this.childrenCount = 1,
    this.childrenIds = const [],
    this.childrenNames = const [],
    this.children = const [],
    required this.parentUid,
    required this.parentUsername,
    required this.parentName,
    this.parentPhone = '',
    this.temporaryParentName = '',
    this.temporaryParentPhone = '',
    this.childType = '',
    this.enrollmentType = '',
    this.childStatus = '',
    this.isTemporaryChild = false,
    this.isTrialChild = false,
    this.isBillable = true,
    this.excludeFromMonthlyInvoice = false,
    required this.section,
    required this.group,
    required this.invoiceCategory,
    required this.billingType,
    this.billingMonthKey = '',
    this.billingYear = 0,
    this.billingMonth = 0,
    required this.title,
    required this.description,
    this.groupId = '',
    this.groupName = '',
    this.startDate,
    this.endDate,
    this.dueDate,
    this.paidAt,
    this.baseAmount = 0,
    this.baseAmountPerChild = 0,
    this.childrenBaseAmount = 0,
    this.transportFee = 0,
    this.mealsFee = 0,
    this.registrationFee = 0,
    this.lateFee = 0,
    this.subscriptionAmount = 0,
    this.discountAmount = 0,
    this.manualDiscount = 0,
    this.offerDiscount = 0,
    this.totalDiscount = 0,
    this.extraHoursAmount = 0,
    this.extraHoursTotal = 0,
    this.extraHoursIds = const [],
    this.consultationsAmount = 0,
    this.consultationIds = const [],
    this.consultations = const [],
    this.otherFeesAmount = 0,
    this.subtotalAmount = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.remainingAmount = 0,
    this.offerId = '',
    this.offerTitle = '',
    this.offerName = '',
    this.offerType = '',
    this.offerCollectionName = '',
    this.isDefaultOffer = false,
    this.isTwoChildrenOffer = false,
    this.hasOffer = false,
    this.includesMeals = false,
    this.includesSaturday = false,
    this.extraHours = 0,
    this.extraHourRate = 10,
    this.hoursCount = 0,
    this.hourlyRate = 0,
    this.daysCount = 0,
    this.dailyRate = 0,
    this.finalAmount = 0,
    this.accessStartAt,
    this.accessEndAt,
    this.consultationId = '',
    this.consultationType = '',
    this.consultationHours = 0,
    this.consultationHourlyRate = 50,
    this.items = const [],
    this.status = 'unpaid',
    this.paymentStatus = 'unpaid',
    this.invoiceStatus = 'unpaid',
    this.paymentMethod = '',
    this.paymentMethodLabel = '',
    required this.createdByUid,
    required this.createdByName,
    this.createdByRole = 'admin',
    this.updatedByUid = '',
    this.updatedByName = '',
    this.updatedByRole = '',
    this.notes = '',
    this.internalNotes = '',
    this.discountNotes = '',
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

    final rawChildren = data['children'];
    final parsedChildren = rawChildren is List
        ? rawChildren
            .whereType<Map>()
            .map((e) => InvoiceChildItem.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <InvoiceChildItem>[];

    final parsedChildrenIds = _parseStringList(data['childrenIds']);
    final parsedChildrenNames = _parseStringList(data['childrenNames']);

    final resolvedChildrenIds = parsedChildrenIds.isNotEmpty
        ? parsedChildrenIds
        : parsedChildren
            .map((e) => e.childId)
            .where((e) => e.isNotEmpty)
            .toList();

    final resolvedChildrenNames = parsedChildrenNames.isNotEmpty
        ? parsedChildrenNames
        : parsedChildren
            .map((e) => e.childName)
            .where((e) => e.isNotEmpty)
            .toList();

    final resolvedGroupName = _firstNonEmpty([
      data['groupName'],
      data['group'],
    ]);

    final resolvedSubtotal = _toDouble(
      data['subtotalAmount'],
      fallback: _calculateSubtotalFromData(data),
    );

    final resolvedManualDiscount = _toDouble(
      data['manualDiscount'] ?? data['discountAmount'],
    );

    final resolvedOfferDiscount = _toDouble(
      data['offerDiscount'] ?? data['offerDiscountAmount'],
    );

    final resolvedTotalDiscount = _toDouble(
      data['totalDiscount'],
      fallback: resolvedManualDiscount + resolvedOfferDiscount,
    );

    final resolvedTotal = _toDouble(
      data['totalAmount'] ?? data['finalAmount'],
      fallback: (resolvedSubtotal -
              resolvedTotalDiscount +
              _toDouble(data['extraHoursAmount'] ?? data['extraHoursTotal']) +
              _toDouble(
                data['consultationsAmount'] ??
                    data['consultationAmount'] ??
                    data['consultationsTotal'],
              ))
          .clamp(0, double.infinity)
          .toDouble(),
    );

    final resolvedPaidAmount = _toDouble(data['paidAmount']);

    final resolvedStatus = normalizeStatus(
      _firstNonEmpty([
        data['paymentStatus'],
        data['status'],
        data['invoiceStatus'],
      ]),
      totalAmount: resolvedTotal,
      paidAmount: resolvedPaidAmount,
    );

    final resolvedOfferTitle = _firstNonEmpty([
      data['offerTitle'],
      data['offerName'],
    ]);

    final resolvedChildType = _normalizeChildType(
      _firstNonEmpty([
        data['childType'],
        data['enrollmentType'],
      ]),
    );

    final resolvedChildStatus = _firstNonEmpty([
      data['childStatus'],
      resolvedChildType == 'temporary' ? 'temporary' : '',
      resolvedChildType == 'trial' ? 'trial' : '',
      resolvedChildType == 'permanent' ? 'active' : '',
    ]).toLowerCase();

    final resolvedIsTemporaryChild = data['isTemporaryChild'] == true ||
        resolvedChildType == 'temporary' ||
        resolvedChildStatus == 'temporary';

    final resolvedIsTrialChild = data['isTrialChild'] == true ||
        resolvedChildType == 'trial' ||
        resolvedChildStatus == 'trial';

    final resolvedIsBillable = data['isBillable'] == null
        ? !resolvedIsTrialChild
        : data['isBillable'] == true;

    final resolvedExcludeFromMonthlyInvoice =
        data['excludeFromMonthlyInvoice'] == true ||
            resolvedIsTemporaryChild ||
            resolvedIsTrialChild;

    return InvoiceModel(
      id: _firstNonEmpty([
        data['id'],
        docId,
      ]),
      childId: _string(data['childId']),
      childName: _string(data['childName']),
      childrenCount: _toInt(
        data['childrenCount'],
        fallback: resolvedChildrenIds.isNotEmpty
            ? resolvedChildrenIds.length
            : resolvedChildrenNames.isNotEmpty
                ? resolvedChildrenNames.length
                : _string(data['childId']).isNotEmpty
                    ? 1
                    : 0,
      ),
      childrenIds: resolvedChildrenIds,
      childrenNames: resolvedChildrenNames,
      children: parsedChildren,
      parentUid: _string(data['parentUid']),
      parentUsername: _string(data['parentUsername']).toLowerCase(),
      parentName: _string(data['parentName']),
      parentPhone: _string(data['parentPhone']),
      temporaryParentName: _string(data['temporaryParentName']),
      temporaryParentPhone: _string(data['temporaryParentPhone']),
      childType: resolvedChildType,
      enrollmentType: resolvedChildType,
      childStatus: resolvedChildStatus,
      isTemporaryChild: resolvedIsTemporaryChild,
      isTrialChild: resolvedIsTrialChild,
      isBillable: resolvedIsBillable,
      excludeFromMonthlyInvoice: resolvedExcludeFromMonthlyInvoice,
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
      billingMonthKey: _string(data['billingMonthKey']),
      billingYear: _toInt(data['billingYear']),
      billingMonth: _toInt(data['billingMonth']),
      title: _string(data['title']),
      description: _string(data['description']),
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      dueDate: _parseDate(data['dueDate']),
      paidAt: _parseDate(data['paidAt']),
      baseAmount: _toDouble(data['baseAmount']),
      baseAmountPerChild: _toDouble(data['baseAmountPerChild']),
      childrenBaseAmount: _toDouble(data['childrenBaseAmount']),
      transportFee: _toDouble(data['transportFee']),
      mealsFee: _toDouble(data['mealsFee']),
      registrationFee: _toDouble(data['registrationFee']),
      lateFee: _toDouble(data['lateFee']),
      subscriptionAmount: _toDouble(data['subscriptionAmount']),
      discountAmount: resolvedManualDiscount,
      manualDiscount: resolvedManualDiscount,
      offerDiscount: resolvedOfferDiscount,
      totalDiscount: resolvedTotalDiscount,
      extraHoursAmount: _toDouble(
        data['extraHoursAmount'] ?? data['extraHoursTotal'],
      ),
      extraHoursTotal: _toDouble(
        data['extraHoursTotal'] ?? data['extraHoursAmount'],
      ),
      extraHoursIds: _parseStringList(data['extraHoursIds']),
      consultationsAmount: _toDouble(
        data['consultationsAmount'] ??
            data['consultationAmount'] ??
            data['consultationsTotal'],
      ),
      consultationIds: _parseStringList(data['consultationIds']),
      consultations: _parseMapList(data['consultations']),
      otherFeesAmount: _toDouble(data['otherFeesAmount']),
      subtotalAmount: resolvedSubtotal,
      totalAmount: resolvedTotal,
      paidAmount: resolvedPaidAmount,
      remainingAmount: _toDouble(
        data['remainingAmount'],
        fallback: (resolvedTotal - resolvedPaidAmount)
            .clamp(0, double.infinity)
            .toDouble(),
      ),
      offerId: _string(data['offerId']),
      offerTitle: resolvedOfferTitle,
      offerName: resolvedOfferTitle,
      offerType: _string(data['offerType']),
      offerCollectionName: _string(data['offerCollectionName']),
      isDefaultOffer: _bool(data['isDefaultOffer']),
      isTwoChildrenOffer: _bool(data['isTwoChildrenOffer']),
      hasOffer: _bool(data['hasOffer']) ||
          _string(data['offerId']).isNotEmpty ||
          resolvedOfferTitle.isNotEmpty ||
          resolvedOfferDiscount > 0,
      includesMeals: _bool(data['includesMeals']),
      includesSaturday: _bool(data['includesSaturday']),
      extraHours: _toDouble(data['extraHours']),
      extraHourRate: _toDouble(data['extraHourRate'], fallback: 10),
      hoursCount: _toDouble(data['hoursCount']),
      hourlyRate: _toDouble(data['hourlyRate']),
      daysCount: _toDouble(data['daysCount']),
      dailyRate: _toDouble(data['dailyRate']),
      finalAmount: _toDouble(
        data['finalAmount'] ?? data['totalAmount'],
      ),
      accessStartAt: _parseDate(
        data['accessStartAt'] ?? data['startDate'],
      ),
      accessEndAt: _parseDate(
        data['accessEndAt'] ?? data['endDate'],
      ),
      consultationId: _string(data['consultationId']),
      consultationType: _string(data['consultationType']),
      consultationHours: _toDouble(data['consultationHours']),
      consultationHourlyRate:
          _toDouble(data['consultationHourlyRate'], fallback: 50),
      items: parsedItems,
      status: resolvedStatus,
      paymentStatus: resolvedStatus,
      invoiceStatus: resolvedStatus,
      paymentMethod: _string(data['paymentMethod']),
      paymentMethodLabel: _string(data['paymentMethodLabel']),
      createdByUid: _string(data['createdByUid']),
      createdByName: _string(data['createdByName']),
      createdByRole: _firstNonEmpty([
        data['createdByRole'],
        'admin',
      ]),
      updatedByUid: _string(data['updatedByUid']),
      updatedByName: _string(data['updatedByName']),
      updatedByRole: _string(data['updatedByRole']),
      notes: _string(data['notes']),
      internalNotes: _string(data['internalNotes']),
      discountNotes: _string(data['discountNotes']),
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

  static String normalizeStatus(
    dynamic value, {
    double? totalAmount,
    double? paidAmount,
  }) {
    final status = _string(value).toLowerCase();

    if (status == 'paid' || status == 'مدفوعة' || status == 'مدفوع') {
      return 'paid';
    }

    if (status == 'partial' ||
        status == 'partially_paid' ||
        status == 'مدفوعة جزئياً' ||
        status == 'مدفوعة جزئيًا' ||
        status == 'مدفوع جزئياً' ||
        status == 'مدفوع جزئيًا') {
      return 'partial';
    }

    if (status == 'overdue' || status == 'متأخرة') return 'overdue';
    if (status == 'cancelled' ||
        status == 'canceled' ||
        status == 'ملغاة') {
      return 'cancelled';
    }
    if (status == 'draft') return 'draft';
    if (status == 'superseded') return 'superseded';

    if (status == 'unpaid' ||
        status == 'pending' ||
        status == 'غير مدفوعة' ||
        status == 'غير مدفوع' ||
        status.isEmpty) {
      if (totalAmount != null && paidAmount != null) {
        if (totalAmount <= 0 || paidAmount <= 0) return 'unpaid';
        if (paidAmount >= totalAmount) return 'paid';
        return 'partial';
      }

      return 'unpaid';
    }

    return status;
  }

  Map<String, dynamic> toMap() {
    final resolvedGroupName = groupName.trim().isNotEmpty ? groupName : group;
    final resolvedGroup = group.trim().isNotEmpty ? group : resolvedGroupName;
    final resolvedChildType = _normalizeChildType(
      childType.trim().isNotEmpty ? childType : enrollmentType,
    );

    final resolvedChildren = children.map((e) => e.toMap()).toList();

    final resolvedChildrenIds = childrenIds.isNotEmpty
        ? childrenIds
        : children.map((e) => e.childId).where((e) => e.isNotEmpty).toList();

    final resolvedChildrenNames = childrenNames.isNotEmpty
        ? childrenNames
        : children.map((e) => e.childName).where((e) => e.isNotEmpty).toList();

    final calculatedSubtotal = effectiveSubtotal;
    final calculatedDiscount = effectiveDiscount;
    final calculatedTotal = effectiveTotalAmount;
    final calculatedRemaining = effectiveRemainingAmount;

    final resolvedStatus = normalizeStatus(
      status,
      totalAmount: calculatedTotal,
      paidAmount: paidAmount,
    );

    final data = <String, dynamic>{
      'id': id,
      'childId': childId,
      'childName': childName,
      'childrenCount': childrenCount > 0
          ? childrenCount
          : resolvedChildrenIds.isNotEmpty
              ? resolvedChildrenIds.length
              : resolvedChildrenNames.length,
      'childrenIds': resolvedChildrenIds,
      'childrenNames': resolvedChildrenNames,
      'children': resolvedChildren,
      'parentUid': parentUid,
      'parentUsername': parentUsername.trim().toLowerCase(),
      'parentName': parentName,
      'parentPhone': parentPhone,
      'temporaryParentName': temporaryParentName,
      'temporaryParentPhone': temporaryParentPhone,
      'childType': resolvedChildType,
      'enrollmentType': resolvedChildType,
      'childStatus': childStatus,
      'isTemporaryChild': isTemporaryChild,
      'isTrialChild': isTrialChild,
      'isBillable': isBillable,
      'excludeFromMonthlyInvoice': excludeFromMonthlyInvoice,
      'section': section.trim().isEmpty ? 'Nursery' : section,
      'group': resolvedGroup,
      'groupId': groupId,
      'groupName': resolvedGroupName,
      'invoiceCategory': invoiceCategory,
      'billingType': billingType,
      'billingMonthKey': billingMonthKey,
      'billingYear': billingYear,
      'billingMonth': billingMonth,
      'title': title,
      'description': description,
      'baseAmount': baseAmount,
      'baseAmountPerChild': baseAmountPerChild,
      'childrenBaseAmount': childrenBaseAmount,
      'transportFee': transportFee,
      'mealsFee': mealsFee,
      'registrationFee': registrationFee,
      'lateFee': lateFee,
      'subscriptionAmount': subscriptionAmount,
      'discountAmount': manualDiscount,
      'manualDiscount': manualDiscount,
      'offerDiscount': offerDiscount,
      'offerDiscountAmount': offerDiscount,
      'totalDiscount': calculatedDiscount,
      'discountNotes': discountNotes,
      'extraHoursAmount': extraHoursAmount,
      'extraHoursTotal': extraHoursTotal > 0 ? extraHoursTotal : extraHoursAmount,
      'extraHoursIds': extraHoursIds,
      'consultationsAmount': consultationsAmount,
      'consultationAmount': consultationsAmount,
      'consultationIds': consultationIds,
      'consultations': consultations,
      'otherFeesAmount': otherFeesAmount,
      'subtotalAmount': calculatedSubtotal,
      'totalAmount': calculatedTotal,
      'paidAmount': paidAmount,
      'remainingAmount': calculatedRemaining,
      'finalAmount': calculatedTotal,
      'hoursCount': hoursCount,
      'hourlyRate': hourlyRate,
      'daysCount': daysCount,
      'dailyRate': dailyRate,
      'offerId': offerId,
      'offerTitle': offerTitle.trim().isNotEmpty ? offerTitle : offerName,
      'offerName': offerName.trim().isNotEmpty ? offerName : offerTitle,
      'offerType': offerType,
      'offerCollectionName': offerCollectionName,
      'isDefaultOffer': isDefaultOffer,
      'isTwoChildrenOffer': isTwoChildrenOffer,
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
      'status': resolvedStatus,
      'paymentStatus': resolvedStatus,
      'invoiceStatus': resolvedStatus,
      'paymentMethod': paymentMethod,
      'paymentMethodLabel': paymentMethodLabel,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdByRole': createdByRole,
      'updatedByUid': updatedByUid,
      'updatedByName': updatedByName,
      'updatedByRole': updatedByRole,
      'notes': notes,
      'internalNotes': internalNotes,
    };

    if (startDate != null) {
      data['startDate'] = Timestamp.fromDate(startDate!);
    }

    if (endDate != null) {
      data['endDate'] = Timestamp.fromDate(endDate!);
    }

    if (dueDate != null) {
      data['dueDate'] = Timestamp.fromDate(dueDate!);
    }

    if (paidAt != null) {
      data['paidAt'] = Timestamp.fromDate(paidAt!);
    }

    if (accessStartAt != null) {
      data['accessStartAt'] = Timestamp.fromDate(accessStartAt!);
    }

    if (accessEndAt != null) {
      data['accessEndAt'] = Timestamp.fromDate(accessEndAt!);
    }

    if (createdAt != null) {
      data['createdAt'] = Timestamp.fromDate(createdAt!);
    }

    if (updatedAt != null) {
      data['updatedAt'] = Timestamp.fromDate(updatedAt!);
    }

    return data;
  }

  bool get isPaid => effectiveStatus == 'paid';
  bool get isPending => effectiveStatus == 'unpaid';
  bool get isOverdue => effectiveStatus == 'overdue';
  bool get isCancelled => effectiveStatus == 'cancelled';
  bool get isPartiallyPaid => effectiveStatus == 'partial';

  String get effectiveStatus {
    return normalizeStatus(
      paymentStatus.trim().isNotEmpty ? paymentStatus : status,
      totalAmount: effectiveTotalAmount,
      paidAmount: paidAmount,
    );
  }

  bool get hasRemainingAmount {
    return effectiveRemainingAmount > 0;
  }

  bool get hasExtraHours {
    return extraHoursAmount > 0 || extraHoursIds.isNotEmpty;
  }

  bool get hasConsultations {
    return consultationsAmount > 0 || consultationIds.isNotEmpty;
  }

  bool get isHourlyTemporaryInvoice {
    return billingType == 'hourly' &&
        (hasTemporaryChild ||
            invoiceCategory == 'temporary_child' ||
            invoiceCategory == 'temporary_fee');
  }

  double get effectiveSubtotal {
    if (subtotalAmount > 0) return subtotalAmount;

    final calculated = childrenBaseAmount +
        transportFee +
        mealsFee +
        registrationFee +
        lateFee +
        subscriptionAmount +
        otherFeesAmount;

    if (calculated > 0) return calculated;

    return baseAmount +
        transportFee +
        mealsFee +
        registrationFee +
        lateFee +
        subscriptionAmount +
        otherFeesAmount;
  }

  double get effectiveDiscount {
    if (totalDiscount > 0) return totalDiscount;
    return manualDiscount + offerDiscount;
  }

  double get effectiveTotalAmount {
    if (totalAmount > 0) return totalAmount;
    if (finalAmount > 0) return finalAmount;

    return (effectiveSubtotal -
            effectiveDiscount +
            extraHoursAmount +
            consultationsAmount)
        .clamp(0, double.infinity);
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

  String get displayChildrenNames {
    if (childrenNames.isNotEmpty) return childrenNames.join('، ');

    final names = children
        .map((e) => e.childName)
        .where((e) => e.trim().isNotEmpty)
        .toList();

    if (names.isNotEmpty) return names.join('، ');

    return childName;
  }

  bool get hasTemporaryChild {
    if (isTemporaryChild ||
        _normalizeChildType(
              childType.trim().isNotEmpty ? childType : enrollmentType,
            ) ==
            'temporary') {
      return true;
    }

    if (children.any((child) => child.isTemporaryChild)) return true;

    final consultationsTemporary = consultations.any((item) {
      return item['isTemporaryChild'] == true ||
          _normalizeChildType(item['childType']) == 'temporary';
    });

    return consultationsTemporary;
  }

  bool get hasTrialChild {
    if (isTrialChild ||
        _normalizeChildType(
              childType.trim().isNotEmpty ? childType : enrollmentType,
            ) ==
            'trial') {
      return true;
    }

    if (children.any((child) => child.isTrialChild)) return true;

    final consultationsTrial = consultations.any((item) {
      return item['isTrialChild'] == true ||
          _normalizeChildType(item['childType']) == 'trial';
    });

    return consultationsTrial;
  }

  String get statusLabel {
    switch (effectiveStatus) {
      case 'paid':
        return 'مدفوعة';
      case 'partial':
        return 'مدفوعة جزئيًا';
      case 'overdue':
        return 'متأخرة';
      case 'cancelled':
        return 'ملغاة';
      case 'draft':
        return 'مسودة';
      case 'superseded':
        return 'مستبدلة';
      case 'unpaid':
      default:
        return 'غير مدفوعة';
    }
  }

  String get paymentMethodArabic {
    switch (paymentMethod) {
      case 'cash':
        return 'كاش';
      case 'card':
      case 'visa':
        return 'بطاقة / فيزا';
      case 'bank_transfer':
        return 'تحويل بنكي';
      case 'other':
        return 'أخرى';
      case 'manual':
        return 'يدوي';
      case 'online':
        return 'إلكتروني';
      default:
        return paymentMethodLabel.trim().isNotEmpty
            ? paymentMethodLabel
            : 'غير محدد';
    }
  }

  String get billingTypeLabel {
    switch (billingType) {
      case 'hourly':
        return 'حسب الساعات';
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      case 'registration':
        return 'تسجيل';
      case 'late_fee':
        return 'رسوم تأخير';
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
        return 'رسوم تأخير';
      case 'temporary_child':
      case 'temporary_fee':
        return 'فاتورة طفل مؤقت';
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
    int? childrenCount,
    List<String>? childrenIds,
    List<String>? childrenNames,
    List<InvoiceChildItem>? children,
    String? parentUid,
    String? parentUsername,
    String? parentName,
    String? parentPhone,
    String? temporaryParentName,
    String? temporaryParentPhone,
    String? childType,
    String? enrollmentType,
    String? childStatus,
    bool? isTemporaryChild,
    bool? isTrialChild,
    bool? isBillable,
    bool? excludeFromMonthlyInvoice,
    String? section,
    String? group,
    String? groupId,
    String? groupName,
    String? invoiceCategory,
    String? billingType,
    String? billingMonthKey,
    int? billingYear,
    int? billingMonth,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? dueDate,
    DateTime? paidAt,
    double? baseAmount,
    double? baseAmountPerChild,
    double? childrenBaseAmount,
    double? transportFee,
    double? mealsFee,
    double? registrationFee,
    double? lateFee,
    double? subscriptionAmount,
    double? discountAmount,
    double? manualDiscount,
    double? offerDiscount,
    double? totalDiscount,
    double? extraHoursAmount,
    double? extraHoursTotal,
    List<String>? extraHoursIds,
    double? consultationsAmount,
    List<String>? consultationIds,
    List<Map<String, dynamic>>? consultations,
    double? otherFeesAmount,
    double? subtotalAmount,
    double? totalAmount,
    double? paidAmount,
    double? remainingAmount,
    String? offerId,
    String? offerTitle,
    String? offerName,
    String? offerType,
    String? offerCollectionName,
    bool? isDefaultOffer,
    bool? isTwoChildrenOffer,
    bool? hasOffer,
    bool? includesMeals,
    bool? includesSaturday,
    double? extraHours,
    double? extraHourRate,
    double? hoursCount,
    double? hourlyRate,
    double? daysCount,
    double? dailyRate,
    double? finalAmount,
    DateTime? accessStartAt,
    DateTime? accessEndAt,
    String? consultationId,
    String? consultationType,
    double? consultationHours,
    double? consultationHourlyRate,
    List<InvoiceLineItem>? items,
    String? status,
    String? paymentStatus,
    String? invoiceStatus,
    String? paymentMethod,
    String? paymentMethodLabel,
    String? createdByUid,
    String? createdByName,
    String? createdByRole,
    String? updatedByUid,
    String? updatedByName,
    String? updatedByRole,
    String? notes,
    String? internalNotes,
    String? discountNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      childrenCount: childrenCount ?? this.childrenCount,
      childrenIds: childrenIds ?? this.childrenIds,
      childrenNames: childrenNames ?? this.childrenNames,
      children: children ?? this.children,
      parentUid: parentUid ?? this.parentUid,
      parentUsername: parentUsername ?? this.parentUsername,
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
      temporaryParentName: temporaryParentName ?? this.temporaryParentName,
      temporaryParentPhone: temporaryParentPhone ?? this.temporaryParentPhone,
      childType: childType ?? this.childType,
      enrollmentType: enrollmentType ?? this.enrollmentType,
      childStatus: childStatus ?? this.childStatus,
      isTemporaryChild: isTemporaryChild ?? this.isTemporaryChild,
      isTrialChild: isTrialChild ?? this.isTrialChild,
      isBillable: isBillable ?? this.isBillable,
      excludeFromMonthlyInvoice:
          excludeFromMonthlyInvoice ?? this.excludeFromMonthlyInvoice,
      section: section ?? this.section,
      group: group ?? this.group,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      invoiceCategory: invoiceCategory ?? this.invoiceCategory,
      billingType: billingType ?? this.billingType,
      billingMonthKey: billingMonthKey ?? this.billingMonthKey,
      billingYear: billingYear ?? this.billingYear,
      billingMonth: billingMonth ?? this.billingMonth,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      dueDate: dueDate ?? this.dueDate,
      paidAt: paidAt ?? this.paidAt,
      baseAmount: baseAmount ?? this.baseAmount,
      baseAmountPerChild: baseAmountPerChild ?? this.baseAmountPerChild,
      childrenBaseAmount: childrenBaseAmount ?? this.childrenBaseAmount,
      transportFee: transportFee ?? this.transportFee,
      mealsFee: mealsFee ?? this.mealsFee,
      registrationFee: registrationFee ?? this.registrationFee,
      lateFee: lateFee ?? this.lateFee,
      subscriptionAmount: subscriptionAmount ?? this.subscriptionAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      manualDiscount: manualDiscount ?? this.manualDiscount,
      offerDiscount: offerDiscount ?? this.offerDiscount,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      extraHoursAmount: extraHoursAmount ?? this.extraHoursAmount,
      extraHoursTotal: extraHoursTotal ?? this.extraHoursTotal,
      extraHoursIds: extraHoursIds ?? this.extraHoursIds,
      consultationsAmount: consultationsAmount ?? this.consultationsAmount,
      consultationIds: consultationIds ?? this.consultationIds,
      consultations: consultations ?? this.consultations,
      otherFeesAmount: otherFeesAmount ?? this.otherFeesAmount,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      offerId: offerId ?? this.offerId,
      offerTitle: offerTitle ?? this.offerTitle,
      offerName: offerName ?? this.offerName,
      offerType: offerType ?? this.offerType,
      offerCollectionName: offerCollectionName ?? this.offerCollectionName,
      isDefaultOffer: isDefaultOffer ?? this.isDefaultOffer,
      isTwoChildrenOffer: isTwoChildrenOffer ?? this.isTwoChildrenOffer,
      hasOffer: hasOffer ?? this.hasOffer,
      includesMeals: includesMeals ?? this.includesMeals,
      includesSaturday: includesSaturday ?? this.includesSaturday,
      extraHours: extraHours ?? this.extraHours,
      extraHourRate: extraHourRate ?? this.extraHourRate,
      hoursCount: hoursCount ?? this.hoursCount,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      daysCount: daysCount ?? this.daysCount,
      dailyRate: dailyRate ?? this.dailyRate,
      finalAmount: finalAmount ?? this.finalAmount,
      accessStartAt: accessStartAt ?? this.accessStartAt,
      accessEndAt: accessEndAt ?? this.accessEndAt,
      consultationId: consultationId ?? this.consultationId,
      consultationType: consultationType ?? this.consultationType,
      consultationHours: consultationHours ?? this.consultationHours,
      consultationHourlyRate:
          consultationHourlyRate ?? this.consultationHourlyRate,
      items: items ?? this.items,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      invoiceStatus: invoiceStatus ?? this.invoiceStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentMethodLabel: paymentMethodLabel ?? this.paymentMethodLabel,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      createdByRole: createdByRole ?? this.createdByRole,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      updatedByName: updatedByName ?? this.updatedByName,
      updatedByRole: updatedByRole ?? this.updatedByRole,
      notes: notes ?? this.notes,
      internalNotes: internalNotes ?? this.internalNotes,
      discountNotes: discountNotes ?? this.discountNotes,
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

int _toInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;

  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value.toString().trim()) ?? fallback;
}

bool _bool(dynamic value) {
  if (value is bool) return value;

  final text = value.toString().trim().toLowerCase();

  return text == 'true' || text == '1' || text == 'yes';
}

List<String> _parseStringList(dynamic value) {
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  return <String>[];
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

String _normalizeChildType(dynamic value) {
  final type = _string(value).toLowerCase();

  switch (type) {
    case 'temporary':
    case 'temp':
    case 'temporary_child':
    case 'مؤقت':
      return 'temporary';
    case 'trial':
    case 'تجربة':
      return 'trial';
    case 'permanent':
    case 'regular':
    case 'active':
    case 'دائم':
    default:
      return type.isEmpty ? 'permanent' : type;
  }
}

double _calculateSubtotalFromData(Map<String, dynamic> data) {
  final childrenBaseAmount = _toDouble(data['childrenBaseAmount']);

  final base = childrenBaseAmount > 0
      ? childrenBaseAmount
      : _toDouble(data['baseAmount']);

  return base +
      _toDouble(data['transportFee']) +
      _toDouble(data['mealsFee']) +
      _toDouble(data['registrationFee']) +
      _toDouble(data['lateFee']) +
      _toDouble(data['subscriptionAmount']) +
      _toDouble(data['otherFeesAmount']);
}