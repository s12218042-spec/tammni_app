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

  bool _showInactiveGroups = false;

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
    required bool isActive,
  }) {
    if (!isActive) return 'غير مفعّلة';
    if (maxChildren <= 0) return 'بدون حد';
    if (currentChildren > maxChildren) return 'تجاوزت الحد';
    if (currentChildren == maxChildren) return 'ممتلئة';
    if (currentChildren >= (maxChildren * 0.8).ceil()) {
      return 'قريبة من الامتلاء';
    }
    return 'متاحة';
  }

  Color _groupStatusColor({
    required int currentChildren,
    required int maxChildren,
    required bool isActive,
  }) {
    if (!isActive) return Colors.blueGrey;
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
    Query<Map<String, dynamic>> query =
        _firestore.collection('groups').orderBy('createdAt', descending: true);

    if (!_showInactiveGroups) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.snapshots();
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

    bool isActive = (groupData['isActive'] ?? true) == true;

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
                        isEditing ? 'تعديل المجموعة' : 'إضافة مجموعة جديدة',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'حددي اسم المجموعة، الحد الأقصى للأطفال، والموظفة المسؤولة عنها.',
                        style: TextStyle(color: Colors.black54, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم المجموعة',
                          hintText: 'مثال: مجموعة الفراشات',
                          prefixIcon: Icon(Icons.groups_2_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: maxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الحد الأقصى للأطفال',
                          hintText: 'مثال: 12',
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
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.25),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'لا توجد موظفات حضانة حالياً. أضيفي حساب موظفة أولاً من صفحة إنشاء حسابات الموظفين.',
                                      style: TextStyle(height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return DropdownButtonFormField<String>(
                            value: selectedStaffUid.isEmpty
                                ? null
                                : selectedStaffUid,
                            decoration: const InputDecoration(
                              labelText: 'الموظفة المسؤولة',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            items: staffDocs.map((doc) {
                              final data = doc.data();

                              final name =
                                  _cleanText(data['name']).isNotEmpty
                                      ? _cleanText(data['name'])
                                      : _cleanText(data['username']).isNotEmpty
                                          ? _cleanText(data['username'])
                                          : 'موظفة بدون اسم';

                              final username = _cleanText(data['username']);

                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  username.isEmpty
                                      ? name
                                      : '$name • @$username',
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
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('المجموعة مفعّلة'),
                        subtitle: const Text(
                          'عند إيقاف التفعيل تبقى المجموعة محفوظة لكن لا تظهر ضمن المجموعات النشطة.',
                        ),
                        value: isActive,
                        onChanged: (value) {
                          setSheetState(() {
                            isActive = value;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(isEditing
                              ? Icons.save_rounded
                              : Icons.add_rounded),
                          label: Text(isEditing ? 'حفظ التعديل' : 'إضافة المجموعة'),
                          onPressed: () async {
                            final groupName = nameCtrl.text.trim();
                            final maxChildren =
                                int.tryParse(maxCtrl.text.trim()) ?? 12;

                            if (groupName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('اكتبي اسم المجموعة أولاً'),
                                ),
                              );
                              return;
                            }

                            if (maxChildren <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'الحد الأقصى للأطفال يجب أن يكون أكبر من صفر',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (selectedStaffUid.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'اختاري الموظفة المسؤولة عن المجموعة',
                                  ),
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
                              isActive: isActive,
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
    required bool isActive,
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
        'isActive': isActive,
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
          content: Text(
            isEditing
                ? 'تم تعديل المجموعة بنجاح'
                : 'تمت إضافة المجموعة بنجاح',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ المجموعة: $e')),
      );
    }
  }

  Future<void> _toggleGroupActive(
    DocumentSnapshot<Map<String, dynamic>> groupDoc,
  ) async {
    final data = groupDoc.data() ?? {};
    final isActive = (data['isActive'] ?? true) == true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(isActive ? 'تعطيل المجموعة' : 'تفعيل المجموعة'),
          content: Text(
            isActive
                ? 'هل أنتِ متأكدة من تعطيل هذه المجموعة؟ لن تظهر ضمن المجموعات النشطة.'
                : 'هل تريدين تفعيل هذه المجموعة من جديد؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isActive ? 'تعطيل' : 'تفعيل'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('groups').doc(groupDoc.id).update({
        'isActive': !isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? 'تم تعطيل المجموعة' : 'تم تفعيل المجموعة'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث حالة المجموعة: $e')),
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
        ),
      ),
    );

    await _syncGroupChildrenCount(groupDoc.id);

    if (!mounted) return;
    setState(() {});
  }

  Widget _buildSummaryCard(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int activeGroups = 0;
    int totalChildren = 0;
    int fullGroups = 0;
    int overCapacityGroups = 0;

    for (final doc in docs) {
      final data = doc.data();
      final isActive = (data['isActive'] ?? true) == true;
      final currentChildren = _toInt(data['currentChildrenCount']);
      final maxChildren = _toInt(data['maxChildren'], fallback: 12);

      if (isActive) activeGroups++;
      totalChildren += currentChildren;

      if (maxChildren > 0 && currentChildren == maxChildren) {
        fullGroups++;
      }

      if (maxChildren > 0 && currentChildren > maxChildren) {
        overCapacityGroups++;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MiniStat(
              icon: Icons.groups_2_rounded,
              title: 'المجموعات النشطة',
              value: '$activeGroups',
            ),
            _MiniStat(
              icon: Icons.child_care_rounded,
              title: 'الأطفال داخل المجموعات',
              value: '$totalChildren',
            ),
            _MiniStat(
              icon: Icons.inventory_2_outlined,
              title: 'مجموعات ممتلئة',
              value: '$fullGroups',
            ),
            _MiniStat(
              icon: Icons.warning_amber_rounded,
              title: 'تجاوزت الحد',
              value: '$overCapacityGroups',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final groupName = _cleanText(data['groupName']).isEmpty
        ? 'مجموعة بدون اسم'
        : _cleanText(data['groupName']);

    final assignedStaffName =
        _cleanText(data['assignedStaffName']).isEmpty
            ? 'غير محددة'
            : _cleanText(data['assignedStaffName']);

    final currentChildren = _toInt(data['currentChildrenCount']);
    final maxChildren = _toInt(data['maxChildren'], fallback: 12);
    final isActive = (data['isActive'] ?? true) == true;

    final statusLabel = _groupStatusLabel(
      currentChildren: currentChildren,
      maxChildren: maxChildren,
      isActive: isActive,
    );

    final statusColor = _groupStatusColor(
      currentChildren: currentChildren,
      maxChildren: maxChildren,
      isActive: isActive,
    );

    final progress = maxChildren <= 0
        ? 0.0
        : (currentChildren / maxChildren).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.12),
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
                        'الموظفة المسؤولة: $assignedStaffName',
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 1.35,
                        ),
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
                    } else if (value == 'toggle') {
                      _toggleGroupActive(doc);
                    } else if (value == 'sync') {
                      _syncGroupChildrenCount(doc.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'children',
                      child: Text('عرض أطفال المجموعة'),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('تعديل المجموعة'),
                    ),
                    const PopupMenuItem(
                      value: 'sync',
                      child: Text('تحديث عدد الأطفال'),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(isActive ? 'تعطيل المجموعة' : 'تفعيل المجموعة'),
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
                backgroundColor: Colors.black.withOpacity(0.06),
                color: statusColor,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.child_care_rounded,
                  label: '$currentChildren / $maxChildren طفل',
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.info_outline_rounded,
                  label: statusLabel,
                  color: statusColor,
                ),
              ],
            ),
            if (maxChildren > 0 && currentChildren >= maxChildren) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusColor.withOpacity(0.20)),
                ),
                child: Text(
                  currentChildren > maxChildren
                      ? 'تنبيه: هذه المجموعة تجاوزت الحد المسموح. قد تحتاج الإدارة إلى فتح مجموعة جديدة أو تعديل السعر/العروض.'
                      : 'تنبيه: هذه المجموعة ممتلئة. عند إضافة أطفال جدد قد تحتاج الإدارة إلى فتح مجموعة جديدة.',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.child_care_rounded),
                    label: const Text('أطفال المجموعة'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openGroupForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('مجموعة جديدة'),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _groupsStream(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              children: [
                Text(
                  'إدارة مجموعات الحضانة',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'أنشئي مجموعات مرنة حسب عدد الأطفال والموظفات، وحددي الحد الأقصى لكل مجموعة والموظفة المسؤولة عنها.',
                  style: TextStyle(color: Colors.black54, height: 1.5),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('عرض المجموعات غير المفعّلة'),
                  value: _showInactiveGroups,
                  onChanged: (value) {
                    setState(() {
                      _showInactiveGroups = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                if (docs.isNotEmpty) _buildSummaryCard(docs),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const _EmptyGroupsBox()
                else
                  ...docs.map(_buildGroupCard),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupChildrenPage extends StatelessWidget {
  final String groupId;
  final String groupName;

  const _GroupChildrenPage({
    required this.groupId,
    required this.groupName,
  });

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'أطفال المجموعة',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('children')
            .where('groupId', isEqualTo: groupId)
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (docs.isEmpty) {
            return const Center(
              child: Text('لا يوجد أطفال داخل هذه المجموعة حالياً'),
            );
          }

          return ListView(
            children: [
              Text(
                groupName.isEmpty ? 'المجموعة' : groupName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'عدد الأطفال: ${docs.length}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ...docs.map((doc) {
                final data = doc.data();

                final childName = _cleanText(data['name']).isNotEmpty
                    ? _cleanText(data['name'])
                    : _cleanText(data['childName']).isNotEmpty
                        ? _cleanText(data['childName'])
                        : 'طفل بدون اسم';

                final parentName = _cleanText(data['parentName']).isNotEmpty
                    ? _cleanText(data['parentName'])
                    : _cleanText(data['parentUsername']).isNotEmpty
                        ? _cleanText(data['parentUsername'])
                        : 'ولي أمر غير محدد';

                final status = _cleanText(data['childStatus']).isNotEmpty
                    ? _cleanText(data['childStatus'])
                    : 'active';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.10),
                      child: const Icon(
                        Icons.child_care_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      childName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'ولي الأمر: $parentName\nالحالة: $status',
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final itemWidth = width > 700 ? (width - 76) / 2 : double.infinity;

    return SizedBox(
      width: itemWidth,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
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
              backgroundColor: AppColors.primary.withOpacity(0.10),
              child: const Icon(
                Icons.groups_2_outlined,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد مجموعات حالياً',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'ابدئي بإنشاء أول مجموعة، ثم اربطي الأطفال والموظفات بها.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}