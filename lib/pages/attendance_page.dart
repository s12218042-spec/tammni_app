import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AttendancePage extends StatefulWidget {
  final String sectionFilter; // Kindergarten only here

  const AttendancePage({
    super.key,
    this.sectionFilter = 'Kindergarten',
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, bool> attendanceValues = {};
  bool isSaving = false;

  bool get isSupportedSection => widget.sectionFilter == 'Kindergarten';

  String sectionLabel(String section) {
    switch (section) {
      case 'Nursery':
        return 'حضانة';
      case 'Kindergarten':
        return 'روضة';
      default:
        return 'الكل';
    }
  }

  String pageDescription() {
    return 'عرض وتسجيل حضور أطفال قسم الروضة';
  }

  String get dateKey {
    final today = DateTime.now();
    return '${today.year}-${today.month}-${today.day}';
  }

  Future<List<ChildModel>> fetchChildren() async {
    final snapshot = await _firestore
    .collection('children')
    .where('section', isEqualTo: 'Kindergarten')
    .where('isActive', isEqualTo: true)
    .get();


    return snapshot.docs.map((doc) {
      final data = doc.data();

      return ChildModel(
        id: doc.id,
        name: data['name'] ?? '',
        section: data['section'] ?? 'Kindergarten',
        group: data['group'] ?? '',
        parentName: data['parentName'] ?? '',
        parentUsername: data['parentUsername'] ?? '',
        birthDate: data['birthDate'] is Timestamp
            ? (data['birthDate'] as Timestamp).toDate()
            : DateTime.now(),
      );
    }).toList();
  }

  Future<void> loadAttendanceForChildren(List<ChildModel> children) async {
    for (final child in children) {
      if (attendanceValues.containsKey(child.id)) continue;

      final docId = '${child.id}_$dateKey';
      final doc = await _firestore.collection('attendance').doc(docId).get();

      attendanceValues[child.id] =
          doc.exists ? (doc.data()?['present'] == true) : false;
    }
  }

  Future<void> saveAttendance(List<ChildModel> children) async {
    setState(() {
      isSaving = true;
    });

    try {
      for (final child in children) {
        final present = attendanceValues[child.id] ?? false;
        final docId = '${child.id}_$dateKey';

        await _firestore.collection('attendance').doc(docId).set({
          'childId': child.id,
          'childName': child.name,
          'section': child.section,
          'group': child.group,
          'dateKey': dateKey,
          'present': present,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ حضور أطفال الروضة ✅')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ الحضور: $e')),
      );
    }

    if (!mounted) return;

    setState(() {
      isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateText = '${today.year}/${today.month}/${today.day}';

    if (!isSupportedSection) {
      return AppPageScaffold(
        title: 'تسجيل الحضور',
        child: ListView(
          children: [
            Text(
              'تسجيل الحضور',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'هذه الصفحة مخصصة لأطفال الروضة فقط.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.warning.withOpacity(0.12),
                      child: const Icon(
                        Icons.info_outline,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'لا يتم استخدام الحضور اليومي الثابت في قسم الحضانة، لأن حضور الطفل يكون مرنًا حسب الزيارة. يمكن متابعة أطفال الحضانة عبر التحديثات والصور والملاحظات.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppPageScaffold(
      title: 'تسجيل الحضور',
      child: FutureBuilder<List<ChildModel>>(
        future: fetchChildren(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ: ${snapshot.error}'),
            );
          }

          final children = snapshot.data ?? [];

          return FutureBuilder<void>(
            future: loadAttendanceForChildren(children),
            builder: (context, attendanceSnapshot) {
              if (attendanceSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              return ListView(
                children: [
                  Text(
                    'الحضور اليومي',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pageDescription(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textLight,
                        ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withOpacity(0.12),
                            child: const Icon(
                              Icons.calendar_today_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'تاريخ اليوم: $dateText',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withOpacity(0.12),
                            child: const Icon(
                              Icons.school_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'القسم الحالي: روضة',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (children.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'لا يوجد أطفال في قسم الروضة حاليًا.',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    )
                  else
                    ...children.map(
                      (child) => _AttendanceChildCard(
                        child: child,
                        isPresent: attendanceValues[child.id] ?? false,
                        sectionText: sectionLabel(child.section),
                        onChanged: (value) {
                          setState(() {
                            attendanceValues[child.id] = value;
                          });
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: isSaving ? null : () => saveAttendance(children),
                    icon: isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ الحضور'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AttendanceChildCard extends StatelessWidget {
  final ChildModel child;
  final bool isPresent;
  final String sectionText;
  final ValueChanged<bool> onChanged;

  const _AttendanceChildCard({
    required this.child,
    required this.isPresent,
    required this.sectionText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: const Icon(
                Icons.child_care,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$sectionText • ${child.group}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: isPresent,
                  onChanged: onChanged,
                ),
                Text(
                  isPresent ? 'حاضر' : 'غائب',
                  style: TextStyle(
                    fontSize: 12,
                    color: isPresent ? Colors.green : Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}