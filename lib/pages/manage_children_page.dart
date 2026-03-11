import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
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

  void openAddDialog() {
    nameCtrl.clear();
    parentCtrl.clear();
    parentUsernameCtrl.clear();
    birthDate = null;
    section = 'Nursery';
    group = 'حضانة صغار';

    showDialog(
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
                onPressed: () {
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

                  DummyData.addChild(
                    ChildModel(
                      id: DummyData.newId('c'),
                      name: name,
                      section: section,
                      group: group,
                      parentName: parent,
                      birthDate: birthDate!,
                      parentUsername: parentUsername,
                    ),
                  );

                  setState(() {});
                  Navigator.pop(context);

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('تمت إضافة الطفل بنجاح ✅'),
                    ),
                  );
                },
                child: const Text('إضافة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openEditDialog(ChildModel child) {
    nameCtrl.text = child.name;
    parentCtrl.text = child.parentName;
    parentUsernameCtrl.text = child.parentUsername;
    section = child.section;
    group = child.group;
    birthDate = child.birthDate;

    showDialog(
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
                onPressed: () {
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

                  DummyData.updateChild(
                    ChildModel(
                      id: child.id,
                      name: name,
                      section: section,
                      group: group,
                      parentName: parent,
                      birthDate: birthDate!,
                      parentUsername: parentUsername,
                    ),
                  );

                  setState(() {});
                  Navigator.pop(context);

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حفظ التعديلات ✅'),
                    ),
                  );
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void deleteChild(String id) {
    DummyData.deleteChild(id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final children = DummyData.children;

    return AppPageScaffold(
      title: 'إدارة الأطفال',
      floatingActionButton: FloatingActionButton(
        onPressed: openAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      child: ListView(
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