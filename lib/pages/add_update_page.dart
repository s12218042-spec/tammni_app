import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/child_model.dart';
import '../models/update_model.dart';
import '../widgets/app_bar_widget.dart';

class AddUpdatePage extends StatefulWidget {
  final ChildModel child;
  final String byRole; // nursery / teacher

  const AddUpdatePage({super.key, required this.child, required this.byRole});

  @override
  State<AddUpdatePage> createState() => _AddUpdatePageState();
}

class _AddUpdatePageState extends State<AddUpdatePage> {
  final TextEditingController noteCtrl = TextEditingController();

  String type = 'ملاحظة';

  final List<String> nurseryTypes = ['وجبة', 'نوم', 'حفاض', 'صحة', 'نشاط', 'ملاحظة'];
  final List<String> teacherTypes = ['نشاط', 'خطة اليوم', 'تقييم', 'واجب', 'ملاحظة'];

  List<String> get types => widget.byRole == 'nursery' ? nurseryTypes : teacherTypes;

  void save() {
    if (noteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتبي ملاحظة قصيرة')),
      );
      return;
    }

    final update = UpdateModel(
      id: DummyData.newId('u'),
      childId: widget.child.id,
      childName: widget.child.name,
      type: type,
      note: noteCtrl.text.trim(),
      time: DateTime.now(),
      byRole: widget.byRole,
    );

    DummyData.updates.add(update);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ التحديث ✅')),
    );

    Navigator.pop(context, true); // رجّع true عشان نعمل refresh
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AppBarWidget(
  title: 'إدارة الأطفال',
),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF6F6FF),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('القسم: ${widget.child.section}'),
                    const SizedBox(height: 4),
                    Text('المجموعة/الصف: ${widget.child.group}'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const Text('نوع التحديث', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: types.contains(type) ? type : types.first,
                items: types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => type = v ?? types.first),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              const Text('الملاحظة', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              TextField(
                controller: noteCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'مثال: تناول وجبة الفطور / نشاط تلوين / بحاجة دواء...',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: save,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ التحديث'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E97FD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}