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
    final data = <String, dynamic>{
      'section': section,
      'group': group,
      'groupId': groupId,
      'groupName': groupName,
      'assignedStaffUid': assignedStaffUid,
      'assignedStaffName': assignedStaffName,
      'assignedStaffUsername': assignedStaffUsername,
    };

    if (from != null) {
      data['from'] = Timestamp.fromDate(from!);
    }

    if (to != null) {
      data['to'] = Timestamp.fromDate(to!);
    }

    return data;
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
  final String identityNumber;
  final String gender;

  final String section;

  final String group;
  final String groupId;
  final String groupName;

  final String assignedStaffUid;
  final String assignedStaffName;
  final String assignedStaffUsername;

  final String parentUid;
  final String parentName;
  final String parentUsername;
  final String parentPhone;
  final String parentProfileId;

  final String temporaryParentUid;
  final String temporaryParentUsername;
  final String temporaryParentName;
  final String temporaryParentPhone;
  final String temporaryParentProfileId;

  final DateTime? birthDate;

  final bool isActive;
  final String accountStatus;
  final bool canReactivate;
  final bool permanentDeleted;
  final String archiveReason;
  final DateTime? archivedAt;
  final DateTime? reactivatedAt;


  final String childType;

  final String enrollmentType;

  final String status;
  final String childStatus;

  final DateTime? temporaryStartAt;
  final DateTime? temporaryEndAt;
  final String temporaryReason;
  final String temporaryNote;

  final String temporaryAccessCodeId;
  final String sharedAccessCodeId;
  final bool usesSharedAccessCode;
  final String temporaryAccessCode;
  final DateTime? temporaryAccessStartAt;
  final DateTime? temporaryAccessEndAt;

  final num temporaryFee;
  final String temporaryBillingType;
  final String temporaryBillingTypeLabel;
  final num temporaryHoursCount;
  final num temporaryHourlyRate;
  final num temporaryPaidAmount;
  final num temporaryRemainingAmount;

  final bool hasConsultation;

  final DateTime? trialStartAt;
  final DateTime? trialEndAt;
  final DateTime? trialDecisionAt;
  final String trialDecision;
  final String trialNote;
  final DateTime? trialApprovedAt;

  final String convertedFromChildType;
  final DateTime? convertedToPermanentAt;
  final String previousTemporaryAccessCodeId;
  final String previousTemporaryParentName;
  final String previousTemporaryParentPhone;

  final bool isBillable;
  final bool excludeFromMonthlyInvoice;

  final bool hasChronicDiseases;
  final String chronicDiseases;

  final bool hasAllergies;
  final String allergies;

  final bool takesMedications;
  final String medications;

  final bool hasDietaryRestrictions;
  final String dietaryRestrictions;

  final bool hasSpecialNeeds;
  final String specialNeeds;

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
    this.identityNumber = '',
    this.groupId = '',
    this.groupName = '',
    this.assignedStaffUid = '',
    this.assignedStaffName = '',
    this.assignedStaffUsername = '',
    this.parentPhone = '',
    this.parentProfileId = '',
    this.temporaryParentUid = '',
    this.temporaryParentUsername = '',
    this.temporaryParentName = '',
    this.temporaryParentPhone = '',
    this.temporaryParentProfileId = '',
    this.birthDate,
    this.isActive = true,
    this.accountStatus = 'active',
    this.canReactivate = true,
    this.permanentDeleted = false,
    this.archiveReason = '',
    this.archivedAt,
    this.reactivatedAt,
    this.childType = 'permanent',
    this.enrollmentType = '',
    this.status = 'active',
    this.childStatus = 'active',
    this.temporaryStartAt,
    this.temporaryEndAt,
    this.temporaryReason = '',
    this.temporaryNote = '',
    this.temporaryAccessCodeId = '',
    this.sharedAccessCodeId = '',
    this.usesSharedAccessCode = false,
    this.temporaryAccessCode = '',
    this.temporaryAccessStartAt,
    this.temporaryAccessEndAt,
    this.temporaryFee = 0,
    this.temporaryBillingType = '',
    this.temporaryBillingTypeLabel = '',
    this.temporaryHoursCount = 0,
    this.temporaryHourlyRate = 0,
    this.temporaryPaidAmount = 0,
    this.temporaryRemainingAmount = 0,
    this.hasConsultation = false,
    this.trialStartAt,
    this.trialEndAt,
    this.trialDecisionAt,
    this.trialDecision = '',
    this.trialNote = '',
    this.trialApprovedAt,
    this.convertedFromChildType = '',
    this.convertedToPermanentAt,
    this.previousTemporaryAccessCodeId = '',
    this.previousTemporaryParentName = '',
    this.previousTemporaryParentPhone = '',
    this.isBillable = true,
    this.excludeFromMonthlyInvoice = false,
    this.hasChronicDiseases = false,
    this.chronicDiseases = '',
    this.hasAllergies = false,
    this.allergies = '',
    this.takesMedications = false,
    this.medications = '',
    this.hasDietaryRestrictions = false,
    this.dietaryRestrictions = '',
    this.hasSpecialNeeds = false,
    this.specialNeeds = '',
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

  static String normalizeChildType(dynamic value) {
    final type = _string(value).trim().toLowerCase();

    switch (type) {
      case 'temporary':
      case 'temp':
      case 'temporary_child':
      case 'مؤقت':
      case 'زائر':
      case 'طفل زائر':
        return 'temporary';
      case 'trial':
      case 'تجربة':
      case 'فترة تجربة':
      case 'طفل تجربة':
        return 'trial';
      case 'permanent':
      case 'regular':
      case 'active':
      case 'دائم':
      case 'طفل دائم':
        return 'permanent';
      default:
        return type.isEmpty ? 'permanent' : type;
    }
  }

  static String normalizeChildStatus(dynamic value) {
    final status = _string(value).toLowerCase();

    switch (status) {
      case 'pending':
      case 'trial':
      case 'temporary':
      case 'trial_pending_decision':
      case 'active':
      case 'rejected_after_trial':
      case 'withdrawn':
      case 'archived':
        return status;
      default:
        return status.isEmpty ? 'active' : status;
    }
  }

  static bool _boolValue(dynamic value, {required bool defaultValue}) {
    if (value is bool) return value;

    final text = _string(value).toLowerCase();

    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;

    return defaultValue;
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

    final resolvedType = normalizeChildType(
      _firstNonEmpty([
        data['childType'],
        data['enrollmentType'],
        data['type'],
      ]),
    );

    final resolvedStatus = normalizeChildStatus(
      _firstNonEmpty([
        data['childStatus'],
        data['status'],
        resolvedType == 'temporary' ? 'temporary' : '',
        resolvedType == 'trial' ? 'trial' : '',
      ]),
    );

    final defaultIsBillable = resolvedType != 'trial';

    final defaultExcludeFromMonthlyInvoice =
        resolvedType == 'temporary' || resolvedType == 'trial';

    final defaultCanReactivate = !(resolvedType == 'trial' &&
        (resolvedStatus == 'trial_pending_decision' ||
            resolvedStatus == 'archived' ||
            resolvedStatus == 'rejected_after_trial'));

    return ChildModel(
      id: _firstNonEmpty([
        data['id'],
        data['childId'],
        docId,
      ]),
      name: _firstNonEmpty([
        data['name'],
        data['childName'],
        data['fullName'],
      ]),
      fullName: _firstNonEmpty([
        data['fullName'],
        data['name'],
        data['childName'],
      ]),
      identityNumber: _string(data['identityNumber']),
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
      parentUsername: _string(data['parentUsername']).toLowerCase(),
      parentPhone: _firstNonEmpty([
        data['parentPhone'],
        data['phone'],
        data['parentMobile'],
        data['mobile'],
      ]),
      parentProfileId: _firstNonEmpty([
        data['parentProfileId'],
        data['parentRecordId'],
        data['familyId'],
      ]),
      temporaryParentUid: _string(data['temporaryParentUid']),
      temporaryParentUsername:
          _string(data['temporaryParentUsername']).toLowerCase(),
      temporaryParentName: _string(data['temporaryParentName']),
      temporaryParentPhone: _firstNonEmpty([
        data['temporaryParentPhone'],
        data['temporaryPhone'],
      ]),
      temporaryParentProfileId: _firstNonEmpty([
        data['temporaryParentProfileId'],
        data['parentProfileId'],
        data['parentRecordId'],
        data['familyId'],
      ]),
      birthDate: _parseDate(data['birthDate']),
      isActive: _boolValue(data['isActive'], defaultValue: true),
      accountStatus: _firstNonEmpty([
        data['accountStatus'],
        data['isActive'] == false ? 'archived' : 'active',
      ]),
      canReactivate: _boolValue(
        data['canReactivate'],
        defaultValue: defaultCanReactivate,
      ),
      permanentDeleted:
          _boolValue(data['permanentDeleted'], defaultValue: false),
      archiveReason: _string(data['archiveReason']),
      archivedAt: _parseDate(data['archivedAt']),
      reactivatedAt: _parseDate(data['reactivatedAt']),
      childType: resolvedType,
      enrollmentType: resolvedType,
      status: resolvedStatus,
      childStatus: resolvedStatus,
      temporaryStartAt: _parseDate(
        data['temporaryStartAt'] ?? data['temporaryStartDate'],
      ),
      temporaryEndAt: _parseDate(
        data['temporaryEndAt'] ?? data['temporaryEndDate'],
      ),
      temporaryReason: _string(data['temporaryReason']),
      temporaryNote: _firstNonEmpty([
        data['temporaryNote'],
        data['temporaryNotes'],
      ]),
      temporaryAccessCodeId: _string(data['temporaryAccessCodeId']),
      sharedAccessCodeId: _firstNonEmpty([
        data['sharedAccessCodeId'],
        data['temporaryAccessCodeId'],
      ]),
      usesSharedAccessCode: _boolValue(
        data['usesSharedAccessCode'],
        defaultValue: _string(data['sharedAccessCodeId']).isNotEmpty,
      ),
      temporaryAccessCode: _string(data['temporaryAccessCode']),
      temporaryAccessStartAt: _parseDate(data['temporaryAccessStartAt']),
      temporaryAccessEndAt: _parseDate(data['temporaryAccessEndAt']),
      temporaryFee: _numValue(data['temporaryFee']),
      temporaryBillingType: _string(data['temporaryBillingType']),
      temporaryBillingTypeLabel:
          _string(data['temporaryBillingTypeLabel']),
      temporaryHoursCount: _numValue(data['temporaryHoursCount']),
      temporaryHourlyRate: _numValue(data['temporaryHourlyRate']),
      temporaryPaidAmount: _numValue(data['temporaryPaidAmount']),
      temporaryRemainingAmount: _numValue(data['temporaryRemainingAmount']),
      hasConsultation:
          _boolValue(data['hasConsultation'], defaultValue: false),
      trialStartAt: _parseDate(data['trialStartAt']),
      trialEndAt: _parseDate(data['trialEndAt']),
      trialDecisionAt: _parseDate(data['trialDecisionAt']),
      trialDecision: _string(data['trialDecision']),
      trialNote: _string(data['trialNote']),
      trialApprovedAt: _parseDate(data['trialApprovedAt']),
      convertedFromChildType: _string(data['convertedFromChildType']),
      convertedToPermanentAt: _parseDate(data['convertedToPermanentAt']),
      previousTemporaryAccessCodeId:
          _string(data['previousTemporaryAccessCodeId']),
      previousTemporaryParentName:
          _string(data['previousTemporaryParentName']),
      previousTemporaryParentPhone:
          _string(data['previousTemporaryParentPhone']),
      isBillable: _boolValue(
        data['isBillable'],
        defaultValue: defaultIsBillable,
      ),
      excludeFromMonthlyInvoice: _boolValue(
        data['excludeFromMonthlyInvoice'],
        defaultValue: defaultExcludeFromMonthlyInvoice,
      ),
      hasChronicDiseases:
          _boolValue(data['hasChronicDiseases'], defaultValue: false),
      chronicDiseases: _string(data['chronicDiseases']),
      hasAllergies: _boolValue(data['hasAllergies'], defaultValue: false),
      allergies: _string(data['allergies']),
      takesMedications:
          _boolValue(data['takesMedications'], defaultValue: false),
      medications: _string(data['medications']),
      hasDietaryRestrictions:
          _boolValue(data['hasDietaryRestrictions'], defaultValue: false),
      dietaryRestrictions: _string(data['dietaryRestrictions']),
      hasSpecialNeeds:
          _boolValue(data['hasSpecialNeeds'], defaultValue: false),
      specialNeeds: _string(data['specialNeeds']),
      healthNotes: _string(data['healthNotes']),
      bloodType: _string(data['bloodType']),
      dietInstructions: _firstNonEmpty([
        data['dietInstructions'],
        data['dietaryRestrictions'],
      ]),
      specialInstructions: _firstNonEmpty([
        data['specialInstructions'],
        data['specialNeeds'],
      ]),
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

    final resolvedType = normalizeChildType(
      childType.trim().isNotEmpty ? childType : enrollmentType,
    );

    final resolvedStatus = normalizeChildStatus(
      childStatus.trim().isNotEmpty
          ? childStatus
          : status.trim().isNotEmpty
              ? status
              : resolvedType == 'temporary'
                  ? 'temporary'
                  : resolvedType == 'trial'
                      ? 'trial'
                      : 'active',
    );

    final data = <String, dynamic>{
      'id': id,
      'childId': id,
      'name': name,
      'childName': name,
      'fullName': fullName,
      'identityNumber': identityNumber,
      'gender': gender,
      'section': normalizeSection(section),
      'group': resolvedGroup,
      'groupId': groupId,
      'groupName': resolvedGroupName,
      'assignedStaffUid': assignedStaffUid,
      'assignedStaffName': assignedStaffName,
      'assignedStaffUsername': assignedStaffUsername,
      'parentUid': parentUid,
      'parentName': parentName,
      'parentUsername': parentUsername.trim().toLowerCase(),
      'parentPhone': parentPhone,
      'parentProfileId': parentProfileId,
      'temporaryParentUid': temporaryParentUid,
      'temporaryParentUsername': temporaryParentUsername.trim().toLowerCase(),
      'temporaryParentName': temporaryParentName,
      'temporaryParentPhone': temporaryParentPhone,
      'temporaryParentProfileId': temporaryParentProfileId,
      'isActive': isActive,
      'accountStatus': accountStatus,
      'canReactivate': resolvedType == 'trial' &&
              (resolvedStatus == 'trial_pending_decision' ||
                  resolvedStatus == 'archived' ||
                  resolvedStatus == 'rejected_after_trial')
          ? false
          : canReactivate,
      'permanentDeleted': permanentDeleted,
      'archiveReason': archiveReason,
      'childType': resolvedType,
      'enrollmentType': resolvedType,
      'isTemporaryChild': resolvedType == 'temporary',
      'isTrialChild': resolvedType == 'trial',
      'status': resolvedStatus,
      'childStatus': resolvedStatus,
      'temporaryReason': temporaryReason,
      'temporaryNote': temporaryNote,
      'temporaryAccessCodeId': temporaryAccessCodeId,
      'sharedAccessCodeId': sharedAccessCodeId.trim().isNotEmpty
          ? sharedAccessCodeId
          : temporaryAccessCodeId,
      'usesSharedAccessCode': usesSharedAccessCode,
      'temporaryAccessCode': temporaryAccessCode,
      'temporaryFee': temporaryFee,
      'temporaryBillingType': temporaryBillingType,
      'temporaryBillingTypeLabel': temporaryBillingTypeLabel,
      'temporaryHoursCount': temporaryHoursCount,
      'temporaryHourlyRate': temporaryHourlyRate,
      'temporaryPaidAmount': temporaryPaidAmount,
      'temporaryRemainingAmount': temporaryRemainingAmount,
      'hasConsultation': hasConsultation,
      'trialDecision': trialDecision,
      'trialNote': trialNote,
      'convertedFromChildType': convertedFromChildType,
      'previousTemporaryAccessCodeId': previousTemporaryAccessCodeId,
      'previousTemporaryParentName': previousTemporaryParentName,
      'previousTemporaryParentPhone': previousTemporaryParentPhone,
      'isBillable': isBillable,
      'excludeFromMonthlyInvoice': excludeFromMonthlyInvoice,
      'hasChronicDiseases': hasChronicDiseases,
      'chronicDiseases': chronicDiseases,
      'hasAllergies': hasAllergies,
      'allergies': allergies,
      'takesMedications': takesMedications,
      'medications': medications,
      'hasDietaryRestrictions': hasDietaryRestrictions,
      'dietaryRestrictions': dietaryRestrictions,
      'hasSpecialNeeds': hasSpecialNeeds,
      'specialNeeds': specialNeeds,
      'healthNotes': healthNotes,
      'bloodType': bloodType,
      'dietInstructions': dietInstructions,
      'specialInstructions': specialInstructions,
      'authorizedPickupContacts': authorizedPickupContacts,
      'history': history.map((e) => e.toMap()).toList(),
    };

    if (birthDate != null) {
      data['birthDate'] = Timestamp.fromDate(birthDate!);
    }

    if (temporaryStartAt != null) {
      data['temporaryStartAt'] = Timestamp.fromDate(temporaryStartAt!);
      data['temporaryStartDate'] = Timestamp.fromDate(temporaryStartAt!);
    }

    if (temporaryEndAt != null) {
      data['temporaryEndAt'] = Timestamp.fromDate(temporaryEndAt!);
      data['temporaryEndDate'] = Timestamp.fromDate(temporaryEndAt!);
    }

    if (temporaryAccessStartAt != null) {
      data['temporaryAccessStartAt'] =
          Timestamp.fromDate(temporaryAccessStartAt!);
    }

    if (temporaryAccessEndAt != null) {
      data['temporaryAccessEndAt'] = Timestamp.fromDate(temporaryAccessEndAt!);
    }

    if (trialStartAt != null) {
      data['trialStartAt'] = Timestamp.fromDate(trialStartAt!);
    }

    if (trialEndAt != null) {
      data['trialEndAt'] = Timestamp.fromDate(trialEndAt!);
    }

    if (trialDecisionAt != null) {
      data['trialDecisionAt'] = Timestamp.fromDate(trialDecisionAt!);
    }

    if (trialApprovedAt != null) {
      data['trialApprovedAt'] = Timestamp.fromDate(trialApprovedAt!);
    }

    if (convertedToPermanentAt != null) {
      data['convertedToPermanentAt'] =
          Timestamp.fromDate(convertedToPermanentAt!);
    }

    if (archivedAt != null) {
      data['archivedAt'] = Timestamp.fromDate(archivedAt!);
    }

    if (reactivatedAt != null) {
      data['reactivatedAt'] = Timestamp.fromDate(reactivatedAt!);
    }

    if (createdAt != null) {
      data['createdAt'] = Timestamp.fromDate(createdAt!);
    }

    if (updatedAt != null) {
      data['updatedAt'] = Timestamp.fromDate(updatedAt!);
    }

    return data;
  }

  bool get isNurseryChild {
    return normalizeSection(section) == 'Nursery';
  }

  bool get isTemporaryChild {
    final type = normalizeChildType(
      childType.trim().isNotEmpty ? childType : enrollmentType,
    );
    final resolvedStatus = normalizeChildStatus(
      childStatus.trim().isNotEmpty ? childStatus : status,
    );

    return type == 'temporary' || resolvedStatus == 'temporary';
  }

  bool get isTrial {
    final type = normalizeChildType(
      childType.trim().isNotEmpty ? childType : enrollmentType,
    );
    final resolvedStatus = normalizeChildStatus(
      childStatus.trim().isNotEmpty ? childStatus : status,
    );

    return type == 'trial' ||
        resolvedStatus == 'trial' ||
        resolvedStatus == 'trial_pending_decision';
  }

  bool get isTrialChild {
    return isTrial;
  }

  bool get isActiveChild {
    final resolvedStatus = normalizeChildStatus(
      childStatus.trim().isNotEmpty ? childStatus : status,
    );

    return isActive &&
        (resolvedStatus == 'active' ||
            resolvedStatus == 'temporary' ||
            resolvedStatus == 'trial');
  }

  bool get isPermanentChild {
    return !isTemporaryChild && !isTrial;
  }

  bool get isPending {
    return childStatus == 'pending' || status == 'pending';
  }

  bool get isTrialPendingDecision {
    return normalizeChildStatus(childStatus) == 'trial_pending_decision' ||
        normalizeChildStatus(status) == 'trial_pending_decision';
  }

  bool get isWithdrawn {
    return childStatus == 'withdrawn' || status == 'withdrawn';
  }

  bool get isArchived {
    return childStatus == 'archived' ||
        status == 'archived' ||
        childStatus == 'rejected_after_trial' ||
        status == 'rejected_after_trial' ||
        accountStatus == 'archived' ||
        !isActive;
  }

  bool get hasSharedTemporaryAccessCode {
    return usesSharedAccessCode && sharedAccessCodeId.trim().isNotEmpty;
  }

  bool get canBeReactivated {
    return isArchived && canReactivate && !isTrial;
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

  String get resolvedParentProfileId {
    if (isTemporaryChild || isTrialChild) {
      return _firstNonEmpty([
        temporaryParentProfileId,
        parentProfileId,
      ]);
    }

    return _firstNonEmpty([
      parentProfileId,
      temporaryParentProfileId,
    ]);
  }

  String get resolvedParentUid {
    if (isTemporaryChild || isTrialChild) {
      return _firstNonEmpty([
        temporaryParentUid,
        parentUid,
      ]);
    }

    return _firstNonEmpty([
      parentUid,
      temporaryParentUid,
    ]);
  }

  String get resolvedParentUsername {
    if (isTemporaryChild || isTrialChild) {
      return _firstNonEmpty([
        temporaryParentUsername,
        parentUsername,
      ]).toLowerCase();
    }

    return _firstNonEmpty([
      parentUsername,
      temporaryParentUsername,
    ]).toLowerCase();
  }

  String get resolvedParentName {
    if (isTemporaryChild || isTrialChild) {
      return _firstNonEmpty([
        temporaryParentName,
        parentName,
        previousTemporaryParentName,
      ]);
    }

    return _firstNonEmpty([
      parentName,
      temporaryParentName,
      previousTemporaryParentName,
    ]);
  }

  String get resolvedParentPhone {
    if (isTemporaryChild || isTrialChild) {
      return _firstNonEmpty([
        temporaryParentPhone,
        parentPhone,
        previousTemporaryParentPhone,
      ]);
    }

    return _firstNonEmpty([
      parentPhone,
      temporaryParentPhone,
      previousTemporaryParentPhone,
    ]);
  }

  String get parentConversationKey {
    final profileId = resolvedParentProfileId.trim().toLowerCase();

    if (profileId.isNotEmpty) {
      return 'profile_$profileId';
    }

    final phone = _normalizePhone(resolvedParentPhone);

    if (phone.isNotEmpty) {
      return 'phone_$phone';
    }

    final uid = resolvedParentUid.trim();

    if (uid.isNotEmpty) {
      return 'uid_$uid';
    }

    final username = resolvedParentUsername.trim().toLowerCase();

    if (username.isNotEmpty) {
      return 'username_$username';
    }

    return 'child_$id';
  }

  String get displayParentName {
    final value = resolvedParentName.trim();
    return value.isEmpty ? 'ولي الأمر' : value;
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

  String get displayChildType {
    if (isTemporaryChild) return 'طفل زائر';
    if (isTrial) return 'طفل تجربة';
    return '';
  }

  String get displayStatus {
    final resolvedStatus = normalizeChildStatus(
      childStatus.trim().isNotEmpty ? childStatus : status,
    );

    switch (resolvedStatus) {
      case 'pending':
        return 'قيد المراجعة';
      case 'trial':
        return 'طفل تجربة';
      case 'trial_pending_decision':
        return 'بانتظار قرار التجربة';
      case 'temporary':
        return 'طفل زائر';
      case 'active':
        return 'نشط';
      case 'rejected_after_trial':
        return 'مؤرشف بعد التجربة';
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
    String? identityNumber,
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
    String? parentPhone,
    String? parentProfileId,
    String? temporaryParentUid,
    String? temporaryParentUsername,
    String? temporaryParentName,
    String? temporaryParentPhone,
    String? temporaryParentProfileId,
    DateTime? birthDate,
    bool? isActive,
    String? accountStatus,
    bool? canReactivate,
    bool? permanentDeleted,
    String? archiveReason,
    DateTime? archivedAt,
    DateTime? reactivatedAt,
    String? childType,
    String? enrollmentType,
    String? status,
    String? childStatus,
    DateTime? temporaryStartAt,
    DateTime? temporaryEndAt,
    String? temporaryReason,
    String? temporaryNote,
    String? temporaryAccessCodeId,
    String? sharedAccessCodeId,
    bool? usesSharedAccessCode,
    String? temporaryAccessCode,
    DateTime? temporaryAccessStartAt,
    DateTime? temporaryAccessEndAt,
    num? temporaryFee,
    String? temporaryBillingType,
    String? temporaryBillingTypeLabel,
    num? temporaryHoursCount,
    num? temporaryHourlyRate,
    num? temporaryPaidAmount,
    num? temporaryRemainingAmount,
    bool? hasConsultation,
    DateTime? trialStartAt,
    DateTime? trialEndAt,
    DateTime? trialDecisionAt,
    String? trialDecision,
    String? trialNote,
    DateTime? trialApprovedAt,
    String? convertedFromChildType,
    DateTime? convertedToPermanentAt,
    String? previousTemporaryAccessCodeId,
    String? previousTemporaryParentName,
    String? previousTemporaryParentPhone,
    bool? isBillable,
    bool? excludeFromMonthlyInvoice,
    bool? hasChronicDiseases,
    String? chronicDiseases,
    bool? hasAllergies,
    String? allergies,
    bool? takesMedications,
    String? medications,
    bool? hasDietaryRestrictions,
    String? dietaryRestrictions,
    bool? hasSpecialNeeds,
    String? specialNeeds,
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
      identityNumber: identityNumber ?? this.identityNumber,
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
      parentPhone: parentPhone ?? this.parentPhone,
      parentProfileId: parentProfileId ?? this.parentProfileId,
      temporaryParentUid: temporaryParentUid ?? this.temporaryParentUid,
      temporaryParentUsername:
          temporaryParentUsername ?? this.temporaryParentUsername,
      temporaryParentName: temporaryParentName ?? this.temporaryParentName,
      temporaryParentPhone: temporaryParentPhone ?? this.temporaryParentPhone,
      temporaryParentProfileId:
          temporaryParentProfileId ?? this.temporaryParentProfileId,
      birthDate: birthDate ?? this.birthDate,
      isActive: isActive ?? this.isActive,
      accountStatus: accountStatus ?? this.accountStatus,
      canReactivate: canReactivate ?? this.canReactivate,
      permanentDeleted: permanentDeleted ?? this.permanentDeleted,
      archiveReason: archiveReason ?? this.archiveReason,
      archivedAt: archivedAt ?? this.archivedAt,
      reactivatedAt: reactivatedAt ?? this.reactivatedAt,
      childType: childType ?? this.childType,
      enrollmentType: enrollmentType ?? this.enrollmentType,
      status: status ?? this.status,
      childStatus: childStatus ?? this.childStatus,
      temporaryStartAt: temporaryStartAt ?? this.temporaryStartAt,
      temporaryEndAt: temporaryEndAt ?? this.temporaryEndAt,
      temporaryReason: temporaryReason ?? this.temporaryReason,
      temporaryNote: temporaryNote ?? this.temporaryNote,
      temporaryAccessCodeId:
          temporaryAccessCodeId ?? this.temporaryAccessCodeId,
      sharedAccessCodeId: sharedAccessCodeId ?? this.sharedAccessCodeId,
      usesSharedAccessCode:
          usesSharedAccessCode ?? this.usesSharedAccessCode,
      temporaryAccessCode: temporaryAccessCode ?? this.temporaryAccessCode,
      temporaryAccessStartAt:
          temporaryAccessStartAt ?? this.temporaryAccessStartAt,
      temporaryAccessEndAt:
          temporaryAccessEndAt ?? this.temporaryAccessEndAt,
      temporaryFee: temporaryFee ?? this.temporaryFee,
      temporaryBillingType:
          temporaryBillingType ?? this.temporaryBillingType,
      temporaryBillingTypeLabel:
          temporaryBillingTypeLabel ?? this.temporaryBillingTypeLabel,
      temporaryHoursCount:
          temporaryHoursCount ?? this.temporaryHoursCount,
      temporaryHourlyRate: temporaryHourlyRate ?? this.temporaryHourlyRate,
      temporaryPaidAmount: temporaryPaidAmount ?? this.temporaryPaidAmount,
      temporaryRemainingAmount:
          temporaryRemainingAmount ?? this.temporaryRemainingAmount,
      hasConsultation: hasConsultation ?? this.hasConsultation,
      trialStartAt: trialStartAt ?? this.trialStartAt,
      trialEndAt: trialEndAt ?? this.trialEndAt,
      trialDecisionAt: trialDecisionAt ?? this.trialDecisionAt,
      trialDecision: trialDecision ?? this.trialDecision,
      trialNote: trialNote ?? this.trialNote,
      trialApprovedAt: trialApprovedAt ?? this.trialApprovedAt,
      convertedFromChildType:
          convertedFromChildType ?? this.convertedFromChildType,
      convertedToPermanentAt:
          convertedToPermanentAt ?? this.convertedToPermanentAt,
      previousTemporaryAccessCodeId:
          previousTemporaryAccessCodeId ?? this.previousTemporaryAccessCodeId,
      previousTemporaryParentName:
          previousTemporaryParentName ?? this.previousTemporaryParentName,
      previousTemporaryParentPhone:
          previousTemporaryParentPhone ?? this.previousTemporaryParentPhone,
      isBillable: isBillable ?? this.isBillable,
      excludeFromMonthlyInvoice:
          excludeFromMonthlyInvoice ?? this.excludeFromMonthlyInvoice,
      hasChronicDiseases:
          hasChronicDiseases ?? this.hasChronicDiseases,
      chronicDiseases: chronicDiseases ?? this.chronicDiseases,
      hasAllergies: hasAllergies ?? this.hasAllergies,
      allergies: allergies ?? this.allergies,
      takesMedications: takesMedications ?? this.takesMedications,
      medications: medications ?? this.medications,
      hasDietaryRestrictions:
          hasDietaryRestrictions ?? this.hasDietaryRestrictions,
      dietaryRestrictions:
          dietaryRestrictions ?? this.dietaryRestrictions,
      hasSpecialNeeds: hasSpecialNeeds ?? this.hasSpecialNeeds,
      specialNeeds: specialNeeds ?? this.specialNeeds,
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

String _normalizePhone(dynamic value) {
  return _string(value).replaceAll(RegExp(r'[^0-9+]'), '');
}

String _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = _string(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

num _numValue(dynamic value, {num fallback = 0}) {
  if (value is num) return value;

  final text = _string(value).replaceAll(',', '.');
  return num.tryParse(text) ?? fallback;
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
