import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ManageClassesPage extends StatefulWidget {
  const ManageClassesPage({super.key});

  @override
  State<ManageClassesPage> createState() => _ManageClassesPageState();
}

class _ManageClassesPageState extends State<ManageClassesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  String section = 'Nursery';
  String selectedSectionFilter = 'all';
  String searchText = '';

  @override
  void dispose() {
    nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String sectionLabel(String s) {
    switch (s) {
      case 'Nursery':
        return 'حضانة';
      case 'Kindergarten':
        return 'روضة';
      case 'all':
        return 'كل الأقسام';
      default:
        return s;
    }
  }

  Color sectionColor(String s) {
    switch (s) {
      case 'Nursery':
        return const Color(0xFFEFA7C8);
      case 'Kindergarten':
        return const Color(0xFF7BB6FF);
      default:
        return AppColors.primary;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> classesStream() {
    return _firestore
        .collection('classes')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<bool> _classNameExists({
    required String name,
    required String section,
    String? ignoreDocId,
  }) async {
    final snapshot = await _firestore
        .collection('classes')
        .where('name', isEqualTo: name.trim())
        .where('section', isEqualTo: section.trim())
        .get();

    for (final doc in snapshot.docs) {
      if (ignoreDocId == null || doc.id != ignoreDocId) {
        return true;
      }
    }
    return false;
  }

  Future<int> _countLinkedChildren({
    required String groupName,
    required String section,
  }) async {
    final snapshot = await _firestore
        .collection('children')
        .where('section', isEqualTo: section)
        .where('group', isEqualTo: groupName)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.length;
  }

  Future<int> _countLinkedTeachers(String groupName) async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .get();

    int count = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final rawGroups = data['assignedGroups'];

      if (rawGroups is List) {
        final groups = rawGroups.map((e) => e.toString().trim()).toList();
        if (groups.contains(groupName.trim())) {
          count++;
        }
      }
    }

    return count;
  }

  Future<void> openAddDialog() async {
    nameCtrl.clear();
    section = 'Nursery';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('إضافة صف / مجموعة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الصف / المجموعة',
                      prefixIcon: Icon(Icons.class_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: section,
                    decoration: const InputDecoration(
                      labelText: 'القسم',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Nursery',
                        child: Text('حضانة'),
                      ),
                      DropdownMenuItem(
                        value: 'Kindergarten',
                        child: Text('روضة'),
                      ),
                    ],
                    onChanged: (v) {
                      setLocal(() {
                        section = v ?? 'Nursery';
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'ملاحظة: عدد الأطفال لا يتم إدخاله يدويًا هنا، بل يتم حسابه تلقائيًا من الأطفال المرتبطين بهذه المجموعة.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('اكتبي اسم الصف / المجموعة'),
                      ),
                    );
                    return;
                  }

                  try {
                    final exists = await _classNameExists(
                      name: name,
                      section: section,
                    );

                    if (exists) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يوجد صف / مجموعة بنفس الاسم داخل هذا القسم',
                          ),
                        ),
                      );
                      return;
                    }

                    await _firestore.collection('classes').add({
                      'name': name,
                      'section': section,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    if (!mounted) return;
                    Navigator.pop(context);

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت إضافة الصف / المجموعة بنجاح ✅'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ أثناء إضافة الصف: $e'),
                      ),
                    );
                  }
                },
                child: const Text('إضافة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openEditDialog({
    required String docId,
    required Map<String, dynamic> classData,
  }) async {
    nameCtrl.text = (classData['name'] ?? '').toString();
    String localSection = (classData['section'] ?? 'Nursery').toString();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('تعديل الصف / المجموعة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الصف / المجموعة',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: localSection,
                    decoration: const InputDecoration(
                      labelText: 'القسم',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Nursery',
                        child: Text('حضانة'),
                      ),
                      DropdownMenuItem(
                        value: 'Kindergarten',
                        child: Text('روضة'),
                      ),
                    ],
                    onChanged: (v) {
                      setLocal(() {
                        localSection = v ?? 'Nursery';
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.24),
                      ),
                    ),
                    child: const Text(
                      'تنبيه: عند تعديل اسم المجموعة أو قسمها تأكدي أن الأطفال أو المعلمات المرتبطين بها تم تحديثهم إن لزم.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = nameCtrl.text.trim();

                  if (newName.isEmpty) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('اكتبي اسم الصف / المجموعة'),
                      ),
                    );
                    return;
                  }

                  try {
                    final exists = await _classNameExists(
                      name: newName,
                      section: localSection,
                      ignoreDocId: docId,
                    );

                    if (exists) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يوجد صف / مجموعة بنفس الاسم داخل هذا القسم',
                          ),
                        ),
                      );
                      return;
                    }

                    await _firestore.collection('classes').doc(docId).update({
                      'name': newName,
                      'section': localSection,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    if (!mounted) return;
                    Navigator.pop(context);

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تعديل الصف / المجموعة بنجاح ✅'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ أثناء التعديل: $e'),
                      ),
                    );
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> deleteClass({
    required String id,
    required String name,
    required String section,
  }) async {
    final linkedChildren = await _countLinkedChildren(
      groupName: name,
      section: section,
    );
    final linkedTeachers = await _countLinkedTeachers(name);

    if (linkedChildren > 0 || linkedTeachers > 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            linkedChildren > 0 && linkedTeachers > 0
                ? 'لا يمكن حذف المجموعة لأنها مرتبطة بـ $linkedChildren طفل/أطفال و $linkedTeachers معلمة/معلمات'
                : linkedChildren > 0
                    ? 'لا يمكن حذف المجموعة لأنها مرتبطة بـ $linkedChildren طفل/أطفال'
                    : 'لا يمكن حذف المجموعة لأنها مرتبطة بـ $linkedTeachers معلمة/معلمات',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('تأكيد الحذف'),
              content: Text('هل أنتِ متأكدة من حذف "$name"؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('حذف'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await _firestore.collection('classes').doc(id).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الصف / المجموعة من النظام ✅'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حذف الصف: $e'),
        ),
      );
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final sectionValue = (data['section'] ?? '').toString();

      final matchesSection = selectedSectionFilter == 'all' ||
          sectionValue == selectedSectionFilter;

      final q = searchText.trim().toLowerCase();
      final matchesSearch =
          q.isEmpty || name.contains(q) || sectionLabel(sectionValue).contains(q);

      return matchesSection && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إدارة الصفوف والأقسام',
      floatingActionButton: FloatingActionButton(
        onPressed: openAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: classesStream(),
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

          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = applyFilters(docs);

          return ListView(
            children: [
              Text(
                'إدارة الصفوف والمجموعات',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'إضافة وتعديل وتنظيم الصفوف والمجموعات داخل الحضانة والروضة.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'ملاحظة: عدد الأطفال في كل مجموعة يتم احتسابه تلقائيًا من بيانات الأطفال النشطين، ولا يُدخل يدويًا.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: 'ابحثي باسم الصف / المجموعة',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: searchText.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
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
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedSectionFilter,
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
                            child: Text('حضانة'),
                          ),
                          DropdownMenuItem(
                            value: 'Kindergarten',
                            child: Text('روضة'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedSectionFilter = value ?? 'all';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (filteredDocs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      docs.isEmpty
                          ? 'لا توجد صفوف أو مجموعات حاليًا.'
                          : 'لا توجد نتائج مطابقة حاليًا.',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              else
                ...filteredDocs.map((doc) {
                  final c = doc.data();
                  final className = (c['name'] ?? '').toString();
                  final classSection = (c['section'] ?? 'Nursery').toString();

                  return FutureBuilder<List<int>>(
                    future: Future.wait([
                      _countLinkedChildren(
                        groupName: className,
                        section: classSection,
                      ),
                      _countLinkedTeachers(className),
                    ]),
                    builder: (context, countsSnapshot) {
                      final childrenCount = countsSnapshot.data?[0] ?? 0;
                      final teachersCount = countsSnapshot.data?[1] ?? 0;

                      return _ClassCard(
                        name: className,
                        sectionText: sectionLabel(classSection),
                        sectionBadgeColor: sectionColor(classSection),
                        childrenCount: childrenCount,
                        teachersCount: teachersCount,
                        onEdit: () => openEditDialog(
                          docId: doc.id,
                          classData: c,
                        ),
                        onDelete: () => deleteClass(
                          id: doc.id,
                          name: className,
                          section: classSection,
                        ),
                      );
                    },
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final String name;
  final String sectionText;
  final Color sectionBadgeColor;
  final int childrenCount;
  final int teachersCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClassCard({
    required this.name,
    required this.sectionText,
    required this.sectionBadgeColor,
    required this.childrenCount,
    required this.teachersCount,
    required this.onEdit,
    required this.onDelete,
  });

  Widget _chip({
    required String text,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            text,
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: const Icon(
                    Icons.class_,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  text: sectionText,
                  color: sectionBadgeColor,
                  icon: Icons.apartment_outlined,
                ),
                _chip(
                  text: 'الأطفال: $childrenCount',
                  color: AppColors.primary,
                  icon: Icons.child_care_outlined,
                ),
                _chip(
                  text: 'المعلمات: $teachersCount',
                  color: Colors.teal,
                  icon: Icons.school_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('تعديل'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'حذف',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.redAccent.withOpacity(0.35),
                      ),
                    ),
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