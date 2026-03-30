import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AdminTeacherAssignmentsPage extends StatefulWidget {
  const AdminTeacherAssignmentsPage({super.key});

  @override
  State<AdminTeacherAssignmentsPage> createState() =>
      _AdminTeacherAssignmentsPageState();
}

class _AdminTeacherAssignmentsPageState
    extends State<AdminTeacherAssignmentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedSection = 'all';

  String sectionLabel(String value) {
    switch (value) {
      case 'Nursery':
        return 'الحضانة';
      case 'Kindergarten':
        return 'الروضة';
      case 'all':
        return 'كل الأقسام';
      default:
        return value;
    }
  }

  Color sectionColor(String section) {
    if (section == 'Nursery') return const Color(0xFFEFA7C8);
    if (section == 'Kindergarten') return const Color(0xFF7BB6FF);
    return AppColors.primary;
  }

  List<Map<String, dynamic>> filterTeachers(
    List<Map<String, dynamic>> teachers,
  ) {
    if (selectedSection == 'all') return teachers;

    return teachers.where((teacher) {
      final section = (teacher['section'] ?? '').toString().trim();
      return section == selectedSection;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchTeachers() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'docId': doc.id,
        ...data,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchClasses() async {
    final snapshot = await _firestore.collection('classes').get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'docId': doc.id,
        ...data,
      };
    }).toList();
  }

  Future<void> openAssignmentsDialog({
    required Map<String, dynamic> teacher,
    required List<Map<String, dynamic>> allClasses,
  }) async {
    final teacherName =
        (teacher['displayName'] ?? teacher['name'] ?? 'معلمة').toString();
    final teacherSection = (teacher['section'] ?? '').toString().trim();

    List<Map<String, dynamic>> availableClasses = allClasses;

    if (teacherSection.isNotEmpty) {
      availableClasses = allClasses.where((item) {
        final section = (item['section'] ?? '').toString().trim();
        return section == teacherSection;
      }).toList();
    }

    final currentAssignedGroups =
        ((teacher['assignedGroups'] ?? []) as List).map((e) => e.toString()).toList();

    final selectedGroups = <String>{...currentAssignedGroups};

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                title: Text('تعيين مجموعات للمعلمة $teacherName'),
                content: SizedBox(
                  width: 380,
                  child: availableClasses.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'لا توجد مجموعات متاحة لهذا القسم حالياً.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: availableClasses.map((classItem) {
                              final groupName = (classItem['name'] ??
                                      classItem['group'] ??
                                      classItem['title'] ??
                                      '')
                                  .toString()
                                  .trim();

                              if (groupName.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              final section =
                                  (classItem['section'] ?? '').toString();

                              final isChecked =
                                  selectedGroups.contains(groupName);

                              return CheckboxListTile(
                                value: isChecked,
                                contentPadding: EdgeInsets.zero,
                                title: Text(groupName),
                                subtitle: section.isNotEmpty
                                    ? Text('القسم: ${sectionLabel(section)}')
                                    : null,
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      selectedGroups.add(groupName);
                                    } else {
                                      selectedGroups.remove(groupName);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('حفظ'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved != true) return;

    await _firestore.collection('users').doc(teacher['docId']).update({
      'assignedGroups': selectedGroups.toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تحديث مجموعات المعلمة $teacherName بنجاح'),
      ),
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'تعيين المعلمات',
      child: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          fetchTeachers(),
          fetchClasses(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ أثناء تحميل البيانات:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final teachers =
              (snapshot.data?[0] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final classes =
              (snapshot.data?[1] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

          final filteredTeachers = filterTeachers(teachers);

          return Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: DropdownButtonFormField<String>(
                    value: selectedSection,
                    decoration: InputDecoration(
                      labelText: 'فلترة حسب القسم',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('كل الأقسام'),
                      ),
                      DropdownMenuItem(
                        value: 'Nursery',
                        child: Text('الحضانة'),
                      ),
                      DropdownMenuItem(
                        value: 'Kindergarten',
                        child: Text('الروضة'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedSection = value ?? 'all';
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredTeachers.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.12),
                                child: const Icon(
                                  Icons.school_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'لا توجد معلمات حالياً',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'عند إضافة حسابات للمعلمات ستظهر هنا.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredTeachers.length,
                        itemBuilder: (context, index) {
                          final teacher = filteredTeachers[index];

                          final teacherName = (teacher['displayName'] ??
                                  teacher['name'] ??
                                  'معلمة')
                              .toString();

                          final username =
                              (teacher['username'] ?? '').toString().trim();

                          final email =
                              (teacher['email'] ?? '').toString().trim();

                          final section =
                              (teacher['section'] ?? '').toString().trim();

                          final assignedGroups =
                              ((teacher['assignedGroups'] ?? []) as List)
                                  .map((e) => e.toString())
                                  .toList();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor:
                                            AppColors.primary.withOpacity(0.12),
                                        child: const Icon(
                                          Icons.person_outline_rounded,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              teacherName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (username.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                'اسم المستخدم: $username',
                                                style: const TextStyle(
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                            if (email.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                email,
                                                style: const TextStyle(
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (section.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: sectionColor(section)
                                                .withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            'القسم: ${sectionLabel(section)}',
                                            style: TextStyle(
                                              color: sectionColor(section),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      if (assignedGroups.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.10),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: const Text(
                                            'لا توجد مجموعات معيّنة',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        )
                                      else
                                        ...assignedGroups.map(
                                          (group) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.withOpacity(0.10),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              group,
                                              style: const TextStyle(
                                                color: Colors.teal,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        openAssignmentsDialog(
                                          teacher: teacher,
                                          allClasses: classes,
                                        );
                                      },
                                      icon: const Icon(Icons.edit_outlined),
                                      label: Text(
                                        assignedGroups.isEmpty
                                            ? 'تعيين المجموعات'
                                            : 'تعديل المجموعات',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}