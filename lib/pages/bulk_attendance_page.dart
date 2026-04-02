import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class BulkAttendancePage extends StatefulWidget {
  const BulkAttendancePage({super.key});

  @override
  State<BulkAttendancePage> createState() => _BulkAttendancePageState();
}

class _BulkAttendancePageState extends State<BulkAttendancePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _noteCtrl = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  List<ChildModel> children = [];
  final Map<String, String> attendanceStatus = {};

  final List<Map<String, String>> statuses = const [
    {'value': 'present', 'label': 'حاضر'},
    {'value': 'absent', 'label': 'غائب'},
    {'value': 'late', 'label': 'متأخر'},
    {'value': 'excused', 'label': 'غياب مبرر'},
  ];

  Future<Map<String, String>> fetchCurrentUserInfo() async {
  final currentUser = _auth.currentUser;

  if (currentUser == null) {
    return {
      'uid': '',
      'name': 'مستخدم غير معروف',
      'role': '',
    };
  }

  final userDoc =
      await _firestore.collection('users').doc(currentUser.uid).get();

  final data = userDoc.data() ?? {};

  return {
    'uid': currentUser.uid,
    'name': (data['displayName'] ?? data['username'] ?? 'مستخدم').toString(),
    'role': (data['role'] ?? '').toString(),
  };
}

  @override
  void initState() {
    super.initState();
    loadChildren();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<List<String>> fetchAssignedGroups() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final userDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();

    if (!userDoc.exists) return [];

    final data = userDoc.data() ?? {};
    final rawGroups = data['assignedGroups'];

    if (rawGroups is List) {
      return rawGroups
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  Future<void> loadChildren() async {
    try {
      final assignedGroups = await fetchAssignedGroups();

      if (assignedGroups.isEmpty) {
        if (!mounted) return;
        setState(() {
          children = [];
          isLoading = false;
        });
        return;
      }

      final snapshot = await _firestore
          .collection('children')
          .where('section', isEqualTo: 'Kindergarten')
          .where('isActive', isEqualTo: true)
          .get();

       final loadedChildren = snapshot.docs.map((doc) {
  final data = doc.data();
  return ChildModel.fromMap(data, docId: doc.id);
}).where((child) {
  return assignedGroups.contains(child.group.trim());
}).toList();

      loadedChildren.sort((a, b) => a.name.compareTo(b.name));

      attendanceStatus.clear();
      for (final child in loadedChildren) {
        attendanceStatus[child.id] = 'present';
      }

      if (!mounted) return;
      setState(() {
        children = loadedChildren;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveBulkAttendance() async {
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد أطفال لحفظ الحضور')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final userInfo = await fetchCurrentUserInfo();
      final batch = _firestore.batch();

      for (final child in children) {
        final docRef = _firestore.collection('attendance').doc();

        batch.set(docRef, {
          'childId': child.id,
          'childName': child.name,
          'parentUsername': child.parentUsername,
          'section': child.section,
          'group': child.group,
          'status': attendanceStatus[child.id] ?? 'present',
          'note': _noteCtrl.text.trim(),
          'recordedByUid': userInfo['uid'],
          'recordedByRole': userInfo['role'],
          'recordedByName': userInfo['name'],
          'createdByUid': userInfo['uid'],
          'createdByName': userInfo['name'],
          'createdByRole': userInfo['role'],
          'createdAt': Timestamp.now(),
          'time': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الحضور الجماعي بنجاح')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ الحضور: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إدخال حضور جماعي',
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildNoteField(),
                const SizedBox(height: 18),
                Text(
                  'حالة حضور الأطفال',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 12),
                if (children.isEmpty)
                  _buildEmptyState()
                else
                  ...children.map(
                    (child) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AttendanceInputCard(
                        childName: child.name,
                        group: child.group,
                        value: attendanceStatus[child.id] ?? 'present',
                        items: statuses,
                        onChanged: (value) {
                          setState(() {
                            attendanceStatus[child.id] = value ?? 'present';
                          });
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : saveBulkAttendance,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ الحضور'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.14),
            AppColors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تسجيل حضور جماعي',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'حددي حالة الحضور لكل طفل من أطفال مجموعاتك ثم احفظي البيانات دفعة واحدة.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextFormField(
        controller: _noteCtrl,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'ملاحظة عامة',
          hintText: 'أضيفي ملاحظة عامة إن وجدت',
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 40,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'لا يوجد أطفال مخصصون لهذه المعلمة حالياً',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'عند ربط المعلمة بمجموعاتها سيظهر الأطفال هنا لتسجيل الحضور.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceInputCard extends StatelessWidget {
  final String childName;
  final String group;
  final String value;
  final List<Map<String, String>> items;
  final ValueChanged<String?> onChanged;

  const _AttendanceInputCard({
    required this.childName,
    required this.group,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      childName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.isEmpty ? 'بدون مجموعة' : group,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              labelText: 'الحالة',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item['value'],
                child: Text(item['label']!),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}