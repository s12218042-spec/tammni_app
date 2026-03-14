import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AddUpdatePage extends StatefulWidget {
  final ChildModel child;
  final String byRole; // nursery / teacher

  const AddUpdatePage({
    super.key,
    required this.child,
    required this.byRole,
  });

  @override
  State<AddUpdatePage> createState() => _AddUpdatePageState();
}

class _AddUpdatePageState extends State<AddUpdatePage> {
  final TextEditingController noteCtrl = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String type = 'ملاحظة';
  bool isLoading = false;

  final List<String> nurseryTypes = [
    'وجبة',
    'نوم',
    'حفاض',
    'صحة',
    'نشاط',
    'ملاحظة',
  ];

  final List<String> teacherTypes = [
    'نشاط',
    'خطة اليوم',
    'تقييم',
    'واجب',
    'ملاحظة',
  ];

  List<String> get types =>
      widget.byRole == 'nursery' ? nurseryTypes : teacherTypes;

  String sectionLabel(String s) {
    if (s == 'Nursery') return 'حضانة';
    if (s == 'Kindergarten') return 'روضة';
    return s;
  }

  String roleLabel() {
    return widget.byRole == 'nursery' ? 'موظفة الحضانة' : 'المعلمة';
  }

  @override
  void initState() {
    super.initState();
    if (!types.contains(type)) {
      type = types.first;
    }
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (noteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اكتبي ملاحظة قصيرة'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await _firestore.collection('updates').add({
        'childId': widget.child.id,
        'childName': widget.child.name,
        'parentUsername': widget.child.parentUsername,
        'type': type,
        'note': noteCtrl.text.trim(),
        'time': FieldValue.serverTimestamp(),
        'byRole': widget.byRole,
        'mediaType': null,
        'mediaPath': null,
        'mediaUrl': null,
        'hasMedia': false,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التحديث'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ التحديث: $e'),
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إضافة تحديث',
      child: ListView(
        children: [
          Text(
            'إضافة تحديث جديد',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'أضيفي ملاحظة أو تحديثًا خاصًا بالطفل ليظهر لوليّ الأمر',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: const Icon(
                          Icons.child_care,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.child.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.apartment_outlined,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'القسم: ${sectionLabel(widget.child.section)}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_outlined,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'الصف / المجموعة: ${widget.child.group}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'بواسطة: ${roleLabel()}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'نوع التحديث',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: types.contains(type) ? type : types.first,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: types
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                type = v ?? types.first;
              });
            },
          ),
          const SizedBox(height: 18),
          Text(
            'الملاحظة',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText:
                  'مثال: تناول وجبة الفطور / شارك في نشاط تلوين / بحاجة إلى متابعة...',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.edit_note_outlined),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: isLoading ? null : save,
            icon: isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(isLoading ? 'جاري الحفظ...' : 'حفظ التحديث'),
          ),
        ],
      ),
    );
  }
}