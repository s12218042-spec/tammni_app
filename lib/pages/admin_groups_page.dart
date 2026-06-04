import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';


class AdminGroupsPage extends StatefulWidget {
  const AdminGroupsPage({super.key});

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
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
                          final staffDocs = snapshot.data?.docs ?? [];

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
                                child: Text('لا توجد موظفات حضانة'),
                              ),
                            );
                          }

                          return DropdownButtonFormField<String>(
                            initialValue: selectedStaffUid.isEmpty
                                ? null
                                : selectedStaffUid,
                            decoration: const InputDecoration(
                              labelText: 'الموظفة المسؤولة',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            items: staffDocs.map((doc) {
                              final data = doc.data();

                              final name = _cleanText(data['name']).isNotEmpty
                                  ? _cleanText(data['name'])
                                  : _cleanText(data['username']).isNotEmpty
                                      ? _cleanText(data['username'])
                                      : 'موظفة بدون اسم';

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
                                  content: Text('اكتبي اسم المجموعة'),
                                ),
                              );
                              return;
                            }

                            if (maxChildren <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('أدخلي عدد أطفال صحيح'),
                                ),
                              );
                              return;
                            }

                            if (selectedStaffUid.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('اختاري الموظفة المسؤولة'),
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
      actions: [
        IconButton(
          tooltip: 'إضافة مجموعة',
          onPressed: () => _openGroupForm(),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
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

  const _GroupChildrenPage({
    required this.groupId,
    required this.groupName,
    required this.assignedStaffUid,
    required this.assignedStaffName,
    required this.assignedStaffUsername,
  });

  @override
  State<_GroupChildrenPage> createState() => _GroupChildrenPageState();
}

class _GroupChildrenPageState extends State<_GroupChildrenPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool showArchivedChildren = false;

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '').trim();
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


  String _childTypeLabel(Map<String, dynamic> data) {
    final childStatus = _cleanText(data['childStatus']).toLowerCase();
    final accountStatus = _cleanText(data['accountStatus']).toLowerCase();
    final childType = _cleanText(data['childType']).toLowerCase();

    if (childStatus == 'rejected_after_trial') return 'مؤرشف بعد التجربة';
    if (childStatus == 'archived' || accountStatus == 'archived') {
      return 'مؤرشف';
    }

    switch (childType.isNotEmpty ? childType : childStatus) {
      case 'temporary':
        return 'مؤقت';
      case 'trial':
        return 'تجربة';
      case 'permanent':
      case 'active':
        return 'دائم';
      default:
        return 'دائم';
    }
  }

  Future<void> _updateGroupCount() async {
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

  Future<void> _openAddChildSheet() async {
    final snapshot = await _firestore
        .collection('children')
        .where('isActive', isEqualTo: true)
        .get();

    final children = snapshot.docs.where((doc) {
      final data = doc.data();
      return _cleanText(data['groupId']) != widget.groupId;
    }).toList();

    if (!mounted) return;

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
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.75,
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
                    'إضافة طفل',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: children.isEmpty
                        ? const Center(child: Text('لا يوجد أطفال متاحون'))
                        : ListView.builder(
                            itemCount: children.length,
                            itemBuilder: (context, index) {
                              final doc = children[index];
                              final data = doc.data();
                              final oldGroupName = _cleanText(data['groupName']);

                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.10),
                                    child: const Icon(
                                      Icons.child_care_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  title: Text(_childName(data)),
                                  subtitle: Text(
                                    oldGroupName.isEmpty
                                        ? _parentName(data)
                                        : '${_parentName(data)} • $oldGroupName',
                                  ),
                                  trailing:
                                      const Icon(Icons.add_circle_outline),
                                  onTap: () async {
                                    await _assignChildToCurrentGroup(
                                      childDoc: doc,
                                    );
                                    if (!sheetContext.mounted) return;
                                    Navigator.pop(sheetContext);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    await _updateGroupCount();
  }

  Future<void> _openAddTemporaryChildSheet() async {
    final childNameCtrl = TextEditingController();
    final parentNameCtrl = TextEditingController();
    final parentPhoneCtrl = TextEditingController();
    final hoursCountCtrl = TextEditingController(text: '1');
    final hourlyRateCtrl = TextEditingController(text: '10');
    final paidAmountCtrl = TextEditingController(text: '0');

    DateTime accessStart = DateTime.now();
    DateTime accessEnd = DateTime.now().add(const Duration(days: 1));

    const billingType = 'hourly';
    bool hasConsultation = false;
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
                        'طفل مؤقت',
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
                        decoration: const InputDecoration(
                          labelText: 'اسم ولي الأمر',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: parentPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم ولي الأمر',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
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
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: hasConsultation,
                        title: const Text('استشارة'),
                        onChanged: (value) {
                          setSheetState(() {
                            hasConsultation = value == true;
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
                                  final childName = childNameCtrl.text.trim();
                                  final parentName = parentNameCtrl.text.trim();
                                  final parentPhone =
                                      parentPhoneCtrl.text.trim();

                                  if (childName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('اكتبي اسم الطفل'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (parentName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('اكتبي اسم ولي الأمر'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (parentPhone.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('اكتبي رقم ولي الأمر'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (!_isValidPalestinianMobile(parentPhone)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                      content: Text('رقم ولي الأمر يجب أن يكون 10 أرقام ويبدأ بـ 059 أو 056 أو 052'),
                                       ),
                                       );
                                      return;
                                      }

                                  if (finalAmount <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('أدخلي قيمة فاتورة صحيحة'),
                                      ),
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
                                    hasConsultation: hasConsultation,
                                    notes: '',
                                  );

                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);

                                  if (!mounted || result == null) return;

                                  await _showTemporaryAccessDialog(
                                    code: result.accessCode,
                                    childName: childName,
                                    accessEnd: accessEnd,
                                  );
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
  required bool hasConsultation,
  required String notes,
}) async {
  try {
    final cleanParentPhone = _normalizePhone(parentPhone);

    final existingChildrenSnapshot = await _firestore
        .collection('children')
        .where('parentPhone', isEqualTo: cleanParentPhone)
        .get();

    QueryDocumentSnapshot<Map<String, dynamic>>? existingChildDoc;

    for (final doc in existingChildrenSnapshot.docs) {
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
              'هذا الطفل مسجل كطفل دائم بالفعل، لا يمكن إضافته كمؤقت.',
            ),
          ),
        );
      }
      return null;
    }

    final childRef = existingChildDoc?.reference ??
        _firestore.collection('children').doc();

    final codeRef = _firestore.collection('temporary_access_codes').doc();
    final invoiceRef = _firestore.collection('invoices').doc();

    final accessCode = _generateAccessCode();

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

    final childData = <String, dynamic>{
      'id': childRef.id,
      'childId': childRef.id,
      'name': childName,
      'childName': childName,

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

      'parentUid': '',
      'parentUsername': '',
      'parentName': parentName,
      'parentPhone': cleanParentPhone,

      'temporaryParentUid': '',
      'temporaryParentUsername': '',
      'temporaryParentName': parentName,
      'temporaryParentPhone': cleanParentPhone,

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

      'hasConsultation': hasConsultation,
      'consultationId': '',
      'consultationStatus': hasConsultation ? 'pending' : 'none',

      'temporaryAccessCodeId': codeRef.id,
      'temporaryAccessCode': accessCode,
      'temporaryAccessStartAt': Timestamp.fromDate(accessStartDate),
      'temporaryAccessEndAt': Timestamp.fromDate(accessEndDate),

      'updatedByUid': adminUid,
      'updatedByRole': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
      'reactivatedAt': FieldValue.serverTimestamp(),
      'archiveReason': FieldValue.delete(),
      'archivedAt': FieldValue.delete(),
    };

    if (existingChildDoc == null) {
      childData['createdByUid'] = adminUid;
      childData['createdByRole'] = 'admin';
      childData['createdAt'] = FieldValue.serverTimestamp();
    }

    batch.set(childRef, childData, SetOptions(merge: true));

    batch.set(codeRef, {
      'id': codeRef.id,
      'code': accessCode,

      'childId': childRef.id,
      'childName': childName,

      'parentUid': '',
      'parentUsername': '',
      'parentName': parentName,
      'parentPhone': cleanParentPhone,

      'temporaryParentName': parentName,
      'temporaryParentPhone': cleanParentPhone,

      'groupId': widget.groupId,
      'groupName': widget.groupName,

      'childType': 'temporary',
      'childStatus': 'temporary',

      'accessStartAt': Timestamp.fromDate(accessStartDate),
      'accessEndAt': Timestamp.fromDate(accessEndDate),

      'isActive': true,
      'accountStatus': 'active',
      'canReactivate': true,
      'permanentDeleted': false,
      'isUsed': false,

      'createdByUid': adminUid,
      'createdByRole': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(invoiceRef, {
      'id': invoiceRef.id,
      'invoiceId': invoiceRef.id,

      'title': 'فاتورة الطفل المؤقت',

      'childId': childRef.id,
      'childName': childName,
      'childType': 'temporary',

      'parentUid': '',
      'parentUsername': '',
      'parentName': parentName,
      'parentPhone': cleanParentPhone,

      'temporaryParentName': parentName,
      'temporaryParentPhone': cleanParentPhone,

      'groupId': widget.groupId,
      'groupName': widget.groupName,

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

    return _TemporaryChildResult(accessCode: accessCode);
  } catch (e) {
    if (!mounted) return null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذر حفظ الطفل المؤقت: $e')),
    );

    return null;
  }
}

  Future<_TemporaryChildResult?> _saveTrialChild({
  required String childName,
  required String parentName,
  required String parentPhone,
  required DateTime trialStart,
  required bool hasConsultation,
}) async {
  try {
    final cleanParentPhone = _normalizePhone(parentPhone);

    final existingChildrenSnapshot = await _firestore
        .collection('children')
        .where('parentPhone', isEqualTo: cleanParentPhone)
        .get();

    QueryDocumentSnapshot<Map<String, dynamic>>? existingChildDoc;

    for (final doc in existingChildrenSnapshot.docs) {
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
              'هذا الطفل مسجل كطفل دائم بالفعل، لا يمكن إضافته كتجربة.',
            ),
          ),
        );
      }
      return null;
    }

    final childRef = existingChildDoc?.reference ??
        _firestore.collection('children').doc();

    final codeRef = _firestore.collection('temporary_access_codes').doc();

    final accessCode = _generateAccessCode();

    final trialStartDate = DateTime(
      trialStart.year,
      trialStart.month,
      trialStart.day,
    );

    final trialEndDate = _trialEndFromStart(trialStartDate);

    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final batch = _firestore.batch();

    final childData = <String, dynamic>{
      'id': childRef.id,
      'childId': childRef.id,
      'name': childName,
      'childName': childName,

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

      'parentUid': '',
      'parentUsername': '',
      'parentName': parentName,
      'parentPhone': cleanParentPhone,

      'temporaryParentUid': '',
      'temporaryParentUsername': '',
      'temporaryParentName': parentName,
      'temporaryParentPhone': cleanParentPhone,

      'groupId': widget.groupId,
      'groupName': widget.groupName,
      'assignedStaffUid': widget.assignedStaffUid,
      'assignedStaffName': widget.assignedStaffName,
      'assignedStaffUsername': widget.assignedStaffUsername,

      'trialStartAt': Timestamp.fromDate(trialStartDate),
      'trialEndAt': Timestamp.fromDate(trialEndDate),

      'temporaryAccessCodeId': codeRef.id,
      'temporaryAccessCode': accessCode,
      'temporaryAccessStartAt': Timestamp.fromDate(trialStartDate),
      'temporaryAccessEndAt': Timestamp.fromDate(trialEndDate),

      'hasConsultation': hasConsultation,
      'consultationId': '',
      'consultationStatus': hasConsultation ? 'pending' : 'none',

      'updatedByUid': adminUid,
      'updatedByRole': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
      'reactivatedAt': FieldValue.serverTimestamp(),
      'archiveReason': FieldValue.delete(),
      'archivedAt': FieldValue.delete(),
    };

    if (existingChildDoc == null) {
      childData['createdByUid'] = adminUid;
      childData['createdByRole'] = 'admin';
      childData['createdAt'] = FieldValue.serverTimestamp();
    }

    batch.set(childRef, childData, SetOptions(merge: true));

    batch.set(codeRef, {
      'id': codeRef.id,
      'code': accessCode,

      'childId': childRef.id,
      'childName': childName,

      'parentUid': '',
      'parentUsername': '',
      'parentName': parentName,
      'parentPhone': cleanParentPhone,

      'temporaryParentName': parentName,
      'temporaryParentPhone': cleanParentPhone,

      'groupId': widget.groupId,
      'groupName': widget.groupName,

      'childType': 'trial',
      'childStatus': 'trial',

      'accessStartAt': Timestamp.fromDate(trialStartDate),
      'accessEndAt': Timestamp.fromDate(trialEndDate),

      'trialStartAt': Timestamp.fromDate(trialStartDate),
      'trialEndAt': Timestamp.fromDate(trialEndDate),

      'isActive': true,
      'accountStatus': 'active',
      'canReactivate': true,
      'permanentDeleted': false,
      'isUsed': false,

      'createdByUid': adminUid,
      'createdByRole': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    await _updateGroupCount();

    return _TemporaryChildResult(accessCode: accessCode);
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

    DateTime trialStart = DateTime.now();
    bool hasConsultation = false;
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
                        decoration: const InputDecoration(
                          labelText: 'اسم ولي الأمر',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: parentPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم ولي الأمر',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
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
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: hasConsultation,
                        title: const Text('استشارة'),
                        onChanged: (value) {
                          setSheetState(() {
                            hasConsultation = value == true;
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
                                  final childName = childNameCtrl.text.trim();
                                  final parentName = parentNameCtrl.text.trim();
                                  final parentPhone = parentPhoneCtrl.text.trim();

                                  if (childName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('اكتبي اسم الطفل'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (parentName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('اكتبي اسم ولي الأمر'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (parentPhone.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('اكتبي رقم ولي الأمر'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (!_isValidPalestinianMobile(parentPhone)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'رقم ولي الأمر يجب أن يكون 10 أرقام ويبدأ بـ 059 أو 056 أو 052',
                                        ),
                                      ),
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
                                    hasConsultation: hasConsultation,
                                  );

                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);

                                  if (!mounted || result == null) return;

                                  final trialEnd = _trialEndFromStart(trialStart);

                                  await _showTemporaryAccessDialog(
                                    code: result.accessCode,
                                    childName: childName,
                                    accessEnd: trialEnd,
                                  );
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
  }

  Future<void> _showTemporaryAccessDialog({
    required String code,
    required String childName,
    required DateTime accessEnd,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تم إنشاء الوصول المؤقت'),
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

  Future<void> _assignChildToCurrentGroup({
    required QueryDocumentSnapshot<Map<String, dynamic>> childDoc,
  }) async {
    await _firestore.collection('children').doc(childDoc.id).update({
      'groupId': widget.groupId,
      'groupName': widget.groupName,
      'assignedStaffUid': widget.assignedStaffUid,
      'assignedStaffName': widget.assignedStaffName,
      'assignedStaffUsername': widget.assignedStaffUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _updateGroupCount();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إضافة الطفل')),
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
      'groupId': FieldValue.delete(),
      'groupName': FieldValue.delete(),
      'assignedStaffUid': FieldValue.delete(),
      'assignedStaffName': FieldValue.delete(),
      'assignedStaffUsername': FieldValue.delete(),
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('أرشفة الطفل'),
          content: const Text('أرشفة الطفل؟'),
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
      final accessCodeId = _cleanText(data['temporaryAccessCodeId']);
      final archiveReason = _isTrialChild(data)
          ? 'trial_not_approved'
          : 'temporary_archived';

      final batch = _firestore.batch();

      batch.set(
        _firestore.collection('children').doc(childDoc.id),
        {
          'childStatus': _isTrialChild(data) ? 'rejected_after_trial' : 'archived',
          'accountStatus': 'archived',
          'isActive': false,
          'isBillable': false,
          'excludeFromMonthlyInvoice': true,
          'canReactivate': true,
          'permanentDeleted': false,
          'archiveReason': archiveReason,
          'archivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (accessCodeId.isNotEmpty) {
        batch.set(
          _firestore.collection('temporary_access_codes').doc(accessCodeId),
          {
            'isActive': false,
            'status': 'archived',
            'accountStatus': 'archived',
            'childStatus': _isTrialChild(data) ? 'rejected_after_trial' : 'archived',
            'canReactivate': true,
            'permanentDeleted': false,
            'archiveReason': archiveReason,
            'archivedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      final deviceSnapshot = await _firestore
          .collection('temporary_parent_devices')
          .where('childId', isEqualTo: childDoc.id)
          .get();

      for (final deviceDoc in deviceSnapshot.docs) {
        batch.set(
          deviceDoc.reference,
          {
            'isActive': false,
            'accountStatus': 'archived',
            'archiveReason': archiveReason,
            'archivedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      await _updateGroupCount();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الأرشفة')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الأرشفة: $e')),
      );
    }
  }

  Future<void> _reactivateArchivedChild({
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
  }) async {
    final data = childDoc.data() ?? <String, dynamic>{};
    final restoreStatus = _isTrialChild(data) ? 'trial' : 'temporary';

    await _firestore.collection('children').doc(childDoc.id).set(
      {
        'childStatus': restoreStatus,
        'accountStatus': 'active',
        'isActive': true,
        'canReactivate': true,
        'permanentDeleted': false,
        'archiveReason': FieldValue.delete(),
        'archivedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _updateGroupCount();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إعادة التفعيل')),
    );
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
          title.contains('المؤقت')) {
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
          const SnackBar(content: Text('أدخلي عدد ساعات صحيح')),
        );
        return;
      }

      if (hourlyRate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخلي سعر ساعة صحيح')),
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
            'title': 'فاتورة الطفل المؤقت',
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
                        'تعديل فاتورة الطفل المؤقت',
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
      useSafeArea: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
                    backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text(
                    'إضافة طفل دائم',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openAddChildSheet();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                    child: const Icon(
                      Icons.child_care_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text(
                    'إضافة طفل مؤقت',
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
        );
      },
    );
  }

  Widget _buildChildCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final isTrial = _isTrialChild(data);
    final isTemporary = _isTemporaryChild(data);
    final isArchived = _isArchivedChild(data);

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
          '${_parentName(data)} • ${_childTypeLabel(data)}',
          style: const TextStyle(height: 1.4),
        ),
        trailing: PopupMenuButton<String>(
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
            }
          },
          itemBuilder: (context) {
            return [
              if (!isArchived) ...[
                const PopupMenuItem(
                  value: 'move',
                  child: Text('نقل'),
                ),
                if (isTemporary)
                  const PopupMenuItem(
                    value: 'edit_temporary_invoice',
                    child: Text('تعديل الفاتورة'),
                  ),
                if (isTrial || isTemporary)
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text('أرشفة'),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('إزالة'),
                ),
              ] else ...[
                const PopupMenuItem(
                  value: 'reactivate',
                  child: Text('إعادة تفعيل'),
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
      actions: [
        if (!showArchivedChildren)
          IconButton(
            tooltip: 'إضافة',
            onPressed: _openAddOptionsSheet,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
      ],
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

          return RefreshIndicator(
            onRefresh: () async => _updateGroupCount(),
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

class _TemporaryChildResult {
  final String accessCode;

  const _TemporaryChildResult({
    required this.accessCode,
  });
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

