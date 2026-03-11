import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'attendance_page.dart';
import 'add_update_page.dart';
import 'camera_checkin_page.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ChildModel>> fetchKgChildren() async {
    final snapshot = await _firestore
        .collection('children')
        .where('section', isEqualTo: 'Kindergarten')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return ChildModel(
        id: doc.id,
        name: data['name'] ?? '',
        section: data['section'] ?? 'Kindergarten',
        group: data['group'] ?? '',
        parentName: data['parentName'] ?? '',
        parentUsername: data['parentUsername'] ?? '',
        birthDate: data['birthDate'] is Timestamp
            ? (data['birthDate'] as Timestamp).toDate()
            : DateTime.now(),
      );
    }).toList();
  }

  Future<void> openAddUpdate(ChildModel child) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddUpdatePage(
          child: child,
          byRole: 'teacher',
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
        builder: (context) =>
            const AttendancePage(sectionFilter: 'Kindergarten'),
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

      try {
        await _firestore.collection('updates').add({
          'childId': child.id,
          'childName': child.name,
          'type': 'كاميرا',
          'note': type == 'image'
              ? 'صورة من المعلمة للطفل 📸'
              : 'فيديو قصير من المعلمة للطفل 🎥',
          'time': FieldValue.serverTimestamp(),
          'byRole': 'teacher',
          'mediaPath': path,
          'mediaType': type,
          'mediaUrl': null,
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال Check-in من المعلمة ✅'),
          ),
        );

        setState(() {});
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ الـ Check-in: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الرئيسية - المعلمة',
      child: FutureBuilder<List<ChildModel>>(
        future: fetchKgChildren(),
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

          final kgChildren = snapshot.data ?? [];

          return ListView(
            children: [
              Text(
                'أهلاً 👩‍🏫',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'اختاري طفلًا لإضافة نشاط أو إرسال Check-in بالكاميرا',
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
                            backgroundColor:
                                AppColors.primary.withOpacity(0.12),
                            child: const Icon(
                              Icons.how_to_reg,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'تسجيل حضور أطفال الروضة',
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

              if (kgChildren.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'لا يوجد أطفال في قسم الروضة حاليًا.',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              else
                ...kgChildren.map(
                  (c) => _ChildActionCard(
                    childModel: c,
                    onAddUpdate: () => openAddUpdate(c),
                    onCamera: () => openCameraCheckin(c),
                  ),
                ),
            ],
          );
        },
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