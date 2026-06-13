import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';


double sheetBottomSafePadding(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);

  return mediaQuery.viewInsets.bottom +
      mediaQuery.viewPadding.bottom +
      16;
}


class AdminGroupsPage extends StatefulWidget {
  final bool openAddChildFlow;

  const AdminGroupsPage({
    super.key,
    this.openAddChildFlow = false,
  });

  @override
  State<AdminGroupsPage> createState() => _AdminGroupsPageState();
}

class _AdminGroupsPageState extends State<AdminGroupsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _groupStatusLabel({
    required int currentChildren,
    required int maxChildren,
  }) {
    if (maxChildren <= 0) return 'بدون حد';
    if (currentChildren > maxChildren) return 'تجاوز';
    if (currentChildren == maxChildren) return 'ممتلئة';
    if (currentChildren >= (maxChildren * 0.8).ceil()) return 'قريبة';
    return 'متاحة';
  }

  Color _groupStatusColor({
    required int currentChildren,
    required int maxChildren,
  }) {
    if (maxChildren <= 0) return Colors.teal;
    if (currentChildren > maxChildren) return Colors.redAccent;
    if (currentChildren == maxChildren) return Colors.orange;
    if (currentChildren >= (maxChildren * 0.8).ceil()) {
      return Colors.amber.shade800;
    }
    return Colors.green;
  }

  Future<Map<String, dynamic>> _loadCurrentAdminData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return {};

    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data() ?? {};
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _groupsStream() {
    return _firestore
        .collection('groups')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _staffStream() {
    return _firestore
        .collection('users')
        .where('role', whereIn: ['nursery_staff', 'nursery', 'nursery staff'])
        .snapshots();
  }

  Future<int> _countChildrenInGroup(String groupId) async {
    if (groupId.trim().isEmpty) return 0;

    final snapshot = await _firestore
        .collection('children')
        .where('groupId', isEqualTo: groupId)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.length;
  }

  Future<void> _syncGroupChildrenCount(String groupId) async {
    final count = await _countChildrenInGroup(groupId);

    await _firestore.collection('groups').doc(groupId).update({
      'currentChildrenCount': count,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _openGroupForm({
    DocumentSnapshot<Map<String, dynamic>>? groupDoc,
  }) async {
    final isEditing = groupDoc != null;
    final groupData = groupDoc?.data() ?? {};

    final nameCtrl = TextEditingController(
      text: _cleanText(groupData['groupName']),
    );

    final maxCtrl = TextEditingController(
      text: _toInt(groupData['maxChildren'], fallback: 12).toString(),
    );

    String selectedStaffUid = _cleanText(groupData['assignedStaffUid']);
    String selectedStaffName = _cleanText(groupData['assignedStaffName']);
    String selectedStaffUsername = _cleanText(groupData['assignedStaffUsername']);

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
                  bottom: sheetBottomSafePadding(context),
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
                        isEditing ? 'تعديل المجموعة' : 'مجموعة جديدة',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم المجموعة',
                          prefixIcon: Icon(Icons.groups_2_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: maxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الحد الأقصى للأطفال',
                          prefixIcon: Icon(Icons.format_list_numbered_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _staffStream(),
                        builder: (context, snapshot) {
                          final staffDocs =
                              (snapshot.data?.docs ?? []).where((doc) {
                            final data = doc.data();
                            final accountStatus =
                                _cleanText(data['accountStatus']).toLowerCase();

                            return data['isLiveStreamStation'] != true &&
                                data['isActive'] != false &&
                                accountStatus != 'archived';
                          }).toList();

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: LinearProgressIndicator(),
                            );
                          }

                          if (staffDocs.isEmpty) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(14),
                                child: Text('لا يوجد موظفو حضانة'),
                              ),
                            );
                          }

                          return DropdownButtonFormField<String>(
                            initialValue: selectedStaffUid.isEmpty
                                ? null
                                : selectedStaffUid,
                            decoration: const InputDecoration(
                              labelText: 'الموظف المسؤول',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            items: staffDocs.map((doc) {
                              final data = doc.data();

                              final name = _cleanText(data['name']).isNotEmpty
                                  ? _cleanText(data['name'])
                                  : _cleanText(data['username']).isNotEmpty
                                      ? _cleanText(data['username'])
                                      : 'موظف بدون اسم';

                              final username = _cleanText(data['username']);

                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  username.isEmpty ? name : '$name • @$username',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              final selectedDoc = staffDocs.firstWhere(
                                (doc) => doc.id == value,
                              );

                              final data = selectedDoc.data();

                              setSheetState(() {
                                selectedStaffUid = selectedDoc.id;
                                selectedStaffName =
                                    _cleanText(data['name']).isNotEmpty
                                        ? _cleanText(data['name'])
                                        : _cleanText(data['username']);
                                selectedStaffUsername =
                                    _cleanText(data['username']);
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(
                            isEditing ? Icons.save_rounded : Icons.add_rounded,
                          ),
                          label: Text(isEditing ? 'حفظ' : 'إضافة'),
                          onPressed: () async {
                            final groupName = nameCtrl.text.trim();
                            final maxChildren =
                                int.tryParse(maxCtrl.text.trim()) ?? 12;

                            if (groupName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('اكتب اسم المجموعة'),
                                ),
                              );
                              return;
                            }

                            if (maxChildren <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('أدخل عدد أطفال صحيح'),
                                ),
                              );
                              return;
                            }

                            if (selectedStaffUid.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('اختر الموظف المسؤول'),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(sheetContext);

                            await _saveGroup(
                              groupId: groupDoc?.id,
                              groupName: groupName,
                              maxChildren: maxChildren,
                              assignedStaffUid: selectedStaffUid,
                              assignedStaffName: selectedStaffName,
                              assignedStaffUsername: selectedStaffUsername,
                            );
                          },
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

  Future<void> _saveGroup({
    required String? groupId,
    required String groupName,
    required int maxChildren,
    required String assignedStaffUid,
    required String assignedStaffName,
    required String assignedStaffUsername,
  }) async {
    try {
      final adminData = await _loadCurrentAdminData();
      final currentUid = _auth.currentUser?.uid ?? '';

      final isEditing = groupId != null && groupId.trim().isNotEmpty;

      int currentChildrenCount = 0;

      if (isEditing) {
        currentChildrenCount = await _countChildrenInGroup(groupId);
      }

      final data = <String, dynamic>{
        'groupName': groupName,
        'maxChildren': maxChildren,
        'assignedStaffUid': assignedStaffUid,
        'assignedStaffName': assignedStaffName,
        'assignedStaffUsername': assignedStaffUsername,
        'currentChildrenCount': currentChildrenCount,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': currentUid,
        'updatedByName': _cleanText(adminData['name']),
        'updatedByRole': 'admin',
      };

      if (isEditing) {
        await _firestore.collection('groups').doc(groupId).update(data);
      } else {
        await _firestore.collection('groups').add({
          ...data,
          'currentChildrenCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'createdByUid': currentUid,
          'createdByName': _cleanText(adminData['name']),
          'createdByRole': 'admin',
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'تم حفظ التعديل' : 'تمت إضافة المجموعة'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ المجموعة: $e')),
      );
    }
  }

  Future<void> _openGroupChildren(
    DocumentSnapshot<Map<String, dynamic>> groupDoc,
  ) async {
    final data = groupDoc.data() ?? {};

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GroupChildrenPage(
          groupId: groupDoc.id,
          groupName: _cleanText(data['groupName']),
          assignedStaffUid: _cleanText(data['assignedStaffUid']),
          assignedStaffName: _cleanText(data['assignedStaffName']),
          assignedStaffUsername: _cleanText(data['assignedStaffUsername']),
          openAddChildFlow: widget.openAddChildFlow,
        ),
      ),
    );

    await _syncGroupChildrenCount(groupDoc.id);

    if (!mounted) return;
    setState(() {});
  }

  Widget _buildGroupCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final groupName = _cleanText(data['groupName']).isEmpty
        ? 'مجموعة بدون اسم'
        : _cleanText(data['groupName']);

    final assignedStaffName = _cleanText(data['assignedStaffName']).isEmpty
        ? 'غير محددة'
        : _cleanText(data['assignedStaffName']);

    final currentChildren = _toInt(data['currentChildrenCount']);
    final maxChildren = _toInt(data['maxChildren'], fallback: 12);

    final statusLabel = _groupStatusLabel(
      currentChildren: currentChildren,
      maxChildren: maxChildren,
    );

    final statusColor = _groupStatusColor(
      currentChildren: currentChildren,
      maxChildren: maxChildren,
    );

    final progress =
        maxChildren <= 0 ? 0.0 : (currentChildren / maxChildren).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openGroupChildren(doc),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    child: Icon(Icons.groups_2_rounded, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          assignedStaffName,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openGroupForm(groupDoc: doc);
                      } else if (value == 'children') {
                        _openGroupChildren(doc);
                      } else if (value == 'sync') {
                        _syncGroupChildrenCount(doc.id);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'children',
                        child: Text('الأطفال'),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('تعديل'),
                      ),
                      PopupMenuItem(
                        value: 'sync',
                        child: Text('تحديث العدد'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: progress,
                  backgroundColor: Colors.black.withValues(alpha: 0.06),
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.child_care_rounded,
                    label: '$currentChildren / $maxChildren',
                    color: statusColor,
                  ),
                  _InfoChip(
                    icon: Icons.info_outline_rounded,
                    label: statusLabel,
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.child_care_rounded),
                      label: const Text('الأطفال'),
                      onPressed: () => _openGroupChildren(doc),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('تعديل'),
                      onPressed: () => _openGroupForm(groupDoc: doc),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إدارة المجموعات',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _groupsStream(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'المجموعات',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إضافة',
                      onPressed: () => _openGroupForm(),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (docs.isEmpty)
                  const _EmptyGroupsBox()
                else
                  ...docs.map(_buildGroupCard),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupChildrenPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String assignedStaffUid;
  final String assignedStaffName;
  final String assignedStaffUsername;
  final bool openAddChildFlow;

  const _GroupChildrenPage({
    required this.groupId,
    required this.groupName,
    required this.assignedStaffUid,
    required this.assignedStaffName,
    required this.assignedStaffUsername,
    this.openAddChildFlow = false,
  });

  @override
  State<_GroupChildrenPage> createState() => _GroupChildrenPageState();
}

class _GroupChildrenPageState extends State<_GroupChildrenPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    Future<bool> _isCurrentUserAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    if (uid.isEmpty) return false;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      final role = _cleanText(data['role']).toLowerCase();

      return role == 'admin';
    } catch (_) {
      return false;
    }
  }
  bool _didOpenInitialAddOptions = false;
  bool _isCheckingExpiredChildren = false;
  final Set<String> _processingExpiredChildIds = <String>{};

@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted ||
        !widget.openAddChildFlow ||
        _didOpenInitialAddOptions) {
      return;
    }

    _didOpenInitialAddOptions = true;
    _openAddOptionsSheet();
  });
}

  bool showArchivedChildren = false;

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '').trim();

    if (digits.startsWith('00970') && digits.length == 15) {
      return '0${digits.substring(5)}';
    }

    if (digits.startsWith('970') && digits.length == 12) {
      return '0${digits.substring(3)}';
    }

    return digits;
  }

  bool _isValidPalestinianMobile(String phone) {
    final clean = _normalizePhone(phone);

    if (!RegExp(r'^(059|056|052)\d{7}$').hasMatch(clean)) {
      return false;
    }

    if (RegExp(r'^(\d)\1+$').hasMatch(clean)) {
      return false;
    }

    return true;
  }

  String _normalizeName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }


bool _isPermanentChildData(Map<String, dynamic> data) {
  final childType = _cleanText(data['childType']).toLowerCase();
  final enrollmentType = _cleanText(data['enrollmentType']).toLowerCase();
  final isTemporaryChild = data['isTemporaryChild'] == true;
  final isTrialChild = data['isTrialChild'] == true;

  if (isTemporaryChild || isTrialChild) {
    return false;
  }

  return childType == 'permanent' || enrollmentType == 'permanent';
}


  String _childName(Map<String, dynamic> data) {
    if (_cleanText(data['name']).isNotEmpty) return _cleanText(data['name']);
    if (_cleanText(data['childName']).isNotEmpty) {
      return _cleanText(data['childName']);
    }
    return 'طفل بدون اسم';
  }

  String _parentName(Map<String, dynamic> data) {
    if (_cleanText(data['parentName']).isNotEmpty) {
      return _cleanText(data['parentName']);
    }
    if (_cleanText(data['parentUsername']).isNotEmpty) {
      return _cleanText(data['parentUsername']);
    }
    return 'ولي أمر غير محدد';
  }

  String _dateKey(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

 
  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  DateTime _trialEndFromStart(DateTime start) {
    return _endOfDay(start.add(const Duration(days: 2)));
  }

  bool _isTrialChild(Map<String, dynamic> data) {
    final childType = _cleanText(data['childType']).toLowerCase();
    final childStatus = _cleanText(data['childStatus']).toLowerCase();
    final enrollmentType = _cleanText(data['enrollmentType']).toLowerCase();

    return childType == 'trial' ||
        childStatus == 'trial' ||
        enrollmentType == 'trial';
  }

  bool _isTemporaryChild(Map<String, dynamic> data) {
    final childType = _cleanText(data['childType']).toLowerCase();
    final childStatus = _cleanText(data['childStatus']).toLowerCase();
    final enrollmentType = _cleanText(data['enrollmentType']).toLowerCase();

    return data['isTemporaryChild'] == true ||
        childType == 'temporary' ||
        childStatus == 'temporary' ||
        enrollmentType == 'temporary';
  }

  bool _isArchivedChild(Map<String, dynamic> data) {
    final childStatus = _cleanText(data['childStatus']).toLowerCase();
    final accountStatus = _cleanText(data['accountStatus']).toLowerCase();
    final isActive = data['isActive'] != true;

    return isActive ||
        childStatus == 'archived' ||
        childStatus == 'rejected_after_trial' ||
        accountStatus == 'archived';
  }

  bool _isTrialPendingDecision(Map<String, dynamic> data) {
    final childStatus = _cleanText(data['childStatus']).toLowerCase();
    final status = _cleanText(data['status']).toLowerCase();
    final accountStatus = _cleanText(data['accountStatus']).toLowerCase();
    final trialDecision = _cleanText(data['trialDecision']).toLowerCase();

    return _isTrialChild(data) &&
        (childStatus == 'trial_pending_decision' ||
            status == 'trial_pending_decision' ||
            accountStatus == 'pending_decision' ||
            trialDecision == 'pending');
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    final raw = _cleanText(value);
    if (raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return _endOfDay(parsed);
    }

    return parsed;
  }

  DateTime? _expiryDateForChild(Map<String, dynamic> data) {
    if (_isTrialChild(data)) {
      return _toDateTime(data['trialEndAt']) ??
          _toDateTime(data['temporaryAccessEndAt']) ??
          _toDateTime(data['temporaryEndDate']);
    }

    if (_isTemporaryChild(data)) {
      return _toDateTime(data['temporaryAccessEndAt']) ??
          _toDateTime(data['temporaryEndDate']) ??
          _toDateTime(data['temporaryEndAt']);
    }

    return null;
  }

  bool _hasExpired(Map<String, dynamic> data) {
    if (_isArchivedChild(data)) return false;
    if (!_isTemporaryChild(data) && !_isTrialChild(data)) return false;

    final expiryDate = _expiryDateForChild(data);
    if (expiryDate == null) return false;

    return !expiryDate.isAfter(DateTime.now());
  }

  Future<void> _archiveChildRecords({
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
    required String archiveReason,
    required bool automated,
  }) async {
    final data = childDoc.data() ?? <String, dynamic>{};
    final isTrial = _isTrialChild(data);
    final archivedChildStatus =
        isTrial ? 'trial_pending_decision' : 'archived';

    final accessCodeIds = <String>{
      _cleanText(data['temporaryAccessCodeId']),
      _cleanText(data['sharedAccessCodeId']),
    }..removeWhere((value) => value.isEmpty);

    final legacyAccessCodesSnapshot = await _firestore
        .collection('temporary_access_codes')
        .where('childId', isEqualTo: childDoc.id)
        .get();

    for (final codeDoc in legacyAccessCodesSnapshot.docs) {
      accessCodeIds.add(codeDoc.id);
    }

    final devicesSnapshot = await _firestore
        .collection('temporary_parent_devices')
        .where('childId', isEqualTo: childDoc.id)
        .get();

    final batch = _firestore.batch();

    batch.set(
      childDoc.reference,
      {
        'childStatus': archivedChildStatus,
        'status': 'archived',
        'accountStatus': 'archived',
        'isActive': false,
        'isBillable': false,
        'excludeFromMonthlyInvoice': true,
        'canReactivate': true,
        'permanentDeleted': false,
        if (isTrial) 'trialUsed': true,
        if (isTrial) 'canStartNewTrial': false,
        if (isTrial) 'trialDecision': 'pending',
        'archiveReason': archiveReason,
        'archivedAutomatically': automated,
        'archivedAt': FieldValue.serverTimestamp(),
        if (automated) 'expiredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    for (final codeId in accessCodeIds) {
      final codeRef = _firestore.collection('temporary_access_codes').doc(codeId);
      final codeDoc = await codeRef.get();

      if (!codeDoc.exists) continue;

      final codeData = codeDoc.data() ?? <String, dynamic>{};
      final linkedChildIds = <String>{
        ..._readStringList(codeData['childIds']),
        _cleanText(codeData['childId']),
      }
        ..removeWhere((value) => value.isEmpty || value == childDoc.id);

      final siblingDocs = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final siblingId in linkedChildIds) {
        final siblingDoc = await _firestore.collection('children').doc(siblingId).get();
        final siblingData = siblingDoc.data();

        if (siblingDoc.exists &&
            siblingData != null &&
            !_isArchivedChild(siblingData) &&
            (_isTemporaryChild(siblingData) || _isTrialChild(siblingData))) {
          siblingDocs.add(siblingDoc);
        }
      }

      if (siblingDocs.isEmpty) {
        batch.set(
          codeRef,
          {
            'childIds': <String>[],
            'childNames': <String>[],
            'hasMultipleChildren': false,
            'usesSharedAccessCode': false,
            'isActive': false,
            'status': automated ? 'expired' : 'archived',
            'accountStatus': 'archived',
            'childStatus': archivedChildStatus,
            'canReactivate': true,
            'permanentDeleted': false,
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

      for (final siblingDoc in siblingDocs) {
        final siblingData = siblingDoc.data() ?? <String, dynamic>{};
        final start = _toDateTime(siblingData['temporaryAccessStartAt']);
        final end = _toDateTime(siblingData['temporaryAccessEndAt']);

        if (start != null && (earliestStart == null || start.isBefore(earliestStart))) {
          earliestStart = start;
        }

        if (end != null && (latestEnd == null || end.isAfter(latestEnd))) {
          latestEnd = end;
        }
      }

      final primarySibling = siblingDocs.first;
      final primarySiblingData = primarySibling.data() ?? <String, dynamic>{};
      final siblingIds = siblingDocs.map((doc) => doc.id).toList();
      final siblingNames = siblingDocs
          .map((doc) => _childName(doc.data() ?? <String, dynamic>{}))
          .toSet()
          .toList();

      batch.set(
        codeRef,
        {
          'childId': primarySibling.id,
          'childName': _childName(primarySiblingData),
          'childIds': siblingIds,
          'childNames': siblingNames,
          'hasMultipleChildren': siblingIds.length > 1,
          'usesSharedAccessCode': siblingIds.length > 1,
          'isActive': true,
          'status': 'active',
          'accountStatus': 'active',
          if (earliestStart != null) 'accessStartAt': Timestamp.fromDate(earliestStart),
          if (latestEnd != null) 'accessEndAt': Timestamp.fromDate(latestEnd),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    for (final deviceDoc in devicesSnapshot.docs) {
      batch.set(
        deviceDoc.reference,
        {
          'isActive': false,
          'accountStatus': 'archived',
          'archiveReason': archiveReason,
          'archivedAt': FieldValue.serverTimestamp(),
          if (automated) 'expiredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

    Future<void> _markExpiredTrialPendingDecision({
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
  }) async {
    await _archiveChildRecords(
      childDoc: childDoc,
      archiveReason: 'trial_expired_pending_decision',
      automated: true,
    );

    await childDoc.reference.set(
      {
        'childStatus': 'trial_pending_decision',
        'status': 'archived',
        'accountStatus': 'archived',
        'isActive': false,
        'isBillable': false,
        'excludeFromMonthlyInvoice': true,
        'canReactivate': true,
        'trialUsed': true,
        'canStartNewTrial': false,
        'trialDecision': 'pending',
        'archiveReason': 'trial_expired_pending_decision',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }



  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadActiveParentAccounts() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .get();

    final docs = snapshot.docs.where((doc) {
      final data = doc.data();
      return data['isActive'] != false &&
          _cleanText(data['accountStatus']).toLowerCase() != 'archived';
    }).toList();

    docs.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      final aName = _cleanText(
        aData['name'] ?? aData['displayName'] ?? aData['username'],
      );
      final bName = _cleanText(
        bData['name'] ?? bData['displayName'] ?? bData['username'],
      );

      return aName.compareTo(bName);
    });

    return docs;
  }

  String _officialParentName(Map<String, dynamic> data) {
    final name = _cleanText(data['name']);
    if (name.isNotEmpty) return name;

    final displayName = _cleanText(data['displayName']);
    if (displayName.isNotEmpty) return displayName;

    final username = _cleanText(data['username']);
    return username.isEmpty ? 'ولي أمر بدون اسم' : username;
  }

  String _officialParentPhone(Map<String, dynamic> data) {
    final phone = _cleanText(data['phone']);
    if (phone.isNotEmpty) return _normalizePhone(phone);

    final parentPhone = _cleanText(data['parentPhone']);
    if (parentPhone.isNotEmpty) return _normalizePhone(parentPhone);

    final mobile = _cleanText(data['mobile']);
    if (mobile.isNotEmpty) return _normalizePhone(mobile);

    final phoneNumber = _cleanText(data['phoneNumber']);
    if (phoneNumber.isNotEmpty) return _normalizePhone(phoneNumber);

    return '';
  }

  bool _isActiveOfficialParentData(Map<String, dynamic> data) {
    final role = _cleanText(data['role']).toLowerCase();
    final accountStatus = _cleanText(data['accountStatus']).toLowerCase();

    return role == 'parent' &&
        data['isActive'] != false &&
        accountStatus != 'archived';
  }

  _OfficialParentAccount _officialParentAccountFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return _OfficialParentAccount(
      uid: doc.id,
      username: _cleanText(data['username']).toLowerCase(),
      name: _officialParentName(data),
      phone: _officialParentPhone(data),
    );
  }

  Future<_OfficialParentAccount?> _findActiveOfficialParentAccount({
    String parentUid = '',
    String parentUsername = '',
    String parentPhone = '',
  }) async {
    final normalizedUid = _cleanText(parentUid);
    final normalizedUsername = _cleanText(parentUsername).toLowerCase();
    final normalizedPhone = _normalizePhone(parentPhone);
    final parentDocs = await _loadActiveParentAccounts();

    if (normalizedUid.isNotEmpty) {
      for (final doc in parentDocs) {
        if (doc.id == normalizedUid && _isActiveOfficialParentData(doc.data())) {
          return _officialParentAccountFromDoc(doc);
        }
      }
    }

    if (normalizedUsername.isNotEmpty) {
      for (final doc in parentDocs) {
        final data = doc.data();
        final username = _cleanText(data['username']).toLowerCase();

        if (username == normalizedUsername &&
            _isActiveOfficialParentData(data)) {
          return _officialParentAccountFromDoc(doc);
        }
      }
    }

    if (normalizedPhone.isNotEmpty) {
      for (final doc in parentDocs) {
        final data = doc.data();

        if (_officialParentPhone(data) == normalizedPhone &&
            _isActiveOfficialParentData(data)) {
          return _officialParentAccountFromDoc(doc);
        }
      }
    }

    return null;
  }

  Future<void> _openApproveTrialChildSheet({
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
  }) async {
    final parentDocs = await _loadActiveParentAccounts();

    if (!mounted) return;

    if (parentDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد حساب ولي أمر رسمي فعال لربط الطفل به'),
        ),
      );
      return;
    }

    final childData = childDoc.data() ?? <String, dynamic>{};
    String selectedParentUid = _cleanText(childData['parentUid']);
    if (!parentDocs.any((doc) => doc.id == selectedParentUid)) {
      selectedParentUid = '';
    }
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
                  bottom: sheetBottomSafePadding(sheetContext),
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
                        items: parentDocs.map((doc) {
                          final data = doc.data();
                          final username = _cleanText(data['username']);
                          final name = _officialParentName(data);

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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'اختر حساب ولي الأمر الرسمي',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                  });

                                  final parentDoc = parentDocs.firstWhere(
                                    (doc) => doc.id == selectedParentUid,
                                  );

                                  final succeeded = await _approveTrialChild(
                                    childDoc: childDoc,
                                    parentDoc: parentDoc,
                                  );

                                  if (!sheetContext.mounted || !succeeded) {
                                    setSheetState(() {
                                      isSaving = false;
                                    });
                                    return;
                                  }

                                  Navigator.pop(sheetContext);
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
                            isSaving ? 'جاري الاعتماد...' : 'تسجيل الطفل رسميًا',
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

    if (!_isTrialChild(childData)) return false;

    try {
      final parentData = parentDoc.data();
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final previousAccessCodeId =
          _cleanText(childData['sharedAccessCodeId']).isNotEmpty
              ? _cleanText(childData['sharedAccessCodeId'])
              : _cleanText(childData['temporaryAccessCodeId']);

      await _archiveChildRecords(
        childDoc: childDoc,
        archiveReason: 'trial_approved',
        automated: false,
      );

      await childDoc.reference.set(
        {
          'childType': 'permanent',
          'enrollmentType': 'permanent',
          'childStatus': 'active',
          'status': 'active',
          'accountStatus': 'active',
          'isTemporaryChild': false,
          'isTrialChild': false,
          'isActive': true,
          'isBillable': true,
          'excludeFromMonthlyInvoice': false,
          'canReactivate': true,
          'permanentDeleted': false,
          'trialDecision': 'approved',
          'trialUsed': true,
          'canStartNewTrial': false,
          'trialDecisionAt': FieldValue.serverTimestamp(),
          'trialApprovedAt': FieldValue.serverTimestamp(),
          'parentUid': parentDoc.id,
          'parentUsername': _cleanText(parentData['username']).toLowerCase(),
          'parentName': _officialParentName(parentData),
          'parentPhone': _cleanText(parentData['phone']).isNotEmpty
              ? _cleanText(parentData['phone'])
              : _cleanText(parentData['parentPhone']),
          'temporaryParentUid': '',
          'temporaryParentUsername': '',
          'usesSharedAccessCode': false,
          if (previousAccessCodeId.isNotEmpty)
            'previousTemporaryAccessCodeId': previousAccessCodeId,
          'temporaryAccessCodeId': '',
          'sharedAccessCodeId': '',
          'temporaryAccessCode': '',
          'temporaryAccessStartAt': '',
          'temporaryAccessEndAt': '',
          'archiveReason': '',
          'archivedAt': '',
          'expiredAt': '',
          'updatedByUid': adminUid,
          'updatedByRole': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _updateGroupCount();

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الطفل رسميًا في الحضانة')),
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

  Future<void> _openConvertTemporaryChildSheet({
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
  }) async {
    final childData = childDoc.data() ?? <String, dynamic>{};

    if (!_isTemporaryChild(childData) || _isTrialChild(childData)) {
      return;
    }

    if (childData['trialUsed'] == true ||
        childData['canStartNewTrial'] == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'هذا الطفل استخدم فترة التجربة المجانية سابقًا. استخدم استعادة لاعتماده رسميًا عند الحاجة.',
            ),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('بدء تجربة للطفل الزائر'),
              content: const Text(
                'سيبدأ الطفل فترة تجربة مجانية لمدة 3 أيام. إذا كان مرتبطًا بحساب ولي أمر رسمي سيظهر داخل الحساب بدون كود، وإذا لم يكن لديه حساب رسمي سيتم استخدام كود الدخول المؤقت أو كود الإخوة عند الحاجة.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('بدء التجربة'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    await _convertTemporaryChildToTrial(childDoc: childDoc);
  }
  Future<bool> _convertTemporaryChildToTrial({
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
  }) async {
    final childData = childDoc.data() ?? <String, dynamic>{};

    if (!_isTemporaryChild(childData) || _isTrialChild(childData)) {
      return false;
    }

    if (childData['trialUsed'] == true ||
        childData['canStartNewTrial'] == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن منح الطفل فترة تجربة مجانية ثانية.'),
          ),
        );
      }
      return false;
    }

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final childName = _childName(childData);
      final parentName = _cleanText(
        childData['temporaryParentName'] ?? childData['parentName'],
      );
      final parentPhone = _normalizePhone(
        _cleanText(
          childData['temporaryParentPhone'] ?? childData['parentPhone'],
        ),
      );
      final trialStartDate = DateTime.now();
      final trialEndDate = _trialEndFromStart(trialStartDate);
      final batch = _firestore.batch();

      final officialParent = await _findActiveOfficialParentAccount(
        parentUid: _cleanText(childData['parentUid']),
        parentUsername: _cleanText(childData['parentUsername']),
        parentPhone: parentPhone,
      );

      _PreparedAccessCode? preparedCode;

      if (officialParent != null) {
        await _deactivateOldTemporaryAccess(
          childId: childDoc.id,
          batch: batch,
        );
      } else {
        String sharedAccessCodeId = _cleanText(childData['sharedAccessCodeId']);
        if (sharedAccessCodeId.isEmpty) {
          sharedAccessCodeId = _cleanText(childData['temporaryAccessCodeId']);
        }

        if (sharedAccessCodeId.isNotEmpty) {
          final codeDoc = await _firestore
              .collection('temporary_access_codes')
              .doc(sharedAccessCodeId)
              .get();

          if (!codeDoc.exists || codeDoc.data()?['isActive'] != true) {
            sharedAccessCodeId = '';
          }
        }

        if (sharedAccessCodeId.isEmpty) {
          sharedAccessCodeId = await _resolveActiveSiblingAccessCodeId(
            childId: childDoc.id,
            childData: childData,
          );
        }

        preparedCode = await _prepareAccessCode(
          sharedAccessCodeId: sharedAccessCodeId,
          childRef: childDoc.reference,
          childName: childName,
          childType: 'trial',
          parentName: parentName,
          cleanParentPhone: parentPhone,
          accessStartDate: trialStartDate,
          accessEndDate: trialEndDate,
          adminUid: adminUid,
          batch: batch,
        );

        if (preparedCode == null) return false;
      }

      final resolvedParentName =
          officialParent != null ? officialParent.name : preparedCode?.parentName ?? parentName;
      final resolvedParentPhone = officialParent != null
          ? (officialParent.phone.isNotEmpty ? officialParent.phone : parentPhone)
          : preparedCode?.parentPhone ?? parentPhone;

      batch.set(
        childDoc.reference,
        {
          'childType': 'trial',
          'enrollmentType': 'trial',
          'childStatus': 'trial',
          'status': 'active',
          'accountStatus': 'active',
          'isTemporaryChild': false,
          'isTrialChild': true,
          'isActive': true,
          'isBillable': false,
          'excludeFromMonthlyInvoice': true,
          'canReactivate': true,
          'permanentDeleted': false,
          'trialUsed': true,
          'canStartNewTrial': false,
          'trialIsFree': true,
          'trialDays': 3,
          'trialDecision': '',
          'trialStartAt': Timestamp.fromDate(trialStartDate),
          'trialEndAt': Timestamp.fromDate(trialEndDate),
          'convertedFromChildType': 'temporary',
          'temporaryConvertedToTrialAt': FieldValue.serverTimestamp(),
          if (officialParent != null) ...{
            'parentUid': officialParent.uid,
            'parentUsername': officialParent.username,
            'parentName': resolvedParentName,
            'parentPhone': resolvedParentPhone,
            'temporaryParentUid': '',
            'temporaryParentUsername': '',
            'temporaryParentName': '',
            'temporaryParentPhone': '',
            'accessMode': 'parent_account',
            'usesTemporaryAccessCode': false,
            'temporaryAccessCodeId': '',
            'sharedAccessCodeId': '',
            'temporaryAccessCode': '',
            'usesSharedAccessCode': false,
          } else ...{
            'parentUid': '',
            'parentUsername': '',
            'parentName': resolvedParentName,
            'parentPhone': resolvedParentPhone,
            'temporaryParentUid': '',
            'temporaryParentUsername': '',
            'temporaryParentName': resolvedParentName,
            'temporaryParentPhone': resolvedParentPhone,
            'accessMode': 'temporary_code',
            'usesTemporaryAccessCode': true,
            'temporaryAccessCodeId': preparedCode?.reference.id ?? '',
            'sharedAccessCodeId': preparedCode?.reference.id ?? '',
            'temporaryAccessCode': preparedCode?.accessCode ?? '',
            'usesSharedAccessCode': preparedCode?.usesSharedAccessCode ?? false,
          },
          'temporaryAccessStartAt': Timestamp.fromDate(trialStartDate),
          'temporaryAccessEndAt': Timestamp.fromDate(trialEndDate),
          'archiveReason': '',
          'archivedAt': '',
          'expiredAt': '',
          'updatedByUid': adminUid,
          'updatedByRole': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      await _updateGroupCount();

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم بدء فترة التجربة المجانية للطفل لمدة 3 أيام'),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر بدء تجربة الطفل الزائر: $e')),
      );
      return false;
    }
  }

  Future<void> _archiveExpiredChildren(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (_isCheckingExpiredChildren) return;

    final isAdmin = await _isCurrentUserAdmin();

    if (!isAdmin) return;

    _isCheckingExpiredChildren = true;
    bool archivedAnyChild = false;

    try {
      for (final doc in docs) {
        final data = doc.data();

        if (!_hasExpired(data) ||
            _processingExpiredChildIds.contains(doc.id)) {
          continue;
        }

        _processingExpiredChildIds.add(doc.id);

        try {
          if (_isTrialChild(data)) {
            await _markExpiredTrialPendingDecision(childDoc: doc);
          } else {
            await _archiveChildRecords(
              childDoc: doc,
              archiveReason: 'temporary_expired',
              automated: true,
            );
          }

          archivedAnyChild = true;
        } finally {
          _processingExpiredChildIds.remove(doc.id);
        }
      }

      if (archivedAnyChild) {
        await _updateGroupCount();
      }
    } catch (e) {
      debugPrint('AUTO ARCHIVE EXPIRED CHILDREN ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر أرشفة بعض الفترات المنتهية'),
        ),
      );
    } finally {
      _isCheckingExpiredChildren = false;
    }
  }

  String _formatDate(DateTime date) {
    return _dateKey(date);
  }

  num _parseMoney(String value) {
    final cleaned = value.trim().replaceAll(',', '.');
    return num.tryParse(cleaned) ?? 0;
  }

  String _billingTypeLabel(String value) {
    switch (value) {
      case 'hourly':
        return 'حسب الساعات';
      case 'daily':
        return 'حسب الأيام';
      case 'fixed':
      default:
        return 'مبلغ ثابت';
    }
  }

  String _paymentMethodLabel(String value) {
    switch (value) {
      case 'visa':
        return 'فيزا';
      case 'cash':
      default:
        return 'كاش';
    }
  }

  String _invoiceStatus({
    required num finalAmount,
    required num paidAmount,
  }) {
    if (paidAmount <= 0) return 'غير مدفوعة';
    if (paidAmount >= finalAmount) return 'مدفوعة';
    return 'مدفوعة جزئياً';
  }

  String _generateAccessCode() {
    final random = Random.secure();
    final number = 100000 + random.nextInt(900000);
    return 'TMP-$number';
  }

  List<String> _readStringList(dynamic value) {
    if (value is! Iterable) return <String>[];

    return value
        .map(_cleanText)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<List<_SiblingAccessCodeOption>> _loadSiblingAccessCodeOptions({
    String parentName = '',
    String parentPhone = '',
    String excludedChildId = '',
  }) async {
    final snapshot = await _firestore
        .collection('temporary_access_codes')
        .where('isActive', isEqualTo: true)
        .get();

    final now = DateTime.now();
    final options = <_SiblingAccessCodeOption>[];
    final normalizedParentPhone = _normalizePhone(parentPhone);
    final normalizedParentName = _normalizeName(parentName);

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final accountStatus = _cleanText(data['accountStatus']).toLowerCase();
      final accessEndAt = _toDateTime(data['accessEndAt']);
      final code = _cleanText(data['code']);
      final optionParentName = _cleanText(data['parentName']).isNotEmpty
          ? _cleanText(data['parentName'])
          : _cleanText(data['temporaryParentName']);
      final optionParentPhone = _cleanText(data['parentPhone']).isNotEmpty
          ? _cleanText(data['parentPhone'])
          : _cleanText(data['temporaryParentPhone']);

      if (code.isEmpty || accountStatus == 'archived') continue;
      if (accessEndAt != null && !accessEndAt.isAfter(now)) continue;

      if (normalizedParentPhone.isNotEmpty) {
        if (_normalizePhone(optionParentPhone) != normalizedParentPhone) {
          continue;
        }
      } else if (normalizedParentName.isNotEmpty &&
          _normalizeName(optionParentName) != normalizedParentName) {
        continue;
      }

      final linkedChildIds = <String>{
        ..._readStringList(data['childIds']),
        _cleanText(data['childId']),
      }..removeWhere(
          (value) => value.isEmpty || value == excludedChildId,
        );

      final eligibleSiblingNames = <String>[];

      for (final siblingId in linkedChildIds) {
        final siblingDoc =
            await _firestore.collection('children').doc(siblingId).get();
        final siblingData = siblingDoc.data();

        if (!siblingDoc.exists || siblingData == null) continue;
        if (_isArchivedChild(siblingData)) continue;

        if (_isTemporaryChild(siblingData) || _isTrialChild(siblingData)) {
          eligibleSiblingNames.add(_childName(siblingData));
        }
      }

      if (eligibleSiblingNames.isEmpty) continue;

      options.add(
        _SiblingAccessCodeOption(
          id: doc.id,
          code: code,
          parentName: optionParentName,
          parentPhone: optionParentPhone,
          childNames: eligibleSiblingNames.toSet().toList(),
        ),
      );
    }

    options.sort((a, b) => a.parentName.compareTo(b.parentName));
    return options;
  }

  Future<String> _resolveActiveSiblingAccessCodeId({
    required String childId,
    required Map<String, dynamic> childData,
  }) async {
    final temporaryParentPhone =
        _cleanText(childData['temporaryParentPhone']).isNotEmpty
            ? _cleanText(childData['temporaryParentPhone'])
            : _cleanText(childData['parentPhone']);

    final options = await _loadSiblingAccessCodeOptions(
      parentName: _parentName(childData),
      parentPhone: temporaryParentPhone,
      excludedChildId: childId,
    );

    if (options.isEmpty) return '';

    final previousSharedAccessCodeId =
        _cleanText(childData['sharedAccessCodeId']).isNotEmpty
            ? _cleanText(childData['sharedAccessCodeId'])
            : _cleanText(childData['temporaryAccessCodeId']);

    if (options.any((option) => option.id == previousSharedAccessCodeId)) {
      return previousSharedAccessCodeId;
    }

    return options.first.id;
  }

  Widget _buildOfficialParentLinkFields({
    required bool linkWithOfficialParent,
    required String selectedOfficialParentUid,
    required Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        officialParentsFuture,
    required ValueChanged<bool> onToggle,
    required ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>?>
        onSelected,
  }) {
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: officialParentsFuture,
      builder: (context, snapshot) {
        final parentDocs = snapshot.data ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        QueryDocumentSnapshot<Map<String, dynamic>>? selectedParentDoc;

        if (selectedOfficialParentUid.isNotEmpty) {
          final matchingDocs = parentDocs.where(
            (doc) => doc.id == selectedOfficialParentUid,
          );

          if (matchingDocs.isNotEmpty) {
            selectedParentDoc = matchingDocs.first;
          }
        }

        return Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: linkWithOfficialParent,
              title: const Text('ربط بحساب ولي أمر رسمي'),
              subtitle: const Text(
                'استخدمي هذا الخيار إذا كان ولي الأمر يملك حسابًا رسميًا في التطبيق.',
              ),
              onChanged: snapshot.connectionState == ConnectionState.waiting
                  ? null
                  : onToggle,
            ),
            if (snapshot.connectionState == ConnectionState.waiting &&
                linkWithOfficialParent)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (linkWithOfficialParent && parentDocs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'لا يوجد حسابات أولياء أمور رسمية مفعّلة حاليًا.',
                  ),
                ),
              ),
            if (linkWithOfficialParent && parentDocs.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: selectedParentDoc?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'حساب ولي الأمر الرسمي',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: parentDocs.map((doc) {
                  final data = doc.data();
                  final name = _officialParentName(data);
                  final username = _cleanText(data['username']);
                  final phone = _officialParentPhone(data);

                  final labelParts = <String>[
                    name,
                    if (username.isNotEmpty) '@$username',
                    if (phone.isNotEmpty) phone,
                  ];

                  return DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(
                      labelParts.join(' • '),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  final selectedId = value ?? '';
                  final matches = parentDocs.where(
                    (doc) => doc.id == selectedId,
                  );

                  onSelected(matches.isEmpty ? null : matches.first);
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSiblingAccessCodeFields({
    required bool linkWithSiblings,
    required String selectedSharedAccessCodeId,
    required Future<List<_SiblingAccessCodeOption>> optionsFuture,
    required ValueChanged<bool> onToggle,
    required ValueChanged<_SiblingAccessCodeOption?> onSelected,
  }) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: linkWithSiblings,
          title: const Text('ربط بإخوة مسجلين بنفس الكود'),
          onChanged: onToggle,
        ),
        if (linkWithSiblings)
          FutureBuilder<List<_SiblingAccessCodeOption>>(
            future: optionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                );
              }

              final options = snapshot.data ?? <_SiblingAccessCodeOption>[];

              if (options.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('لا توجد أكواد إخوة متاحة'),
                  ),
                );
              }

              return DropdownButtonFormField<String>(
                initialValue: selectedSharedAccessCodeId.isEmpty
                    ? null
                    : selectedSharedAccessCodeId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'كود الإخوة',
                  prefixIcon: Icon(Icons.family_restroom_rounded),
                ),
                items: options.map((option) {
                  return DropdownMenuItem<String>(
                    value: option.id,
                    child: Text(
                      option.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) {
                    onSelected(null);
                    return;
                  }

                  onSelected(
                    options.firstWhere((option) => option.id == value),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Future<_PreparedAccessCode?> _prepareAccessCode({
    required String sharedAccessCodeId,
    required DocumentReference<Map<String, dynamic>> childRef,
    required String childName,
    required String childType,
    required String parentName,
    required String cleanParentPhone,
    required DateTime accessStartDate,
    required DateTime accessEndDate,
    required String adminUid,
    required WriteBatch batch,
  }) async {
    final isLinkingWithSiblings = sharedAccessCodeId.trim().isNotEmpty;
    final codeRef = isLinkingWithSiblings
        ? _firestore.collection('temporary_access_codes').doc(sharedAccessCodeId)
        : _firestore.collection('temporary_access_codes').doc();

    if (!isLinkingWithSiblings) {
      final accessCode = _generateAccessCode();

      batch.set(codeRef, {
        'id': codeRef.id,
        'code': accessCode,
        'childId': childRef.id,
        'childName': childName,
        'childIds': [childRef.id],
        'childNames': [childName],
        'childTypes': [childType],
        'groupId': widget.groupId,
        'groupName': widget.groupName,
        'groupIds': [widget.groupId],
        'groupNames': [widget.groupName],
        'parentUid': '',
        'parentUsername': '',
        'parentName': parentName,
        'parentPhone': cleanParentPhone,
        'temporaryParentName': parentName,
        'temporaryParentPhone': cleanParentPhone,
        'childType': childType,
        'childStatus': childType,
        'accessStartAt': Timestamp.fromDate(accessStartDate),
        'accessEndAt': Timestamp.fromDate(accessEndDate),
        if (childType == 'trial') 'trialStartAt': Timestamp.fromDate(accessStartDate),
        if (childType == 'trial') 'trialEndAt': Timestamp.fromDate(accessEndDate),
        'hasMultipleChildren': false,
        'usesSharedAccessCode': false,
        'isActive': true,
        'accountStatus': 'active',
        'canReactivate': childType != 'trial',
        'permanentDeleted': false,
        'isUsed': false,
        'createdByUid': adminUid,
        'createdByRole': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return _PreparedAccessCode(
        reference: codeRef,
        accessCode: accessCode,
        parentName: parentName,
        parentPhone: cleanParentPhone,
        usesSharedAccessCode: false,
      );
    }

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

    final accessCode = _cleanText(codeData['code']);

    if (accessCode.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('كود الإخوة غير صالح')),
        );
      }
      return null;
    }

    final savedParentName = _cleanText(codeData['parentName']).isNotEmpty
        ? _cleanText(codeData['parentName'])
        : _cleanText(codeData['temporaryParentName']);
    final savedParentPhone = _cleanText(codeData['parentPhone']).isNotEmpty
        ? _cleanText(codeData['parentPhone'])
        : _cleanText(codeData['temporaryParentPhone']);

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

    final linkedGroupIds = <String>{
      ..._readStringList(codeData['groupIds']),
      _cleanText(codeData['groupId']),
      widget.groupId,
    }..removeWhere((value) => value.isEmpty);

    final linkedGroupNames = <String>{
      ..._readStringList(codeData['groupNames']),
      _cleanText(codeData['groupName']),
      widget.groupName,
    }..removeWhere((value) => value.isEmpty);

    final linkedChildTypes = <String>{
      ..._readStringList(codeData['childTypes']),
      _cleanText(codeData['childType']),
      childType,
    }..removeWhere((value) => value.isEmpty);

    final oldStart = _toDateTime(codeData['accessStartAt']);
    final oldEnd = _toDateTime(codeData['accessEndAt']);
    final mergedStart = oldStart != null && oldStart.isBefore(accessStartDate)
        ? oldStart
        : accessStartDate;
    final mergedEnd = oldEnd != null && oldEnd.isAfter(accessEndDate)
        ? oldEnd
        : accessEndDate;

    batch.set(
      codeRef,
      {
        'childIds': linkedChildIds.toList(),
        'childNames': linkedChildNames.toList(),
        'childTypes': linkedChildTypes.toList(),
        'groupIds': linkedGroupIds.toList(),
        'groupNames': linkedGroupNames.toList(),
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

    for (final siblingChildId in linkedChildIds) {
      batch.set(
        _firestore.collection('children').doc(siblingChildId),
        {
          'sharedAccessCodeId': codeRef.id,
          'usesSharedAccessCode': linkedChildIds.length > 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    return _PreparedAccessCode(
      reference: codeRef,
      accessCode: accessCode,
      parentName: savedParentName.isEmpty ? parentName : savedParentName,
      parentPhone: savedParentPhone.isEmpty ? cleanParentPhone : savedParentPhone,
      usesSharedAccessCode: linkedChildIds.length > 1,
    );
  }


  String _childTypeLabel(Map<String, dynamic> data) {
    final childStatus = _cleanText(data['childStatus']).toLowerCase();
    final accountStatus = _cleanText(data['accountStatus']).toLowerCase();
    final childType = _cleanText(data['childType']).toLowerCase();

    if (childStatus == 'trial_pending_decision') {
      return 'بانتظار قرار التجربة';
    }

    if (childStatus == 'rejected_after_trial') {
      return 'مؤرشف بعد التجربة';
    }

    if (childStatus == 'archived' || accountStatus == 'archived') {
      return 'مؤرشف';
    }

    switch (childType.isNotEmpty ? childType : childStatus) {
      case 'temporary':
        return 'طفل زائر';
      case 'trial':
        return 'طفل تجربة';
      default:
        return '';
    }
  }

    Future<void> _updateGroupCount() async {
    final isAdmin = await _isCurrentUserAdmin();

    if (!isAdmin) return;

    final count = await _firestore
        .collection('children')
        .where('groupId', isEqualTo: widget.groupId)
        .where('isActive', isEqualTo: true)
        .get();

    await _firestore.collection('groups').doc(widget.groupId).update({
      'currentChildrenCount': count.docs.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _pickTemporaryProfileBirthDate({
    required _TemporaryChildProfileDraft profile,
    required StateSetter setSheetState,
    required BuildContext context,
  }) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: profile.birthDate ?? DateTime(now.year - 2),
      firstDate: DateTime(2015),
      lastDate: now,
    );

    if (picked == null) return;

    setSheetState(() {
      profile.birthDate = picked;
    });
  }

  Future<void> _showSheetValidationError(
    BuildContext sheetContext,
    String message,
  ) async {
    if (!sheetContext.mounted) return;

    await showDialog<void>(
      context: sheetContext,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تنبيه'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('تم'),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _temporaryProfileValidationError(
    _TemporaryChildProfileDraft profile,
  ) {
    if (profile.birthDate == null) {
      return 'اختر تاريخ ميلاد الطفل';
    }

    for (final pickup in profile.pickupContacts) {
      if (!pickup.isValid()) {
        return 'تأكد من تعبئة بيانات الشخص المخوّل بالاستلام';
      }

      if (!_isValidPalestinianMobile(pickup.phoneCtrl.text)) {
        return 'رقم المخوّل بالاستلام يجب أن يكون 10 أرقام ويبدأ بـ 059 أو 056 أو 052';
      }
    }

    return null;
  }

  Widget _buildTemporaryProfileFields({
    required _TemporaryChildProfileDraft profile,
    required StateSetter setSheetState,
    required BuildContext sheetContext,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: profile.gender,
          decoration: const InputDecoration(
            labelText: 'الجنس',
            prefixIcon: Icon(Icons.wc_rounded),
          ),
          items: const [
            DropdownMenuItem(value: 'female', child: Text('أنثى')),
            DropdownMenuItem(value: 'male', child: Text('ذكر')),
          ],
          onChanged: (value) {
            setSheetState(() {
              profile.gender = value ?? 'female';
            });
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _pickTemporaryProfileBirthDate(
              profile: profile,
              setSheetState: setSheetState,
              context: sheetContext,
            ),
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(
              profile.birthDate == null
                  ? 'تاريخ الميلاد'
                  : _formatDate(profile.birthDate!),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'البيانات الصحية',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
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
            labelText: 'ملاحظات صحية ',
            prefixIcon: Icon(Icons.health_and_safety_rounded),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'المخولون بالاستلام',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(profile.pickupContacts.length, (index) {
          final pickup = profile.pickupContacts[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
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
              profile.pickupContacts.add(_TemporaryPickupDraft());
            });
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة شخص مخوّل آخر'),
        ),
      ],
    );
  }

  Future<void> _openAddTemporaryChildSheet() async {
    final childNameCtrl = TextEditingController();
    final parentNameCtrl = TextEditingController();
    final parentPhoneCtrl = TextEditingController();
    final hoursCountCtrl = TextEditingController(text: '1');
    final hourlyRateCtrl = TextEditingController(text: '10');
    final paidAmountCtrl = TextEditingController(text: '0');
    final profile = _TemporaryChildProfileDraft();
    final siblingCodesFuture = _loadSiblingAccessCodeOptions();
    final officialParentsFuture = _loadActiveParentAccounts();

    DateTime accessStart = DateTime.now();
    DateTime accessEnd = DateTime.now().add(const Duration(days: 1));

    const billingType = 'hourly';
    bool linkWithSiblings = false;
    bool linkWithOfficialParent = false;
    String selectedSharedAccessCodeId = '';
    String selectedOfficialParentUid = '';
    bool isSaving = false;

    num calculateFinalAmount() {
      return _parseMoney(hoursCountCtrl.text) *
          _parseMoney(hourlyRateCtrl.text);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        Future<void> pickStartDate(StateSetter setSheetState) async {
          final picked = await showDatePicker(
            context: sheetContext,
            initialDate: accessStart,
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
          );

          if (picked == null) return;

          setSheetState(() {
            accessStart = picked;
            if (accessEnd.isBefore(accessStart)) {
              accessEnd = accessStart;
            }
          });
        }

        Future<void> pickEndDate(StateSetter setSheetState) async {
          final picked = await showDatePicker(
            context: sheetContext,
            initialDate: accessEnd,
            firstDate: accessStart,
            lastDate: DateTime(2035),
          );

          if (picked == null) return;

          setSheetState(() {
            accessEnd = picked;
          });
        }

        Widget moneySummary() {
          final finalAmount = calculateFinalAmount();
          final paidAmount = _parseMoney(paidAmountCtrl.text);
          final remainingAmount =
              (finalAmount - paidAmount) < 0 ? 0 : finalAmount - paidAmount;

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملخص الفاتورة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('الإجمالي: $finalAmount شيكل'),
                Text('المدفوع: $paidAmount شيكل'),
                Text('المتبقي: $remainingAmount شيكل'),
              ],
            ),
          );
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final finalAmount = calculateFinalAmount();
              final paidAmount = _parseMoney(paidAmountCtrl.text);
              final remainingAmount =
                  (finalAmount - paidAmount) < 0 ? 0 : finalAmount - paidAmount;

              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: sheetBottomSafePadding(sheetContext),
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
                        'طفل زائر',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: childNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم الطفل',
                          prefixIcon: Icon(Icons.child_care_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: parentNameCtrl,
                        enabled: !linkWithSiblings && !linkWithOfficialParent,
                        decoration: const InputDecoration(
                          labelText: 'اسم ولي الأمر',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: parentPhoneCtrl,
                        enabled: !linkWithSiblings && !linkWithOfficialParent,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم ولي الأمر',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      _buildOfficialParentLinkFields(
                        linkWithOfficialParent: linkWithOfficialParent,
                        selectedOfficialParentUid: selectedOfficialParentUid,
                        officialParentsFuture: officialParentsFuture,
                        onToggle: (value) {
                          setSheetState(() {
                            linkWithOfficialParent = value;
                            selectedOfficialParentUid = '';

                            if (value) {
                              linkWithSiblings = false;
                              selectedSharedAccessCodeId = '';
                              parentNameCtrl.clear();
                              parentPhoneCtrl.clear();
                            }
                          });
                        },
                        onSelected: (parentDoc) {
                          setSheetState(() {
                            selectedOfficialParentUid = parentDoc?.id ?? '';

                            if (parentDoc == null) {
                              parentNameCtrl.clear();
                              parentPhoneCtrl.clear();
                              return;
                            }

                            final data = parentDoc.data();
                            parentNameCtrl.text = _officialParentName(data);
                            parentPhoneCtrl.text = _officialParentPhone(data);
                          });
                        },
                      ),
                      if (!linkWithOfficialParent)
                      _buildSiblingAccessCodeFields(
                        linkWithSiblings: linkWithSiblings,
                        selectedSharedAccessCodeId: selectedSharedAccessCodeId,
                        optionsFuture: siblingCodesFuture,
                        onToggle: (value) {
                          setSheetState(() {
                            linkWithSiblings = value;
                            selectedSharedAccessCodeId = '';
                            if (value) {
                              linkWithOfficialParent = false;
                              selectedOfficialParentUid = '';
                              parentNameCtrl.clear();
                              parentPhoneCtrl.clear();
                            }
                          });
                        },
                        onSelected: (option) {
                          setSheetState(() {
                            selectedSharedAccessCodeId = option?.id ?? '';
                            parentNameCtrl.text = option?.parentName ?? '';
                            parentPhoneCtrl.text = option?.parentPhone ?? '';
                          });
                        },
                      ),
                      _buildTemporaryProfileFields(
                        profile: profile,
                        setSheetState: setSheetState,
                        sheetContext: sheetContext,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickStartDate(setSheetState),
                              icon: const Icon(Icons.event_outlined),
                              label: Text(_formatDate(accessStart)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickEndDate(setSheetState),
                              icon: const Icon(Icons.event_available_outlined),
                              label: Text(_formatDate(accessEnd)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'الفاتورة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: hoursCountCtrl,
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
                        controller: paidAmountCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'المدفوع',
                          prefixIcon: Icon(Icons.done_all_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      moneySummary(),
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
                                      parentPhoneCtrl.text.trim();

                                  if (childName.isEmpty) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'اكتب اسم الطفل',
                                    );
                                    return;
                                  }

                                  if (linkWithOfficialParent &&
                                      selectedOfficialParentUid.isEmpty) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'اختر حساب ولي الأمر الرسمي',
                                    );
                                    return;
                                  }

                                  if (!linkWithOfficialParent &&
                                      parentName.isEmpty) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'اكتب اسم ولي الأمر',
                                    );
                                    return;
                                  }

                                  if (!linkWithOfficialParent &&
                                      parentPhone.isEmpty) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'اكتب رقم ولي الأمر',
                                    );
                                    return;
                                  }

                                  if (!linkWithOfficialParent &&
                                      !_isValidPalestinianMobile(parentPhone)) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'رقم ولي الأمر يجب أن يكون 10 أرقام ويبدأ بـ 059 أو 056 أو 052',
                                    );
                                    return;
                                  }

                                  if (!linkWithOfficialParent &&
                                      linkWithSiblings &&
                                      selectedSharedAccessCodeId.isEmpty) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'اختر كود الإخوة',
                                    );
                                    return;
                                  }

                                  if (finalAmount <= 0) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'أدخل قيمة فاتورة صحيحة',
                                    );
                                    return;
                                  }

                                  final profileError =
                                      _temporaryProfileValidationError(profile);

                                  if (profileError != null) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      profileError,
                                    );
                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                  });

                                  final result = await _saveTemporaryChild(
                                    childName: childName,
                                    parentName: parentName,
                                    parentPhone: parentPhone,
                                    accessStart: accessStart,
                                    accessEnd: accessEnd,
                                    billingType: billingType,
                                    hoursCount: _parseMoney(hoursCountCtrl.text),
                                    daysCount: 0,
                                    hourlyRate: _parseMoney(hourlyRateCtrl.text),
                                    dailyRate: 0,
                                    baseAmount: finalAmount,
                                    finalAmount: finalAmount,
                                    paidAmount: paidAmount,
                                    remainingAmount: remainingAmount,
                                    paymentMethod: 'cash',
                                    notes: '',
                                    profileFields: profile.toChildFields(),
                                    officialParentUid: linkWithOfficialParent
                                        ? selectedOfficialParentUid
                                        : '',
                                    sharedAccessCodeId: linkWithOfficialParent
                                        ? ''
                                        : linkWithSiblings
                                            ? selectedSharedAccessCodeId
                                            : '',
                                  );

                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);

                                  if (!mounted || result == null) return;

                                  if (result.linkedToOfficialParentAccount) {
                                    await _showOfficialParentLinkedDialog(
                                      childName: childName,
                                      parentName: result.officialParentName,
                                    );
                                  } else {
                                    await _showTemporaryAccessDialog(
                                      code: result.accessCode,
                                      childName: childName,
                                      accessEnd: accessEnd,
                                      usesSharedAccessCode:
                                          result.usesSharedAccessCode,
                                    );
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

    profile.dispose();
  }
  Future<_TemporaryChildResult?> _saveTemporaryChild({
    required String childName,
    required String parentName,
    required String parentPhone,
    required DateTime accessStart,
    required DateTime accessEnd,
    required String billingType,
    required num hoursCount,
    required num daysCount,
    required num hourlyRate,
    required num dailyRate,
    required num baseAmount,
    required num finalAmount,
    required num paidAmount,
    required num remainingAmount,
    required String paymentMethod,
    required String notes,
    required Map<String, dynamic> profileFields,
    String officialParentUid = '',
    required String sharedAccessCodeId,
  }) async {
    try {
      final cleanParentPhone = _normalizePhone(parentPhone);

      final possibleExistingChildren =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

      if (cleanParentPhone.isNotEmpty) {
        final byPhoneSnapshot = await _firestore
            .collection('children')
            .where('parentPhone', isEqualTo: cleanParentPhone)
            .get();

        for (final doc in byPhoneSnapshot.docs) {
          possibleExistingChildren[doc.id] = doc;
        }
      }

      final cleanOfficialParentUid = officialParentUid.trim();

      if (cleanOfficialParentUid.isNotEmpty) {
        final byParentUidSnapshot = await _firestore
            .collection('children')
            .where('parentUid', isEqualTo: cleanOfficialParentUid)
            .get();

        for (final doc in byParentUidSnapshot.docs) {
          possibleExistingChildren[doc.id] = doc;
        }
      }

      QueryDocumentSnapshot<Map<String, dynamic>>? existingChildDoc;

      for (final doc in possibleExistingChildren.values) {
        final data = doc.data();
        final existingName = _normalizeName(
          _cleanText(data['name']).isNotEmpty
              ? _cleanText(data['name'])
              : _cleanText(data['childName']),
        );

        if (existingName == _normalizeName(childName)) {
          existingChildDoc = doc;
          break;
        }
      }

      if (existingChildDoc != null &&
          _isPermanentChildData(existingChildDoc.data())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'هذا الطفل مسجل بالفعل في الحضانة، لا يمكن إضافته كزائر.',
              ),
            ),
          );
        }
        return null;
      }

      final existingChildData =
          existingChildDoc?.data() ?? <String, dynamic>{};

      final childRef = existingChildDoc?.reference ??
          _firestore.collection('children').doc();
      final invoiceRef = _firestore.collection('invoices').doc();

      final accessStartDate = DateTime(
        accessStart.year,
        accessStart.month,
        accessStart.day,
      );
      final accessEndDate = DateTime(
        accessEnd.year,
        accessEnd.month,
        accessEnd.day,
        23,
        59,
        59,
      );
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final status = _invoiceStatus(
        finalAmount: finalAmount,
        paidAmount: paidAmount,
      );
      final batch = _firestore.batch();

      final officialParent = await _findActiveOfficialParentAccount(
        parentUid: officialParentUid.trim().isNotEmpty
            ? officialParentUid.trim()
            : _cleanText(existingChildData['parentUid']),
        parentUsername: _cleanText(existingChildData['parentUsername']),
        parentPhone: cleanParentPhone,
      );

      _PreparedAccessCode? preparedCode;

      if (officialParent != null) {
        if (existingChildDoc != null) {
          await _deactivateOldTemporaryAccess(
            childId: childRef.id,
            batch: batch,
          );
        }
      } else {
        preparedCode = await _prepareAccessCode(
          sharedAccessCodeId: sharedAccessCodeId,
          childRef: childRef,
          childName: childName,
          childType: 'temporary',
          parentName: parentName,
          cleanParentPhone: cleanParentPhone,
          accessStartDate: accessStartDate,
          accessEndDate: accessEndDate,
          adminUid: adminUid,
          batch: batch,
        );

        if (preparedCode == null) return null;
      }

      final resolvedParentName =
          officialParent != null ? officialParent.name : preparedCode?.parentName ?? parentName;
      final resolvedParentPhone = officialParent != null
          ? (officialParent.phone.isNotEmpty ? officialParent.phone : cleanParentPhone)
          : preparedCode?.parentPhone ?? parentPhone;

      final childData = <String, dynamic>{
        'id': childRef.id,
        'childId': childRef.id,
        'name': childName,
        'childName': childName,
        ...profileFields,
        'childType': 'temporary',
        'childStatus': 'temporary',
        'enrollmentType': 'temporary',
        'isTemporaryChild': true,
        'isTrialChild': false,
        'isActive': true,
        'status': 'active',
        'accountStatus': 'active',
        'canReactivate': true,
        'permanentDeleted': false,
        'isBillable': true,
        'excludeFromMonthlyInvoice': true,
        if (officialParent != null) ...{
          'parentUid': officialParent.uid,
          'parentUsername': officialParent.username,
          'parentName': resolvedParentName,
          'parentPhone': resolvedParentPhone,
          'temporaryParentUid': '',
          'temporaryParentUsername': '',
          'temporaryParentName': '',
          'temporaryParentPhone': '',
          'accessMode': 'parent_account',
          'usesTemporaryAccessCode': false,
          'temporaryAccessCodeId': '',
          'sharedAccessCodeId': '',
          'temporaryAccessCode': '',
          'usesSharedAccessCode': false,
        } else ...{
          'parentUid': '',
          'parentUsername': '',
          'parentName': resolvedParentName,
          'parentPhone': resolvedParentPhone,
          'temporaryParentUid': '',
          'temporaryParentUsername': '',
          'temporaryParentName': resolvedParentName,
          'temporaryParentPhone': resolvedParentPhone,
          'accessMode': 'temporary_code',
          'usesTemporaryAccessCode': true,
          'temporaryAccessCodeId': preparedCode?.reference.id ?? '',
          'sharedAccessCodeId': preparedCode?.reference.id ?? '',
          'usesSharedAccessCode': preparedCode?.usesSharedAccessCode ?? false,
          'temporaryAccessCode': preparedCode?.accessCode ?? '',
        },
        'groupId': widget.groupId,
        'groupName': widget.groupName,
        'assignedStaffUid': widget.assignedStaffUid,
        'assignedStaffName': widget.assignedStaffName,
        'assignedStaffUsername': widget.assignedStaffUsername,
        'temporaryStartDate': Timestamp.fromDate(accessStartDate),
        'temporaryEndDate': Timestamp.fromDate(accessEndDate),
        'temporaryDateKeys': [
          _dateKey(accessStartDate),
          _dateKey(accessEndDate),
        ],
        'temporaryFee': finalAmount,
        'temporaryBillingType': billingType,
        'temporaryBillingTypeLabel': _billingTypeLabel(billingType),
        'hasConsultation': false,
        'consultationId': '',
        'consultationStatus': 'none',
        'temporaryAccessStartAt': Timestamp.fromDate(accessStartDate),
        'temporaryAccessEndAt': Timestamp.fromDate(accessEndDate),
        'updatedByUid': adminUid,
        'updatedByRole': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
        'reactivatedAt': FieldValue.serverTimestamp(),
        'archiveReason': '',
        'archivedAt': '',
      };

      if (existingChildDoc == null) {
        childData['createdByUid'] = adminUid;
        childData['createdByRole'] = 'admin';
        childData['createdAt'] = FieldValue.serverTimestamp();
      }

      batch.set(childRef, childData, SetOptions(merge: true));
      batch.set(invoiceRef, {
        'id': invoiceRef.id,
        'invoiceId': invoiceRef.id,
        'title': 'فاتورة الطفل الزائر',
        'childId': childRef.id,
        'childName': childName,
        'childType': 'temporary',
        'parentUid': officialParent?.uid ?? '',
        'parentUsername': officialParent?.username ?? '',
        'parentName': resolvedParentName,
        'parentPhone': resolvedParentPhone,
        'temporaryParentName': officialParent == null ? resolvedParentName : '',
        'temporaryParentPhone': officialParent == null ? resolvedParentPhone : '',
        'groupId': widget.groupId,
        'groupName': widget.groupName,
        if (officialParent != null) ...{
          'accessMode': 'parent_account',
          'usesTemporaryAccessCode': false,
        } else ...{
          'accessMode': 'temporary_code',
          'usesTemporaryAccessCode': true,
          'temporaryAccessCodeId': preparedCode?.reference.id ?? '',
          'sharedAccessCodeId': preparedCode?.reference.id ?? '',
        },
        'billingType': billingType,
        'billingTypeLabel': _billingTypeLabel(billingType),
        'hoursCount': billingType == 'hourly' ? hoursCount : 0,
        'daysCount': billingType == 'daily' ? daysCount : 0,
        'hourlyRate': billingType == 'hourly' ? hourlyRate : 0,
        'dailyRate': billingType == 'daily' ? dailyRate : 0,
        'baseAmount': baseAmount,
        'discount': 0,
        'discountAmount': 0,
        'finalAmount': finalAmount,
        'totalAmount': finalAmount,
        'paidAmount': paidAmount,
        'remainingAmount': remainingAmount,
        'paymentMethod': paymentMethod,
        'paymentMethodLabel': _paymentMethodLabel(paymentMethod),
        'status': status,
        'invoiceDate': FieldValue.serverTimestamp(),
        'accessStartAt': Timestamp.fromDate(accessStartDate),
        'accessEndAt': Timestamp.fromDate(accessEndDate),
        'createdByUid': adminUid,
        'createdByRole': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      await _updateGroupCount();

      return _TemporaryChildResult(
        accessCode: officialParent != null ? '' : preparedCode?.accessCode ?? '',
        usesSharedAccessCode:
            officialParent != null ? false : preparedCode?.usesSharedAccessCode ?? false,
        linkedToOfficialParentAccount: officialParent != null,
        officialParentName: officialParent?.name ?? '',
      );
    } catch (e) {
      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الطفل الزائر: $e')),
      );
      return null;
    }
  }
  Future<_TemporaryChildResult?> _saveTrialChild({
    required String childName,
    required String parentName,
    required String parentPhone,
    required DateTime trialStart,
    required Map<String, dynamic> profileFields,
    String officialParentUid = '',
    required String sharedAccessCodeId,
  }) async {
    try {
      final cleanParentPhone = _normalizePhone(parentPhone);
      final possibleExistingChildren =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

      if (cleanParentPhone.isNotEmpty) {
        final byPhoneSnapshot = await _firestore
            .collection('children')
            .where('parentPhone', isEqualTo: cleanParentPhone)
            .get();

        for (final doc in byPhoneSnapshot.docs) {
          possibleExistingChildren[doc.id] = doc;
        }
      }

      final cleanOfficialParentUid = officialParentUid.trim();

      if (cleanOfficialParentUid.isNotEmpty) {
        final byParentUidSnapshot = await _firestore
            .collection('children')
            .where('parentUid', isEqualTo: cleanOfficialParentUid)
            .get();

        for (final doc in byParentUidSnapshot.docs) {
          possibleExistingChildren[doc.id] = doc;
        }
      }

      QueryDocumentSnapshot<Map<String, dynamic>>? existingChildDoc;

      for (final doc in possibleExistingChildren.values) {
        final data = doc.data();
        final existingName = _normalizeName(
          _cleanText(data['name']).isNotEmpty
              ? _cleanText(data['name'])
              : _cleanText(data['childName']),
        );

        if (existingName == _normalizeName(childName)) {
          existingChildDoc = doc;
          break;
        }
      }

      if (existingChildDoc != null) {
        final existingData = existingChildDoc.data();
        final existingStatus =
            _cleanText(existingData['childStatus']).toLowerCase();

        if (_isPermanentChildData(existingData)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'هذا الطفل مسجل بالفعل في الحضانة، لا يمكن إضافته كتجربة.',
                ),
              ),
            );
          }
          return null;
        }

        if (existingData['trialUsed'] == true ||
            existingData['canStartNewTrial'] == false ||
            _isTrialChild(existingData) ||
            existingStatus == 'trial_pending_decision' ||
            existingStatus == 'rejected_after_trial') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'هذا الطفل استخدم فترة التجربة سابقًا. استخدم استعادة من سجل الطفل الموجود لاعتماده رسميًا.',
                ),
              ),
            );
          }
          return null;
        }
      }

      final existingChildData =
          existingChildDoc?.data() ?? <String, dynamic>{};

      final childRef = existingChildDoc?.reference ??
          _firestore.collection('children').doc();
      final trialStartDate = DateTime(
        trialStart.year,
        trialStart.month,
        trialStart.day,
      );
      final trialEndDate = _trialEndFromStart(trialStartDate);
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final batch = _firestore.batch();

      final officialParent = await _findActiveOfficialParentAccount(
        parentUid: officialParentUid.trim().isNotEmpty
            ? officialParentUid.trim()
            : _cleanText(existingChildData['parentUid']),
        parentUsername: _cleanText(existingChildData['parentUsername']),
        parentPhone: cleanParentPhone,
      );

      _PreparedAccessCode? preparedCode;

      if (officialParent != null) {
        if (existingChildDoc != null) {
          await _deactivateOldTemporaryAccess(
            childId: childRef.id,
            batch: batch,
          );
        }
      } else {
        String resolvedSharedAccessCodeId = sharedAccessCodeId.trim();

        if (resolvedSharedAccessCodeId.isEmpty && existingChildDoc != null) {
          final existingData = existingChildDoc.data();
          final existingCodeId = _cleanText(
            existingData['sharedAccessCodeId'] ??
                existingData['temporaryAccessCodeId'],
          );

          if (existingCodeId.isNotEmpty) {
            final existingCodeDoc = await _firestore
                .collection('temporary_access_codes')
                .doc(existingCodeId)
                .get();

            if (existingCodeDoc.exists &&
                existingCodeDoc.data()?['isActive'] == true) {
              resolvedSharedAccessCodeId = existingCodeId;
            }
          }
        }

        preparedCode = await _prepareAccessCode(
          sharedAccessCodeId: resolvedSharedAccessCodeId,
          childRef: childRef,
          childName: childName,
          childType: 'trial',
          parentName: parentName,
          cleanParentPhone: cleanParentPhone,
          accessStartDate: trialStartDate,
          accessEndDate: trialEndDate,
          adminUid: adminUid,
          batch: batch,
        );

        if (preparedCode == null) return null;
      }

      final resolvedParentName =
          officialParent != null ? officialParent.name : preparedCode?.parentName ?? parentName;
      final resolvedParentPhone =
          officialParent != null ? officialParent.phone : preparedCode?.parentPhone ?? parentPhone;

      final childData = <String, dynamic>{
        'id': childRef.id,
        'childId': childRef.id,
        'name': childName,
        'childName': childName,
        ...profileFields,
        'childType': 'trial',
        'enrollmentType': 'trial',
        'childStatus': 'trial',
        'isTemporaryChild': false,
        'isTrialChild': true,
        'isActive': true,
        'status': 'active',
        'accountStatus': 'active',
        'canReactivate': true,
        'permanentDeleted': false,
        'isBillable': false,
        'excludeFromMonthlyInvoice': true,
        'trialIsFree': true,
        'trialDays': 3,
        'trialUsed': true,
        'canStartNewTrial': false,
        if (officialParent != null) ...{
          'parentUid': officialParent.uid,
          'parentUsername': officialParent.username,
          'parentName': resolvedParentName,
          'parentPhone': resolvedParentPhone,
          'temporaryParentUid': '',
          'temporaryParentUsername': '',
          'temporaryParentName': '',
          'temporaryParentPhone': '',
          'accessMode': 'parent_account',
          'usesTemporaryAccessCode': false,
          'temporaryAccessCodeId': '',
          'sharedAccessCodeId': '',
          'temporaryAccessCode': '',
          'usesSharedAccessCode': false,
        } else ...{
          'parentUid': '',
          'parentUsername': '',
          'parentName': resolvedParentName,
          'parentPhone': resolvedParentPhone,
          'temporaryParentUid': '',
          'temporaryParentUsername': '',
          'temporaryParentName': resolvedParentName,
          'temporaryParentPhone': resolvedParentPhone,
          'accessMode': 'temporary_code',
          'usesTemporaryAccessCode': true,
          'temporaryAccessCodeId': preparedCode?.reference.id ?? '',
          'sharedAccessCodeId': preparedCode?.reference.id ?? '',
          'usesSharedAccessCode': preparedCode?.usesSharedAccessCode ?? false,
          'temporaryAccessCode': preparedCode?.accessCode ?? '',
        },
        'groupId': widget.groupId,
        'groupName': widget.groupName,
        'assignedStaffUid': widget.assignedStaffUid,
        'assignedStaffName': widget.assignedStaffName,
        'assignedStaffUsername': widget.assignedStaffUsername,
        'trialStartAt': Timestamp.fromDate(trialStartDate),
        'trialEndAt': Timestamp.fromDate(trialEndDate),
        'temporaryAccessStartAt': Timestamp.fromDate(trialStartDate),
        'temporaryAccessEndAt': Timestamp.fromDate(trialEndDate),
        'hasConsultation': false,
        'consultationId': '',
        'consultationStatus': 'none',
        'updatedByUid': adminUid,
        'updatedByRole': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
        'reactivatedAt': FieldValue.serverTimestamp(),
        'archiveReason': '',
        'archivedAt': '',
      };

      if (existingChildDoc == null) {
        childData['createdByUid'] = adminUid;
        childData['createdByRole'] = 'admin';
        childData['createdAt'] = FieldValue.serverTimestamp();
      }

      batch.set(childRef, childData, SetOptions(merge: true));
      await batch.commit();
      await _updateGroupCount();

      return _TemporaryChildResult(
        accessCode: officialParent != null ? '' : preparedCode?.accessCode ?? '',
        usesSharedAccessCode:
            officialParent != null ? false : preparedCode?.usesSharedAccessCode ?? false,
        linkedToOfficialParentAccount: officialParent != null,
        officialParentName: officialParent?.name ?? '',
      );
    } catch (e) {
      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ طفل التجربة: $e')),
      );
      return null;
    }
  }

  Future<void> _openAddTrialChildSheet() async {
    final childNameCtrl = TextEditingController();
    final parentNameCtrl = TextEditingController();
    final parentPhoneCtrl = TextEditingController();
    final profile = _TemporaryChildProfileDraft();
    final siblingCodesFuture = _loadSiblingAccessCodeOptions();
    final officialParentsFuture = _loadActiveParentAccounts();

    DateTime trialStart = DateTime.now();
    bool linkWithSiblings = false;
    bool linkWithOfficialParent = false;
    String selectedSharedAccessCodeId = '';
    String selectedOfficialParentUid = '';
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        Future<void> pickStartDate(StateSetter setSheetState) async {
          final picked = await showDatePicker(
            context: sheetContext,
            initialDate: trialStart,
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
          );

          if (picked == null) return;

          setSheetState(() {
            trialStart = picked;
          });
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final trialEnd = _trialEndFromStart(trialStart);

              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: sheetBottomSafePadding(sheetContext),
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
                        'طفل تجربة',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: childNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم الطفل',
                          prefixIcon: Icon(Icons.child_care_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: parentNameCtrl,
                        enabled: !linkWithSiblings && !linkWithOfficialParent,
                        decoration: const InputDecoration(
                          labelText: 'اسم ولي الأمر',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: parentPhoneCtrl,
                        enabled: !linkWithSiblings && !linkWithOfficialParent,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم ولي الأمر',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      _buildOfficialParentLinkFields(
                        linkWithOfficialParent: linkWithOfficialParent,
                        selectedOfficialParentUid: selectedOfficialParentUid,
                        officialParentsFuture: officialParentsFuture,
                        onToggle: (value) {
                          setSheetState(() {
                            linkWithOfficialParent = value;
                            selectedOfficialParentUid = '';

                            if (value) {
                              linkWithSiblings = false;
                              selectedSharedAccessCodeId = '';
                              parentNameCtrl.clear();
                              parentPhoneCtrl.clear();
                            }
                          });
                        },
                        onSelected: (parentDoc) {
                          setSheetState(() {
                            selectedOfficialParentUid = parentDoc?.id ?? '';

                            if (parentDoc == null) {
                              parentNameCtrl.clear();
                              parentPhoneCtrl.clear();
                              return;
                            }

                            final data = parentDoc.data();
                            parentNameCtrl.text = _officialParentName(data);
                            parentPhoneCtrl.text = _officialParentPhone(data);
                          });
                        },
                      ),
                      if (!linkWithOfficialParent)
                      _buildSiblingAccessCodeFields(
                        linkWithSiblings: linkWithSiblings,
                        selectedSharedAccessCodeId: selectedSharedAccessCodeId,
                        optionsFuture: siblingCodesFuture,
                        onToggle: (value) {
                          setSheetState(() {
                            linkWithSiblings = value;
                            selectedSharedAccessCodeId = '';
                            if (value) {
                              linkWithOfficialParent = false;
                              selectedOfficialParentUid = '';
                              parentNameCtrl.clear();
                              parentPhoneCtrl.clear();
                            }
                          });
                        },
                        onSelected: (option) {
                          setSheetState(() {
                            selectedSharedAccessCodeId = option?.id ?? '';
                            parentNameCtrl.text = option?.parentName ?? '';
                            parentPhoneCtrl.text = option?.parentPhone ?? '';
                          });
                        },
                      ),
                      _buildTemporaryProfileFields(
                        profile: profile,
                        setSheetState: setSheetState,
                        sheetContext: sheetContext,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickStartDate(setSheetState),
                              icon: const Icon(Icons.event_outlined),
                              label: Text(_formatDate(trialStart)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.event_available_outlined),
                              label: Text(_formatDate(trialEnd)),
                            ),
                          ),
                        ],
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
                                  final parentPhone = parentPhoneCtrl.text.trim();

                                  if (childName.isEmpty) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'اكتب اسم الطفل',
                                    );
                                    return;
                                  }

                                  if (linkWithOfficialParent &&
                                      selectedOfficialParentUid.isEmpty) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'اختر حساب ولي الأمر الرسمي',
                                    );
                                    return;
                                  }

                                  if (!linkWithOfficialParent &&
                                      parentName.isEmpty) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'اكتب اسم ولي الأمر',
                                    );
                                    return;
                                  }

                                  if (!linkWithOfficialParent &&
                                      parentPhone.isEmpty) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'اكتب رقم ولي الأمر',
                                    );
                                    return;
                                  }

                                  if (!linkWithOfficialParent &&
                                      !_isValidPalestinianMobile(parentPhone)) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'رقم ولي الأمر يجب أن يكون 10 أرقام ويبدأ بـ 059 أو 056 أو 052',
                                    );
                                    return;
                                  }

                                  if (!linkWithOfficialParent &&
                                      linkWithSiblings &&
                                      selectedSharedAccessCodeId.isEmpty) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'اختر كود الإخوة',
                                    );
                                    return;
                                  }

                                  final profileError =
                                      _temporaryProfileValidationError(profile);

                                  if (profileError != null) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      profileError,
                                    );
                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                  });

                                  final result = await _saveTrialChild(
                                    childName: childName,
                                    parentName: parentName,
                                    parentPhone: parentPhone,
                                    trialStart: trialStart,
                                    profileFields: profile.toChildFields(),
                                    officialParentUid: linkWithOfficialParent
                                        ? selectedOfficialParentUid
                                        : '',
                                    sharedAccessCodeId: linkWithOfficialParent
                                        ? ''
                                        : linkWithSiblings
                                            ? selectedSharedAccessCodeId
                                            : '',
                                  );

                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);

                                  if (!mounted || result == null) return;

                                  final trialEnd = _trialEndFromStart(trialStart);

                                  if (result.linkedToOfficialParentAccount) {
                                    await _showOfficialParentLinkedDialog(
                                      childName: childName,
                                      parentName: result.officialParentName,
                                    );
                                  } else {
                                    await _showTemporaryAccessDialog(
                                      code: result.accessCode,
                                      childName: childName,
                                      accessEnd: trialEnd,
                                      usesSharedAccessCode:
                                          result.usesSharedAccessCode,
                                    );
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

    profile.dispose();
  }

  Future<void> _showTemporaryAccessDialog({
    required String code,
    required String childName,
    required DateTime accessEnd,
    bool usesSharedAccessCode = false,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(
              usesSharedAccessCode
                  ? 'تم ربط الطفل بكود الإخوة'
                  : 'تم إنشاء كود الدخول',
            ),
            content: SelectableText(
              'الطفل: $childName\nالكود: $code\nالصلاحية: ${_formatDate(accessEnd)}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('تم'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showOfficialParentLinkedDialog({
    required String childName,
    required String parentName,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تم الربط بحساب ولي الأمر'),
            content: Text(
              'الطفل: $childName\nولي الأمر: $parentName\nلن يتم إنشاء كود دخول مؤقت لأن ولي الأمر لديه حساب رسمي.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('تم'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _removeChildFromGroup(String childId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إزالة الطفل'),
          content: const Text('إزالة الطفل من المجموعة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إزالة'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    await _firestore.collection('children').doc(childId).update({
      'groupId': '',
      'groupName': '',
      'assignedStaffUid': '',
      'assignedStaffName': '',
      'assignedStaffUsername': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _updateGroupCount();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إزالة الطفل')),
    );
  }

  Future<void> _archiveChild({
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
  }) async {
    final data = childDoc.data() ?? <String, dynamic>{};

    if (!_isTemporaryChild(data) && !_isTrialChild(data)) return;

    final isTrial = _isTrialChild(data);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('أرشفة الطفل'),
          content: Text(
            isTrial
                ? 'سيتم نقل طفل التجربة إلى الأرشيف مع الاحتفاظ بسجله، ويمكن اعتماده لاحقًا من خيار استعادة.'
                : 'أرشفة الطفل؟',
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
    );

    if (confirm != true) return;

    try {
      await _archiveChildRecords(
        childDoc: childDoc,
        archiveReason: isTrial
            ? 'trial_archived_pending_official_restore'
            : 'temporary_archived',
        automated: false,
      );

      await _updateGroupCount();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTrial
                ? 'تمت أرشفة طفل التجربة ويمكن اعتماده لاحقًا من استعادة'
                : 'تمت أرشفة الطفل',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر أرشفة الطفل: $e')),
      );
    }
  }

  Future<void> _reactivateArchivedChild({
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
  }) async {
    final data = childDoc.data() ?? <String, dynamic>{};

    if (_isTrialChild(data)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('طفل التجربة المؤرشف لا يمكن إعادة تفعيله'),
        ),
      );
      return;
    }

    if (_isTemporaryChild(data) && data['canReactivate'] != false) {
      await _openReactivateTemporaryChildSheet(childDoc: childDoc);
    }
  }

  Future<void> _deactivateOldTemporaryAccess({
    required String childId,
    required WriteBatch batch,
    String excludedAccessCodeId = '',
  }) async {
    final accessCodeIds = <String>{};

    final childDoc = await _firestore.collection('children').doc(childId).get();
    final childData = childDoc.data() ?? <String, dynamic>{};

    accessCodeIds.addAll([
      _cleanText(childData['temporaryAccessCodeId']),
      _cleanText(childData['sharedAccessCodeId']),
    ]);

    final legacyAccessCodesSnapshot = await _firestore
        .collection('temporary_access_codes')
        .where('childId', isEqualTo: childId)
        .get();

    for (final codeDoc in legacyAccessCodesSnapshot.docs) {
      accessCodeIds.add(codeDoc.id);
    }

    try {
      final sharedAccessCodesSnapshot = await _firestore
          .collection('temporary_access_codes')
          .where('childIds', arrayContains: childId)
          .get();

      for (final codeDoc in sharedAccessCodesSnapshot.docs) {
        accessCodeIds.add(codeDoc.id);
      }
    } catch (_) {
    }

    accessCodeIds.removeWhere(
      (value) => value.isEmpty || value == excludedAccessCodeId,
    );

    for (final codeId in accessCodeIds) {
      final codeRef =
          _firestore.collection('temporary_access_codes').doc(codeId);
      final codeDoc = await codeRef.get();

      if (!codeDoc.exists) continue;

      final codeData = codeDoc.data() ?? <String, dynamic>{};

      final linkedChildIds = <String>{
        ..._readStringList(codeData['childIds']),
        _cleanText(codeData['childId']),
      }..removeWhere((value) => value.isEmpty || value == childId);

      final siblingDocs = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final siblingId in linkedChildIds) {
        final siblingDoc =
            await _firestore.collection('children').doc(siblingId).get();
        final siblingData = siblingDoc.data();

        if (siblingDoc.exists &&
            siblingData != null &&
            !_isArchivedChild(siblingData) &&
            (_isTemporaryChild(siblingData) || _isTrialChild(siblingData))) {
          siblingDocs.add(siblingDoc);
        }
      }

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
            'status': 'superseded',
            'accountStatus': 'inactive',
            'supersededAt': FieldValue.serverTimestamp(),
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
        siblingNames.add(_childName(siblingData));

        final siblingType = _cleanText(siblingData['childType']);
        if (siblingType.isNotEmpty) siblingTypes.add(siblingType);

        final groupId = _cleanText(siblingData['groupId']);
        if (groupId.isNotEmpty) groupIds.add(groupId);

        final groupName = _cleanText(siblingData['groupName']);
        if (groupName.isNotEmpty) groupNames.add(groupName);
      }

      final primarySibling = siblingDocs.first;
      final primarySiblingData =
          primarySibling.data() ?? <String, dynamic>{};

      batch.set(
        codeRef,
        {
          'childId': primarySibling.id,
          'childName': _childName(primarySiblingData),
          'childIds': siblingIds,
          'childNames': siblingNames.toSet().toList(),
          'childTypes': siblingTypes.toList(),
          'groupId': _cleanText(primarySiblingData['groupId']),
          'groupName': _cleanText(primarySiblingData['groupName']),
          'groupIds': groupIds.toList(),
          'groupNames': groupNames.toList(),
          'hasMultipleChildren': siblingIds.length > 1,
          'usesSharedAccessCode': siblingIds.length > 1,
          'isActive': true,
          'status': 'active',
          'accountStatus': 'active',
          if (earliestStart != null)
            'accessStartAt': Timestamp.fromDate(earliestStart),
          if (latestEnd != null)
            'accessEndAt': Timestamp.fromDate(latestEnd),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      for (final siblingDoc in siblingDocs) {
        batch.set(
          siblingDoc.reference,
          {
            'sharedAccessCodeId': codeRef.id,
            'usesSharedAccessCode': siblingIds.length > 1,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    final devicesSnapshot = await _firestore
        .collection('temporary_parent_devices')
        .where('childId', isEqualTo: childId)
        .get();

    for (final deviceDoc in devicesSnapshot.docs) {
      batch.set(
        deviceDoc.reference,
        {
          'isActive': false,
          'accountStatus': 'inactive',
          'supersededAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<void> _openReactivateTemporaryChildSheet({
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
  }) async {
    final childData = childDoc.data() ?? <String, dynamic>{};

    final hoursCountCtrl = TextEditingController(
      text: _cleanText(childData['temporaryHoursCount']).isNotEmpty
          ? _cleanText(childData['temporaryHoursCount'])
          : '1',
    );

    final hourlyRateCtrl = TextEditingController(
      text: _cleanText(childData['temporaryHourlyRate']).isNotEmpty
          ? _cleanText(childData['temporaryHourlyRate'])
          : '10',
    );

    final paidAmountCtrl = TextEditingController(text: '0');

    DateTime accessStart = DateTime.now();
    DateTime accessEnd = DateTime.now().add(const Duration(days: 1));
    final temporaryParentPhone =
        _cleanText(childData['temporaryParentPhone']).isNotEmpty
            ? _cleanText(childData['temporaryParentPhone'])
            : _cleanText(childData['parentPhone']);
    final previousSharedAccessCodeId =
        _cleanText(childData['sharedAccessCodeId']).isNotEmpty
            ? _cleanText(childData['sharedAccessCodeId'])
            : _cleanText(childData['temporaryAccessCodeId']);

    final officialParent = await _findActiveOfficialParentAccount(
      parentUid: _cleanText(childData['parentUid']),
      parentUsername: _cleanText(childData['parentUsername']),
      parentPhone: temporaryParentPhone,
    );

    final siblingCodeOptions = officialParent != null
        ? <_SiblingAccessCodeOption>[]
        : await _loadSiblingAccessCodeOptions(
            parentName: _parentName(childData),
            parentPhone: temporaryParentPhone,
            excludedChildId: childDoc.id,
          );

    final siblingCodesFuture =
        Future<List<_SiblingAccessCodeOption>>.value(siblingCodeOptions);

    bool linkWithSiblings = officialParent == null && siblingCodeOptions.isNotEmpty;
    String selectedSharedAccessCodeId = '';

    if (siblingCodeOptions.any(
      (option) => option.id == previousSharedAccessCodeId,
    )) {
      selectedSharedAccessCodeId = previousSharedAccessCodeId;
    } else if (siblingCodeOptions.isNotEmpty) {
      selectedSharedAccessCodeId = siblingCodeOptions.first.id;
    }

    bool isSaving = false;

    num calculateFinalAmount() {
      return _parseMoney(hoursCountCtrl.text) *
          _parseMoney(hourlyRateCtrl.text);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        Future<void> pickStartDate(StateSetter setSheetState) async {
          final picked = await showDatePicker(
            context: sheetContext,
            initialDate: accessStart,
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
          );

          if (picked == null) return;

          setSheetState(() {
            accessStart = picked;
            if (accessEnd.isBefore(accessStart)) {
              accessEnd = accessStart;
            }
          });
        }

        Future<void> pickEndDate(StateSetter setSheetState) async {
          final picked = await showDatePicker(
            context: sheetContext,
            initialDate: accessEnd,
            firstDate: accessStart,
            lastDate: DateTime(2035),
          );

          if (picked == null) return;

          setSheetState(() {
            accessEnd = picked;
          });
        }

        Widget moneySummary() {
          final finalAmount = calculateFinalAmount();
          final paidAmount = _parseMoney(paidAmountCtrl.text);
          final remainingAmount =
              (finalAmount - paidAmount) < 0 ? 0 : finalAmount - paidAmount;

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملخص الفاتورة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('الإجمالي: $finalAmount شيكل'),
                Text('المدفوع: $paidAmount شيكل'),
                Text('المتبقي: $remainingAmount شيكل'),
              ],
            ),
          );
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: sheetBottomSafePadding(sheetContext),
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
                        'إعادة تفعيل الطفل الزائر',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      if (officialParent != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Text(
                            'سيتم ربط الطفل بحساب ولي الأمر الرسمي (${officialParent.name}) بدون إنشاء كود دخول مؤقت.',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (siblingCodeOptions.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  AppColors.primary.withValues(alpha: 0.16),
                            ),
                          ),
                          child: const Text(
                            'تم العثور على إخوة غير مؤرشفين لنفس ولي الأمر. سيتم ربط الطفل المستعاد بنفس كود الدخول تلقائيًا.',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildSiblingAccessCodeFields(
                        linkWithSiblings: linkWithSiblings,
                        selectedSharedAccessCodeId: selectedSharedAccessCodeId,
                        optionsFuture: siblingCodesFuture,
                        onToggle: (value) {
                          setSheetState(() {
                            if (siblingCodeOptions.isNotEmpty) {
                              linkWithSiblings = true;
                              selectedSharedAccessCodeId =
                                  selectedSharedAccessCodeId.isNotEmpty
                                      ? selectedSharedAccessCodeId
                                      : siblingCodeOptions.first.id;
                              return;
                            }

                            linkWithSiblings = value;
                            if (!value) selectedSharedAccessCodeId = '';
                          });
                        },
                        onSelected: (option) {
                          setSheetState(() {
                            selectedSharedAccessCodeId = option?.id ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickStartDate(setSheetState),
                              icon: const Icon(Icons.event_outlined),
                              label: Text(_formatDate(accessStart)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickEndDate(setSheetState),
                              icon:
                                  const Icon(Icons.event_available_outlined),
                              label: Text(_formatDate(accessEnd)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: hoursCountCtrl,
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
                        controller: paidAmountCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'المدفوع',
                          prefixIcon: Icon(Icons.done_all_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      moneySummary(),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final hoursCount =
                                      _parseMoney(hoursCountCtrl.text);
                                  final hourlyRate =
                                      _parseMoney(hourlyRateCtrl.text);
                                  final paidAmount =
                                      _parseMoney(paidAmountCtrl.text);
                                  final finalAmount =
                                      hoursCount * hourlyRate;
                                  final remainingAmount =
                                      (finalAmount - paidAmount) < 0
                                          ? 0
                                          : finalAmount - paidAmount;

                                  if (hoursCount <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('أدخل عدد ساعات صحيح'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (hourlyRate <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('أدخل سعر ساعة صحيح'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (linkWithSiblings &&
                                      selectedSharedAccessCodeId.isEmpty) {
                                    await _showSheetValidationError(
                                      sheetContext,
                                      'اختر كود الإخوة',
                                    );
                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                  });

                                  final result =
                                      await _saveReactivatedTemporaryChild(
                                    childDoc: childDoc,
                                    accessStart: accessStart,
                                    accessEnd: accessEnd,
                                    hoursCount: hoursCount,
                                    hourlyRate: hourlyRate,
                                    finalAmount: finalAmount,
                                    paidAmount: paidAmount,
                                    remainingAmount: remainingAmount,
                                    sharedAccessCodeId: linkWithSiblings
                                        ? selectedSharedAccessCodeId
                                        : '',
                                  );

                                  if (!sheetContext.mounted ||
                                      !mounted ||
                                      result == null) {
                                    setSheetState(() {
                                      isSaving = false;
                                    });
                                    return;
                                  }

                                  Navigator.pop(sheetContext);

                                  if (result.linkedToOfficialParentAccount) {
                                    await _showOfficialParentLinkedDialog(
                                      childName: _childName(childData),
                                      parentName: result.officialParentName,
                                    );
                                  } else {
                                    await _showTemporaryAccessDialog(
                                      code: result.accessCode,
                                      childName: _childName(childData),
                                      accessEnd: accessEnd,
                                      usesSharedAccessCode:
                                          result.usesSharedAccessCode,
                                    );
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
                            isSaving ? 'جاري الحفظ...' : 'إعادة التفعيل',
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

    hoursCountCtrl.dispose();
    hourlyRateCtrl.dispose();
    paidAmountCtrl.dispose();
  }
  Future<_TemporaryChildResult?> _saveReactivatedTemporaryChild({
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
    required DateTime accessStart,
    required DateTime accessEnd,
    required num hoursCount,
    required num hourlyRate,
    required num finalAmount,
    required num paidAmount,
    required num remainingAmount,
    required String sharedAccessCodeId,
  }) async {
    try {
      final childData = childDoc.data() ?? <String, dynamic>{};
      final invoiceRef = _firestore.collection('invoices').doc();
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final accessStartDate = DateTime(
        accessStart.year,
        accessStart.month,
        accessStart.day,
      );

      final accessEndDate = DateTime(
        accessEnd.year,
        accessEnd.month,
        accessEnd.day,
        23,
        59,
        59,
      );

      final childName = _childName(childData);
      final parentName = _parentName(childData);
      final temporaryParentPhone =
          _cleanText(childData['temporaryParentPhone']);
      final parentPhone = _normalizePhone(
        temporaryParentPhone.isNotEmpty
            ? temporaryParentPhone
            : _cleanText(childData['parentPhone']),
      );

      final status = _invoiceStatus(
        finalAmount: finalAmount,
        paidAmount: paidAmount,
      );

      final batch = _firestore.batch();

      final officialParent = await _findActiveOfficialParentAccount(
        parentUid: _cleanText(childData['parentUid']),
        parentUsername: _cleanText(childData['parentUsername']),
        parentPhone: parentPhone,
      );

      _PreparedAccessCode? preparedCode;

      if (officialParent != null) {
        await _deactivateOldTemporaryAccess(
          childId: childDoc.id,
          batch: batch,
        );
      } else {
        await _deactivateOldTemporaryAccess(
          childId: childDoc.id,
          batch: batch,
          excludedAccessCodeId: sharedAccessCodeId,
        );

        preparedCode = await _prepareAccessCode(
          sharedAccessCodeId: sharedAccessCodeId,
          childRef: childDoc.reference,
          childName: childName,
          childType: 'temporary',
          parentName: parentName,
          cleanParentPhone: parentPhone,
          accessStartDate: accessStartDate,
          accessEndDate: accessEndDate,
          adminUid: adminUid,
          batch: batch,
        );

        if (preparedCode == null) return null;
      }

      final resolvedParentName =
          officialParent != null ? officialParent.name : preparedCode?.parentName ?? parentName;
      final resolvedParentPhone =
          officialParent != null ? officialParent.phone : preparedCode?.parentPhone ?? parentPhone;

      batch.set(
        childDoc.reference,
        {
          'childType': 'temporary',
          'enrollmentType': 'temporary',
          'childStatus': 'temporary',
          'isTemporaryChild': true,
          'isTrialChild': false,
          'isActive': true,
          'status': 'active',
          'accountStatus': 'active',
          'canReactivate': true,
          'permanentDeleted': false,
          'isBillable': true,
          'excludeFromMonthlyInvoice': true,
          if (officialParent != null) ...{
            'parentUid': officialParent.uid,
            'parentUsername': officialParent.username,
            'parentName': resolvedParentName,
            'parentPhone': resolvedParentPhone,
            'temporaryParentUid': '',
            'temporaryParentUsername': '',
            'temporaryParentName': '',
            'temporaryParentPhone': '',
            'accessMode': 'parent_account',
            'usesTemporaryAccessCode': false,
            'temporaryAccessCodeId': '',
            'sharedAccessCodeId': '',
            'temporaryAccessCode': '',
            'usesSharedAccessCode': false,
          } else ...{
            'parentUid': '',
            'parentUsername': '',
            'parentName': resolvedParentName,
            'parentPhone': resolvedParentPhone,
            'temporaryParentUid': '',
            'temporaryParentUsername': '',
            'temporaryParentName': resolvedParentName,
            'temporaryParentPhone': resolvedParentPhone,
            'accessMode': 'temporary_code',
            'usesTemporaryAccessCode': true,
            'temporaryAccessCodeId': preparedCode?.reference.id ?? '',
            'sharedAccessCodeId': preparedCode?.reference.id ?? '',
            'usesSharedAccessCode': preparedCode?.usesSharedAccessCode ?? false,
            'temporaryAccessCode': preparedCode?.accessCode ?? '',
          },
          'groupId': widget.groupId,
          'groupName': widget.groupName,
          'assignedStaffUid': widget.assignedStaffUid,
          'assignedStaffName': widget.assignedStaffName,
          'assignedStaffUsername': widget.assignedStaffUsername,
          'temporaryStartDate': Timestamp.fromDate(accessStartDate),
          'temporaryEndDate': Timestamp.fromDate(accessEndDate),
          'temporaryDateKeys': [
            _dateKey(accessStartDate),
            _dateKey(accessEndDate),
          ],
          'temporaryBillingType': 'hourly',
          'temporaryBillingTypeLabel': _billingTypeLabel('hourly'),
          'temporaryHoursCount': hoursCount,
          'temporaryHourlyRate': hourlyRate,
          'temporaryFee': finalAmount,
          'temporaryPaidAmount': paidAmount,
          'temporaryRemainingAmount': remainingAmount,
          'temporaryAccessStartAt': Timestamp.fromDate(accessStartDate),
          'temporaryAccessEndAt': Timestamp.fromDate(accessEndDate),
          'archiveReason': '',
          'archivedAt': '',
          'reactivatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': adminUid,
          'updatedByRole': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
          'reactivationHistory': FieldValue.arrayUnion([
            {
              'type': 'temporary',
              'accessStartAt': Timestamp.fromDate(accessStartDate),
              'accessEndAt': Timestamp.fromDate(accessEndDate),
              'billingType': 'hourly',
              'hoursCount': hoursCount,
              'hourlyRate': hourlyRate,
              'finalAmount': finalAmount,
              'paidAmount': paidAmount,
              'remainingAmount': remainingAmount,
              'sharedAccessCodeId':
                  officialParent != null ? '' : preparedCode?.reference.id ?? '',
              'usesSharedAccessCode':
                  officialParent != null ? false : preparedCode?.usesSharedAccessCode ?? false,
              'accessMode':
                  officialParent != null ? 'parent_account' : 'temporary_code',
              'createdAt': Timestamp.now(),
            },
          ]),
        },
        SetOptions(merge: true),
      );

      batch.set(invoiceRef, {
        'id': invoiceRef.id,
        'invoiceId': invoiceRef.id,
        'title': 'فاتورة الطفل الزائر',
        'childId': childDoc.id,
        'childName': childName,
        'childType': 'temporary',
        'parentUid': officialParent?.uid ?? '',
        'parentUsername': officialParent?.username ?? '',
        'parentName': resolvedParentName,
        'parentPhone': resolvedParentPhone,
        'temporaryParentName': officialParent == null ? resolvedParentName : '',
        'temporaryParentPhone': officialParent == null ? resolvedParentPhone : '',
        'groupId': widget.groupId,
        'groupName': widget.groupName,
        if (officialParent != null) ...{
          'accessMode': 'parent_account',
          'usesTemporaryAccessCode': false,
        } else ...{
          'accessMode': 'temporary_code',
          'usesTemporaryAccessCode': true,
          'temporaryAccessCodeId': preparedCode?.reference.id ?? '',
          'sharedAccessCodeId': preparedCode?.reference.id ?? '',
        },
        'billingType': 'hourly',
        'billingTypeLabel': _billingTypeLabel('hourly'),
        'hoursCount': hoursCount,
        'daysCount': 0,
        'hourlyRate': hourlyRate,
        'dailyRate': 0,
        'baseAmount': finalAmount,
        'discount': 0,
        'discountAmount': 0,
        'finalAmount': finalAmount,
        'totalAmount': finalAmount,
        'paidAmount': paidAmount,
        'remainingAmount': remainingAmount,
        'status': status,
        'invoiceDate': FieldValue.serverTimestamp(),
        'accessStartAt': Timestamp.fromDate(accessStartDate),
        'accessEndAt': Timestamp.fromDate(accessEndDate),
        'createdByUid': adminUid,
        'createdByRole': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      await _updateGroupCount();

      return _TemporaryChildResult(
        accessCode: officialParent != null ? '' : preparedCode?.accessCode ?? '',
        usesSharedAccessCode:
            officialParent != null ? false : preparedCode?.usesSharedAccessCode ?? false,
        linkedToOfficialParentAccount: officialParent != null,
        officialParentName: officialParent?.name ?? '',
      );
    } catch (e) {
      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إعادة تفعيل الطفل الزائر: $e')),
      );

      return null;
    }
  }

  Future<void> _openEditTemporaryInvoiceSheet({
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
  }) async {
    final childData = childDoc.data() ?? <String, dynamic>{};

    if (!_isTemporaryChild(childData)) return;

    QueryDocumentSnapshot<Map<String, dynamic>>? invoiceDoc;

    final invoiceSnapshot = await _firestore
        .collection('invoices')
        .where('childId', isEqualTo: childDoc.id)
        .get();

    for (final doc in invoiceSnapshot.docs) {
      final data = doc.data();
      final childType = _cleanText(data['childType']).toLowerCase();
      final billingType = _cleanText(data['billingType']).toLowerCase();
      final title = _cleanText(data['title']);

      if (childType == 'temporary' ||
          billingType == 'hourly' ||
          title.contains('الزائر')) {
        invoiceDoc = doc;
        break;
      }
    }

    final invoiceData = invoiceDoc?.data() ?? <String, dynamic>{};

    final hoursCountCtrl = TextEditingController(
      text: _cleanText(invoiceData['hoursCount']).isNotEmpty
          ? _cleanText(invoiceData['hoursCount'])
          : _cleanText(childData['temporaryHoursCount']).isNotEmpty
              ? _cleanText(childData['temporaryHoursCount'])
              : '1',
    );

    final hourlyRateCtrl = TextEditingController(
      text: _cleanText(invoiceData['hourlyRate']).isNotEmpty
          ? _cleanText(invoiceData['hourlyRate'])
          : _cleanText(childData['temporaryHourlyRate']).isNotEmpty
              ? _cleanText(childData['temporaryHourlyRate'])
              : '10',
    );

    final paidAmountCtrl = TextEditingController(
      text: _cleanText(invoiceData['paidAmount']).isNotEmpty
          ? _cleanText(invoiceData['paidAmount'])
          : _cleanText(childData['temporaryPaidAmount']).isNotEmpty
              ? _cleanText(childData['temporaryPaidAmount'])
              : '0',
    );

    bool isSaving = false;

    num calculateTotal() {
      return _parseMoney(hoursCountCtrl.text) * _parseMoney(hourlyRateCtrl.text);
    }

    Future<void> saveChanges(StateSetter setSheetState) async {
      final hoursCount = _parseMoney(hoursCountCtrl.text);
      final hourlyRate = _parseMoney(hourlyRateCtrl.text);
      final paidAmount = _parseMoney(paidAmountCtrl.text);
      final finalAmount = hoursCount * hourlyRate;
      final remainingAmount =
          (finalAmount - paidAmount) < 0 ? 0 : finalAmount - paidAmount;

      if (hoursCount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل عدد ساعات صحيح')),
        );
        return;
      }

      if (hourlyRate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل سعر ساعة صحيح')),
        );
        return;
      }

      setSheetState(() {
        isSaving = true;
      });

      try {
        final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final invoiceRef = invoiceDoc?.reference ??
            _firestore.collection('invoices').doc();

        final childName = _childName(childData);
        final parentName = _parentName(childData);
        final parentPhone = _cleanText(
          childData['parentPhone'] ?? childData['temporaryParentPhone'],
        );

        final status = _invoiceStatus(
          finalAmount: finalAmount,
          paidAmount: paidAmount,
        );

        final batch = _firestore.batch();

        batch.set(
          childDoc.reference,
          {
            'temporaryBillingType': 'hourly',
            'temporaryBillingTypeLabel': _billingTypeLabel('hourly'),
            'temporaryHoursCount': hoursCount,
            'temporaryHourlyRate': hourlyRate,
            'temporaryFee': finalAmount,
            'temporaryPaidAmount': paidAmount,
            'temporaryRemainingAmount': remainingAmount,
            'isBillable': true,
            'excludeFromMonthlyInvoice': true,
            'updatedByUid': adminUid,
            'updatedByRole': 'admin',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        batch.set(
          invoiceRef,
          {
            'id': invoiceRef.id,
            'invoiceId': invoiceRef.id,
            'title': 'فاتورة الطفل الزائر',
            'childId': childDoc.id,
            'childName': childName,
            'childType': 'temporary',
            'parentUid': _cleanText(childData['parentUid']),
            'parentUsername': _cleanText(childData['parentUsername']),
            'parentName': parentName,
            'parentPhone': parentPhone,
            'temporaryParentName': _cleanText(childData['temporaryParentName'])
                    .isNotEmpty
                ? _cleanText(childData['temporaryParentName'])
                : parentName,
            'temporaryParentPhone':
                _cleanText(childData['temporaryParentPhone']).isNotEmpty
                    ? _cleanText(childData['temporaryParentPhone'])
                    : parentPhone,
            'groupId': widget.groupId,
            'groupName': widget.groupName,
            'billingType': 'hourly',
            'billingTypeLabel': _billingTypeLabel('hourly'),
            'hoursCount': hoursCount,
            'daysCount': 0,
            'hourlyRate': hourlyRate,
            'dailyRate': 0,
            'baseAmount': finalAmount,
            'discount': 0,
            'discountAmount': 0,
            'finalAmount': finalAmount,
            'totalAmount': finalAmount,
            'paidAmount': paidAmount,
            'remainingAmount': remainingAmount,
            'paymentMethod': _cleanText(invoiceData['paymentMethod']).isNotEmpty
                ? _cleanText(invoiceData['paymentMethod'])
                : 'cash',
            'paymentMethodLabel': _paymentMethodLabel(
              _cleanText(invoiceData['paymentMethod']).isNotEmpty
                  ? _cleanText(invoiceData['paymentMethod'])
                  : 'cash',
            ),
            'status': status,
            'invoiceDate':
                invoiceData['invoiceDate'] ?? FieldValue.serverTimestamp(),
            'accessStartAt':
                invoiceData['accessStartAt'] ?? childData['temporaryAccessStartAt'],
            'accessEndAt':
                invoiceData['accessEndAt'] ?? childData['temporaryAccessEndAt'],
            'updatedByUid': adminUid,
            'updatedByRole': 'admin',
            'updatedAt': FieldValue.serverTimestamp(),
            if (invoiceDoc == null) ...{
              'createdByUid': adminUid,
              'createdByRole': 'admin',
              'createdAt': FieldValue.serverTimestamp(),
            },
          },
          SetOptions(merge: true),
        );

        await batch.commit();

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الفاتورة')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الفاتورة: $e')),
        );
      } finally {
        if (mounted) {
          setSheetState(() {
            isSaving = false;
          });
        }
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        Widget moneySummary() {
          final finalAmount = calculateTotal();
          final paidAmount = _parseMoney(paidAmountCtrl.text);
          final remainingAmount =
              (finalAmount - paidAmount) < 0 ? 0 : finalAmount - paidAmount;

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملخص الفاتورة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('الإجمالي: $finalAmount شيكل'),
                Text('المدفوع: $paidAmount شيكل'),
                Text('المتبقي: $remainingAmount شيكل'),
              ],
            ),
          );
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: sheetBottomSafePadding(sheetContext),
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
                        'تعديل فاتورة الطفل الزائر',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: hoursCountCtrl,
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
                        controller: paidAmountCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'المدفوع',
                          prefixIcon: Icon(Icons.done_all_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      moneySummary(),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              isSaving ? null : () => saveChanges(setSheetState),
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

    hoursCountCtrl.dispose();
    hourlyRateCtrl.dispose();
    paidAmountCtrl.dispose();
  }

  Future<void> _openMoveChildSheet({
    required String childId,
  }) async {
    final snapshot = await _firestore
        .collection('groups')
        .orderBy('createdAt', descending: true)
        .get();

    final groups = snapshot.docs.where((doc) => doc.id != widget.groupId).toList();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: groups.isEmpty
                ? const Text('لا توجد مجموعات أخرى')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'نقل الطفل إلى',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...groups.map((groupDoc) {
                        final data = groupDoc.data();
                        final name = _cleanText(data['groupName']).isEmpty
                            ? 'مجموعة بدون اسم'
                            : _cleanText(data['groupName']);

                        return Card(
                          child: ListTile(
                            title: Text(name),
                            trailing:
                                const Icon(Icons.arrow_forward_ios_rounded),
                            onTap: () async {
                              await _firestore
                                  .collection('children')
                                  .doc(childId)
                                  .update({
                                'groupId': groupDoc.id,
                                'groupName': name,
                                'assignedStaffUid':
                                    _cleanText(data['assignedStaffUid']),
                                'assignedStaffName':
                                    _cleanText(data['assignedStaffName']),
                                'assignedStaffUsername':
                                    _cleanText(data['assignedStaffUsername']),
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              await _updateGroupCount();

                              final newCount = await _firestore
                                  .collection('children')
                                  .where('groupId', isEqualTo: groupDoc.id)
                                  .where('isActive', isEqualTo: true)
                                  .get();

                              await _firestore
                                  .collection('groups')
                                  .doc(groupDoc.id)
                                  .update({
                                'currentChildrenCount': newCount.docs.length,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              if (mounted) Navigator.pop(context);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Future<void> _openAddOptionsSheet() async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: sheetBottomSafePadding(sheetContext),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.10),
                    child: const Icon(
                      Icons.child_care_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text(
                    'إضافة طفل زائر',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openAddTemporaryChildSheet();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withValues(alpha: 0.10),
                    child: const Icon(
                      Icons.volunteer_activism_outlined,
                      color: Colors.teal,
                    ),
                  ),
                  title: const Text(
                    'إضافة طفل تجربة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openAddTrialChildSheet();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildChildCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final isTrial = _isTrialChild(data);
    final isTemporary = _isTemporaryChild(data);
    final isArchived = _isArchivedChild(data);
    final isTrialPendingDecision = _isTrialPendingDecision(data);
    final canReactivateTemporary = isArchived &&
        isTemporary &&
        !isTrial &&
        data['canReactivate'] != false;
    final canConvertTemporary = isTemporary &&
        !isTrial &&
        data['permanentDeleted'] != true &&
        data['trialUsed'] != true &&
        data['canStartNewTrial'] != false;
    final childStatus = _cleanText(data['childStatus']).toLowerCase();
    final canRestoreTrial = isArchived &&
        isTrial &&
        (isTrialPendingDecision || childStatus == 'rejected_after_trial');
    final childTypeLabel = _childTypeLabel(data);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isArchived
              ? Colors.grey.withValues(alpha: 0.12)
              : isTrial
                  ? Colors.teal.withValues(alpha: 0.10)
                  : isTemporary
                      ? Colors.orange.withValues(alpha: 0.10)
                      : AppColors.primary.withValues(alpha: 0.10),
          child: Icon(
            isArchived
                ? Icons.archive_outlined
                : isTrial
                    ? Icons.volunteer_activism_outlined
                    : Icons.child_care_rounded,
            color: isArchived
                ? Colors.grey
                : isTrial
                    ? Colors.teal
                    : isTemporary
                        ? Colors.orange
                        : AppColors.primary,
          ),
        ),
        title: Text(
          _childName(data),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          childTypeLabel.isEmpty
              ? _parentName(data)
              : '${_parentName(data)} • $childTypeLabel',
          style: const TextStyle(height: 1.4),
        ),
        trailing: isArchived &&
                !canReactivateTemporary &&
                !canConvertTemporary &&
                !canRestoreTrial
            ? null
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'move') {
                    _openMoveChildSheet(childId: doc.id);
                  } else if (value == 'edit_temporary_invoice') {
                    _openEditTemporaryInvoiceSheet(childDoc: doc);
                  } else if (value == 'remove') {
                    _removeChildFromGroup(doc.id);
                  } else if (value == 'archive') {
                    _archiveChild(childDoc: doc);
                  } else if (value == 'reactivate') {
                    _reactivateArchivedChild(childDoc: doc);
                  } else if (value == 'convert_temporary') {
                    _openConvertTemporaryChildSheet(childDoc: doc);
                  } else if (value == 'restore_trial') {
                    _openApproveTrialChildSheet(childDoc: doc);
                  }
                },
                itemBuilder: (context) {
                  return [
                    if (!isArchived) ...[
                      const PopupMenuItem(
                        value: 'move',
                        child: Text('نقل'),
                      ),
                      if (isTemporary && !isTrial)
                        const PopupMenuItem(
                          value: 'edit_temporary_invoice',
                          child: Text('تعديل الفاتورة'),
                        ),
                      if (isTrial) ...[
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text('أرشفة'),
                        ),
                      ] else if (isTemporary) ...[
                        const PopupMenuItem(
                          value: 'convert_temporary',
                          child: Text('بدء تجربة 3 أيام'),
                        ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text('أرشفة'),
                        ),
                      ],
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('إزالة'),
                      ),
                    ] else if (canRestoreTrial) ...[
                      const PopupMenuItem(
                        value: 'restore_trial',
                        child: Text('استعادة'),
                      ),
                    ] else if (canReactivateTemporary) ...[
                      const PopupMenuItem(
                        value: 'reactivate',
                        child: Text('استعادة كطفل زائر'),
                      ),
                      if (canConvertTemporary)
                        const PopupMenuItem(
                          value: 'convert_temporary',
                          child: Text('استعادة وبدء تجربة 3 أيام'),
                        ),
                    ] else if (canConvertTemporary) ...[
                      const PopupMenuItem(
                        value: 'convert_temporary',
                        child: Text('استعادة وبدء تجربة 3 أيام'),
                      ),
                    ],
                  ];
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: widget.groupName.isEmpty ? 'أطفال المجموعة' : widget.groupName,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('children')
            .where('groupId', isEqualTo: widget.groupId)
            .where('isActive', isEqualTo: !showArchivedChildren)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!showArchivedChildren && docs.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _archiveExpiredChildren(docs);
            });
          }

          return RefreshIndicator(
            onRefresh: () async {
              if (!showArchivedChildren) {
                await _archiveExpiredChildren(docs);
              }
              await _updateGroupCount();
            },
            child: ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        showArchivedChildren
                            ? 'الأرشيف (${docs.length})'
                            : 'الأطفال (${docs.length})',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    if (!showArchivedChildren)
                      IconButton(
                        tooltip: 'إضافة',
                        onPressed: _openAddOptionsSheet,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('النشطون')),
                        selected: !showArchivedChildren,
                        onSelected: (_) {
                          setState(() {
                            showArchivedChildren = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('الأرشيف')),
                        selected: showArchivedChildren,
                        onSelected: (_) {
                          setState(() {
                            showArchivedChildren = true;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (docs.isEmpty)
                  _EmptyChildrenBox(showArchivedChildren: showArchivedChildren)
                else
                  ...docs.map(_buildChildCard),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}


class _TemporaryChildProfileDraft {
  String gender = 'female';
  DateTime? birthDate;

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

  final List<_TemporaryPickupDraft> pickupContacts = [
    _TemporaryPickupDraft(),
  ];

  Map<String, dynamic> toChildFields() {
    return {
      'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),
      'gender': gender,
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
      'bloodType': '',
      'dietInstructions': hasDietaryRestrictions
          ? dietaryRestrictionsCtrl.text.trim()
          : '',
      'specialInstructions':
          hasSpecialNeeds ? specialNeedsCtrl.text.trim() : '',
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

class _TemporaryPickupDraft {
  final nameCtrl = TextEditingController();
  final relationCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  bool isValid() {
    return nameCtrl.text.trim().isNotEmpty &&
        relationCtrl.text.trim().isNotEmpty &&
        phoneCtrl.text.trim().isNotEmpty;
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

class _TemporaryChildResult {
  final String accessCode;
  final bool usesSharedAccessCode;
  final bool linkedToOfficialParentAccount;
  final String officialParentName;

  const _TemporaryChildResult({
    required this.accessCode,
    this.usesSharedAccessCode = false,
    this.linkedToOfficialParentAccount = false,
    this.officialParentName = '',
  });
}

class _OfficialParentAccount {
  final String uid;
  final String username;
  final String name;
  final String phone;

  const _OfficialParentAccount({
    required this.uid,
    required this.username,
    required this.name,
    required this.phone,
  });
}

class _PreparedAccessCode {
  final DocumentReference<Map<String, dynamic>> reference;
  final String accessCode;
  final String parentName;
  final String parentPhone;
  final bool usesSharedAccessCode;

  const _PreparedAccessCode({
    required this.reference,
    required this.accessCode,
    required this.parentName,
    required this.parentPhone,
    required this.usesSharedAccessCode,
  });
}

class _SiblingAccessCodeOption {
  final String id;
  final String code;
  final String parentName;
  final String parentPhone;
  final List<String> childNames;

  const _SiblingAccessCodeOption({
    required this.id,
    required this.code,
    required this.parentName,
    required this.parentPhone,
    required this.childNames,
  });

  String get label {
    final children = childNames.isEmpty ? '' : ' • ${childNames.join('، ')}';
    return '$parentName • $code$children';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroupsBox extends StatelessWidget {
  const _EmptyGroupsBox();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.10),
              child: const Icon(
                Icons.groups_2_outlined,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد مجموعات',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChildrenBox extends StatelessWidget {
  final bool showArchivedChildren;

  const _EmptyChildrenBox({
    required this.showArchivedChildren,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: Text(
            showArchivedChildren
                ? 'لا يوجد أطفال داخل الأرشيف'
                : 'لا يوجد أطفال داخل هذه المجموعة',
          ),
        ),
      ),
    );
  }
}

