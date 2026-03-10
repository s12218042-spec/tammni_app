import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/child_model.dart';
import '../widgets/app_bar_widget.dart';

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
        builder: (context, setLocal) => AlertDialog(
          title: const Text('إضافة طفل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الطفل'),
                ),
                TextField(
                  controller: parentCtrl,
                  decoration: const InputDecoration(labelText: 'اسم ولي الأمر'),
                ),
                TextField(
                  controller: parentUsernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم مستخدم ولي الأمر',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => pickBirthDate(setLocal),
                    icon: const Icon(Icons.calendar_month),
                    label: Text(birthDateText()),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: section,
                  items: const [
                    DropdownMenuItem(value: 'Nursery', child: Text('حضانة')),
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
                  decoration: const InputDecoration(labelText: 'القسم'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: group,
                  items: groupsBySection
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) {
                    setLocal(() {
                      group = v ?? groupsBySection.first;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'الصف/المجموعة'),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('اكتبي اسم الطفل وولي الأمر واسم المستخدم'),
                    ),
                  );
                  return;
                }

                if (birthDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('اختاري تاريخ الميلاد')),
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
              },
              child: const Text('إضافة'),
            ),
          ],
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
        builder: (context, setLocal) => AlertDialog(
          title: const Text('تعديل طفل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الطفل'),
                ),
                TextField(
                  controller: parentCtrl,
                  decoration: const InputDecoration(labelText: 'اسم ولي الأمر'),
                ),
                TextField(
                  controller: parentUsernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم مستخدم ولي الأمر',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => pickBirthDate(setLocal),
                    icon: const Icon(Icons.calendar_month),
                    label: Text(birthDateText()),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: section,
                  items: const [
                    DropdownMenuItem(value: 'Nursery', child: Text('حضانة')),
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
                  decoration: const InputDecoration(labelText: 'القسم'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: group,
                  items: groupsBySection
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) {
                    setLocal(() {
                      group = v ?? child.group;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'الصف/المجموعة'),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('اكتبي اسم الطفل وولي الأمر واسم المستخدم'),
                    ),
                  );
                  return;
                }

                if (birthDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('اختاري تاريخ الميلاد')),
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
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void deleteChild(String id) {
    DummyData.deleteChild(id);
    setState(() {});
  }

  String sectionLabel(String s) => s == 'Nursery' ? 'حضانة' : 'روضة';

  @override
  Widget build(BuildContext context) {
    final children = DummyData.children;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AppBarWidget(
  title: 'إدارة الأطفال',
),
        floatingActionButton: FloatingActionButton(
          onPressed: openAddDialog,
          backgroundColor: const Color(0xFF8E97FD),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            itemCount: children.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = children[i];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF8E97FD),
                      child: Icon(Icons.child_care, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${sectionLabel(c.section)} • ${c.group} • ولي الأمر: ${c.parentName}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => openEditDialog(c),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () => deleteChild(c.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}