import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../services/account_settings_service.dart';
import '../services/auth_service.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'account_settings_page.dart';
import 'add_update_page.dart';
import 'assignments_page.dart';
import 'attendance_page.dart';
import 'bulk_attendance_page.dart';
import 'bulk_grade_entry_page.dart';
import 'camera_checkin_page.dart';
import 'detailed_attendance_page.dart';
import 'grades_page.dart';
import 'rewards_page.dart';
import 'teacher_chats_page.dart';
import 'teacher_groups_page.dart';
import 'teacher_reports_page.dart';
import 'welcome_page.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GalleryService _galleryService = GalleryService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AccountSettingsService _accountSettingsService =
      AccountSettingsService();

  int selectedIndex = 0;
  bool isArabic = true;
  bool isDarkMode = false;

  String searchQuery = '';
  String selectedGroupFilter = 'all';

  String get _pageTitle {
    switch (selectedIndex) {
      case 0:
        return 'الرئيسية - المعلمة';
      case 1:
        return 'المتابعة';
      case 2:
        return 'الرسائل';
      case 3:
        return 'الإعدادات';
      default:
        return 'الرئيسية - المعلمة';
    }
  }

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

    final children = snapshot.docs
        .map((doc) {
          final data = doc.data();
          return ChildModel.fromMap(data, docId: doc.id);
        })
        .where((child) => assignedGroups.contains(child.group.trim()))
        .toList();

    children.sort((a, b) => a.name.compareTo(b.name));
    return children;
  }

  Future<List<Map<String, dynamic>>> fetchTeacherNotifications() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final updatesSnapshot = await _firestore
        .collection('updates')
        .where('createdByUid', isEqualTo: currentUser.uid)
        .get();

    final directNotificationsSnapshot = await _firestore
        .collection('notifications')
        .where('targetUid', isEqualTo: currentUser.uid)
        .get();

    final fallbackNotificationsSnapshot = await _firestore
        .collection('notifications')
        .where('uid', isEqualTo: currentUser.uid)
        .get();

    final accountHistorySnapshot = await _firestore
        .collection('account_activity_logs')
        .where('targetUid', isEqualTo: currentUser.uid)
        .get();

    final List<Map<String, dynamic>> items = [];

    for (final doc in updatesSnapshot.docs) {
      final data = doc.data();
      items.add({
        'title': (data['type'] ?? 'تحديث').toString(),
        'childName': (data['childName'] ?? '').toString(),
        'body': (data['note'] ?? '').toString(),
        'createdAt': data['time'] ?? data['createdAt'],
        'hasMedia': data['hasMedia'] == true,
        'sourceType': 'update',
        'status': 'info',
      });
    }

    final seenNotificationIds = <String>{};

    for (final doc in [
      ...directNotificationsSnapshot.docs,
      ...fallbackNotificationsSnapshot.docs,
    ]) {
      if (seenNotificationIds.contains(doc.id)) continue;
      seenNotificationIds.add(doc.id);

      final data = doc.data();
      items.add({
        'title': (data['title'] ?? 'إشعار').toString(),
        'childName': (data['childName'] ?? '').toString(),
        'body': (data['body'] ?? data['message'] ?? '').toString(),
        'createdAt': data['createdAt'],
        'hasMedia': false,
        'sourceType': 'notification',
        'status': (data['status'] ?? 'info').toString(),
      });
    }

    for (final doc in accountHistorySnapshot.docs) {
      final data = doc.data();
      items.add({
        'title': (data['title'] ?? 'نشاط حساب').toString(),
        'childName': '',
        'body': (data['message'] ?? '').toString(),
        'createdAt': data['createdAt'],
        'hasMedia': false,
        'sourceType': 'account_activity',
        'status': (data['status'] ?? 'info').toString(),
      });
    }

    items.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return items.take(30).toList();
  }

  void openTeacherGroupsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TeacherGroupsPage()),
    );
  }

  void openGradesPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GradesPage()),
    );
  }

  void openAssignmentsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AssignmentsPage()),
    );
  }

  void openRewardsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RewardsPage()),
    );
  }

  void openDetailedAttendancePage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DetailedAttendancePage()),
    );
  }

  void openBulkAttendancePage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BulkAttendancePage()),
    );
  }

  void openBulkGradeEntryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BulkGradeEntryPage()),
    );
  }

  void openTeacherReportsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TeacherReportsPage()),
    );
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
          content: Text(
            'لا توجد مراسلات متاحة لأنه لا يوجد أطفال نشطون في الروضة',
          ),
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

  Future<void> _openNotificationsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TeacherNotificationsPage(
          fetchNotifications: fetchTeacherNotifications,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنتِ متأكدة أنكِ تريدين تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );

    if (shouldLogout != true) return;

    await AuthService().logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
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

  List<ChildModel> applyChildrenFilters(List<ChildModel> children) {
    return children.where((child) {
      final matchesSearch = child.name.toLowerCase().contains(
            searchQuery.toLowerCase(),
          );

      final matchesGroup = selectedGroupFilter == 'all'
          ? true
          : child.group.trim() == selectedGroupFilter;

      return matchesSearch && matchesGroup;
    }).toList();
  }

  Widget _buildBody(List<ChildModel> children) {
    final groups = extractGroups(children);
    final filteredChildren = applyChildrenFilters(children);

    switch (selectedIndex) {
      case 0:
        return _buildDashboardTab(children, groups);
      case 1:
        return _buildFollowUpTab(filteredChildren, groups);
      case 2:
        return _buildMessagesTab(children);
      case 3:
        return _buildSettingsTab(children);
      default:
        return _buildDashboardTab(children, groups);
    }
  }

  Widget _buildDashboardTab(List<ChildModel> children, List<String> groups) {
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFollowUpTab(
    List<ChildModel> filteredChildren,
    List<String> groups,
  ) {
    return RefreshIndicator(
      onRefresh: refreshPage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSearchAndFilterBar(groups),
          const SizedBox(height: 18),
          Text(
            'أطفال الروضة',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 10),
          if (filteredChildren.isEmpty)
            _buildEmptyState()
          else
            ...filteredChildren.map(
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
  }

  Widget _buildMessagesTab(List<ChildModel> children) {
    return TeacherChatsPage(children: children);
  }

  Widget _buildSettingsTab(List<ChildModel> children) {
    return ListView(
      children: [
        Card(
          child: FutureBuilder<AccountSettingsData>(
            future: _accountSettingsService.getCurrentUserData(),
            builder: (context, snapshot) {
              final data = snapshot.data;

              final displayName = data?.name.trim().isNotEmpty == true
                  ? data!.name
                  : 'المعلمة';

              final subtitle = data == null
                  ? 'متابعة الروضة والمجموعات'
                  : '${data.roleLabel} • ${data.username.isNotEmpty ? data.username : "بدون اسم مستخدم"}';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.10),
                  child: Text(
                    displayName.trim().isNotEmpty
                        ? displayName.trim()[0]
                        : 'م',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                title: Text(
                  displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(subtitle),
                trailing: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: const Icon(
                    Icons.edit,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountSettingsPage(),
                    ),
                  );
                  if (!mounted) return;
                  setState(() {});
                },
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'الإعدادات العامة',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textLight,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.12),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.orange,
                  ),
                ),
                title: const Text('تعديل الملف الشخصي'),
                subtitle: const Text('تعديل الاسم، كلمة المرور، وإدارة الحساب'),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountSettingsPage(),
                    ),
                  );
                  if (!mounted) return;
                  setState(() {});
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.12),
                  child:
                      const Icon(Icons.language_rounded, color: Colors.blue),
                ),
                title: const Text('لغة التطبيق'),
                subtitle: Text(isArabic ? 'العربية' : 'English'),
                value: isArabic,
                onChanged: (value) {
                  setState(() {
                    isArabic = value;
                  });
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: CircleAvatar(
                  backgroundColor: Colors.purple.withOpacity(0.12),
                  child: const Icon(
                    Icons.palette_outlined,
                    color: Colors.purple,
                  ),
                ),
                title: const Text('الوضع الليلي'),
                value: isDarkMode,
                onChanged: (value) {
                  setState(() {
                    isDarkMode = value;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'الخدمات',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textLight,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.12),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.green,
                  ),
                ),
                title: const Text('الإشعارات'),
                subtitle: const Text('عرض إشعارات المعلمة والنظام'),
                onTap: _openNotificationsPage,
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: const Icon(
                    Icons.send_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text('الرسائل'),
                subtitle: const Text('فتح محادثات المعلمة'),
                onTap: () => openTeacherChats(children),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'المساعدة والدعم',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textLight,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.withOpacity(0.12),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.red,
                  ),
                ),
                title: const Text('مركز الدعم'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('قيد التطوير')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.redAccent.withOpacity(0.12),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                  ),
                ),
                title: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: _logout,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'إصدار النظام V1.0.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChildModel>>(
      future: fetchKgChildren(),
      builder: (context, snapshot) {
        final children = snapshot.data ?? [];

        return Scaffold(
          body: AppPageScaffold(
            title: _pageTitle,
            actions: selectedIndex == 0
                ? [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded),
                      tooltip: 'الإشعارات',
                      onPressed: _openNotificationsPage,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'تحديث الصفحة',
                      onPressed: refreshPage,
                    ),
                  ]
                : selectedIndex == 2
                    ? [
                        IconButton(
                          icon: const Icon(Icons.notifications_none_rounded),
                          tooltip: 'الإشعارات',
                          onPressed: _openNotificationsPage,
                        ),
                      ]
                    : selectedIndex == 3
                        ? [
                            IconButton(
                              icon:
                                  const Icon(Icons.notifications_none_rounded),
                              tooltip: 'الإشعارات',
                              onPressed: _openNotificationsPage,
                            ),
                          ]
                        : [
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded),
                              tooltip: 'تحديث الصفحة',
                              onPressed: refreshPage,
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

                return _buildBody(children);
              },
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check_rounded),
                label: 'المتابعة',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'الرسائل',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'الإعدادات',
              ),
            ],
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
    final actions = [
      _TeacherQuickActionItem(
        title: 'الحضور',
        subtitle: 'تسجيل حضور اليوم',
        icon: Icons.how_to_reg_rounded,
        onTap: openAttendance,
      ),
      _TeacherQuickActionItem(
        title: 'المراسلات',
        subtitle: 'فتح محادثات المعلمة',
        icon: Icons.send_outlined,
        onTap: () => openTeacherChats(children),
      ),
      _TeacherQuickActionItem(
        title: 'المجموعات',
        subtitle: 'عرض مجموعات المعلمة والطلاب',
        icon: Icons.groups_2_rounded,
        onTap: openTeacherGroupsPage,
      ),
      _TeacherQuickActionItem(
        title: 'التقييمات',
        subtitle: 'عرض وإضافة الدرجات',
        icon: Icons.grade_outlined,
        onTap: openGradesPage,
      ),
      _TeacherQuickActionItem(
        title: 'الواجبات',
        subtitle: 'إدارة واجبات الطلاب',
        icon: Icons.assignment_outlined,
        onTap: openAssignmentsPage,
      ),
      _TeacherQuickActionItem(
        title: 'التعزيز',
        subtitle: 'نجوم وشارات وتشجيع',
        icon: Icons.emoji_events_outlined,
        onTap: openRewardsPage,
      ),
    ];

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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.18,
          ),
          itemBuilder: (context, index) {
            final item = actions[index];
            return _TeacherQuickActionCard(
              title: item.title,
              subtitle: item.subtitle,
              icon: item.icon,
              onTap: item.onTap,
            );
          },
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

  Widget _buildSearchAndFilterBar(List<String> groups) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'ابحثي باسم الطفل...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChipItem(
                    label: 'الكل',
                    isSelected: selectedGroupFilter == 'all',
                    onTap: () {
                      setState(() {
                        selectedGroupFilter = 'all';
                      });
                    },
                  ),
                  ...groups.map(
                    (group) => _FilterChipItem(
                      label: group,
                      isSelected: selectedGroupFilter == group,
                      onTap: () {
                        setState(() {
                          selectedGroupFilter = group;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _TeacherNotificationsPage extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> Function() fetchNotifications;

  const _TeacherNotificationsPage({
    required this.fetchNotifications,
  });

  String _formatTimestamp(dynamic raw) {
    if (raw is Timestamp) {
      final d = raw.toDate();
      return '${d.year}/${d.month}/${d.day} - ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    return 'غير محدد';
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'success':
      case 'approved':
        return AppColors.success;
      case 'warning':
      case 'pending':
        return AppColors.warning;
      case 'danger':
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  IconData _iconForItem(Map<String, dynamic> item) {
    final sourceType = (item['sourceType'] ?? '').toString();
    final hasMedia = item['hasMedia'] == true;
    final status = (item['status'] ?? '').toString().toLowerCase();

    if (hasMedia) return Icons.photo_camera_outlined;

    if (sourceType == 'account_activity') {
      if (status == 'success' || status == 'approved') {
        return Icons.check_circle_outline_rounded;
      }
      if (status == 'warning' || status == 'pending') {
        return Icons.warning_amber_rounded;
      }
      if (status == 'danger' || status == 'rejected') {
        return Icons.error_outline_rounded;
      }
      return Icons.manage_accounts_outlined;
    }

    if (sourceType == 'notification') {
      return Icons.notifications_active_outlined;
    }

    return Icons.notifications_none_rounded;
  }

  String _sectionTitle(List<Map<String, dynamic>> items) {
    final hasGeneral = items.any(
      (item) => (item['sourceType'] ?? '').toString() != 'update',
    );

    return hasGeneral ? 'آخر الإشعارات والتنبيهات' : 'آخر الإشعارات';
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الإشعارات',
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchNotifications(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];

          return ListView(
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: _InfoPanel(
                    icon: Icons.notifications_active_outlined,
                    title: 'إشعارات المعلمة',
                    message:
                        'تظهر هنا التحديثات التي أضفتها المعلمة بالإضافة إلى إشعارات النظام والنشاطات المرتبطة بالحساب.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _sectionTitle(items),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'لا توجد إشعارات أو تحديثات مضافة بعد.',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  ),
                )
              else
                ...items.map((item) {
                  final color = _statusColor((item['status'] ?? '').toString());

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: color.withOpacity(0.12),
                            child: Icon(
                              _iconForItem(item),
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (item['title'] ?? 'إشعار').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                  ),
                                ),
                                if ((item['childName'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'الطفل: ${item['childName']}',
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                if ((item['body'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    (item['body'] ?? '').toString(),
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  _formatTimestamp(item['createdAt']),
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.4,
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

class _TeacherQuickActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _TeacherQuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
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
    return SizedBox(
      width: 160,
      child: Container(
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
      ),
    );
  }
}

class _TeacherQuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _TeacherQuickActionCard({
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

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}