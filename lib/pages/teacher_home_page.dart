import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'attendance_page.dart';
import 'add_update_page.dart';
import 'assignments_page.dart';
import 'bulk_attendance_page.dart';
import 'bulk_grade_entry_page.dart';
import 'camera_checkin_page.dart';
import 'detailed_attendance_page.dart';
import 'grades_page.dart';
import 'rewards_page.dart';
import 'teacher_chats_page.dart';
import 'teacher_groups_page.dart';
import 'teacher_reports_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GalleryService _galleryService = GalleryService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, String>> fetchCurrentUserInfo() async {
  final currentUser = _auth.currentUser;

  if (currentUser == null) {
    return {
      'uid': '',
      'name': 'مستخدم غير معروف',
      'role': '',
    };
  }

  final userDoc =
      await _firestore.collection('users').doc(currentUser.uid).get();

  final data = userDoc.data() ?? {};

  return {
    'uid': currentUser.uid,
    'name': (data['displayName'] ?? data['username'] ?? 'مستخدم').toString(),
    'role': (data['role'] ?? '').toString(),
  };
}
  Future<List<String>> fetchAssignedGroups() async {
  final currentUser = _auth.currentUser;
  if (currentUser == null) return [];

  final userDoc =
      await _firestore.collection('users').doc(currentUser.uid).get();

  if (!userDoc.exists) return [];

  final data = userDoc.data() ?? {};
  final rawGroups = data['assignedGroups'];

  if (rawGroups is List) {
    return rawGroups
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  return [];
}

  void openTeacherGroupsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TeacherGroupsPage(),
      ),
    );
  }

  void openGradesPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const GradesPage(),
      ),
    );
  }

  void openAssignmentsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AssignmentsPage(),
      ),
    );
  }

  void openRewardsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RewardsPage(),
      ),
    );
  }

  void openDetailedAttendancePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DetailedAttendancePage(),
      ),
    );
  }

  void openBulkAttendancePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BulkAttendancePage(),
      ),
    );
  }

  void openBulkGradeEntryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BulkGradeEntryPage(),
      ),
    );
  }

  void openTeacherReportsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TeacherReportsPage(),
      ),
    );
  }

  Future<List<ChildModel>> fetchKgChildren() async {
  final assignedGroups = await fetchAssignedGroups();

  if (assignedGroups.isEmpty) {
    return [];
  }

  final snapshot = await _firestore
      .collection('children')
      .where('section', isEqualTo: 'Kindergarten')
      .where('isActive', isEqualTo: true)
      .get();

  final children = snapshot.docs.map((doc) {
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
  }).where((child) {
    return assignedGroups.contains(child.group.trim());
  }).toList();

  children.sort((a, b) => a.name.compareTo(b.name));
  return children;
}

  Future<void> refreshPage() async {
    setState(() {});
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
        builder: (context) => const AttendancePage(
          sectionFilter: 'Kindergarten',
        ),
      ),
    );

    if (res == true) {
      setState(() {});
    }
  }

  Future<void> openTeacherChats(List<ChildModel> children) async {
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد مراسلات متاحة لأنه لا يوجد أطفال نشطون في الروضة'),
        ),
      );
      return;
    }

    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherChatsPage(children: children),
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
        final mediaUrl = await _galleryService.uploadChildMedia(
          childId: child.id,
          localPath: path,
          mediaType: type,
        );
        final userInfo = await fetchCurrentUserInfo();
        await _firestore.collection('updates').add({
          'childId': child.id,
          'childName': child.name,
          'parentUsername': child.parentUsername,
          'section': child.section,
          'group': child.group,
          'type': 'كاميرا',
          'note': type == 'image' ? 'صورة للطفل' : 'فيديو قصير للطفل',
          'createdAt': Timestamp.now(),
          'time': FieldValue.serverTimestamp(),
          'byRole': userInfo['role'],
          'createdByUid': userInfo['uid'],
          'createdByName': userInfo['name'],
          'createdByRole': userInfo['role'],
          'mediaPath': path,
          'mediaType': type,
          'mediaUrl': mediaUrl,
          'hasMedia': true,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال التحديث بالكاميرا بنجاح'),
          ),
        );
        setState(() {});
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ التحديث بالكاميرا: $e'),
          ),
        );
      }
    }
  }

  List<String> extractGroups(List<ChildModel> children) {
    final groups = children
        .map((child) => child.group.trim())
        .where((group) => group.isNotEmpty)
        .toSet()
        .toList();

    groups.sort();
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChildModel>>(
      future: fetchKgChildren(),
      builder: (context, snapshot) {
        final children = snapshot.data ?? [];
        final groups = extractGroups(children);

        return AppPageScaffold(
          title: 'لوحة المعلمة',
          actions: [
            IconButton(
              icon: const Icon(Icons.send_outlined),
              tooltip: 'المراسلات',
              onPressed: snapshot.connectionState == ConnectionState.waiting
                  ? null
                  : () => openTeacherChats(children),
            ),
          ],
          child: Builder(
            builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'حدث خطأ أثناء تحميل البيانات',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: refreshPage,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 18),
                    _buildStatsSection(children.length, groups.length),
                    const SizedBox(height: 18),
                    _buildQuickActions(children),
                    const SizedBox(height: 18),
                    _buildAcademicSection(),
                    const SizedBox(height: 18),
                    _buildMonitoringSection(),
                    const SizedBox(height: 18),
                    _buildGroupsSection(groups),
                    const SizedBox(height: 18),
                    _buildAttendanceCard(),
                    const SizedBox(height: 22),
                    Text(
                      'أطفال الروضة',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                    ),
                    const SizedBox(height: 10),
                    if (children.isEmpty)
                      _buildEmptyState()
                    else
                      ...children.map(
                        (child) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ChildActionCard(
                            childModel: child,
                            onAddUpdate: () => openAddUpdate(child),
                            onCamera: () => openCameraCheckin(child),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.14),
            AppColors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً بكِ',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'لوحة المعلمة لمتابعة الأطفال، المجموعات، الحضور، التقييمات، الواجبات، والتعزيز.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLight,
                        height: 1.6,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(int totalChildren, int totalGroups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ملخص سريع',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
              title: 'القسم',
              value: 'الروضة',
              icon: Icons.auto_stories_rounded,
            ),
            _StatCard(
              title: 'عدد الأطفال',
              value: '$totalChildren',
              icon: Icons.groups_rounded,
            ),
            _StatCard(
              title: 'عدد المجموعات',
              value: '$totalGroups',
              icon: Icons.view_module_rounded,
            ),
            const _StatCard(
              title: 'نوع العمل',
              value: 'متابعة يومية',
              icon: Icons.task_alt_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(List<ChildModel> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    title: 'الحضور',
                    subtitle: 'تسجيل حضور اليوم',
                    icon: Icons.how_to_reg_rounded,
                    onTap: openAttendance,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    title: 'المراسلات',
                    subtitle: 'فتح محادثات المعلمة',
                    icon: Icons.send_outlined,
                    onTap: () => openTeacherChats(children),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _QuickActionButton(
              title: 'المجموعات',
              subtitle: 'عرض مجموعات المعلمة والطلاب',
              icon: Icons.groups_2_rounded,
              onTap: openTeacherGroupsPage,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAcademicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الأدوات الأكاديمية',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    title: 'التقييمات',
                    subtitle: 'عرض وإضافة الدرجات',
                    icon: Icons.grade_outlined,
                    onTap: openGradesPage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    title: 'الواجبات',
                    subtitle: 'إدارة واجبات الطلاب',
                    icon: Icons.assignment_outlined,
                    onTap: openAssignmentsPage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    title: 'التعزيز',
                    subtitle: 'نجوم وشارات وتشجيع',
                    icon: Icons.emoji_events_outlined,
                    onTap: openRewardsPage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    title: 'درجات جماعية',
                    subtitle: 'إدخال درجات دفعة واحدة',
                    icon: Icons.playlist_add_check_circle_outlined,
                    onTap: openBulkGradeEntryPage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonitoringSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المتابعة والتقارير',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    title: 'الحضور التفصيلي',
                    subtitle: 'عرض سجل الحضور الكامل',
                    icon: Icons.fact_check_outlined,
                    onTap: openDetailedAttendancePage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    title: 'حضور جماعي',
                    subtitle: 'إدخال الحضور دفعة واحدة',
                    icon: Icons.checklist_rtl_outlined,
                    onTap: openBulkAttendancePage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _QuickActionButton(
              title: 'التقارير',
              subtitle: 'ملخصات وإحصائيات المعلمة',
              icon: Icons.analytics_outlined,
              onTap: openTeacherReportsPage,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupsSection(List<String> groups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'المجموعات الحالية',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
            TextButton(
              onPressed: openTeacherGroupsPage,
              child: const Text('عرض الكل'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.border.withOpacity(0.8),
              ),
            ),
            child: const Text(
              'لا توجد مجموعات محددة حالياً للأطفال.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: groups
                .map(
                  (group) => InkWell(
                    onTap: openTeacherGroupsPage,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.border.withOpacity(0.85),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.groups_2_rounded,
                            size: 18,
                            color: AppColors.primary.withOpacity(0.9),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            group,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildAttendanceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.14),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.14),
                child: const Icon(
                  Icons.how_to_reg_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تسجيل حضور أطفال الروضة',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'افتحي صفحة الحضور لتحديد حالة الحضور اليومية للأطفال.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textLight,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: openAttendance,
              icon: const Icon(Icons.checklist_rounded),
              label: const Text('فتح صفحة الحضور'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.sentiment_dissatisfied_outlined,
            size: 38,
            color: AppColors.textLight.withOpacity(0.8),
          ),
          const SizedBox(height: 10),
           const Text(
  'لا توجد مجموعات أو أطفال مخصصون لهذه المعلمة حالياً',
  textAlign: TextAlign.center,
  style: TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  ),
),
const SizedBox(height: 6),
const Text(
  'عند ربط المعلمة بمجموعاتها سيظهر الأطفال هنا مباشرة.',
  textAlign: TextAlign.center,
  style: TextStyle(
    fontSize: 13.5,
    color: AppColors.textLight,
    height: 1.5,
  ),
),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.border.withOpacity(0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textLight,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.border.withOpacity(0.75),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.75),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.child_care_rounded,
                    color: Colors.white,
                    size: 28,
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
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _smallTag(
                            icon: Icons.groups_rounded,
                            text: childModel.group.isEmpty
                                ? 'بدون مجموعة'
                                : childModel.group,
                          ),
                          _smallTag(
                            icon: Icons.person_outline_rounded,
                            text: childModel.parentName.isEmpty
                                ? 'ولي أمر غير محدد'
                                : childModel.parentName,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('الكاميرا'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: BorderSide(
                        color: AppColors.primary.withOpacity(0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAddUpdate,
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('إضافة تحديث'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallTag({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: AppColors.textLight,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}