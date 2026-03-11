import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/child_model.dart';
import '../models/update_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'add_update_page.dart';
import 'attendance_page.dart';
import 'camera_checkin_page.dart';

class NurseryStaffHomePage extends StatefulWidget {
  const NurseryStaffHomePage({super.key});

  @override
  State<NurseryStaffHomePage> createState() => _NurseryStaffHomePageState();
}

class _NurseryStaffHomePageState extends State<NurseryStaffHomePage> {
  List<ChildModel> get nurseryChildren =>
      DummyData.children.where((c) => c.section == 'Nursery').toList();

  Future<void> openAddUpdate(ChildModel child) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddUpdatePage(
          child: child,
          byRole: 'nursery',
        ),
      ),
    );

    if (res == true) {
      setState(() {});
    }
  }

  Future<void> openAttendance() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AttendancePage(
          sectionFilter: 'Nursery',
        ),
      ),
    );

    if (res == true) {
      setState(() {});
    }
  }

  Future<void> openCameraCheckin(ChildModel child) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraCheckinPage(),
      ),
    );

    if (res is Map) {
      final path = res['path'] as String?;
      final type = res['type'] as String?;

      if (path == null || type == null) return;

      DummyData.updates.add(
        UpdateModel(
          id: DummyData.newId('u'),
          childId: child.id,
          childName: child.name,
          type: 'كاميرا',
          note: type == 'image'
              ? 'صورة للطفل 📸'
              : 'فيديو قصير للطفل 🎥',
          time: DateTime.now(),
          byRole: 'nursery',
          mediaPath: path,
          mediaType: type,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال Check-in ✅'),
        ),
      );

      setState(() {});
    }
  }

  void sendNotificationPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ميزة إرسال الإشعار للأهل سنطوّرها لاحقًا ✅'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الرئيسية - موظفة الحضانة',
      child: ListView(
        children: [
          Text(
            'أهلاً 👩‍🍼',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'اختاري طفلًا لتسجيل تحديث جديد أو إرسال Check-in بالكاميرا',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
          const SizedBox(height: 20),

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
                          Icons.how_to_reg,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'تسجيل حضور أطفال الحضانة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: openAttendance,
                      icon: const Icon(Icons.checklist_rtl),
                      label: const Text('فتح صفحة الحضور'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (nurseryChildren.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'لا يوجد أطفال في قسم الحضانة حاليًا.',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 15,
                  ),
                ),
              ),
            )
          else
            ...nurseryChildren.map(
              (c) => _ChildActionCard(
                childModel: c,
                onAddUpdate: () => openAddUpdate(c),
                onCamera: () => openCameraCheckin(c),
              ),
            ),

          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: sendNotificationPlaceholder,
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('إرسال إشعار للأهل'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildActionCard extends StatelessWidget {
  final ChildModel childModel;
  final VoidCallback onAddUpdate;
  final VoidCallback onCamera;

  const _ChildActionCard({
    required this.childModel,
    required this.onAddUpdate,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Icons.child_care,
                    color: Colors.white,
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
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        childModel.group,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('كاميرا'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAddUpdate,
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('إضافة تحديث'),
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