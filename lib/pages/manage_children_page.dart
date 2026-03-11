import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ManageChildrenPage extends StatefulWidget {
  const ManageChildrenPage({super.key});

  @override
  State<ManageChildrenPage> createState() => _ManageChildrenPageState();
}

class _ManageChildrenPageState extends State<ManageChildrenPage> {
  final nameCtrl = TextEditingController();
  final parentCtrl = TextEditingController();
  final parentUsernameCtrl = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String section = 'Nursery';
  String group = 'حضانة صغار';
  DateTime? birthDate;

  @override
  void dispose() {
    nameCtrl.dispose();
    parentCtrl.dispose();
    parentUsernameCtrl.dispose();
    super.dispose();
  }

  List<String> get groupsBySection {
    if (section == 'Nursery') {
      return ['حضانة صغار', 'حضانة كبار'];
    }
    return ['KG1', 'KG2'];
  }

  Future<void> pickBirthDate(StateSetter setLocal) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 2),
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );

    if (picked != null) {
      setLocal(() {
        birthDate = picked;
      });
    }
  }

  String birthDateText() {
    if (birthDate == null) return 'اختيار تاريخ الميلاد';
    return '${birthDate!.year}/${birthDate!.month}/${birthDate!.day}';
  }

  String sectionLabel(String s) => s == 'Nursery' ? 'حضانة' : 'روضة';

  Stream<QuerySnapshot<Map<String, dynamic>>> childrenStream() {
    return _firestore
        .collection('children')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> openAddDialog() async {
    nameCtrl.clear();
    parentCtrl.clear();
    parentUsernameCtrl.clear();
    birthDate = null;
    section = 'Nursery';
    group = 'حضانة صغار';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('إضافة طفل'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الطفل',
                      prefixIcon: Icon(Icons.child_care),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: parentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم ولي الأمر',
                      prefixIcon: Icon(Icons.family_restroom),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: parentUsernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم مستخدم ولي الأمر',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => pickBirthDate(setLocal),
                      icon: const Icon(Icons.calendar_month),
                      label: Text(birthDateText()),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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
                        group = groupsBySection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: group,
                    decoration: const InputDecoration(
                      labelText: 'الصف / المجموعة',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    items: groupsBySection
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) {
                      setLocal(() {
                        group = v ?? groupsBySection.first;
                      });
                    },
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
                  final parent = parentCtrl.text.trim();
                  final parentUsername = parentUsernameCtrl.text.trim();

                  if (name.isEmpty || parent.isEmpty || parentUsername.isEmpty) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('اكتبي اسم الطفل وولي الأمر واسم المستخدم'),
                      ),
                    );
                    return;
                  }

                  if (birthDate == null) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('اختاري تاريخ الميلاد'),
                      ),
                    );
                    return;
                  }

                  try {
                    await _firestore.collection('children').add({
                      'name': name,
                      'section': section,
                      'group': group,
                      'parentName': parent,
                      'parentUsername': parentUsername,
                      'birthDate': Timestamp.fromDate(birthDate!),
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    if (!mounted) return;
                    Navigator.pop(context);

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت إضافة الطفل بنجاح ✅'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ أثناء إضافة الطفل: $e'),
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

  Future<void> openEditDialog(ChildModel child) async {
    nameCtrl.text = child.name;
    parentCtrl.text = child.parentName;
    parentUsernameCtrl.text = child.parentUsername;
    section = child.section;
    group = child.group;
    birthDate = child.birthDate;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('تعديل طفل'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الطفل',
                      prefixIcon: Icon(Icons.child_care),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: parentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم ولي الأمر',
                      prefixIcon: Icon(Icons.family_restroom),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: parentUsernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم مستخدم ولي الأمر',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => pickBirthDate(setLocal),
                      icon: const Icon(Icons.calendar_month),
                      label: Text(birthDateText()),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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
                        section = v ?? child.section;
                        group = groupsBySection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: group,
                    decoration: const InputDecoration(
                      labelText: 'الصف / المجموعة',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    items: groupsBySection
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) {
                      setLocal(() {
                        group = v ?? child.group;
                      });
                    },
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
                  final parent = parentCtrl.text.trim();
                  final parentUsername = parentUsernameCtrl.text.trim();

                  if (name.isEmpty || parent.isEmpty || parentUsername.isEmpty) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('اكتبي اسم الطفل وولي الأمر واسم المستخدم'),
                      ),
                    );
                    return;
                  }

                  if (birthDate == null) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('اختاري تاريخ الميلاد'),
                      ),
                    );
                    return;
                  }

                  try {
                    await _firestore.collection('children').doc(child.id).update({
                      'name': name,
                      'section': section,
                      'group': group,
                      'parentName': parent,
                      'parentUsername': parentUsername,
                      'birthDate': Timestamp.fromDate(birthDate!),
                    });

                    if (!mounted) return;
                    Navigator.pop(context);

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حفظ التعديلات ✅'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ أثناء تعديل الطفل: $e'),
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

  Future<void> deleteChild(String id) async {
    try {
      await _firestore.collection('children').doc(id).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الطفل من النظام ✅'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حذف الطفل: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إدارة الأطفال',
      floatingActionButton: FloatingActionButton(
        onPressed: openAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: childrenStream(),
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

          final children = docs.map((doc) {
            final data = doc.data();

            return ChildModel(
              id: doc.id,
              name: data['name'] ?? '',
              section: data['section'] ?? 'Nursery',
              group: data['group'] ?? '',
              parentName: data['parentName'] ?? '',
              parentUsername: data['parentUsername'] ?? '',
              birthDate: data['birthDate'] is Timestamp
                  ? (data['birthDate'] as Timestamp).toDate()
                  : DateTime.now(),
            );
          }).toList();

          return ListView(
            children: [
              Text(
                'إدارة الأطفال',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'إضافة وتعديل وحذف بيانات الأطفال وربطهم بالأقسام والأهالي',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
              ),
              const SizedBox(height: 20),
              if (children.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'لا يوجد أطفال حاليًا.',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              else
                ...children.map(
                  (c) => _ChildCard(
                    childModel: c,
                    sectionText: sectionLabel(c.section),
                    onEdit: () => openEditDialog(c),
                    onDelete: () => deleteChild(c.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final ChildModel childModel;
  final String sectionText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ChildCard({
    required this.childModel,
    required this.sectionText,
    required this.onEdit,
    required this.onDelete,
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
                    childModel.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$sectionText • ${childModel.group}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ولي الأمر: ${childModel.parentName}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'اسم المستخدم: ${childModel.parentUsername}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'تعديل',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              color: AppColors.primary,
            ),
            IconButton(
              tooltip: 'حذف',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }
}