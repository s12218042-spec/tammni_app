import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'admin_groups_page.dart';
import 'entry_exit_log_page.dart';

class ManageChildrenPage extends StatefulWidget {
  const ManageChildrenPage({super.key});

  @override
  State<ManageChildrenPage> createState() => _ManageChildrenPageState();
}

class _ManageChildrenPageState extends State<ManageChildrenPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

final Set<String> selectedViews = {'active'};

String searchText = '';
String selectedChildTypeFilter = 'all';

  String sectionLabel(String section) {
    return 'حضانة';
  }

  Color sectionColor(String section) {
    return const Color(0xFFEFA7C8);
  }

  String statusLabel(String value) {
    if (value == 'active') return 'النشطون';
    if (value == 'archived') return 'المؤرشفون';
    return value;
  }

String childTypeLabel(Map<String, dynamic> child) {
  final childType = (child['childType'] ?? '').toString().trim();
  final childStatus = (child['childStatus'] ?? '').toString().trim();

  final value = childType.isNotEmpty ? childType : childStatus;

  switch (value) {
    case 'temporary':
      return 'طفل مؤقت';
    case 'trial':
      return 'فترة تجربة';
    case 'permanent':
    case 'active':
    default:
      return 'طفل دائم';
  }
}

Color childTypeColor(Map<String, dynamic> child) {
  final childType = (child['childType'] ?? '').toString().trim();
  final childStatus = (child['childStatus'] ?? '').toString().trim();

  final value = childType.isNotEmpty ? childType : childStatus;

  switch (value) {
    case 'temporary':
      return Colors.deepPurple;
    case 'trial':
      return Colors.orange;
    case 'permanent':
    case 'active':
    default:
      return Colors.green;
  }
}

String resolveChildType(Map<String, dynamic> child) {
  final childType = (child['childType'] ?? '').toString().trim();
  final childStatus = (child['childStatus'] ?? '').toString().trim();

  final value = childType.isNotEmpty ? childType : childStatus;

  if (value == 'temporary') return 'temporary';
  if (value == 'trial') return 'trial';

  return 'permanent';
}

  void toggleViewFilter(String value) {
    setState(() {
      if (selectedViews.contains(value)) {
        selectedViews.remove(value);
      } else {
        selectedViews.add(value);
      }
    });
  }

  void clearAllFilters() {
  setState(() {
    selectedViews
      ..clear()
      ..add('active');
    searchText = '';
    selectedChildTypeFilter = 'all';
  });
}

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    final raw = _cleanText(value);
    if (raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59);
    }

    return parsed;
  }

  bool _isTemporaryChildData(Map<String, dynamic> data) {
    final childType = _cleanText(data['childType']).toLowerCase();
    final enrollmentType = _cleanText(data['enrollmentType']).toLowerCase();
    final childStatus = _cleanText(data['childStatus']).toLowerCase();

    return data['isTemporaryChild'] == true ||
        data['isTemporary'] == true ||
        childType == 'temporary' ||
        enrollmentType == 'temporary' ||
        childStatus == 'temporary';
  }

  bool _isTrialChildData(Map<String, dynamic> data) {
    final childType = _cleanText(data['childType']).toLowerCase();
    final enrollmentType = _cleanText(data['enrollmentType']).toLowerCase();
    final childStatus = _cleanText(data['childStatus']).toLowerCase();

    return data['isTrialChild'] == true ||
        childType == 'trial' ||
        enrollmentType == 'trial' ||
        childStatus == 'trial';
  }

  bool _isArchivedChildData(Map<String, dynamic> data) {
    final childStatus = _cleanText(data['childStatus']).toLowerCase();
    final accountStatus = _cleanText(data['accountStatus']).toLowerCase();
    final status = _cleanText(data['status']).toLowerCase();

    return data['isActive'] == false ||
        childStatus == 'archived' ||
        childStatus == 'rejected_after_trial' ||
        accountStatus == 'archived' ||
        status == 'archived';
  }

  DateTime? _expiryDateForChild(Map<String, dynamic> data) {
    if (_isTrialChildData(data)) {
      return _toDateTime(data['trialEndAt']) ??
          _toDateTime(data['temporaryAccessEndAt']) ??
          _toDateTime(data['temporaryEndDate']) ??
          _toDateTime(data['temporaryEndAt']);
    }

    if (_isTemporaryChildData(data)) {
      return _toDateTime(data['temporaryAccessEndAt']) ??
          _toDateTime(data['temporaryEndDate']) ??
          _toDateTime(data['temporaryEndAt']);
    }

    return null;
  }


  List<String> _readStringList(dynamic value) {
    if (value is! List) return <String>[];

    return value
        .map(_cleanText)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  String _childNameFromData(Map<String, dynamic> data) {
    final name = _cleanText(data['name']);
    if (name.isNotEmpty) return name;

    final childName = _cleanText(data['childName']);
    if (childName.isNotEmpty) return childName;

    return 'طفل بدون اسم';
  }

  Future<Set<String>> _findAccessCodeIdsForChild({
    required String childId,
    required Map<String, dynamic> childData,
  }) async {
    final ids = <String>{
      _cleanText(childData['temporaryAccessCodeId']),
      _cleanText(childData['sharedAccessCodeId']),
    }..removeWhere((value) => value.isEmpty);

    final legacySnapshot = await _firestore
        .collection('temporary_access_codes')
        .where('childId', isEqualTo: childId)
        .get();

    for (final doc in legacySnapshot.docs) {
      ids.add(doc.id);
    }

    try {
      final sharedSnapshot = await _firestore
          .collection('temporary_access_codes')
          .where('childIds', arrayContains: childId)
          .get();

      for (final doc in sharedSnapshot.docs) {
        ids.add(doc.id);
      }
    } catch (_) {
      // بعض السجلات القديمة لا تحتوي childIds بعد.
    }

    return ids;
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _loadActiveSiblingDocs({
    required Iterable<String> linkedChildIds,
    required String excludedChildId,
  }) async {
    final siblings = <DocumentSnapshot<Map<String, dynamic>>>[];

    for (final siblingId in linkedChildIds) {
      if (siblingId.isEmpty || siblingId == excludedChildId) continue;

      final siblingDoc =
          await _firestore.collection('children').doc(siblingId).get();
      final siblingData = siblingDoc.data();

      if (siblingDoc.exists &&
          siblingData != null &&
          !_isArchivedChildData(siblingData)) {
        siblings.add(siblingDoc);
      }
    }

    return siblings;
  }

  Future<void> _updateAccessCodesAfterChildRemoval({
    required WriteBatch batch,
    required String childId,
    required Map<String, dynamic> childData,
    required String archiveReason,
    required bool automated,
  }) async {
    final accessCodeIds = await _findAccessCodeIdsForChild(
      childId: childId,
      childData: childData,
    );

    for (final codeId in accessCodeIds) {
      final codeRef = _firestore.collection('temporary_access_codes').doc(codeId);
      final codeDoc = await codeRef.get();

      if (!codeDoc.exists) continue;

      final codeData = codeDoc.data() ?? <String, dynamic>{};
      final linkedChildIds = <String>{
        ..._readStringList(codeData['childIds']),
        _cleanText(codeData['childId']),
      }..removeWhere((value) => value.isEmpty || value == childId);

      final siblingDocs = await _loadActiveSiblingDocs(
        linkedChildIds: linkedChildIds,
        excludedChildId: childId,
      );

      if (siblingDocs.isEmpty) {
        batch.set(
          codeRef,
          {
            'childIds': <String>[],
            'childNames': <String>[],
            'childTypes': <String>[],
            'groupIds': <String>[],
            'groupNames': <String>[],
            'hasMultipleChildren': false,
            'usesSharedAccessCode': false,
            'isActive': false,
            'status': automated ? 'expired' : 'archived',
            'accountStatus': 'archived',
            'archiveReason': archiveReason,
            'archivedAt': FieldValue.serverTimestamp(),
            if (automated) 'expiredAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        continue;
      }

      DateTime? earliestStart;
      DateTime? latestEnd;
      final siblingIds = <String>[];
      final siblingNames = <String>[];
      final siblingTypes = <String>{};
      final groupIds = <String>{};
      final groupNames = <String>{};

      for (final siblingDoc in siblingDocs) {
        final siblingData = siblingDoc.data() ?? <String, dynamic>{};
        final start = _toDateTime(siblingData['temporaryAccessStartAt']);
        final end = _toDateTime(siblingData['temporaryAccessEndAt']) ??
            _toDateTime(siblingData['temporaryEndDate']) ??
            _toDateTime(siblingData['trialEndAt']);

        if (start != null &&
            (earliestStart == null || start.isBefore(earliestStart))) {
          earliestStart = start;
        }

        if (end != null && (latestEnd == null || end.isAfter(latestEnd))) {
          latestEnd = end;
        }

        siblingIds.add(siblingDoc.id);
        siblingNames.add(_childNameFromData(siblingData));

        final type = _cleanText(siblingData['childType']);
        if (type.isNotEmpty) siblingTypes.add(type);

        final groupId = _cleanText(siblingData['groupId']);
        if (groupId.isNotEmpty) groupIds.add(groupId);

        final groupName = _cleanText(siblingData['groupName']);
        if (groupName.isNotEmpty) groupNames.add(groupName);
      }

      final primarySibling = siblingDocs.first;
      final primaryData = primarySibling.data() ?? <String, dynamic>{};

      batch.set(
        codeRef,
        {
          'childId': primarySibling.id,
          'childName': _childNameFromData(primaryData),
          'childIds': siblingIds,
          'childNames': siblingNames.toSet().toList(),
          'childTypes': siblingTypes.toList(),
          'groupId': _cleanText(primaryData['groupId']),
          'groupName': _cleanText(primaryData['groupName']),
          'groupIds': groupIds.toList(),
          'groupNames': groupNames.toList(),
          'hasMultipleChildren': siblingIds.length > 1,
          'usesSharedAccessCode': siblingIds.length > 1,
          'isActive': true,
          'status': 'active',
          'accountStatus': 'active',
          if (earliestStart != null)
            'accessStartAt': Timestamp.fromDate(earliestStart),
          if (latestEnd != null) 'accessEndAt': Timestamp.fromDate(latestEnd),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      for (final siblingDoc in siblingDocs) {
        batch.set(
          siblingDoc.reference,
          {
            'sharedAccessCodeId': codeId,
            'usesSharedAccessCode': siblingIds.length > 1,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }
  }

  Future<bool> _archiveExpiredChildrenIfNeeded(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    bool archivedAnyChild = false;
    final affectedGroupIds = <String>{};

    for (final doc in docs) {
      final data = doc.data();

      if (_isArchivedChildData(data)) continue;

      final isTemporary = _isTemporaryChildData(data);
      final isTrial = _isTrialChildData(data);

      if (!isTemporary && !isTrial) continue;

      final expiryDate = _expiryDateForChild(data);
      if (expiryDate == null || expiryDate.isAfter(DateTime.now())) continue;

      final archiveReason = isTrial ? 'trial_expired' : 'temporary_expired';
      final archivedChildStatus = isTrial ? 'rejected_after_trial' : 'archived';

      final devicesSnapshot = await _firestore
          .collection('temporary_parent_devices')
          .where('childId', isEqualTo: doc.id)
          .get();

      final batch = _firestore.batch();

      batch.set(
        doc.reference,
        {
          'isActive': false,
          'status': 'archived',
          'childStatus': archivedChildStatus,
          'accountStatus': 'archived',
          'isBillable': false,
          'excludeFromMonthlyInvoice': true,
          'canReactivate': true,
          'permanentDeleted': false,
          'archiveReason': archiveReason,
          'archivedAutomatically': true,
          'archivedAt': FieldValue.serverTimestamp(),
          'expiredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _updateAccessCodesAfterChildRemoval(
        batch: batch,
        childId: doc.id,
        childData: data,
        archiveReason: archiveReason,
        automated: true,
      );

      for (final deviceDoc in devicesSnapshot.docs) {
        batch.set(
          deviceDoc.reference,
          {
            'isActive': false,
            'accountStatus': 'archived',
            'archiveReason': archiveReason,
            'archivedAt': FieldValue.serverTimestamp(),
            'expiredAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      final groupId = _cleanText(data['groupId']);
      if (groupId.isNotEmpty) affectedGroupIds.add(groupId);

      archivedAnyChild = true;
    }

    for (final groupId in affectedGroupIds) {
      try {
        await _refreshGroupChildrenCount(groupId);
      } catch (_) {
        // لا نوقف عرض الأطفال إذا كانت المجموعة القديمة غير موجودة.
      }
    }

    return archivedAnyChild;
  }

  Future<List<Map<String, dynamic>>> fetchChildren() async {
    var snapshot = await _firestore.collection('children').get();

    final archivedExpiredChildren =
        await _archiveExpiredChildrenIfNeeded(snapshot.docs);

    if (archivedExpiredChildren) {
      snapshot = await _firestore.collection('children').get();
    }

    final items = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'name': data['name'] ?? '',
        'identityNumber': data['identityNumber'] ?? '',
        'gender': data['gender'] ?? 'female',
        'section': 'Nursery',
        'birthDate': data['birthDate'],
        'isActive': data['isActive'] ?? true,
        'status': data['status'] ?? 'active',
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],
        'history': (data['history'] as List?) ?? [],
        'parentName': data['parentName'] ?? '',
        'parentUsername': data['parentUsername'] ?? '',
        'parentUid': data['parentUid'] ?? '',
        'groupId': data['groupId'] ?? '',
        'groupName': data['groupName'] ?? '',
        'assignedStaffUid': data['assignedStaffUid'] ?? '',
        'assignedStaffName': data['assignedStaffName'] ?? '',
        'assignedStaffUsername': data['assignedStaffUsername'] ?? '',
        'childStatus': data['childStatus'] ?? data['status'] ?? 'active',
        'childType': data['childType'] ?? '',
        'isTemporary': data['isTemporary'] ?? false,
        'temporaryStartDate': data['temporaryStartDate'],
        'temporaryEndDate': data['temporaryEndDate'],
        'temporaryFee': data['temporaryFee'] ?? 0,
        'temporaryBillingType': data['temporaryBillingType'] ?? '',
        'temporaryBillingTypeLabel': data['temporaryBillingTypeLabel'] ?? '',
        'hasConsultation': data['hasConsultation'] ?? false,
        'consultationStatus': data['consultationStatus'] ?? '',
        'temporaryAccessCode': data['temporaryAccessCode'] ?? '',
        'hasChronicDiseases': data['hasChronicDiseases'] ?? false,
        'chronicDiseases': data['chronicDiseases'] ?? '',
        'hasAllergies': data['hasAllergies'] ?? false,
        'allergies': data['allergies'] ?? '',
        'takesMedications': data['takesMedications'] ?? false,
        'medications': data['medications'] ?? '',
        'hasDietaryRestrictions': data['hasDietaryRestrictions'] ?? false,
        'dietaryRestrictions': data['dietaryRestrictions'] ?? '',
        'hasSpecialNeeds': data['hasSpecialNeeds'] ?? false,
        'specialNeeds': data['specialNeeds'] ?? '',
        'healthNotes': data['healthNotes'] ?? '',
        'authorizedPickupContacts':
            (data['authorizedPickupContacts'] as List?) ?? [],
      };
    }).toList();

    final filteredByStatus = items.where((child) {
      final isActive = child['isActive'] == true;
      final currentStatus = isActive ? 'active' : 'archived';

      if (selectedViews.isEmpty) return true;
      return selectedViews.contains(currentStatus);
    }).toList();

    final query = searchText.trim().toLowerCase();

   final filtered = filteredByStatus.where((child) {
  final name = (child['name'] ?? '').toString().toLowerCase();
  final identity = (child['identityNumber'] ?? '').toString().toLowerCase();
  final section = (child['section'] ?? '').toString().toLowerCase();
  final parentName = (child['parentName'] ?? '').toString().toLowerCase();
  final parentUsername =
      (child['parentUsername'] ?? '').toString().toLowerCase();
  final groupName = (child['groupName'] ?? '').toString().toLowerCase();
  final assignedStaffName =
      (child['assignedStaffName'] ?? '').toString().toLowerCase();

  final childType = resolveChildType(child);

  final matchesType = selectedChildTypeFilter == 'all' ||
      selectedChildTypeFilter == childType;

  final matchesSearch = query.isEmpty ||
      name.contains(query) ||
      identity.contains(query) ||
      section.contains(query) ||
      parentName.contains(query) ||
      parentUsername.contains(query) ||
      groupName.contains(query) ||
      assignedStaffName.contains(query);

  return matchesType && matchesSearch;
}).toList();

    filtered.sort((a, b) {
      final aName = (a['name'] ?? '').toString();
      final bName = (b['name'] ?? '').toString();
      return aName.compareTo(bName);
    });

    return filtered;
  }

  String formatBirthDate(dynamic raw) {
    if (raw is Timestamp) {
      final date = raw.toDate();
      return '${date.year}/${date.month}/${date.day}';
    }
    return 'غير محدد';
  }

String formatOptionalDate(dynamic raw) {
  if (raw is Timestamp) {
    final date = raw.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$year/$month/$day';
  }

  if (raw is DateTime) {
    final day = raw.day.toString().padLeft(2, '0');
    final month = raw.month.toString().padLeft(2, '0');
    final year = raw.year.toString();

    return '$year/$month/$day';
  }

  return '';
}

  int? calculateAge(dynamic raw) {
    if (raw is Timestamp) {
      final birthDate = raw.toDate();
      final now = DateTime.now();

      int years = now.year - birthDate.year;

      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        years--;
      }

      return years;
    }

    return null;
  }

  String genderLabel(String value) {
    return value == 'male' ? 'ذكر' : 'أنثى';
  }

  String healthSummary(Map<String, dynamic> child) {
    final items = <String>[];

    if (child['hasChronicDiseases'] == true) items.add('مرض مزمن');
    if (child['hasAllergies'] == true) items.add('حساسية');
    if (child['takesMedications'] == true) items.add('أدوية');
    if (child['hasDietaryRestrictions'] == true) items.add('قيود غذائية');
    if (child['hasSpecialNeeds'] == true) items.add('احتياجات خاصة');

    if (items.isEmpty) return 'لا توجد ملاحظات صحية بارزة';
    return items.join(' • ');
  }

  ChildModel mapToChildModel(Map<String, dynamic> child) {
  return ChildModel.fromMap(
    {
      'id': child['id'] ?? '',
      'childId': child['id'] ?? '',
      'name': child['name'] ?? '',
      'childName': child['name'] ?? '',
      'section': 'Nursery',
      'parentName': child['parentName'] ?? '',
      'parentUsername': child['parentUsername'] ?? '',
      'parentUid': child['parentUid'] ?? '',
      'group': child['groupName'] ?? '',
      'groupName': child['groupName'] ?? '',
      'groupId': child['groupId'] ?? '',
      'birthDate': child['birthDate'],
      'isActive': child['isActive'] ?? true,
      'status': child['status'] ?? 'active',
      'childStatus': child['childStatus'] ?? child['status'] ?? 'active',
      'childType': child['childType'] ?? '',
      'enrollmentType': child['childType'] ?? '',
      'isTemporaryChild': resolveChildType(child) == 'temporary',
      'isTrialChild': resolveChildType(child) == 'trial',
    },
    docId: (child['id'] ?? '').toString(),
  );
}

  Future<void> openEntryExitLog(Map<String, dynamic> child) async {
    final childModel = mapToChildModel(child);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryExitLogPage(child: childModel),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> showChildForm({
    required Map<String, dynamic> child,
  }) async {
    final nameCtrl = TextEditingController(text: child['name'] ?? '');
    final identityNumberCtrl =
        TextEditingController(text: child['identityNumber'] ?? '');
    final healthNotesCtrl =
        TextEditingController(text: child['healthNotes'] ?? '');

    final chronicDiseasesCtrl =
        TextEditingController(text: child['chronicDiseases'] ?? '');
    final allergiesCtrl =
        TextEditingController(text: child['allergies'] ?? '');
    final medicationsCtrl =
        TextEditingController(text: child['medications'] ?? '');
    final dietaryRestrictionsCtrl =
        TextEditingController(text: child['dietaryRestrictions'] ?? '');
    final specialNeedsCtrl =
        TextEditingController(text: child['specialNeeds'] ?? '');

    DateTime selectedBirthDate = child['birthDate'] is Timestamp
        ? (child['birthDate'] as Timestamp).toDate()
        : DateTime(2023, 1, 1);

    String selectedSection = 'Nursery';

    String selectedGender = (child['gender'] ?? 'female').toString();
   final String currentChildType = resolveChildType(child);

    DateTime temporaryStartDate =
     child['temporaryStartDate'] is Timestamp
        ? (child['temporaryStartDate'] as Timestamp).toDate()
        : DateTime.now();

    DateTime temporaryEndDate =
    child['temporaryEndDate'] is Timestamp
        ? (child['temporaryEndDate'] as Timestamp).toDate()
        : DateTime.now().add(const Duration(days: 1));

    final temporaryNotesCtrl = TextEditingController(
    text: (child['temporaryNotes'] ?? '').toString(),
   );

    bool hasConsultation = child['hasConsultation'] == true;

    bool hasChronicDiseases = child['hasChronicDiseases'] == true;
    bool hasAllergies = child['hasAllergies'] == true;
    bool takesMedications = child['takesMedications'] == true;
    bool hasDietaryRestrictions = child['hasDietaryRestrictions'] == true;
    bool hasSpecialNeeds = child['hasSpecialNeeds'] == true;

    final List<_PickupContactEditor> pickupContacts =
        ((child['authorizedPickupContacts'] as List?) ?? [])
            .map(
              (e) => _PickupContactEditor.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();

    if (pickupContacts.isEmpty) {
      pickupContacts.add(_PickupContactEditor());
    }

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('تعديل بيانات الطفل'),
                content: SizedBox(
                  width: 470,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'اسم الطفل',
                              prefixIcon: Icon(Icons.child_care_outlined),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'اكتب اسم الطفل';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          if (currentChildType == 'permanent') ...[
                            TextFormField(
                              controller: identityNumberCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'رقم هوية الطفل',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: (value) {
                                final text = (value ?? '').trim();
                                if (text.isEmpty) {
                                  return 'أدخل رقم هوية الطفل';
                                }
                                if (!RegExp(r'^\d{9}$').hasMatch(text)) {
                                  return 'رقم الهوية يجب أن يتكون من 9 أرقام';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          DropdownButtonFormField<String>(
                            value: selectedGender,
                            decoration: const InputDecoration(
                              labelText: 'الجنس',
                              prefixIcon: Icon(Icons.wc_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'female',
                                child: Text('أنثى'),
                              ),
                              DropdownMenuItem(
                                value: 'male',
                                child: Text('ذكر'),
                              ),
                            ],
                            onChanged: (value) {
                              setLocalState(() {
                                selectedGender = value ?? 'female';
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedBirthDate,
                                firstDate: DateTime(2015),
                                lastDate: DateTime.now(),
                              );

                              if (picked != null) {
                                setLocalState(() {
                                  selectedBirthDate = picked;
                                  selectedSection = 'Nursery';
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'تاريخ الميلاد',
                                prefixIcon:
                                    Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                '${selectedBirthDate.year}/${selectedBirthDate.month}/${selectedBirthDate.day}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'القسم',
                              prefixIcon: Icon(Icons.apartment_outlined),
                            ),
                            child: Text(sectionLabel(selectedSection)),
                          ),
                         const SizedBox(height: 18),
Align(
  alignment: Alignment.centerRight,
  child: Text(
    'نوع الطفل',
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
  ),
),
const SizedBox(height: 8),
InputDecorator(
  decoration: const InputDecoration(
    labelText: 'نوع الطفل',
    prefixIcon: Icon(Icons.flag_outlined),
  ),
  child: Text(childTypeLabel(child)),
),
if (currentChildType == 'temporary' || currentChildType == 'trial') ...[
  const SizedBox(height: 12),
  Row(
    children: [
      Expanded(
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'تاريخ البداية',
            prefixIcon: Icon(Icons.event_outlined),
          ),
          child: Text(
            '${temporaryStartDate.year}/${temporaryStartDate.month}/${temporaryStartDate.day}',
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'تاريخ النهاية',
            prefixIcon: Icon(Icons.event_available_outlined),
          ),
          child: Text(
            '${temporaryEndDate.year}/${temporaryEndDate.month}/${temporaryEndDate.day}',
          ),
        ),
      ),
    ],
  ),
  const SizedBox(height: 12),
  SwitchListTile(
    value: hasConsultation,
    onChanged: (value) {
      setLocalState(() {
        hasConsultation = value;
      });
    },
    contentPadding: EdgeInsets.zero,
    title: const Text('مرتبط باستشارة'),
  ),
  const SizedBox(height: 12),
  TextFormField(
    controller: temporaryNotesCtrl,
    maxLines: 2,
    decoration: const InputDecoration(
      labelText: 'ملاحظات الطفل المؤقت / التجربة',
      prefixIcon: Icon(Icons.notes_outlined),
    ),
  ),
],
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'البيانات الصحية',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            value: hasChronicDiseases,
                            onChanged: (value) {
                              setLocalState(() {
                                hasChronicDiseases = value;
                                if (!value) chronicDiseasesCtrl.clear();
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            title: const Text('هل لدى الطفل أمراض مزمنة؟'),
                          ),
                          if (hasChronicDiseases) ...[
                            TextFormField(
                              controller: chronicDiseasesCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'تفاصيل الأمراض المزمنة',
                                prefixIcon:
                                    Icon(Icons.monitor_heart_outlined),
                              ),
                              validator: (value) {
                                if (hasChronicDiseases &&
                                    (value ?? '').trim().isEmpty) {
                                  return 'أدخل تفاصيل الأمراض المزمنة';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          SwitchListTile(
                            value: hasAllergies,
                            onChanged: (value) {
                              setLocalState(() {
                                hasAllergies = value;
                                if (!value) allergiesCtrl.clear();
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            title: const Text('هل لدى الطفل حساسية؟'),
                          ),
                          if (hasAllergies) ...[
                            TextFormField(
                              controller: allergiesCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'تفاصيل الحساسية',
                                prefixIcon:
                                    Icon(Icons.warning_amber_rounded),
                              ),
                              validator: (value) {
                                if (hasAllergies &&
                                    (value ?? '').trim().isEmpty) {
                                  return 'أدخل تفاصيل الحساسية';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          SwitchListTile(
                            value: takesMedications,
                            onChanged: (value) {
                              setLocalState(() {
                                takesMedications = value;
                                if (!value) medicationsCtrl.clear();
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'هل يتناول الطفل أدوية بشكل مستمر؟',
                            ),
                          ),
                          if (takesMedications) ...[
                            TextFormField(
                              controller: medicationsCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'تفاصيل الأدوية',
                                prefixIcon: Icon(Icons.medication_outlined),
                              ),
                              validator: (value) {
                                if (takesMedications &&
                                    (value ?? '').trim().isEmpty) {
                                  return 'أدخل تفاصيل الأدوية';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          SwitchListTile(
                            value: hasDietaryRestrictions,
                            onChanged: (value) {
                              setLocalState(() {
                                hasDietaryRestrictions = value;
                                if (!value) dietaryRestrictionsCtrl.clear();
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            title: const Text('هل لدى الطفل قيود غذائية؟'),
                          ),
                          if (hasDietaryRestrictions) ...[
                            TextFormField(
                              controller: dietaryRestrictionsCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'تفاصيل القيود الغذائية',
                                prefixIcon:
                                    Icon(Icons.restaurant_menu_rounded),
                              ),
                              validator: (value) {
                                if (hasDietaryRestrictions &&
                                    (value ?? '').trim().isEmpty) {
                                  return 'أدخل تفاصيل القيود الغذائية';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          SwitchListTile(
                            value: hasSpecialNeeds,
                            onChanged: (value) {
                              setLocalState(() {
                                hasSpecialNeeds = value;
                                if (!value) specialNeedsCtrl.clear();
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            title: const Text('هل لدى الطفل احتياجات خاصة؟'),
                          ),
                          if (hasSpecialNeeds) ...[
                            TextFormField(
                              controller: specialNeedsCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'تفاصيل الاحتياجات الخاصة',
                                prefixIcon: Icon(Icons.accessible_rounded),
                              ),
                              validator: (value) {
                                if (hasSpecialNeeds &&
                                    (value ?? '').trim().isEmpty) {
                                  return 'أدخل تفاصيل الاحتياجات الخاصة';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: healthNotesCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظات صحية عامة',
                              prefixIcon:
                                  Icon(Icons.health_and_safety_rounded),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'المخولون بالاستلام',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...List.generate(pickupContacts.length, (index) {
                            final pickup = pickupContacts[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'الشخص ${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ),
                                      if (pickupContacts.length > 1)
                                        IconButton(
                                          onPressed: () {
                                            setLocalState(() {
                                              pickup.dispose();
                                              pickupContacts.removeAt(index);
                                            });
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                          color: Colors.redAccent,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: pickup.nameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'الاسم',
                                      prefixIcon:
                                          Icon(Icons.person_outline_rounded),
                                    ),
                                    validator: (value) {
                                      if ((value?.trim() ?? '').isEmpty) {
                                        return 'أدخل الاسم';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: pickup.relationCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'صلة القرابة',
                                      prefixIcon:
                                          Icon(Icons.family_restroom_rounded),
                                    ),
                                    validator: (value) {
                                      if ((value?.trim() ?? '').isEmpty) {
                                        return 'أدخل صلة القرابة';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: pickup.phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      labelText: 'رقم الجوال',
                                      prefixIcon: Icon(Icons.phone_rounded),
                                    ),
                                    validator: (value) {
                                      final clean = (value ?? '').trim();
                                      if (clean.isEmpty) {
                                        return 'أدخل رقم الجوال';
                                      }
                                      if (!RegExp(r'^(059|056|052)\d{7}$')
                                          .hasMatch(clean)) {
                                        return 'رقم جوال فلسطيني غير صالح';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setLocalState(() {
                                  pickupContacts.add(_PickupContactEditor());
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة شخص مخوّل آخر'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      const resolvedSection = 'Nursery';

                      final oldSection = (child['section'] ?? '').toString();
                      final oldHistory = List<Map<String, dynamic>>.from(
                        (child['history'] as List?) ?? [],
                      );

                      List<Map<String, dynamic>> newHistory = oldHistory;
                      final nowTs = Timestamp.now();

                      final sectionChanged = oldSection != resolvedSection;

                      if (sectionChanged) {
                        newHistory = oldHistory.map((item) {
                          final updated = Map<String, dynamic>.from(item);
                          if (updated['to'] == null) {
                            updated['to'] = nowTs;
                          }
                          return updated;
                        }).toList();

                        newHistory.add({
                          'section': resolvedSection,
                          'from': nowTs,
                          'to': null,
                        });
                      }

                      await _firestore
                          .collection('children')
                          .doc(child['id'])
                          .update({
                        'name': nameCtrl.text.trim(),
                        if (currentChildType == 'permanent')
                          'identityNumber': identityNumberCtrl.text.trim(),
                        'gender': selectedGender,
                        'birthDate': Timestamp.fromDate(selectedBirthDate),
                        'section': resolvedSection,
                        'hasChronicDiseases': hasChronicDiseases,
                        'chronicDiseases': hasChronicDiseases
                            ? chronicDiseasesCtrl.text.trim()
                            : '',
                        'hasAllergies': hasAllergies,
                        'allergies':
                            hasAllergies ? allergiesCtrl.text.trim() : '',
                        'takesMedications': takesMedications,
                        'medications':
                            takesMedications ? medicationsCtrl.text.trim() : '',
                        'hasDietaryRestrictions': hasDietaryRestrictions,
                        'dietaryRestrictions': hasDietaryRestrictions
                            ? dietaryRestrictionsCtrl.text.trim()
                            : '',
                        'hasSpecialNeeds': hasSpecialNeeds,
                        'specialNeeds':
                            hasSpecialNeeds ? specialNeedsCtrl.text.trim() : '',
                        'healthNotes': healthNotesCtrl.text.trim(),
                        'authorizedPickupContacts':
                            pickupContacts.map((e) => e.toMap()).toList(),
                         'updatedAt': FieldValue.serverTimestamp(),
                         'history': newHistory,
                         'hasConsultation': hasConsultation,
                         'consultationStatus': hasConsultation ? 'pending' : 'none',
                         'temporaryNotes': temporaryNotesCtrl.text.trim(),

                      });

                      if (!mounted) return;
                      Navigator.pop(dialogContext);
                      setState(() {});

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تحديث بيانات الطفل بنجاح'),
                        ),
                      );
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    identityNumberCtrl.dispose();
    healthNotesCtrl.dispose();
    chronicDiseasesCtrl.dispose();
    allergiesCtrl.dispose();
    medicationsCtrl.dispose();
    dietaryRestrictionsCtrl.dispose();
    specialNeedsCtrl.dispose();
    temporaryNotesCtrl.dispose();

    for (final pickup in pickupContacts) {
      pickup.dispose();
    }
  }

  Future<void> archiveChild(Map<String, dynamic> child) async {
    final childId = (child['id'] ?? '').toString().trim();
    final childName = (child['name'] ?? '').toString().trim();

    if (childId.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('أرشفة الطفل'),
              content: Text(
                'هل تريد أرشفة الطفل "$childName"؟\n\nلن يتم حذف بياناته من النظام.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('أرشفة'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    final childRef = _firestore.collection('children').doc(childId);
    final childDoc = await childRef.get();
    final childData = childDoc.data() ?? Map<String, dynamic>.from(child);

    final batch = _firestore.batch();

    batch.set(
      childRef,
      {
        'isActive': false,
        'status': 'archived',
        'childStatus': 'archived',
        'accountStatus': 'archived',
        'canReactivate': true,
        'permanentDeleted': false,
        'archivedAt': FieldValue.serverTimestamp(),
        'archiveReason': 'archived_from_manage_children',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (_isTemporaryChildData(childData) || _isTrialChildData(childData)) {
      await _updateAccessCodesAfterChildRemoval(
        batch: batch,
        childId: childId,
        childData: childData,
        archiveReason: 'archived_from_manage_children',
        automated: false,
      );
    }

    final devicesSnapshot = await _firestore
        .collection('temporary_parent_devices')
        .where('childId', isEqualTo: childId)
        .get();

    for (final doc in devicesSnapshot.docs) {
      batch.set(
        doc.reference,
        {
          'isActive': false,
          'accountStatus': 'archived',
          'archivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تمت أرشفة الطفل بنجاح'),
      ),
    );
  }

  Future<void> restoreChild(Map<String, dynamic> child) async {
  final childId = (child['id'] ?? '').toString().trim();

  if (childId.isEmpty) return;

  final childType = resolveChildType(child);

  if (childType == 'temporary' || childType == 'trial') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'يتم إعادة تفعيل الطفل المؤقت أو طفل التجربة من إدارة المجموعات.',
        ),
      ),
    );
    return;
  }

  await _firestore.collection('children').doc(childId).update({
    'isActive': true,
    'status': 'active',
    'childStatus': 'active',
    'accountStatus': 'active',
    'canReactivate': true,
    'permanentDeleted': false,
    'restoredAt': FieldValue.serverTimestamp(),
    'archiveReason': FieldValue.delete(),
    'archivedAt': FieldValue.delete(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  if (!mounted) return;

  setState(() {});

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('تمت استعادة الطفل إلى القائمة النشطة'),
    ),
  );
}

  Widget buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? selectedColor,
  }) {
    final activeColor = selectedColor ?? AppColors.secondary;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: activeColor,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? activeColor : AppColors.primary.withOpacity(0.14),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Future<void> openAssignGroupDialog(Map<String, dynamic> child) async {
  final groupsSnapshot = await _firestore
      .collection('groups')
      .where('isActive', isEqualTo: true)
      .get();

  if (!mounted) return;

  final groups = groupsSnapshot.docs;

  if (groups.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لا توجد مجموعات مفعّلة. أنشئي مجموعة أولاً من إدارة المجموعات.'),
      ),
    );
    return;
  }

  String selectedGroupId = (child['groupId'] ?? '').toString();

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تحديد مجموعة الطفل'),
              content: SizedBox(
                width: 430,
                child: DropdownButtonFormField<String>(
                  value: selectedGroupId.trim().isEmpty ? null : selectedGroupId,
                  decoration: const InputDecoration(
                    labelText: 'اختاري المجموعة',
                    prefixIcon: Icon(Icons.groups_2_outlined),
                  ),
                  items: groups.map((doc) {
                    final data = doc.data();

                    final groupName =
                        (data['groupName'] ?? 'مجموعة بدون اسم').toString();

                    final staffName =
                        (data['assignedStaffName'] ?? 'موظفة غير محددة')
                            .toString();

                    final currentChildren =
                        (data['currentChildrenCount'] as num?)?.toInt() ?? 0;

                    final maxChildren =
                        (data['maxChildren'] as num?)?.toInt() ?? 12;

                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(
                        '$groupName • $staffName • $currentChildren/$maxChildren',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setLocalState(() {
                      selectedGroupId = value ?? '';
                    });
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: selectedGroupId.trim().isEmpty
                      ? null
                      : () async {
                          final selectedGroupDoc = groups.firstWhere(
                            (doc) => doc.id == selectedGroupId,
                          );

                          final groupData = selectedGroupDoc.data();

                          final oldGroupId = (child['groupId'] ?? '').toString();

                          await _firestore
                              .collection('children')
                              .doc(child['id'])
                              .update({
                            'groupId': selectedGroupDoc.id,
                            'groupName': groupData['groupName'] ?? '',
                            'assignedStaffUid':
                                groupData['assignedStaffUid'] ?? '',
                            'assignedStaffName':
                                groupData['assignedStaffName'] ?? '',
                            'assignedStaffUsername':
                                groupData['assignedStaffUsername'] ?? '',
                            'childStatus':
                                child['childStatus'] ?? child['status'] ?? 'active',
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          await _refreshGroupChildrenCount(selectedGroupDoc.id);

                          if (oldGroupId.trim().isNotEmpty &&
                              oldGroupId != selectedGroupDoc.id) {
                            await _refreshGroupChildrenCount(oldGroupId);
                          }

                          if (!mounted) return;

                          Navigator.pop(dialogContext);
                          setState(() {});

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم ربط الطفل بالمجموعة بنجاح'),
                            ),
                          );
                        },
                  child: const Text('حفظ'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _refreshGroupChildrenCount(String groupId) async {
  if (groupId.trim().isEmpty) return;

  final childrenSnapshot = await _firestore
      .collection('children')
      .where('groupId', isEqualTo: groupId)
      .where('isActive', isEqualTo: true)
      .get();

  await _firestore.collection('groups').doc(groupId).update({
    'currentChildrenCount': childrenSnapshot.docs.length,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

String temporaryChildSummary(Map<String, dynamic> child) {
  final type = resolveChildType(child);

  if (type != 'temporary' && type != 'trial') {
    return '';
  }

  final start = formatOptionalDate(child['temporaryStartDate']);
  final end = formatOptionalDate(child['temporaryEndDate']);
  final fee = child['temporaryFee'] ?? 0;
  final billingLabel =
      (child['temporaryBillingTypeLabel'] ?? '').toString().trim();
  final hasConsultation = child['hasConsultation'] == true;
  final accessCode = (child['temporaryAccessCode'] ?? '').toString().trim();

  final parts = <String>[
    if (start.isNotEmpty || end.isNotEmpty)
      'الفترة: ${start.isEmpty ? '-' : start} إلى ${end.isEmpty ? '-' : end}',
    if (fee != 0)
      'الرسوم: $fee شيكل${billingLabel.isNotEmpty ? ' - $billingLabel' : ''}',
    'استشارة: ${hasConsultation ? 'نعم' : 'لا'}',
    if (accessCode.isNotEmpty) 'كود الدخول: $accessCode',
  ];

  return parts.join(' | ');
}

  Widget buildChildCard(Map<String, dynamic> child) {
    final name = (child['name'] ?? '').toString();
    final section = (child['section'] ?? '').toString();
    final identityNumber = (child['identityNumber'] ?? '').toString();
    final gender = (child['gender'] ?? 'female').toString();
    final isActive = child['isActive'] == true;
    final color = sectionColor(section);
    final age = calculateAge(child['birthDate']);
    final groupName = (child['groupName'] ?? '').toString();
    final assignedStaffName = (child['assignedStaffName'] ?? '').toString();
    final typeLabel = childTypeLabel(child);
    final typeColor = childTypeColor(child);
    final tempSummary = temporaryChildSummary(child);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: color.withOpacity(0.15),
                child: Text(
                  name.isEmpty ? 'ط' : name.substring(0, 1),
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'بدون اسم' : name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sectionLabel(section),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.12)
            : Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        isActive ? 'نشط' : 'مؤرشف',
        style: TextStyle(
          color: isActive ? Colors.green : Colors.orange,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    const SizedBox(height: 6),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        typeLabel,
        style: TextStyle(
          color: typeColor,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    ),
  ],
),
            ],
          ),
          const SizedBox(height: 14),
          if (identityNumber.isNotEmpty)
            _infoRow(Icons.badge_outlined, 'رقم الهوية', identityNumber),
          if (identityNumber.isNotEmpty) const SizedBox(height: 8),
          _infoRow(Icons.wc_outlined, 'الجنس', genderLabel(gender)),
          const SizedBox(height: 8),
          _infoRow(
            Icons.calendar_today_outlined,
            'تاريخ الميلاد',
            formatBirthDate(child['birthDate']),
          ),
          if (age != null) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.cake_outlined, 'العمر', '$age سنة'),
          ],
          const SizedBox(height: 8),
          _infoRow(
            Icons.health_and_safety_outlined,
            'الحالة الصحية',
            healthSummary(child),
          ),

          const SizedBox(height: 8),
          _infoRow(
            Icons.flag_outlined,
            'نوع الطفل',
            typeLabel,
          ),

          if (tempSummary.isNotEmpty) ...[
           const SizedBox(height: 8),
          _infoRow(
           Icons.event_available_outlined,
           'تفاصيل المؤقت',
           tempSummary,
           ),
          ],

          const SizedBox(height: 8),
           _infoRow(
           Icons.groups_2_outlined,
            'المجموعة',
           groupName.trim().isEmpty ? 'غير محددة' : groupName,
           ),
           if (assignedStaffName.trim().isNotEmpty) ...[
           const SizedBox(height: 8),
            _infoRow(
             Icons.badge_outlined,
             'الموظفة المسؤولة',
             assignedStaffName,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => openEntryExitLog(child),
              icon: const Icon(Icons.login_outlined),
              label: const Text('السجل الإداري للدخول والخروج'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
           SizedBox(
           width: double.infinity,
           child: OutlinedButton.icon(
           onPressed: () => openAssignGroupDialog(child),
           icon: const Icon(Icons.groups_2_outlined),
           label: const Text('تحديد / نقل المجموعة'),
           style: OutlinedButton.styleFrom(
           minimumSize: const Size(double.infinity, 50),
           shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(14),
          ),
           ),
          ),
         ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => showChildForm(child: child),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (isActive) {
                      archiveChild(child);
                    } else {
                      restoreChild(child);
                    }
                  },
                  icon: Icon(
                    isActive ? Icons.archive_outlined : Icons.restore_outlined,
                  ),
                  label: Text(isActive ? 'أرشفة' : 'استعادة'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFiltersCard() {
    final hasCustomFilters = selectedViews.length != 1 ||
    !selectedViews.contains('active') ||
    searchText.trim().isNotEmpty ||
    selectedChildTypeFilter != 'all';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'ابحثي باسم الطفل أو رقم الهوية أو اسم ولي الأمر',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchText.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        setState(() {
                          searchText = '';
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onChanged: (value) {
              setState(() {
                searchText = value;
              });
            },
          ),
          const SizedBox(height: 14),
          const Text(
            'الحالة',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildFilterChip(
                label: 'النشطون',
                selected: selectedViews.contains('active'),
                onTap: () => toggleViewFilter('active'),
                selectedColor: Colors.green,
              ),
              buildFilterChip(
                label: 'المؤرشفون',
                selected: selectedViews.contains('archived'),
                onTap: () => toggleViewFilter('archived'),
                selectedColor: Colors.orange,
              ),
            ],
          ),

        const SizedBox(height: 14),
const Text(
  'نوع الطفل',
  style: TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
  ),
),
const SizedBox(height: 8),
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    buildFilterChip(
      label: 'الكل',
      selected: selectedChildTypeFilter == 'all',
      onTap: () {
        setState(() {
          selectedChildTypeFilter = 'all';
        });
      },
      selectedColor: AppColors.primary,
    ),
    buildFilterChip(
      label: 'دائم',
      selected: selectedChildTypeFilter == 'permanent',
      onTap: () {
        setState(() {
          selectedChildTypeFilter = 'permanent';
        });
      },
      selectedColor: Colors.green,
    ),
    buildFilterChip(
      label: 'مؤقت',
      selected: selectedChildTypeFilter == 'temporary',
      onTap: () {
        setState(() {
          selectedChildTypeFilter = 'temporary';
        });
      },
      selectedColor: Colors.deepPurple,
    ),
    buildFilterChip(
      label: 'تجربة',
      selected: selectedChildTypeFilter == 'trial',
      onTap: () {
        setState(() {
          selectedChildTypeFilter = 'trial';
        });
      },
      selectedColor: Colors.orange,
    ),
  ],
),
          if (hasCustomFilters) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: clearAllFilters,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('إعادة تعيين الفلاتر'),
              ),
            ),
          ],
        ],
      ),
    );
  }


  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }


  String _parentDisplayName(Map<String, dynamic> data) {
    final values = [
      data['displayName'],
      data['name'],
      data['fullName'],
      data['username'],
    ];

    for (final value in values) {
      final text = _cleanText(value);
      if (text.isNotEmpty) return text;
    }

    return 'ولي أمر بدون اسم';
  }

  String _parentPhone(Map<String, dynamic> data) {
    final values = [
      data['phone'],
      data['phoneNumber'],
      data['mobile'],
      data['parentPhone'],
    ];

    for (final value in values) {
      final text = _cleanText(value);
      if (text.isNotEmpty) return text;
    }

    return '';
  }

  Future<void> _openAddChildOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_add_alt_1_rounded),
                  ),
                  title: const Text(
                    'إضافة طفل دائم',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('ربطه بحساب ولي أمر رسمي موجود'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _openAddPermanentChildSheet();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.schedule_rounded),
                  ),
                  title: const Text(
                    'إضافة طفل مؤقت أو تجربة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('اختيار المجموعة ثم نوع الإضافة'),
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminGroupsPage(
                          openAddChildFlow: true,
                        ),
                      ),
                    );

                    if (!mounted) return;
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadOfficialParents() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .get();

    final parents = snapshot.docs.where((doc) {
      final data = doc.data();

      final isTemporaryOrTrial = data['isTemporaryAccount'] == true ||
          data['isTrialAccount'] == true ||
          _cleanText(data['accountType']) == 'temporary_parent' ||
          _cleanText(data['accountType']) == 'trial_parent';

      return data['isActive'] != false && !isTemporaryOrTrial;
    }).toList();

    parents.sort((a, b) {
      return _parentDisplayName(a.data()).compareTo(
        _parentDisplayName(b.data()),
      );
    });

    return parents;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadActiveGroups() async {
    final snapshot = await _firestore
        .collection('groups')
        .where('isActive', isEqualTo: true)
        .get();

    final groups = snapshot.docs.toList();

    groups.sort((a, b) {
      final aName = _cleanText(a.data()['groupName']);
      final bName = _cleanText(b.data()['groupName']);
      return aName.compareTo(bName);
    });

    return groups;
  }

  Future<void> _openAddPermanentChildSheet() async {
    final parents = await _loadOfficialParents();
    final groups = await _loadActiveGroups();

    if (!mounted) return;

    if (parents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد حساب ولي أمر رسمي مفعّل'),
        ),
      );
      return;
    }

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أنشئي مجموعة مفعّلة أولًا'),
        ),
      );
      return;
    }

    final childNameCtrl = TextEditingController();
    final identityNumberCtrl = TextEditingController();

    String selectedParentUid = '';
    String selectedGroupId = '';
    String selectedGender = 'female';
    DateTime selectedBirthDate = DateTime(2023, 1, 1);
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'إضافة طفل دائم',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue:
                            selectedParentUid.isEmpty ? null : selectedParentUid,
                        decoration: const InputDecoration(
                          labelText: 'ولي الأمر',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        items: parents.map((doc) {
                          final data = doc.data();
                          final username = _cleanText(data['username']);
                          final name = _parentDisplayName(data);

                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              username.isEmpty ? name : '$name • @$username',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setSheetState(() {
                            selectedParentUid = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue:
                            selectedGroupId.isEmpty ? null : selectedGroupId,
                        decoration: const InputDecoration(
                          labelText: 'المجموعة',
                          prefixIcon: Icon(Icons.groups_2_outlined),
                        ),
                        items: groups.map((doc) {
                          final data = doc.data();
                          final groupName = _cleanText(data['groupName']);
                          final currentChildren =
                              (data['currentChildrenCount'] as num?)?.toInt() ??
                                  0;
                          final maxChildren =
                              (data['maxChildren'] as num?)?.toInt() ?? 12;

                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              '$groupName • $currentChildren/$maxChildren',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setSheetState(() {
                            selectedGroupId = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: childNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم الطفل',
                          prefixIcon: Icon(Icons.child_care_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: identityNumberCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'رقم هوية الطفل',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'الجنس',
                          prefixIcon: Icon(Icons.wc_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('أنثى'),
                          ),
                          DropdownMenuItem(
                            value: 'male',
                            child: Text('ذكر'),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() {
                            selectedGender = value ?? 'female';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: sheetContext,
                            initialDate: selectedBirthDate,
                            firstDate: DateTime(2015),
                            lastDate: DateTime.now(),
                          );

                          if (picked == null) return;

                          setSheetState(() {
                            selectedBirthDate = picked;
                          });
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تاريخ الميلاد',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(
                            '${selectedBirthDate.year}/${selectedBirthDate.month}/${selectedBirthDate.day}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final childName = childNameCtrl.text.trim();
                                  final identityNumber =
                                      identityNumberCtrl.text.trim();

                                  if (selectedParentUid.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('اختاري ولي الأمر'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (selectedGroupId.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('اختاري المجموعة'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (childName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('اكتبي اسم الطفل'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (!RegExp(r'^\d{9}$')
                                      .hasMatch(identityNumber)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'رقم الهوية يجب أن يتكون من 9 أرقام',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                  });

                                  final saved = await _savePermanentChild(
                                    childName: childName,
                                    identityNumber: identityNumber,
                                    gender: selectedGender,
                                    birthDate: selectedBirthDate,
                                    parentDoc: parents.firstWhere(
                                      (doc) => doc.id == selectedParentUid,
                                    ),
                                    groupDoc: groups.firstWhere(
                                      (doc) => doc.id == selectedGroupId,
                                    ),
                                  );

                                  if (!sheetContext.mounted) return;

                                  if (saved) {
                                    Navigator.pop(sheetContext);
                                  } else {
                                    setSheetState(() {
                                      isSaving = false;
                                    });
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            isSaving ? 'جاري الحفظ...' : 'حفظ',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    childNameCtrl.dispose();
    identityNumberCtrl.dispose();
  }

  Future<bool> _savePermanentChild({
    required String childName,
    required String identityNumber,
    required String gender,
    required DateTime birthDate,
    required QueryDocumentSnapshot<Map<String, dynamic>> parentDoc,
    required QueryDocumentSnapshot<Map<String, dynamic>> groupDoc,
  }) async {
    try {
      final identitySnapshot = await _firestore
          .collection('children')
          .where('identityNumber', isEqualTo: identityNumber)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? existingChildDoc;

      if (identitySnapshot.docs.isNotEmpty) {
        existingChildDoc = identitySnapshot.docs.first;
      }

      final existingData = existingChildDoc?.data() ?? <String, dynamic>{};

      final existingType = _cleanText(existingData['childType']).toLowerCase();
      final existingEnrollmentType =
          _cleanText(existingData['enrollmentType']).toLowerCase();
      final isExistingPermanent = existingType == 'permanent' ||
          existingEnrollmentType == 'permanent';

      if (isExistingPermanent) {
        if (!mounted) return false;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هذا الطفل مسجل كطفل دائم بالفعل'),
          ),
        );
        return false;
      }

      final groupData = groupDoc.data();
      final currentChildren =
          (groupData['currentChildrenCount'] as num?)?.toInt() ?? 0;
      final maxChildren =
          (groupData['maxChildren'] as num?)?.toInt() ?? 12;

      final oldGroupId = _cleanText(existingData['groupId']);
      final wasActive = existingData['isActive'] == true;

      if (maxChildren > 0 &&
          currentChildren >= maxChildren &&
          (!wasActive || oldGroupId != groupDoc.id)) {
        if (!mounted) return false;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('المجموعة ممتلئة، اختاري مجموعة أخرى'),
          ),
        );
        return false;
      }

      final parentData = parentDoc.data();
      final parentUsername = _cleanText(parentData['username']).toLowerCase();
      final parentName = _parentDisplayName(parentData);
      final parentPhone = _parentPhone(parentData);
      final childRef = existingChildDoc?.reference ??
          _firestore.collection('children').doc();

      final batch = _firestore.batch();

      batch.set(
        childRef,
        {
          'id': childRef.id,
          'childId': childRef.id,
          'name': childName,
          'childName': childName,
          'identityNumber': identityNumber,
          'gender': gender,
          'birthDate': Timestamp.fromDate(birthDate),
          'section': 'Nursery',
          'childType': 'permanent',
          'enrollmentType': 'permanent',
          'childStatus': 'active',
          'status': 'active',
          'accountStatus': 'active',
          'isActive': true,
          'isTemporaryChild': false,
          'isTrialChild': false,
          'isTemporary': false,
          'isBillable': true,
          'excludeFromMonthlyInvoice': false,
          'parentUid': parentDoc.id,
          'parentUsername': parentUsername,
          'parentName': parentName,
          'parentPhone': parentPhone,
          'groupId': groupDoc.id,
          'groupName': _cleanText(groupData['groupName']),
          'assignedStaffUid': _cleanText(groupData['assignedStaffUid']),
          'assignedStaffName': _cleanText(groupData['assignedStaffName']),
          'assignedStaffUsername':
              _cleanText(groupData['assignedStaffUsername']),
          'canReactivate': true,
          'permanentDeleted': false,
          'convertedFromTemporary':
              existingChildDoc != null && !isExistingPermanent,
          'convertedToPermanentAt': existingChildDoc == null
              ? null
              : FieldValue.serverTimestamp(),
          'temporaryAccess': false,
          'temporaryAccessCodeId': FieldValue.delete(),
          'sharedAccessCodeId': FieldValue.delete(),
          'usesSharedAccessCode': FieldValue.delete(),
          'temporaryAccessCode': FieldValue.delete(),
          'temporaryAccessStartAt': FieldValue.delete(),
          'temporaryAccessEndAt': FieldValue.delete(),
          'archiveReason': FieldValue.delete(),
          'archivedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (existingChildDoc == null) ...{
            'createdAt': FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );

      if (existingChildDoc != null && !isExistingPermanent) {
        await _updateAccessCodesAfterChildRemoval(
          batch: batch,
          childId: childRef.id,
          childData: existingData,
          archiveReason: 'converted_to_permanent',
          automated: false,
        );

        final devicesSnapshot = await _firestore
            .collection('temporary_parent_devices')
            .where('childId', isEqualTo: childRef.id)
            .get();

        for (final deviceDoc in devicesSnapshot.docs) {
          batch.set(
            deviceDoc.reference,
            {
              'isActive': false,
              'accountStatus': 'archived',
              'archiveReason': 'converted_to_permanent',
              'archivedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      await batch.commit();

      await _refreshGroupChildrenCount(groupDoc.id);

      if (oldGroupId.isNotEmpty && oldGroupId != groupDoc.id) {
        await _refreshGroupChildrenCount(oldGroupId);
      }

      if (!mounted) return true;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت إضافة الطفل الدائم بنجاح'),
        ),
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ الطفل الدائم: $e'),
        ),
      );

      return false;
    }
  }


 String buildEmptyStateText() {
  final hasCustomStatusFilter = selectedViews.length != 1 ||
      !selectedViews.contains('active');

  final hasSearch = searchText.trim().isNotEmpty;
  final hasChildTypeFilter = selectedChildTypeFilter != 'all';

  if (hasSearch || hasCustomStatusFilter || hasChildTypeFilter) {
    return 'لا توجد نتائج مطابقة للفلاتر الحالية';
  }

  return 'لا توجد بيانات بعد';
}

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إدارة الأطفال',
      actions: [
        IconButton(
          tooltip: 'إضافة طفل',
          onPressed: _openAddChildOptions,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          buildFiltersCard(),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchChildren(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  debugPrint('MANAGE CHILDREN LOAD ERROR: ${snapshot.error}');
                  debugPrintStack(
                    label: 'MANAGE CHILDREN LOAD STACK',
                    stackTrace: snapshot.stackTrace,
                  );

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'حدث خطأ أثناء تحميل الأطفال\n\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }

                final children = snapshot.data ?? [];

                if (children.isEmpty) {
                  return Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.child_care_outlined,
                            size: 52,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'لا يوجد أطفال في هذه القائمة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            buildEmptyStateText(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      return buildChildCard(children[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupContactEditor {
  final nameCtrl = TextEditingController();
  final relationCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  _PickupContactEditor();

  factory _PickupContactEditor.fromMap(Map<String, dynamic> data) {
    final editor = _PickupContactEditor();
    editor.nameCtrl.text = (data['name'] ?? '').toString();
    editor.relationCtrl.text = (data['relation'] ?? '').toString();
    editor.phoneCtrl.text = (data['phone'] ?? '').toString();
    return editor;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': nameCtrl.text.trim(),
      'relation': relationCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
    };
  }

  void dispose() {
    nameCtrl.dispose();
    relationCtrl.dispose();
    phoneCtrl.dispose();
  }
}