import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
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

  if (childStatus == 'trial_pending_decision') {
    return 'بانتظار قرار التجربة';
  }

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
      final archivedChildStatus =
          isTrial ? 'trial_pending_decision' : 'archived';

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
          'canReactivate': !isTrial,
          'permanentDeleted': false,
          'archiveReason': isTrial
              ? 'trial_expired_pending_decision'
              : archiveReason,
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
        'enrollmentType': data['enrollmentType'] ?? '',
        'accountStatus': data['accountStatus'] ?? '',
        'isTemporaryChild': data['isTemporaryChild'] ?? false,
        'isTrialChild': data['isTrialChild'] ?? false,
        'trialDecision': data['trialDecision'] ?? '',
        'isTemporary': data['isTemporary'] ?? false,
        'temporaryStartDate': data['temporaryStartDate'],
        'temporaryEndDate': data['temporaryEndDate'],
        'temporaryFee': data['temporaryFee'] ?? 0,
        'temporaryBillingType': data['temporaryBillingType'] ?? '',
        'temporaryBillingTypeLabel': data['temporaryBillingTypeLabel'] ?? '',
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

    final isTrial = _isTrialChildData(childData);

    batch.set(
      childRef,
      {
        'isActive': false,
        'status': 'archived',
        'childStatus': isTrial ? 'rejected_after_trial' : 'archived',
        'accountStatus': 'archived',
        'canReactivate': !isTrial,
        'permanentDeleted': false,
        'archivedAt': FieldValue.serverTimestamp(),
        'archiveReason': isTrial
            ? 'trial_rejected_from_manage_children'
            : 'archived_from_manage_children',
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
    final childId = _cleanText(child['id']);
    if (childId.isEmpty) return;

    final childType = resolveChildType(child);

    if (childType == 'trial') {
      final childStatus = _cleanText(child['childStatus']).toLowerCase();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            childStatus == 'trial_pending_decision'
                ? 'طفل التجربة بانتظار قرار الاعتماد أو الرفض.'
                : 'لا يمكن استعادة طفل التجربة بعد أرشفته.',
          ),
        ),
      );
      return;
    }

    if (childType == 'temporary') {
      await _openRestoreTemporaryChildSheet(child);
      return;
    }

    await _restorePermanentChild(child);
  }

  Future<void> _restorePermanentChild(Map<String, dynamic> child) async {
    final childId = _cleanText(child['id']);
    if (childId.isEmpty) return;

    try {
      final childRef = _firestore.collection('children').doc(childId);
      final freshChildDoc = await childRef.get();
      final childData = freshChildDoc.data() ?? Map<String, dynamic>.from(child);

      String parentUid = _cleanText(childData['parentUid']);
      String parentUsername =
          _cleanText(childData['parentUsername']).toLowerCase();
      DocumentSnapshot<Map<String, dynamic>>? parentDoc;

      if (parentUid.isNotEmpty) {
        final loadedParentDoc =
            await _firestore.collection('users').doc(parentUid).get();

        if (loadedParentDoc.exists) {
          parentDoc = loadedParentDoc;
        }
      }

      if (parentDoc == null) {
        final selectedParent = await _pickOfficialParentForRestore();

        if (selectedParent == null) return;

        parentDoc = selectedParent;
        parentUid = selectedParent.id;
        parentUsername =
            _cleanText(selectedParent.data()['username']).toLowerCase();
      }

      final parentData = parentDoc.data() ?? <String, dynamic>{};
      final parentIsArchived = parentData['isActive'] == false ||
          _cleanText(parentData['accountStatus']).toLowerCase() == 'archived';

      if (parentIsArchived) {
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  title: const Text('استعادة الطفل وولي الأمر'),
                  content: const Text(
                    'حساب ولي الأمر مرتبط بهذا الطفل وهو مؤرشف. سيتم إعادة تفعيل حساب ولي الأمر مع الطفل.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('استعادة'),
                    ),
                  ],
                ),
              ),
            ) ??
            false;

        if (!confirmed) return;
      }

      final resolvedParentName = _parentDisplayName(parentData);
      final resolvedParentPhone = _parentPhone(parentData);
      final batch = _firestore.batch();

      batch.set(
        childRef,
        {
          'isActive': true,
          'status': 'active',
          'childStatus': 'active',
          'accountStatus': 'active',
          'canReactivate': true,
          'permanentDeleted': false,
          'parentUid': parentUid,
          'parentUsername': parentUsername,
          'parentName': resolvedParentName,
          if (resolvedParentPhone.isNotEmpty) 'parentPhone': resolvedParentPhone,
          'restoredAt': FieldValue.serverTimestamp(),
          'reactivatedAt': FieldValue.serverTimestamp(),
          'archiveReason': FieldValue.delete(),
          'archivedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (parentIsArchived) {
        batch.set(
          parentDoc.reference,
          {
            'isActive': true,
            'accountStatus': 'active',
            'reactivatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        if (parentUsername.isNotEmpty) {
          batch.set(
            _firestore.collection('login_usernames').doc(parentUsername),
            {
              'isActive': true,
              'accountStatus': 'active',
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      await batch.commit();

      final groupId = _cleanText(childData['groupId']);
      if (groupId.isNotEmpty) {
        await _refreshGroupChildrenCount(groupId);
      }

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parentIsArchived
                ? 'تمت استعادة الطفل وتفعيل حساب ولي الأمر'
                : 'تمت استعادة الطفل إلى القائمة النشطة',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر استعادة الطفل: $e')),
      );
    }
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
      _pickOfficialParentForRestore() async {
    final parents = await _loadOfficialParents();

    if (!mounted) return null;

    if (parents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد حساب ولي أمر رسمي مفعّل')),
      );
      return null;
    }

    String selectedParentUid = '';

    return showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('ربط الطفل بولي أمر'),
                content: SizedBox(
                  width: 430,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        selectedParentUid.isEmpty ? null : selectedParentUid,
                    isExpanded: true,
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
                      setLocalState(() {
                        selectedParentUid = value ?? '';
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
                    onPressed: selectedParentUid.isEmpty
                        ? null
                        : () {
                            Navigator.pop(
                              dialogContext,
                              parents.firstWhere(
                                (doc) => doc.id == selectedParentUid,
                              ),
                            );
                          },
                    child: const Text('ربط واستعادة'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openRestoreTemporaryChildSheet(
    Map<String, dynamic> child,
  ) async {
    final groups = await _loadActiveGroups();
    final accessCodes = await _loadActiveTemporaryAccessCodes();

    if (!mounted) return;

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أنشئي مجموعة مفعلة أولًا')),
      );
      return;
    }

    final childId = _cleanText(child['id']);
    final childName = _cleanText(child['name']).isNotEmpty
        ? _cleanText(child['name'])
        : _cleanText(child['childName']);

    final parentNameCtrl = TextEditingController(
      text: _cleanText(child['temporaryParentName']).isNotEmpty
          ? _cleanText(child['temporaryParentName'])
          : _cleanText(child['parentName']),
    );

    final parentPhoneCtrl = TextEditingController(
      text: _cleanText(child['temporaryParentPhone']).isNotEmpty
          ? _cleanText(child['temporaryParentPhone'])
          : _cleanText(child['parentPhone']),
    );

    final hoursCtrl = TextEditingController(text: '1');
    final hourlyRateCtrl = TextEditingController(text: '10');
    final paidCtrl = TextEditingController(text: '0');

    DateTime start = DateTime.now();
    DateTime end = DateTime.now().add(const Duration(days: 1));

    String selectedGroupId = _cleanText(child['groupId']);
    if (!groups.any((doc) => doc.id == selectedGroupId)) {
      selectedGroupId = '';
    }

    final previousSharedAccessCodeId =
        _cleanText(child['sharedAccessCodeId']).isNotEmpty
            ? _cleanText(child['sharedAccessCodeId'])
            : _cleanText(child['temporaryAccessCodeId']);

    bool linkWithSiblings = accessCodes.any(
      (doc) => doc.id == previousSharedAccessCodeId,
    );

    String selectedSharedAccessCodeId =
        linkWithSiblings ? previousSharedAccessCodeId : '';

    bool isSaving = false;

    num parseMoney(String value) {
      return num.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final total =
                  parseMoney(hoursCtrl.text) * parseMoney(hourlyRateCtrl.text);
              final paid = parseMoney(paidCtrl.text);
              final remaining = total - paid < 0 ? 0 : total - paid;

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
                        'استعادة الطفل المؤقت',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'اسم الطفل',
                          prefixIcon: Icon(Icons.child_care_outlined),
                        ),
                        child: Text(childName),
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
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              _cleanText(data['groupName']),
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
                        controller: parentNameCtrl,
                        enabled: !linkWithSiblings,
                        decoration: const InputDecoration(
                          labelText: 'اسم ولي الأمر',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: parentPhoneCtrl,
                        enabled: !linkWithSiblings,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم ولي الأمر',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: linkWithSiblings,
                        title: const Text('ربط بإخوة مسجلين بنفس الكود'),
                        onChanged: (value) {
                          setSheetState(() {
                            linkWithSiblings = value;
                            selectedSharedAccessCodeId = '';

                            if (!value) return;

                            parentNameCtrl.clear();
                            parentPhoneCtrl.clear();
                          });
                        },
                      ),
                      if (linkWithSiblings) ...[
                        DropdownButtonFormField<String>(
                          initialValue: selectedSharedAccessCodeId.isEmpty
                              ? null
                              : selectedSharedAccessCodeId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'كود الإخوة',
                            prefixIcon: Icon(Icons.family_restroom_rounded),
                          ),
                          items: accessCodes.map((doc) {
                            final data = doc.data();
                            final code = _cleanText(data['code']);
                            final parentName = _cleanText(
                              data['parentName'] ??
                                  data['temporaryParentName'],
                            );

                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(
                                '$code • $parentName',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            final selectedId = value ?? '';
                            final selectedDoc = accessCodes.where(
                              (doc) => doc.id == selectedId,
                            );

                            setSheetState(() {
                              selectedSharedAccessCodeId = selectedId;

                              if (selectedDoc.isEmpty) return;

                              final data = selectedDoc.first.data();
                              parentNameCtrl.text = _cleanText(
                                data['parentName'] ??
                                    data['temporaryParentName'],
                              );
                              parentPhoneCtrl.text = _cleanText(
                                data['parentPhone'] ??
                                    data['temporaryParentPhone'],
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: sheetContext,
                                  initialDate: start,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );

                                if (picked == null) return;

                                setSheetState(() {
                                  start = picked;
                                  if (end.isBefore(start)) end = start;
                                });
                              },
                              icon: const Icon(Icons.event_outlined),
                              label: Text(formatOptionalDate(start)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: sheetContext,
                                  initialDate: end,
                                  firstDate: start,
                                  lastDate: DateTime(2035),
                                );

                                if (picked == null) return;

                                setSheetState(() {
                                  end = picked;
                                });
                              },
                              icon:
                                  const Icon(Icons.event_available_outlined),
                              label: Text(formatOptionalDate(end)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: hoursCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'عدد الساعات',
                          prefixIcon: Icon(Icons.access_time_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: hourlyRateCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'سعر الساعة',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: paidCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'المدفوع',
                          prefixIcon: Icon(Icons.done_all_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.14),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الإجمالي: $total شيكل'),
                            Text('المدفوع: $paid شيكل'),
                            Text('المتبقي: $remaining شيكل'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final parentName =
                                      parentNameCtrl.text.trim();
                                  final parentPhone = _normalizePhone(
                                    parentPhoneCtrl.text,
                                  );

                                  if (selectedGroupId.isEmpty) {
                                    await _showValidationError(
                                      'اختاري المجموعة',
                                    );
                                    return;
                                  }

                                  if (parentName.isEmpty ||
                                      !_isValidPalestinianMobile(parentPhone)) {
                                    await _showValidationError(
                                      'تأكدي من اسم ولي الأمر ورقم الجوال',
                                    );
                                    return;
                                  }

                                  if (linkWithSiblings &&
                                      selectedSharedAccessCodeId.isEmpty) {
                                    await _showValidationError(
                                      'اختاري كود الإخوة',
                                    );
                                    return;
                                  }

                                  if (end.isBefore(start)) {
                                    await _showValidationError(
                                      'تاريخ النهاية يجب ألا يسبق تاريخ البداية',
                                    );
                                    return;
                                  }

                                  if (parseMoney(hoursCtrl.text) <= 0) {
                                    await _showValidationError(
                                      'أدخلي عدد ساعات صحيح',
                                    );
                                    return;
                                  }

                                  if (parseMoney(hourlyRateCtrl.text) <= 0) {
                                    await _showValidationError(
                                      'أدخلي سعر ساعة صحيح',
                                    );
                                    return;
                                  }

                                  if (paid < 0) {
                                    await _showValidationError(
                                      'قيمة المدفوع غير صحيحة',
                                    );
                                    return;
                                  }

                                  if (paid > total) {
                                    await _showValidationError(
                                      'قيمة المدفوع لا يمكن أن تتجاوز الإجمالي',
                                    );
                                    return;
                                  }

                                  if (total <= 0) {
                                    await _showValidationError(
                                      'أدخلي فاتورة صحيحة',
                                    );
                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                  });

                                  final saved =
                                      await _restoreTemporaryChildDirect(
                                    child: child,
                                    childId: childId,
                                    childName: childName,
                                    parentName: parentName,
                                    parentPhone: parentPhone,
                                    groupDoc: groups.firstWhere(
                                      (doc) => doc.id == selectedGroupId,
                                    ),
                                    start: DateTime(
                                      start.year,
                                      start.month,
                                      start.day,
                                    ),
                                    end: DateTime(
                                      end.year,
                                      end.month,
                                      end.day,
                                      23,
                                      59,
                                      59,
                                    ),
                                    hours: parseMoney(hoursCtrl.text),
                                    hourlyRate:
                                        parseMoney(hourlyRateCtrl.text),
                                    paid: paid,
                                    total: total,
                                    remaining: remaining,
                                    sharedAccessCodeId:
                                        selectedSharedAccessCodeId,
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
                              : const Icon(Icons.restore_rounded),
                          label: Text(
                            isSaving ? 'جاري الاستعادة...' : 'استعادة',
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

    parentNameCtrl.dispose();
    parentPhoneCtrl.dispose();
    hoursCtrl.dispose();
    hourlyRateCtrl.dispose();
    paidCtrl.dispose();
  }

  Future<bool> _restoreTemporaryChildDirect({
    required Map<String, dynamic> child,
    required String childId,
    required String childName,
    required String parentName,
    required String parentPhone,
    required QueryDocumentSnapshot<Map<String, dynamic>> groupDoc,
    required DateTime start,
    required DateTime end,
    required num hours,
    required num hourlyRate,
    required num paid,
    required num total,
    required num remaining,
    required String sharedAccessCodeId,
  }) async {
    try {
      if (!_groupHasCapacity(groupDoc)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('المجموعة ممتلئة')),
          );
        }
        return false;
      }

      final childRef = _firestore.collection('children').doc(childId);
      final invoiceRef = _firestore.collection('invoices').doc();
      final batch = _firestore.batch();
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final groupData = groupDoc.data();

      final preparedCode = await _prepareDirectTemporaryAccessCode(
        batch: batch,
        childRef: childRef,
        childName: childName,
        childType: 'temporary',
        parentName: parentName,
        parentPhone: parentPhone,
        groupDoc: groupDoc,
        start: start,
        end: end,
        sharedAccessCodeId: sharedAccessCodeId,
        adminUid: adminUid,
      );

      if (preparedCode == null) return false;

      batch.set(
        childRef,
        {
          'childType': 'temporary',
          'enrollmentType': 'temporary',
          'childStatus': 'temporary',
          'status': 'active',
          'accountStatus': 'active',
          'isActive': true,
          'isTemporaryChild': true,
          'isTrialChild': false,
          'isTemporary': true,
          'isBillable': true,
          'excludeFromMonthlyInvoice': true,
          'canReactivate': true,
          'permanentDeleted': false,
          'parentUid': '',
          'parentUsername': '',
          'parentName': preparedCode.parentName,
          'parentPhone': preparedCode.parentPhone,
          'temporaryParentName': preparedCode.parentName,
          'temporaryParentPhone': preparedCode.parentPhone,
          'groupId': groupDoc.id,
          'groupName': _cleanText(groupData['groupName']),
          'assignedStaffUid': _cleanText(groupData['assignedStaffUid']),
          'assignedStaffName': _cleanText(groupData['assignedStaffName']),
          'assignedStaffUsername':
              _cleanText(groupData['assignedStaffUsername']),
          'temporaryAccessCodeId': preparedCode.id,
          'sharedAccessCodeId': preparedCode.id,
          'usesSharedAccessCode': preparedCode.usesSharedAccessCode,
          'temporaryAccessCode': preparedCode.code,
          'temporaryAccessStartAt': Timestamp.fromDate(start),
          'temporaryAccessEndAt': Timestamp.fromDate(end),
          'temporaryStartDate': Timestamp.fromDate(start),
          'temporaryEndDate': Timestamp.fromDate(end),
          'temporaryFee': total,
          'temporaryBillingType': 'hourly',
          'temporaryBillingTypeLabel': 'حسب الساعات',
          'temporaryHoursCount': hours,
          'temporaryHourlyRate': hourlyRate,
          'temporaryPaidAmount': paid,
          'temporaryRemainingAmount': remaining,
          'restoredAt': FieldValue.serverTimestamp(),
          'reactivatedAt': FieldValue.serverTimestamp(),
          'archiveReason': FieldValue.delete(),
          'archivedAt': FieldValue.delete(),
          'expiredAt': FieldValue.delete(),
          'updatedByUid': adminUid,
          'updatedByRole': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final status = paid <= 0
          ? 'غير مدفوعة'
          : paid >= total
              ? 'مدفوعة'
              : 'مدفوعة جزئياً';

      batch.set(invoiceRef, {
        'id': invoiceRef.id,
        'invoiceId': invoiceRef.id,
        'title': 'فاتورة الطفل المؤقت',
        'childId': childRef.id,
        'childName': childName,
        'childType': 'temporary',
        'parentUid': '',
        'parentUsername': '',
        'parentName': preparedCode.parentName,
        'parentPhone': preparedCode.parentPhone,
        'temporaryParentName': preparedCode.parentName,
        'temporaryParentPhone': preparedCode.parentPhone,
        'groupId': groupDoc.id,
        'groupName': _cleanText(groupData['groupName']),
        'temporaryAccessCodeId': preparedCode.id,
        'sharedAccessCodeId': preparedCode.id,
        'billingType': 'hourly',
        'billingTypeLabel': 'حسب الساعات',
        'hoursCount': hours,
        'hourlyRate': hourlyRate,
        'baseAmount': total,
        'finalAmount': total,
        'totalAmount': total,
        'paidAmount': paid,
        'remainingAmount': remaining,
        'status': status,
        'invoiceDate': FieldValue.serverTimestamp(),
        'accessStartAt': Timestamp.fromDate(start),
        'accessEndAt': Timestamp.fromDate(end),
        'createdByUid': adminUid,
        'createdByRole': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      final groupId = _cleanText(groupData['groupId']).isNotEmpty
          ? _cleanText(groupData['groupId'])
          : groupDoc.id;

      await _refreshGroupChildrenCount(groupId);

      if (!mounted) return true;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت استعادة الطفل المؤقت')),
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر استعادة الطفل المؤقت: $e')),
      );

      return false;
    }
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
  final accessCode = (child['temporaryAccessCode'] ?? '').toString().trim();

  final parts = <String>[
    if (start.isNotEmpty || end.isNotEmpty)
      'الفترة: ${start.isEmpty ? '-' : start} إلى ${end.isEmpty ? '-' : end}',
    if (fee != 0)
      'الرسوم: $fee شيكل${billingLabel.isNotEmpty ? ' - $billingLabel' : ''}',
    if (accessCode.isNotEmpty) 'كود الدخول: $accessCode',
  ];

  return parts.join(' | ');
}


  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadFreshChildDoc(
    Map<String, dynamic> child,
  ) async {
    final childId = _cleanText(child['id']);
    if (childId.isEmpty) return null;

    final doc = await _firestore.collection('children').doc(childId).get();
    if (!doc.exists) return null;

    return doc;
  }

  Future<void> _openConvertTemporaryChildSheet(
    Map<String, dynamic> child,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تحويل الطفل إلى دائم'),
              content: const Text(
                'سيتم تعطيل كود الدخول المؤقت وربط الطفل بحساب ولي أمر رسمي مع الاحتفاظ بسجلاته السابقة.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('متابعة'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    final childDoc = await _loadFreshChildDoc(child);
    if (!mounted || childDoc == null) return;

    final childData = childDoc.data() ?? <String, dynamic>{};

    if (!_isTemporaryChildData(childData) || _isTrialChildData(childData)) {
      return;
    }

    final parents = await _loadOfficialParents();

    if (!mounted) return;

    if (parents.isEmpty) {
      await _showValidationError('لا يوجد حساب ولي أمر رسمي مفعّل');
      return;
    }

    String selectedParentUid = '';
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
                        'ربط الطفل بولي أمر رسمي',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue:
                            selectedParentUid.isEmpty ? null : selectedParentUid,
                        isExpanded: true,
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
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (selectedParentUid.isEmpty) {
                                    await _showValidationError(
                                      'اختاري حساب ولي الأمر الرسمي',
                                    );
                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                  });

                                  final saved =
                                      await _convertTemporaryChildToPermanent(
                                    childDoc: childDoc,
                                    parentDoc: parents.firstWhere(
                                      (doc) => doc.id == selectedParentUid,
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
                              : const Icon(Icons.sync_alt_rounded),
                          label: Text(
                            isSaving
                                ? 'جاري التحويل...'
                                : 'تحويل إلى طفل دائم',
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
  }

  Future<bool> _convertTemporaryChildToPermanent({
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
    required QueryDocumentSnapshot<Map<String, dynamic>> parentDoc,
  }) async {
    final childData = childDoc.data() ?? <String, dynamic>{};

    if (!_isTemporaryChildData(childData) || _isTrialChildData(childData)) {
      return false;
    }

    try {
      final batch = _firestore.batch();
      final parentData = parentDoc.data();
      final childId = childDoc.id;
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final previousAccessCodeId =
          _cleanText(childData['sharedAccessCodeId']).isNotEmpty
              ? _cleanText(childData['sharedAccessCodeId'])
              : _cleanText(childData['temporaryAccessCodeId']);
      final previousTemporaryParentName = _cleanText(
        childData['temporaryParentName'] ?? childData['parentName'],
      );
      final previousTemporaryParentPhone = _cleanText(
        childData['temporaryParentPhone'] ?? childData['parentPhone'],
      );

      await _updateAccessCodesAfterChildRemoval(
        batch: batch,
        childId: childId,
        childData: childData,
        archiveReason: 'temporary_converted_to_permanent',
        automated: false,
      );

      final devices = await _firestore
          .collection('temporary_parent_devices')
          .where('childId', isEqualTo: childId)
          .get();

      for (final deviceDoc in devices.docs) {
        batch.set(
          deviceDoc.reference,
          {
            'isActive': false,
            'accountStatus': 'archived',
            'archiveReason': 'temporary_converted_to_permanent',
            'archivedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      batch.set(
        childDoc.reference,
        {
          'childType': 'permanent',
          'enrollmentType': 'permanent',
          'childStatus': 'active',
          'status': 'active',
          'accountStatus': 'active',
          'isTemporaryChild': false,
          'isTrialChild': false,
          'isTemporary': false,
          'isActive': true,
          'isBillable': true,
          'excludeFromMonthlyInvoice': false,
          'canReactivate': true,
          'permanentDeleted': false,
          'convertedFromChildType': 'temporary',
          'convertedToPermanentAt': FieldValue.serverTimestamp(),
          'parentUid': parentDoc.id,
          'parentUsername': _cleanText(parentData['username']).toLowerCase(),
          'parentName': _parentDisplayName(parentData),
          'parentPhone': _parentPhone(parentData),
          if (previousTemporaryParentName.isNotEmpty)
            'previousTemporaryParentName': previousTemporaryParentName,
          if (previousTemporaryParentPhone.isNotEmpty)
            'previousTemporaryParentPhone': previousTemporaryParentPhone,
          if (previousAccessCodeId.isNotEmpty)
            'previousTemporaryAccessCodeId': previousAccessCodeId,
          'temporaryParentName': FieldValue.delete(),
          'temporaryParentPhone': FieldValue.delete(),
          'temporaryAccessCodeId': FieldValue.delete(),
          'sharedAccessCodeId': FieldValue.delete(),
          'temporaryAccessCode': FieldValue.delete(),
          'temporaryAccessStartAt': FieldValue.delete(),
          'temporaryAccessEndAt': FieldValue.delete(),
          'usesSharedAccessCode': false,
          'archiveReason': FieldValue.delete(),
          'archivedAt': FieldValue.delete(),
          'expiredAt': FieldValue.delete(),
          'updatedByUid': adminUid,
          'updatedByRole': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      final groupId = _cleanText(childData['groupId']);
      if (groupId.isNotEmpty) {
        await _refreshGroupChildrenCount(groupId);
      }

      if (!mounted) return true;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحويل الطفل المؤقت إلى طفل دائم')),
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحويل الطفل المؤقت: $e')),
      );

      return false;
    }
  }

  Future<void> _openApproveTrialChildSheet(
    Map<String, dynamic> child,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('اعتماد طفل التجربة'),
              content: const Text(
                'سيتم تحويل طفل التجربة إلى طفل دائم وربطه بحساب ولي أمر رسمي مع الاحتفاظ بسجلاته السابقة.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('متابعة'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    final childDoc = await _loadFreshChildDoc(child);
    if (!mounted || childDoc == null) return;

    final childData = childDoc.data() ?? <String, dynamic>{};

    if (!_isTrialChildData(childData) ||
        _cleanText(childData['childStatus']).toLowerCase() !=
            'trial_pending_decision') {
      return;
    }

    final parents = await _loadOfficialParents();

    if (!mounted) return;

    if (parents.isEmpty) {
      await _showValidationError('لا يوجد حساب ولي أمر رسمي مفعّل');
      return;
    }

    String selectedParentUid = '';
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
                        'اعتماد طفل التجربة',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue:
                            selectedParentUid.isEmpty ? null : selectedParentUid,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'حساب ولي الأمر الرسمي',
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
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (selectedParentUid.isEmpty) {
                                    await _showValidationError(
                                      'اختاري حساب ولي الأمر الرسمي',
                                    );
                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                  });

                                  final saved = await _approveTrialChild(
                                    childDoc: childDoc,
                                    parentDoc: parents.firstWhere(
                                      (doc) => doc.id == selectedParentUid,
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
                              : const Icon(Icons.verified_rounded),
                          label: Text(
                            isSaving ? 'جاري الاعتماد...' : 'اعتماد كطفل دائم',
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
  }

  Future<bool> _approveTrialChild({
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
    required QueryDocumentSnapshot<Map<String, dynamic>> parentDoc,
  }) async {
    final childData = childDoc.data() ?? <String, dynamic>{};

    if (!_isTrialChildData(childData)) return false;

    try {
      final batch = _firestore.batch();
      final childId = childDoc.id;
      final parentData = parentDoc.data();
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final previousAccessCodeId =
          _cleanText(childData['sharedAccessCodeId']).isNotEmpty
              ? _cleanText(childData['sharedAccessCodeId'])
              : _cleanText(childData['temporaryAccessCodeId']);

      await _updateAccessCodesAfterChildRemoval(
        batch: batch,
        childId: childId,
        childData: childData,
        archiveReason: 'trial_approved',
        automated: false,
      );

      final devices = await _firestore
          .collection('temporary_parent_devices')
          .where('childId', isEqualTo: childId)
          .get();

      for (final deviceDoc in devices.docs) {
        batch.set(
          deviceDoc.reference,
          {
            'isActive': false,
            'accountStatus': 'archived',
            'archiveReason': 'trial_approved',
            'archivedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      batch.set(
        childDoc.reference,
        {
          'childType': 'permanent',
          'enrollmentType': 'permanent',
          'childStatus': 'active',
          'status': 'active',
          'accountStatus': 'active',
          'isTemporaryChild': false,
          'isTrialChild': false,
          'isTemporary': false,
          'isActive': true,
          'isBillable': true,
          'excludeFromMonthlyInvoice': false,
          'canReactivate': true,
          'permanentDeleted': false,
          'trialDecision': 'approved',
          'trialDecisionAt': FieldValue.serverTimestamp(),
          'trialApprovedAt': FieldValue.serverTimestamp(),
          'parentUid': parentDoc.id,
          'parentUsername': _cleanText(parentData['username']).toLowerCase(),
          'parentName': _parentDisplayName(parentData),
          'parentPhone': _parentPhone(parentData),
          if (previousAccessCodeId.isNotEmpty)
            'previousTemporaryAccessCodeId': previousAccessCodeId,
          'temporaryParentName': FieldValue.delete(),
          'temporaryParentPhone': FieldValue.delete(),
          'temporaryAccessCodeId': FieldValue.delete(),
          'sharedAccessCodeId': FieldValue.delete(),
          'temporaryAccessCode': FieldValue.delete(),
          'temporaryAccessStartAt': FieldValue.delete(),
          'temporaryAccessEndAt': FieldValue.delete(),
          'usesSharedAccessCode': false,
          'archiveReason': FieldValue.delete(),
          'archivedAt': FieldValue.delete(),
          'expiredAt': FieldValue.delete(),
          'updatedByUid': adminUid,
          'updatedByRole': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      final groupId = _cleanText(childData['groupId']);
      if (groupId.isNotEmpty) {
        await _refreshGroupChildrenCount(groupId);
      }

      if (!mounted) return true;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم اعتماد الطفل كطفل دائم')),
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر اعتماد طفل التجربة: $e')),
      );

      return false;
    }
  }

  Future<void> _rejectTrialChild(
    Map<String, dynamic> child,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('رفض طفل التجربة'),
              content: const Text('رفض طفل التجربة وأرشفته نهائيًا؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('رفض وأرشفة'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    final childDoc = await _loadFreshChildDoc(child);
    if (!mounted || childDoc == null) return;

    final childData = childDoc.data() ?? <String, dynamic>{};

    if (!_isTrialChildData(childData)) return;

    try {
      final batch = _firestore.batch();
      final childId = childDoc.id;

      await _updateAccessCodesAfterChildRemoval(
        batch: batch,
        childId: childId,
        childData: childData,
        archiveReason: 'trial_not_approved',
        automated: false,
      );

      final devices = await _firestore
          .collection('temporary_parent_devices')
          .where('childId', isEqualTo: childId)
          .get();

      for (final deviceDoc in devices.docs) {
        batch.set(
          deviceDoc.reference,
          {
            'isActive': false,
            'accountStatus': 'archived',
            'archiveReason': 'trial_not_approved',
            'archivedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      batch.set(
        childDoc.reference,
        {
          'childStatus': 'rejected_after_trial',
          'status': 'archived',
          'accountStatus': 'archived',
          'isActive': false,
          'isBillable': false,
          'excludeFromMonthlyInvoice': true,
          'canReactivate': false,
          'trialDecision': 'rejected',
          'trialDecisionAt': FieldValue.serverTimestamp(),
          'archiveReason': 'trial_not_approved',
          'archivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      final groupId = _cleanText(childData['groupId']);
      if (groupId.isNotEmpty) {
        await _refreshGroupChildrenCount(groupId);
      }

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض طفل التجربة وأرشفته')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر رفض طفل التجربة: $e')),
      );
    }
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
    final resolvedChildType = resolveChildType(child);
    final isArchivedTrial = !isActive && resolvedChildType == 'trial';
    final isTrialPendingDecision =
        _cleanText(child['childStatus']).toLowerCase() ==
            'trial_pending_decision';

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
          if (isActive &&
              resolvedChildType == 'temporary' &&
              !_isTrialChildData(child)) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openConvertTemporaryChildSheet(child),
                icon: const Icon(Icons.sync_alt_rounded),
                label: const Text('تحويل إلى طفل دائم'),
              ),
            ),
          ],
          if (isTrialPendingDecision) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openApproveTrialChildSheet(child),
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text('اعتماد كطفل دائم'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectTrialChild(child),
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('رفض وأرشفة'),
                  ),
                ),
              ],
            ),
          ],
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
              if (!isArchivedTrial) ...[
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
                      isActive
                          ? Icons.archive_outlined
                          : Icons.restore_outlined,
                    ),
                    label: Text(
                      isActive ? 'أرشفة' : 'استعادة',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
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


  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '').trim();
  }

  bool _isValidPalestinianMobile(String phone) {
    final clean = _normalizePhone(phone);
    return RegExp(r'^(059|056|052)\d{7}$').hasMatch(clean) &&
        !RegExp(r'^(\d)\1+$').hasMatch(clean);
  }

  String _generateTemporaryAccessCode() {
    final random = Random.secure();
    return 'TMP-${100000 + random.nextInt(900000)}';
  }

  String? _newChildProfileValidationError(_NewChildProfileDraft profile) {
    if (profile.hasChronicDiseases &&
        profile.chronicDiseasesCtrl.text.trim().isEmpty) {
      return 'أدخلي تفاصيل الأمراض المزمنة';
    }

    if (profile.hasAllergies && profile.allergiesCtrl.text.trim().isEmpty) {
      return 'أدخلي تفاصيل الحساسية';
    }

    if (profile.takesMedications &&
        profile.medicationsCtrl.text.trim().isEmpty) {
      return 'أدخلي تفاصيل الأدوية';
    }

    if (profile.hasDietaryRestrictions &&
        profile.dietaryRestrictionsCtrl.text.trim().isEmpty) {
      return 'أدخلي تفاصيل القيود الغذائية';
    }

    if (profile.hasSpecialNeeds &&
        profile.specialNeedsCtrl.text.trim().isEmpty) {
      return 'أدخلي تفاصيل الاحتياجات الخاصة';
    }

    if (profile.pickupContacts.isEmpty) {
      return 'أضيفي شخصًا مخولًا بالاستلام';
    }

    for (final pickup in profile.pickupContacts) {
      if (pickup.nameCtrl.text.trim().isEmpty ||
          pickup.relationCtrl.text.trim().isEmpty ||
          pickup.phoneCtrl.text.trim().isEmpty) {
        return 'تأكدي من تعبئة بيانات الأشخاص المخولين بالاستلام';
      }

      if (!_isValidPalestinianMobile(pickup.phoneCtrl.text)) {
        return 'رقم المخول بالاستلام غير صالح';
      }
    }

    return null;
  }

  Future<void> _showValidationError(String message) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('راجعي البيانات'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تم'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTemporaryAccessCreatedDialog({
    required String childName,
    required String accessCode,
    required DateTime accessEndAt,
  }) async {
    if (!mounted) return;

    final day = accessEndAt.day.toString().padLeft(2, '0');
    final month = accessEndAt.month.toString().padLeft(2, '0');
    final year = accessEndAt.year.toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تم إنشاء الوصول المؤقت'),
          content: Text(
            'الطفل: $childName\n'
            'الكود: $accessCode\n'
            'الصلاحية: $day-$month-$year',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تم'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewChildProfileFields({
    required _NewChildProfileDraft profile,
    required StateSetter setSheetState,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Text(
          'البيانات الصحية',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: profile.hasChronicDiseases,
          title: const Text('هل لدى الطفل أمراض مزمنة؟'),
          onChanged: (value) {
            setSheetState(() {
              profile.hasChronicDiseases = value;
              if (!value) profile.chronicDiseasesCtrl.clear();
            });
          },
        ),
        if (profile.hasChronicDiseases) ...[
          TextField(
            controller: profile.chronicDiseasesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'تفاصيل الأمراض المزمنة',
              prefixIcon: Icon(Icons.monitor_heart_outlined),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: profile.hasAllergies,
          title: const Text('هل لدى الطفل حساسية؟'),
          onChanged: (value) {
            setSheetState(() {
              profile.hasAllergies = value;
              if (!value) profile.allergiesCtrl.clear();
            });
          },
        ),
        if (profile.hasAllergies) ...[
          TextField(
            controller: profile.allergiesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'تفاصيل الحساسية',
              prefixIcon: Icon(Icons.warning_amber_rounded),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: profile.takesMedications,
          title: const Text('هل يتناول الطفل أدوية بشكل مستمر؟'),
          onChanged: (value) {
            setSheetState(() {
              profile.takesMedications = value;
              if (!value) profile.medicationsCtrl.clear();
            });
          },
        ),
        if (profile.takesMedications) ...[
          TextField(
            controller: profile.medicationsCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'تفاصيل الأدوية',
              prefixIcon: Icon(Icons.medication_outlined),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: profile.hasDietaryRestrictions,
          title: const Text('هل لدى الطفل قيود غذائية؟'),
          onChanged: (value) {
            setSheetState(() {
              profile.hasDietaryRestrictions = value;
              if (!value) profile.dietaryRestrictionsCtrl.clear();
            });
          },
        ),
        if (profile.hasDietaryRestrictions) ...[
          TextField(
            controller: profile.dietaryRestrictionsCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'تفاصيل القيود الغذائية',
              prefixIcon: Icon(Icons.restaurant_menu_rounded),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: profile.hasSpecialNeeds,
          title: const Text('هل لدى الطفل احتياجات خاصة؟'),
          onChanged: (value) {
            setSheetState(() {
              profile.hasSpecialNeeds = value;
              if (!value) profile.specialNeedsCtrl.clear();
            });
          },
        ),
        if (profile.hasSpecialNeeds) ...[
          TextField(
            controller: profile.specialNeedsCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'تفاصيل الاحتياجات الخاصة',
              prefixIcon: Icon(Icons.accessible_rounded),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: profile.healthNotesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'ملاحظات صحية عامة',
            prefixIcon: Icon(Icons.health_and_safety_rounded),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'المخولون بالاستلام',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        ...List.generate(profile.pickupContacts.length, (index) {
          final pickup = profile.pickupContacts[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'الشخص ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (profile.pickupContacts.length > 1)
                      IconButton(
                        onPressed: () {
                          setSheetState(() {
                            pickup.dispose();
                            profile.pickupContacts.removeAt(index);
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
                TextField(
                  controller: pickup.nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الاسم',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pickup.relationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'صلة القرابة',
                    prefixIcon: Icon(Icons.family_restroom_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pickup.phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الجوال',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () {
            setSheetState(() {
              profile.pickupContacts.add(_PickupContactEditor());
            });
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة شخص مخول آخر'),
        ),
      ],
    );
  }

  bool _groupHasCapacity(
    QueryDocumentSnapshot<Map<String, dynamic>> groupDoc,
  ) {
    final data = groupDoc.data();
    final currentChildren =
        (data['currentChildrenCount'] as num?)?.toInt() ?? 0;
    final maxChildren = (data['maxChildren'] as num?)?.toInt() ?? 12;

    return maxChildren <= 0 || currentChildren < maxChildren;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadActiveTemporaryAccessCodes() async {
    final snapshot = await _firestore
        .collection('temporary_access_codes')
        .where('isActive', isEqualTo: true)
        .get();

    final now = DateTime.now();

    final docs = snapshot.docs.where((doc) {
      final data = doc.data();
      final end = _toDateTime(data['accessEndAt']);
      return end == null || end.isAfter(now);
    }).toList();

    docs.sort((a, b) {
      final aName = _cleanText(
        a.data()['parentName'] ?? a.data()['temporaryParentName'],
      );
      final bName = _cleanText(
        b.data()['parentName'] ?? b.data()['temporaryParentName'],
      );
      return aName.compareTo(bName);
    });

    return docs;
  }

  Future<_PreparedTemporaryAccessCode?> _prepareDirectTemporaryAccessCode({
    required WriteBatch batch,
    required DocumentReference<Map<String, dynamic>> childRef,
    required String childName,
    required String childType,
    required String parentName,
    required String parentPhone,
    required QueryDocumentSnapshot<Map<String, dynamic>> groupDoc,
    required DateTime start,
    required DateTime end,
    required String sharedAccessCodeId,
    required String adminUid,
  }) async {
    final groupData = groupDoc.data();

    if (sharedAccessCodeId.trim().isEmpty) {
      final codeRef = _firestore.collection('temporary_access_codes').doc();
      final code = _generateTemporaryAccessCode();

      batch.set(codeRef, {
        'id': codeRef.id,
        'code': code,
        'childId': childRef.id,
        'childName': childName,
        'childIds': [childRef.id],
        'childNames': [childName],
        'childTypes': [childType],
        'groupId': groupDoc.id,
        'groupName': _cleanText(groupData['groupName']),
        'groupIds': [groupDoc.id],
        'groupNames': [_cleanText(groupData['groupName'])],
        'parentUid': '',
        'parentUsername': '',
        'parentName': parentName,
        'parentPhone': parentPhone,
        'temporaryParentName': parentName,
        'temporaryParentPhone': parentPhone,
        'childType': childType,
        'childStatus': childType,
        'accessStartAt': Timestamp.fromDate(start),
        'accessEndAt': Timestamp.fromDate(end),
        if (childType == 'trial') 'trialStartAt': Timestamp.fromDate(start),
        if (childType == 'trial') 'trialEndAt': Timestamp.fromDate(end),
        'hasMultipleChildren': false,
        'usesSharedAccessCode': false,
        'isActive': true,
        'status': 'active',
        'accountStatus': 'active',
        'canReactivate': childType != 'trial',
        'permanentDeleted': false,
        'createdByUid': adminUid,
        'createdByRole': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return _PreparedTemporaryAccessCode(
        id: codeRef.id,
        code: code,
        parentName: parentName,
        parentPhone: parentPhone,
        usesSharedAccessCode: false,
      );
    }

    final codeRef = _firestore
        .collection('temporary_access_codes')
        .doc(sharedAccessCodeId);
    final codeDoc = await codeRef.get();
    final codeData = codeDoc.data();

    if (!codeDoc.exists || codeData == null || codeData['isActive'] != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('كود الإخوة غير متاح')),
        );
      }
      return null;
    }

    final code = _cleanText(codeData['code']);
    if (code.isEmpty) return null;

    final linkedChildIds = <String>{
      ..._readStringList(codeData['childIds']),
      _cleanText(codeData['childId']),
      childRef.id,
    }..removeWhere((value) => value.isEmpty);

    final linkedChildNames = <String>{
      ..._readStringList(codeData['childNames']),
      _cleanText(codeData['childName']),
      childName,
    }..removeWhere((value) => value.isEmpty);

    final linkedChildTypes = <String>{
      ..._readStringList(codeData['childTypes']),
      _cleanText(codeData['childType']),
      childType,
    }..removeWhere((value) => value.isEmpty);

    final groupIds = <String>{
      ..._readStringList(codeData['groupIds']),
      _cleanText(codeData['groupId']),
      groupDoc.id,
    }..removeWhere((value) => value.isEmpty);

    final groupNames = <String>{
      ..._readStringList(codeData['groupNames']),
      _cleanText(codeData['groupName']),
      _cleanText(groupData['groupName']),
    }..removeWhere((value) => value.isEmpty);

    final oldStart = _toDateTime(codeData['accessStartAt']);
    final oldEnd = _toDateTime(codeData['accessEndAt']);
    final mergedStart =
        oldStart != null && oldStart.isBefore(start) ? oldStart : start;
    final mergedEnd = oldEnd != null && oldEnd.isAfter(end) ? oldEnd : end;

    batch.set(
      codeRef,
      {
        'childIds': linkedChildIds.toList(),
        'childNames': linkedChildNames.toList(),
        'childTypes': linkedChildTypes.toList(),
        'groupIds': groupIds.toList(),
        'groupNames': groupNames.toList(),
        'accessStartAt': Timestamp.fromDate(mergedStart),
        'accessEndAt': Timestamp.fromDate(mergedEnd),
        'hasMultipleChildren': linkedChildIds.length > 1,
        'usesSharedAccessCode': linkedChildIds.length > 1,
        'isActive': true,
        'status': 'active',
        'accountStatus': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    for (final siblingId in linkedChildIds) {
      batch.set(
        _firestore.collection('children').doc(siblingId),
        {
          'sharedAccessCodeId': codeRef.id,
          'usesSharedAccessCode': linkedChildIds.length > 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    final savedParentName = _cleanText(
      codeData['parentName'] ?? codeData['temporaryParentName'],
    );
    final savedParentPhone = _cleanText(
      codeData['parentPhone'] ?? codeData['temporaryParentPhone'],
    );

    return _PreparedTemporaryAccessCode(
      id: codeRef.id,
      code: code,
      parentName: savedParentName.isEmpty ? parentName : savedParentName,
      parentPhone: savedParentPhone.isEmpty ? parentPhone : savedParentPhone,
      usesSharedAccessCode: linkedChildIds.length > 1,
    );
  }

  Future<void> _openAddTemporaryOrTrialChildSheet({
    required String childType,
  }) async {
    final groups = await _loadActiveGroups();
    final accessCodes = await _loadActiveTemporaryAccessCodes();

    if (!mounted) return;

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أنشئي مجموعة مفعلة أولًا')),
      );
      return;
    }

    final isTrial = childType == 'trial';
    final childNameCtrl = TextEditingController();
    final parentNameCtrl = TextEditingController();
    final parentPhoneCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final hoursCtrl = TextEditingController(text: '1');
    final hourlyRateCtrl = TextEditingController(text: '10');
    final paidCtrl = TextEditingController(text: '0');
    final profile = _NewChildProfileDraft();

    String selectedGroupId = '';
    String selectedGender = 'female';
    String selectedSharedAccessCodeId = '';
    bool linkWithSiblings = false;
    bool isSaving = false;
    DateTime start = DateTime.now();
    DateTime end = DateTime.now().add(const Duration(days: 1));

    num parseMoney(String value) {
      return num.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
    }

    DateTime trialEnd() {
      return DateTime(start.year, start.month, start.day + 2, 23, 59, 59);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final effectiveEnd = isTrial
                  ? trialEnd()
                  : DateTime(end.year, end.month, end.day, 23, 59, 59);
              final total = isTrial
                  ? 0
                  : parseMoney(hoursCtrl.text) * parseMoney(hourlyRateCtrl.text);
              final paid = isTrial ? 0 : parseMoney(paidCtrl.text);
              final remaining = total - paid < 0 ? 0 : total - paid;

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
                        isTrial ? 'إضافة طفل تجربة' : 'إضافة طفل مؤقت',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue:
                            selectedGroupId.isEmpty ? null : selectedGroupId,
                        decoration: const InputDecoration(
                          labelText: 'المجموعة',
                          prefixIcon: Icon(Icons.groups_2_outlined),
                        ),
                        items: groups.map((doc) {
                          final data = doc.data();
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              '${_cleanText(data['groupName'])} • ${_cleanText(data['assignedStaffName'])}',
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
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: linkWithSiblings,
                        title: const Text('ربط بإخوة مسجلين بنفس الكود'),
                        onChanged: (value) {
                          setSheetState(() {
                            linkWithSiblings = value;
                            selectedSharedAccessCodeId = '';
                            if (value) {
                              parentNameCtrl.clear();
                              parentPhoneCtrl.clear();
                            }
                          });
                        },
                      ),
                      if (linkWithSiblings) ...[
                        DropdownButtonFormField<String>(
                          initialValue: selectedSharedAccessCodeId.isEmpty
                              ? null
                              : selectedSharedAccessCodeId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'كود الإخوة',
                            prefixIcon: Icon(Icons.family_restroom_rounded),
                          ),
                          items: accessCodes.map((doc) {
                            final data = doc.data();
                            final parent = _cleanText(
                              data['parentName'] ??
                                  data['temporaryParentName'],
                            );
                            final names = _readStringList(data['childNames']);
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(
                                '$parent • ${names.join('، ')}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setSheetState(() {
                              selectedSharedAccessCodeId = value ?? '';
                              if (selectedSharedAccessCodeId.isNotEmpty) {
                                final data = accessCodes
                                    .firstWhere(
                                      (doc) =>
                                          doc.id == selectedSharedAccessCodeId,
                                    )
                                    .data();
                                parentNameCtrl.text = _cleanText(
                                  data['parentName'] ??
                                      data['temporaryParentName'],
                                );
                                parentPhoneCtrl.text = _cleanText(
                                  data['parentPhone'] ??
                                      data['temporaryParentPhone'],
                                );
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: parentNameCtrl,
                        enabled: !linkWithSiblings,
                        decoration: const InputDecoration(
                          labelText: 'اسم ولي الأمر',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: parentPhoneCtrl,
                        enabled: !linkWithSiblings,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم ولي الأمر',
                          prefixIcon: Icon(Icons.phone_outlined),
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
                          DropdownMenuItem(value: 'female', child: Text('أنثى')),
                          DropdownMenuItem(value: 'male', child: Text('ذكر')),
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
                            initialDate: profile.birthDate,
                            firstDate: DateTime(2015),
                            lastDate: DateTime.now(),
                          );
                          if (picked == null) return;
                          setSheetState(() {
                            profile.birthDate = picked;
                          });
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تاريخ الميلاد',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(
                            '${profile.birthDate.year}/${profile.birthDate.month}/${profile.birthDate.day}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: sheetContext,
                                  initialDate: start,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked == null) return;
                                setSheetState(() {
                                  start = picked;
                                  if (!isTrial && end.isBefore(start)) {
                                    end = start;
                                  }
                                });
                              },
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                '${start.year}/${start.month}/${start.day}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isTrial
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                        context: sheetContext,
                                        initialDate: end,
                                        firstDate: start,
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked == null) return;
                                      setSheetState(() {
                                        end = picked;
                                      });
                                    },
                              icon: const Icon(Icons.event_available_outlined),
                              label: Text(
                                '${effectiveEnd.year}/${effectiveEnd.month}/${effectiveEnd.day}',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isTrial) ...[
                        const SizedBox(height: 18),
                        const Text(
                          'الفاتورة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: hoursCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'عدد الساعات',
                            prefixIcon: Icon(Icons.access_time_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: hourlyRateCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'سعر الساعة',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: paidCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'المدفوع',
                            prefixIcon: Icon(Icons.done_all_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('الإجمالي: $total شيكل'),
                        Text('المتبقي: $remaining شيكل'),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      _buildNewChildProfileFields(
                        profile: profile,
                        setSheetState: setSheetState,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final childName = childNameCtrl.text.trim();
                                  final parentName = parentNameCtrl.text.trim();
                                  final parentPhone =
                                      _normalizePhone(parentPhoneCtrl.text);

                                  if (selectedGroupId.isEmpty) {
                                    await _showValidationError(
                                      'اختاري المجموعة',
                                    );
                                    return;
                                  }

                                  if (childName.isEmpty) {
                                    await _showValidationError(
                                      'اكتبي اسم الطفل',
                                    );
                                    return;
                                  }

                                  if (parentName.isEmpty ||
                                      !_isValidPalestinianMobile(parentPhone)) {
                                    await _showValidationError(
                                      'تأكدي من اسم ولي الأمر ورقم الجوال',
                                    );
                                    return;
                                  }

                                  if (linkWithSiblings &&
                                      selectedSharedAccessCodeId.isEmpty) {
                                    await _showValidationError(
                                      'اختاري كود الإخوة',
                                    );
                                    return;
                                  }

                                  if (!isTrial && effectiveEnd.isBefore(start)) {
                                    await _showValidationError(
                                      'تاريخ النهاية يجب ألا يسبق تاريخ البداية',
                                    );
                                    return;
                                  }

                                  if (!isTrial && parseMoney(hoursCtrl.text) <= 0) {
                                    await _showValidationError(
                                      'أدخلي عدد ساعات صحيح',
                                    );
                                    return;
                                  }

                                  if (!isTrial &&
                                      parseMoney(hourlyRateCtrl.text) <= 0) {
                                    await _showValidationError(
                                      'أدخلي سعر ساعة صحيح',
                                    );
                                    return;
                                  }

                                  if (!isTrial && paid < 0) {
                                    await _showValidationError(
                                      'قيمة المدفوع غير صحيحة',
                                    );
                                    return;
                                  }

                                  if (!isTrial && paid > total) {
                                    await _showValidationError(
                                      'قيمة المدفوع لا يمكن أن تتجاوز الإجمالي',
                                    );
                                    return;
                                  }

                                  if (!isTrial && total <= 0) {
                                    await _showValidationError(
                                      'أدخلي فاتورة صحيحة',
                                    );
                                    return;
                                  }

                                  final profileError =
                                      _newChildProfileValidationError(profile);

                                  if (profileError != null) {
                                    await _showValidationError(profileError);
                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                  });

                                  final saved =
                                      await _saveTemporaryOrTrialChildDirect(
                                    childType: childType,
                                    childName: childName,
                                    parentName: parentName,
                                    parentPhone: parentPhone,
                                    gender: selectedGender,
                                    profile: profile,
                                    note: noteCtrl.text.trim(),
                                    start: DateTime(
                                      start.year,
                                      start.month,
                                      start.day,
                                    ),
                                    end: effectiveEnd,
                                    hours: parseMoney(hoursCtrl.text),
                                    hourlyRate:
                                        parseMoney(hourlyRateCtrl.text),
                                    paid: paid,
                                    total: total,
                                    remaining: remaining,
                                    sharedAccessCodeId:
                                        selectedSharedAccessCodeId,
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
                          label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ'),
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
    parentNameCtrl.dispose();
    parentPhoneCtrl.dispose();
    noteCtrl.dispose();
    hoursCtrl.dispose();
    hourlyRateCtrl.dispose();
    paidCtrl.dispose();
    profile.dispose();
  }

  Future<bool> _saveTemporaryOrTrialChildDirect({
    required String childType,
    required String childName,
    required String parentName,
    required String parentPhone,
    required String gender,
    required _NewChildProfileDraft profile,
    required String note,
    required DateTime start,
    required DateTime end,
    required num hours,
    required num hourlyRate,
    required num paid,
    required num total,
    required num remaining,
    required String sharedAccessCodeId,
    required QueryDocumentSnapshot<Map<String, dynamic>> groupDoc,
  }) async {
    try {
      if (!_groupHasCapacity(groupDoc)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('المجموعة ممتلئة')),
          );
        }
        return false;
      }

      final isTrial = childType == 'trial';
      final childRef = _firestore.collection('children').doc();
      final invoiceRef = _firestore.collection('invoices').doc();
      final batch = _firestore.batch();
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final groupData = groupDoc.data();

      final preparedCode = await _prepareDirectTemporaryAccessCode(
        batch: batch,
        childRef: childRef,
        childName: childName,
        childType: childType,
        parentName: parentName,
        parentPhone: parentPhone,
        groupDoc: groupDoc,
        start: start,
        end: end,
        sharedAccessCodeId: sharedAccessCodeId,
        adminUid: adminUid,
      );

      if (preparedCode == null) return false;

      batch.set(childRef, {
        'id': childRef.id,
        'childId': childRef.id,
        'name': childName,
        'childName': childName,
        'gender': gender,
        'birthDate': Timestamp.fromDate(profile.birthDate),
        ...profile.toMap(),
        'section': 'Nursery',
        'childType': childType,
        'enrollmentType': childType,
        'childStatus': childType,
        'status': 'active',
        'accountStatus': 'active',
        'isActive': true,
        'isTemporaryChild': childType == 'temporary',
        'isTrialChild': isTrial,
        'isTemporary': childType == 'temporary',
        'isBillable': !isTrial,
        'excludeFromMonthlyInvoice': true,
        'canReactivate': !isTrial,
        'permanentDeleted': false,
        'parentUid': '',
        'parentUsername': '',
        'parentName': preparedCode.parentName,
        'parentPhone': preparedCode.parentPhone,
        'temporaryParentName': preparedCode.parentName,
        'temporaryParentPhone': preparedCode.parentPhone,
        'groupId': groupDoc.id,
        'groupName': _cleanText(groupData['groupName']),
        'assignedStaffUid': _cleanText(groupData['assignedStaffUid']),
        'assignedStaffName': _cleanText(groupData['assignedStaffName']),
        'assignedStaffUsername':
            _cleanText(groupData['assignedStaffUsername']),
        'temporaryAccessCodeId': preparedCode.id,
        'sharedAccessCodeId': preparedCode.id,
        'usesSharedAccessCode': preparedCode.usesSharedAccessCode,
        'temporaryAccessCode': preparedCode.code,
        'temporaryAccessStartAt': Timestamp.fromDate(start),
        'temporaryAccessEndAt': Timestamp.fromDate(end),
        if (isTrial) ...{
          'trialStartAt': Timestamp.fromDate(start),
          'trialEndAt': Timestamp.fromDate(end),
          'trialDays': 3,
          'trialIsFree': true,
        } else ...{
          'temporaryStartDate': Timestamp.fromDate(start),
          'temporaryEndDate': Timestamp.fromDate(end),
          'temporaryFee': total,
          'temporaryBillingType': 'hourly',
          'temporaryBillingTypeLabel': 'حسب الساعات',
          'temporaryHoursCount': hours,
          'temporaryHourlyRate': hourlyRate,
          'temporaryPaidAmount': paid,
          'temporaryRemainingAmount': remaining,
        },
        'temporaryNotes': note,
        'hasConsultation': false,
        'consultationStatus': 'none',
        'createdByUid': adminUid,
        'createdByRole': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!isTrial) {
        final status = paid <= 0
            ? 'غير مدفوعة'
            : paid >= total
                ? 'مدفوعة'
                : 'مدفوعة جزئياً';

        batch.set(invoiceRef, {
          'id': invoiceRef.id,
          'invoiceId': invoiceRef.id,
          'title': 'فاتورة الطفل المؤقت',
          'childId': childRef.id,
          'childName': childName,
          'childType': 'temporary',
          'parentUid': '',
          'parentUsername': '',
          'parentName': preparedCode.parentName,
          'parentPhone': preparedCode.parentPhone,
          'temporaryParentName': preparedCode.parentName,
          'temporaryParentPhone': preparedCode.parentPhone,
          'groupId': groupDoc.id,
          'groupName': _cleanText(groupData['groupName']),
          'temporaryAccessCodeId': preparedCode.id,
          'sharedAccessCodeId': preparedCode.id,
          'billingType': 'hourly',
          'billingTypeLabel': 'حسب الساعات',
          'hoursCount': hours,
          'hourlyRate': hourlyRate,
          'baseAmount': total,
          'finalAmount': total,
          'totalAmount': total,
          'paidAmount': paid,
          'remainingAmount': remaining,
          'status': status,
          'invoiceDate': FieldValue.serverTimestamp(),
          'accessStartAt': Timestamp.fromDate(start),
          'accessEndAt': Timestamp.fromDate(end),
          'createdByUid': adminUid,
          'createdByRole': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      await _refreshGroupChildrenCount(groupDoc.id);

      if (!mounted) return true;

      setState(() {});

      await _showTemporaryAccessCreatedDialog(
        childName: childName,
        accessCode: preparedCode.code,
        accessEndAt: end,
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الطفل: $e')),
      );

      return false;
    }
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
                    'إضافة طفل مؤقت',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('تحديد المجموعة والفترة والفاتورة'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _openAddTemporaryOrTrialChildSheet(
                      childType: 'temporary',
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.volunteer_activism_outlined),
                  ),
                  title: const Text(
                    'إضافة طفل تجربة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('تحديد المجموعة وفترة التجربة'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _openAddTemporaryOrTrialChildSheet(
                      childType: 'trial',
                    );
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
        const SnackBar(content: Text('لا يوجد حساب ولي أمر رسمي مفعّل')),
      );
      return;
    }

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أنشئي مجموعة مفعلة أولًا')),
      );
      return;
    }

    final childNameCtrl = TextEditingController();
    final identityNumberCtrl = TextEditingController();
    final profile = _NewChildProfileDraft();

    String selectedParentUid = '';
    String selectedGroupId = '';
    String selectedGender = 'female';
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
                          DropdownMenuItem(value: 'female', child: Text('أنثى')),
                          DropdownMenuItem(value: 'male', child: Text('ذكر')),
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
                            initialDate: profile.birthDate,
                            firstDate: DateTime(2015),
                            lastDate: DateTime.now(),
                          );
                          if (picked == null) return;
                          setSheetState(() {
                            profile.birthDate = picked;
                          });
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تاريخ الميلاد',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(
                            '${profile.birthDate.year}/${profile.birthDate.month}/${profile.birthDate.day}',
                          ),
                        ),
                      ),
                      _buildNewChildProfileFields(
                        profile: profile,
                        setSheetState: setSheetState,
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
                                    await _showValidationError(
                                      'اختاري ولي الأمر',
                                    );
                                    return;
                                  }

                                  if (selectedGroupId.isEmpty) {
                                    await _showValidationError(
                                      'اختاري المجموعة',
                                    );
                                    return;
                                  }

                                  if (childName.isEmpty) {
                                    await _showValidationError(
                                      'اكتبي اسم الطفل',
                                    );
                                    return;
                                  }

                                  if (!RegExp(r'^\d{9}$')
                                      .hasMatch(identityNumber)) {
                                    await _showValidationError(
                                      'رقم الهوية يجب أن يتكون من 9 أرقام',
                                    );
                                    return;
                                  }

                                  final profileError =
                                      _newChildProfileValidationError(profile);

                                  if (profileError != null) {
                                    await _showValidationError(profileError);
                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                  });

                                  final saved = await _savePermanentChild(
                                    childName: childName,
                                    identityNumber: identityNumber,
                                    gender: selectedGender,
                                    birthDate: profile.birthDate,
                                    profileFields: profile.toMap(),
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
                          label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ'),
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
    profile.dispose();
  }


  Future<bool> _savePermanentChild({
    required String childName,
    required String identityNumber,
    required String gender,
    required DateTime birthDate,
    required Map<String, dynamic> profileFields,
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
          const SnackBar(content: Text('هذا الطفل مسجل كطفل دائم بالفعل')),
        );
        return false;
      }

      final groupData = groupDoc.data();
      final oldGroupId = _cleanText(existingData['groupId']);
      final wasActive = existingData['isActive'] == true;

      if (!_groupHasCapacity(groupDoc) &&
          (!wasActive || oldGroupId != groupDoc.id)) {
        if (!mounted) return false;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('المجموعة ممتلئة، اختاري مجموعة أخرى')),
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
          ...profileFields,
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
          if (existingChildDoc != null)
            'convertedToPermanentAt': FieldValue.serverTimestamp(),
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
          if (existingChildDoc == null)
            'createdAt': FieldValue.serverTimestamp(),
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
        const SnackBar(content: Text('تمت إضافة الطفل الدائم بنجاح')),
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الطفل الدائم: $e')),
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


class _PreparedTemporaryAccessCode {
  final String id;
  final String code;
  final String parentName;
  final String parentPhone;
  final bool usesSharedAccessCode;

  const _PreparedTemporaryAccessCode({
    required this.id,
    required this.code,
    required this.parentName,
    required this.parentPhone,
    required this.usesSharedAccessCode,
  });
}

class _NewChildProfileDraft {
  DateTime birthDate = DateTime(2023, 1, 1);

  bool hasChronicDiseases = false;
  bool hasAllergies = false;
  bool takesMedications = false;
  bool hasDietaryRestrictions = false;
  bool hasSpecialNeeds = false;

  final chronicDiseasesCtrl = TextEditingController();
  final allergiesCtrl = TextEditingController();
  final medicationsCtrl = TextEditingController();
  final dietaryRestrictionsCtrl = TextEditingController();
  final specialNeedsCtrl = TextEditingController();
  final healthNotesCtrl = TextEditingController();

  final List<_PickupContactEditor> pickupContacts = [
    _PickupContactEditor(),
  ];

  Map<String, dynamic> toMap() {
    return {
      'hasChronicDiseases': hasChronicDiseases,
      'chronicDiseases':
          hasChronicDiseases ? chronicDiseasesCtrl.text.trim() : '',
      'hasAllergies': hasAllergies,
      'allergies': hasAllergies ? allergiesCtrl.text.trim() : '',
      'takesMedications': takesMedications,
      'medications': takesMedications ? medicationsCtrl.text.trim() : '',
      'hasDietaryRestrictions': hasDietaryRestrictions,
      'dietaryRestrictions': hasDietaryRestrictions
          ? dietaryRestrictionsCtrl.text.trim()
          : '',
      'hasSpecialNeeds': hasSpecialNeeds,
      'specialNeeds': hasSpecialNeeds ? specialNeedsCtrl.text.trim() : '',
      'healthNotes': healthNotesCtrl.text.trim(),
      'authorizedPickupContacts':
          pickupContacts.map((contact) => contact.toMap()).toList(),
    };
  }

  void dispose() {
    chronicDiseasesCtrl.dispose();
    allergiesCtrl.dispose();
    medicationsCtrl.dispose();
    dietaryRestrictionsCtrl.dispose();
    specialNeedsCtrl.dispose();
    healthNotesCtrl.dispose();

    for (final contact in pickupContacts) {
      contact.dispose();
    }
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