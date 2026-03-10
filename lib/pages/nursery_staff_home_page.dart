import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/child_model.dart';
import 'add_update_page.dart';
import 'attendance_page.dart';
import 'camera_checkin_page.dart';
import '../models/update_model.dart';
import '../widgets/app_bar_widget.dart';

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
        builder: (context) => AddUpdatePage(child: child, byRole: 'nursery'),
      ),
    );
    if (res == true) setState(() {});
  }

  Future<void> openAttendance() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AttendancePage(sectionFilter: 'Nursery'),
      ),
    );
    if (res == true) setState(() {});
  }

  Future<void> openCameraCheckin(ChildModel child) async {
  final res = await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CameraCheckinPage()),
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
        note: type == 'image' ? 'صورة للطفل 📸' : 'فيديو قصير للطفل 🎥',
        time: DateTime.now(),
        byRole: 'nursery',
        mediaPath: path,
        mediaType: type,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال Check-in ✅')),
    );

    setState(() {});
  }
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
              const Text('أهلاً 👩‍🍼',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('اختاري طفل لتسجيل تحديث جديد',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: openAttendance,
                icon: const Icon(Icons.how_to_reg),
                label: const Text('تسجيل الحضور'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E97FD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              ...nurseryChildren.map((c) => _ChildTile(
              child: c,
              onAddUpdate: () => openAddUpdate(c),
              onCamera: () => openCameraCheckin(c),
              )),

              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('إرسال إشعار للأهل لاحقًا')),
                  );
                },
                icon: const Icon(Icons.notifications),
                label: const Text('إرسال إشعار للأهل'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildTile extends StatelessWidget {
  final ChildModel child;
  final VoidCallback onAddUpdate;
  final VoidCallback onCamera;

  const _ChildTile({
    required this.child,
    required this.onAddUpdate,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
                Text(child.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(child.group, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'كاميرا Check-in',
            onPressed: onCamera,
            icon: const Icon(Icons.photo_camera),
          ),
          IconButton(
            tooltip: 'إضافة تحديث',
            onPressed: onAddUpdate,
            icon: const Icon(Icons.note_add),
          ),
        ],
      ),
    );
  }
}