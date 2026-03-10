import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../widgets/app_bar_widget.dart';

class ManageClassesPage extends StatefulWidget {
  const ManageClassesPage({super.key});

  @override
  State<ManageClassesPage> createState() => _ManageClassesPageState();
}

class _ManageClassesPageState extends State<ManageClassesPage> {
  final nameCtrl = TextEditingController();
  String section = 'Nursery';
  int count = 10;

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  String sectionLabel(String s) => s == 'Nursery' ? 'حضانة' : 'روضة';

  void openAddDialog() {
    nameCtrl.clear();
    section = 'Nursery';
    count = 10;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة صف/مجموعة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم الصف/المجموعة',
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
                onChanged: (v) => setState(() => section = v ?? 'Nursery'),
                decoration: const InputDecoration(labelText: 'القسم'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('عدد الأطفال:'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Slider(
                      value: count.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: '$count',
                      onChanged: (v) => setState(() => count = v.toInt()),
                    ),
                  ),
                ],
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
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('اكتبي اسم الصف/المجموعة')),
                );
                return;
              }

              DummyData.addClass({
                'id': DummyData.newId('class'),
                'section': section,
                'name': name,
                'childrenCount': count,
              });

              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void deleteClass(String id) {
    DummyData.deleteClass(id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final classes = DummyData.classes;

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
            itemCount: classes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = classes[i];
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
                      child: Icon(Icons.class_, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${sectionLabel(c['section'])} • عدد الأطفال: ${c['childrenCount']}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => deleteClass(c['id']),
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