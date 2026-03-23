import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'admin_add_user_page.dart';
import 'admin_teacher_assignments_page.dart';
import 'admin_updates_feed_page.dart';
import 'manage_children_page.dart';
import 'manage_classes_page.dart';
import 'manage_users_page.dart';
import 'welcome_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> logout(BuildContext context) async {
    final shouldLogout = await showDialog(
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

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  Future<_AdminDashboardData> _loadDashboardData() async {
    final usersSnapshot = await _firestore.collection('users').get();
    final childrenSnapshot = await _firestore.collection('children').get();
    final classesSnapshot = await _firestore.collection('classes').get();
    final updatesSnapshot =
        await _firestore.collection('updates').limit(50).get();

    final users = usersSnapshot.docs.map((e) => e.data()).toList();
    final children = childrenSnapshot.docs.map((e) => e.data()).toList();
    final classes = classesSnapshot.docs.map((e) => e.data()).toList();
    final updates = updatesSnapshot.docs.map((e) => e.data()).toList();

    int activeChildren = 0;
    int archivedChildren = 0;
    int nurseryChildren = 0;
    int kindergartenChildren = 0;
    int kindergartenWithoutGroup = 0;

    for (final child in children) {
      final isActive = (child['isActive'] ?? true) == true;
      final section = (child['section'] ?? '').toString().trim();
      final group = (child['group'] ?? '').toString().trim();

      if (isActive) {
        activeChildren++;
      } else {
        archivedChildren++;
      }

      if (section == 'Nursery') nurseryChildren++;
      if (section == 'Kindergarten') kindergartenChildren++;

      if (isActive && section == 'Kindergarten' && group.isEmpty) {
        kindergartenWithoutGroup++;
      }
    }

    int parentsCount = 0;
    int staffCount = 0;
    int teachersCount = 0;
    int adminsCount = 0;

    for (final user in users) {
      final role = (user['role'] ?? '').toString().trim().toLowerCase();

      if (role == 'parent') parentsCount++;
      if (role == 'nursery staff' || role == 'nursery_staff') staffCount++;
      if (role == 'teacher') teachersCount++;
      if (role == 'admin') adminsCount++;
    }

    final alerts = <_AdminAlertItem>[];

    if (classes.isEmpty) {
      alerts.add(
        const _AdminAlertItem(
          title: 'لا توجد صفوف أو مجموعات بعد',
          subtitle: 'يفضّل إضافة الصفوف والمجموعات لبدء تنظيم الأطفال والمعلمين.',
          icon: Icons.class_,
          color: Colors.orange,
        ),
      );
    }

    if (archivedChildren > 0) {
      alerts.add(
        _AdminAlertItem(
          title: 'يوجد $archivedChildren طفل/أطفال مؤرشفون',
          subtitle: 'راجعي الأطفال المؤرشفين وتحققي إذا كانت حالتهم ما زالت صحيحة.',
          icon: Icons.archive_outlined,
          color: Colors.blueGrey,
        ),
      );
    }

    if (kindergartenWithoutGroup > 0) {
      alerts.add(
        _AdminAlertItem(
          title: 'يوجد $kindergartenWithoutGroup طفل/أطفال روضة بدون مجموعة',
          subtitle:
              'يفضّل تعيين مجموعة لكل طفل في الروضة لتسهيل المتابعة والتقارير.',
          icon: Icons.warning_amber_rounded,
          color: Colors.deepOrange,
        ),
      );
    }

    if (users.isEmpty) {
      alerts.add(
        const _AdminAlertItem(
          title: 'لا يوجد مستخدمون في النظام',
          subtitle:
              'ابدئي بإضافة حسابات الأدمن، المعلمات، الموظفات، وأولياء الأمور.',
          icon: Icons.person_add_alt_1_rounded,
          color: Colors.redAccent,
        ),
      );
    }

    final recentActivities = updates
        .map((item) {
          final time = _extractDate(item);
          return _AdminActivityItem(
            title: _buildActivityTitle(item),
            subtitle: _buildActivitySubtitle(item),
            time: time,
            icon: _activityIcon((item['type'] ?? '').toString()),
          );
        })
        .toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    return _AdminDashboardData(
      totalUsers: users.length,
      totalChildren: children.length,
      activeChildren: activeChildren,
      archivedChildren: archivedChildren,
      nurseryChildren: nurseryChildren,
      kindergartenChildren: kindergartenChildren,
      totalClasses: classes.length,
      parentsCount: parentsCount,
      staffCount: staffCount,
      teachersCount: teachersCount,
      adminsCount: adminsCount,
      alerts: alerts,
      recentActivities: recentActivities.take(6).toList(),
    );
  }

  static DateTime _extractDate(Map<String, dynamic> data) {
    final dynamic value = data['time'] ?? data['createdAt'];

    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _buildActivityTitle(Map<String, dynamic> item) {
    final type = (item['type'] ?? 'update').toString();
    final childName = (item['childName'] ?? item['name'] ?? 'طفل').toString();

    switch (type) {
      case 'meal':
        return 'تمت إضافة تحديث وجبة للطفل $childName';
      case 'sleep':
        return 'تمت إضافة تحديث نوم للطفل $childName';
      case 'health':
        return 'تمت إضافة تحديث صحي للطفل $childName';
      case 'activity':
        return 'تمت إضافة نشاط جديد للطفل $childName';
      case 'attendance':
        return 'تم تسجيل حضور للطفل $childName';
      case 'homework':
        return 'تمت إضافة واجب للطفل $childName';
      case 'grade':
        return 'تمت إضافة تقييم/علامة للطفل $childName';
      default:
        return 'تمت إضافة تحديث جديد للطفل $childName';
    }
  }

  static String _buildActivitySubtitle(Map<String, dynamic> item) {
    final createdByName =
        (item['createdByName'] ?? 'مستخدم غير معروف').toString();
    final section = (item['section'] ?? '').toString();
    final group = (item['group'] ?? '').toString();

    final details = <String>[
      'بواسطة: $createdByName',
      if (section.isNotEmpty) 'القسم: $section',
      if (group.isNotEmpty) 'المجموعة: $group',
    ];

    return details.join(' • ');
  }

  static IconData _activityIcon(String type) {
    switch (type) {
      case 'meal':
        return Icons.restaurant_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      case 'health':
        return Icons.medical_services_rounded;
      case 'activity':
        return Icons.extension_rounded;
      case 'attendance':
        return Icons.fact_check_rounded;
      case 'homework':
        return Icons.assignment_rounded;
      case 'grade':
        return Icons.grade_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _formatDateTime(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'بدون وقت';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'م' : 'ص';

    return '$year/$month/$day - $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'لوحة تحكم الإدارة',
      actions: [
        IconButton(
          tooltip: 'تسجيل الخروج',
          onPressed: () => logout(context),
          icon: const Icon(Icons.logout),
        ),
      ],
      child: FutureBuilder<_AdminDashboardData>(
        future: _loadDashboardData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'حدث خطأ أثناء تحميل لوحة التحكم:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('لا توجد بيانات متاحة حالياً'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              children: [
                Text(
                  'أهلاً بكِ في لوحة الإدارة 👋',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'من هنا يمكنك متابعة حالة النظام بسرعة، وإدارة المستخدمين والأطفال والصفوف، ومراجعة التنبيهات والأنشطة الحديثة.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLight,
                      ),
                ),
                const SizedBox(height: 20),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _DashboardStatCard(
                      title: 'إجمالي المستخدمين',
                      value: '${data.totalUsers}',
                      subtitle:
                          'أدمن ${data.adminsCount} • أولياء ${data.parentsCount}',
                      icon: Icons.groups_rounded,
                    ),
                    _DashboardStatCard(
                      title: 'الأطفال النشطون',
                      value: '${data.activeChildren}',
                      subtitle:
                          'الحضانة ${data.nurseryChildren} • الروضة ${data.kindergartenChildren}',
                      icon: Icons.child_care_rounded,
                    ),
                    _DashboardStatCard(
                      title: 'الأطفال المؤرشفون',
                      value: '${data.archivedChildren}',
                      subtitle: 'مراجعة الحالات غير النشطة',
                      icon: Icons.archive_rounded,
                    ),
                    _DashboardStatCard(
                      title: 'الصفوف / المجموعات',
                      value: '${data.totalClasses}',
                      subtitle:
                          'معلمات ${data.teachersCount} • موظفات ${data.staffCount}',
                      icon: Icons.class_rounded,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  'الإجراءات الأساسية',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),

                _AdminActionCard(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'إضافة مستخدم جديد',
                  subtitle: 'إنشاء حسابات المستخدمين من خلال الإدارة فقط',
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminAddUserPage(),
                      ),
                    );

                    if (result == true) {
                      setState(() {});
                    }
                  },
                ),
                _AdminActionCard(
                  icon: Icons.group,
                  title: 'إدارة المستخدمين',
                  subtitle: 'إضافة وتعديل وتنظيم حسابات المستخدمين',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageUsersPage(),
                      ),
                    );

                    setState(() {});
                  },
                ),
                _AdminActionCard(
                  icon: Icons.child_care,
                  title: 'إدارة الأطفال',
                  subtitle: 'متابعة بيانات الأطفال، الأرشفة، والحالة الحالية',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageChildrenPage(),
                      ),
                    );

                    setState(() {});
                  },
                ),
                _AdminActionCard(
                  icon: Icons.class_,
                  title: 'إدارة الصفوف والأقسام',
                  subtitle: 'تنظيم الصفوف والمجموعات وربط الأطفال بها',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageClassesPage(),
                      ),
                    );

                    setState(() {});
                  },
                ),
                _AdminActionCard(
                  icon: Icons.bar_chart,
                  title: 'التقارير العامة',
                  subtitle: 'تجهيز صفحة تقارير أوسع لاحقاً',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'قيد العمل',
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                Text(
                  'أدوات الإدارة المتقدمة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),

                _AdminActionCard(
                  icon: Icons.assignment_ind_rounded,
                  title: 'تعيين المعلمات',
                  subtitle: 'ربط المعلمات بالمجموعات والصفوف والمواد',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminTeacherAssignmentsPage(),
                      ),
                    );

                    setState(() {});
                  },
                ),
                _AdminActionCard(
                  icon: Icons.dynamic_feed_rounded,
                  title: 'سجل التحديثات الإداري',
                  subtitle: 'متابعة آخر تحديثات الموظفات والمعلمات داخل النظام',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminUpdatesFeedPage(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                Text(
                  'التنبيهات',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),

                if (data.alerts.isEmpty)
                  _EmptyDashboardBox(
                    icon: Icons.verified_rounded,
                    title: 'لا توجد تنبيهات حالياً',
                    subtitle: 'الوضع يبدو جيداً داخل النظام.',
                  )
                else
                  ...data.alerts.map(
                    (alert) => _AlertCard(item: alert),
                  ),

                const SizedBox(height: 24),

                Text(
                  'آخر الأنشطة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),

                if (data.recentActivities.isEmpty)
                  const _EmptyDashboardBox(
                    icon: Icons.history_toggle_off_rounded,
                    title: 'لا توجد أنشطة حديثة',
                    subtitle: 'عند إضافة تحديثات للأطفال ستظهر هنا.',
                  )
                else
                  ...data.recentActivities.map(
                    (activity) => _ActivityCard(
                      item: activity,
                      formattedTime: _formatDateTime(activity.time),
                    ),
                  ),

                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _DashboardStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width > 700 ? (width - 48) / 2 : double.infinity;

    return SizedBox(
      width: cardWidth,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final _AdminAlertItem item;

  const _AlertCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.color.withOpacity(0.12),
          child: Icon(item.icon, color: item.color),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(item.subtitle),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final _AdminActivityItem item;
  final String formattedTime;

  const _ActivityCard({
    required this.item,
    required this.formattedTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Icon(item.icon, color: AppColors.primary),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${item.subtitle}\n$formattedTime'),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _EmptyDashboardBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyDashboardBox({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminDashboardData {
  final int totalUsers;
  final int totalChildren;
  final int activeChildren;
  final int archivedChildren;
  final int nurseryChildren;
  final int kindergartenChildren;
  final int totalClasses;
  final int parentsCount;
  final int staffCount;
  final int teachersCount;
  final int adminsCount;
  final List<_AdminAlertItem> alerts;
  final List<_AdminActivityItem> recentActivities;

  const _AdminDashboardData({
    required this.totalUsers,
    required this.totalChildren,
    required this.activeChildren,
    required this.archivedChildren,
    required this.nurseryChildren,
    required this.kindergartenChildren,
    required this.totalClasses,
    required this.parentsCount,
    required this.staffCount,
    required this.teachersCount,
    required this.adminsCount,
    required this.alerts,
    required this.recentActivities,
  });
}

class _AdminAlertItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _AdminAlertItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _AdminActivityItem {
  final String title;
  final String subtitle;
  final DateTime time;
  final IconData icon;

  const _AdminActivityItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
  });
}