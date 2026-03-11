import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'عدد الأطفال:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text('$count'),
                    ],
                  ),
                  Slider(
                    value: count.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: '$count',
                    onChanged: (v) {
                      setLocal(() {
                        count = v.toInt();
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

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('اكتبي اسم الصف / المجموعة'),
                      ),
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

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('تمت إضافة الصف بنجاح ✅'),
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

  void deleteClass(String id) {
    DummyData.deleteClass(id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final classes = DummyData.classes;

    return AppPageScaffold(
      title: 'إدارة الصفوف والأقسام',
      floatingActionButton: FloatingActionButton(
        onPressed: openAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      child: ListView(
        children: [
          Text(
            'إدارة الصفوف والمجموعات',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'إضافة وحذف الصفوف وتنظيم الأقسام داخل الحضانة والروضة',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
          const SizedBox(height: 20),
          if (classes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'لا توجد صفوف أو مجموعات حاليًا.',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 15,
                  ),
                ),
              ),
            )
          else
            ...classes.map(
              (c) => _ClassCard(
                name: c['name'],
                sectionText: sectionLabel(c['section']),
                childrenCount: c['childrenCount'],
                onDelete: () => deleteClass(c['id']),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final String name;
  final String sectionText;
  final int childrenCount;
  final VoidCallback onDelete;

  const _ClassCard({
    required this.name,
    required this.sectionText,
    required this.childrenCount,
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
                Icons.class_,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$sectionText • عدد الأطفال: $childrenCount',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
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