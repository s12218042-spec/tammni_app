import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'manage_users_page.dart';
import 'manage_children_page.dart';
import 'manage_classes_page.dart';
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
          content: const Text('هل أنت متأكدة أنك تريدين تسجيل الخروج؟'),
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

  Future<Map<String, dynamic>> fetchAdminStats() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final usersSnapshot = await _firestore.collection('users').get();
    final childrenSnapshot = await _firestore.collection('children').get();
    final entryExitSnapshot = await _firestore.collection('entry_exit_logs').get();
    final updatesSnapshot = await _firestore.collection('updates').get();

    int parentsCount = 0;
    int teachersCount = 0;
    int nurseryStaffCount = 0;
    int adminsCount = 0;
    int activeChildrenCount = 0;
    int archivedChildrenCount = 0;

    for (final doc in usersSnapshot.docs) {
      final data = doc.data();
      final role = (data['role'] ?? '').toString().toLowerCase();

      if (role == 'parent') parentsCount++;
      if (role == 'teacher') teachersCount++;
      if (role == 'nursery' || role == 'nursery staff' || role == 'nursery_staff') {
        nurseryStaffCount++;
      }
      if (role == 'admin') adminsCount++;
    }

    final Map<String, String> childSectionById = {};

    for (final doc in childrenSnapshot.docs) {
      final data = doc.data();
      final isActive = data['isActive'] == true;
      final section = (data['section'] ?? '').toString();

      childSectionById[doc.id] = section;

      if (isActive) {
        activeChildrenCount++;
      } else {
        archivedChildrenCount++;
      }
    }

    int entryTodayCount = 0;
    int exitTodayCount = 0;
    int insideNowCount = 0;
    int nurseryUpdatesToday = 0;
    int kindergartenUpdatesToday = 0;

    final Map<String, Map<String, dynamic>> latestLogByChild = {};

    for (final doc in entryExitSnapshot.docs) {
      final data = doc.data();
      final childId = (data['childId'] ?? '').toString();
      if (childId.isEmpty) continue;

      final Timestamp? ts = data['time'] is Timestamp
          ? data['time'] as Timestamp
          : data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : null;

      if (ts == null) continue;

      final eventType = (data['eventType'] ?? '').toString();
      final date = ts.toDate();

      if (!date.isBefore(startOfDay)) {
        if (eventType == 'entry') entryTodayCount++;
        if (eventType == 'exit') exitTodayCount++;
      }

      final old = latestLogByChild[childId];
      if (old == null) {
        latestLogByChild[childId] = {
          'eventType': eventType,
          'time': ts,
        };
      } else {
        final oldTs = old['time'] as Timestamp?;
        if (oldTs == null || ts.compareTo(oldTs) > 0) {
          latestLogByChild[childId] = {
            'eventType': eventType,
            'time': ts,
          };
        }
      }
    }

    for (final entry in latestLogByChild.entries) {
      final latestEventType = (entry.value['eventType'] ?? '').toString();
      if (latestEventType == 'entry') {
        insideNowCount++;
      }
    }

    for (final doc in updatesSnapshot.docs) {
      final data = doc.data();

      final Timestamp? ts = data['time'] is Timestamp
          ? data['time'] as Timestamp
          : data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : null;

      if (ts == null) continue;
      if (ts.toDate().isBefore(startOfDay)) continue;

      final section = (data['section'] ?? '').toString();
      if (section == 'Nursery') nurseryUpdatesToday++;
      if (section == 'Kindergarten') kindergartenUpdatesToday++;
    }

    return {
      'childrenCount': childrenSnapshot.docs.length,
      'activeChildrenCount': activeChildrenCount,
      'archivedChildrenCount': archivedChildrenCount,
      'parentsCount': parentsCount,
      'teachersCount': teachersCount,
      'nurseryStaffCount': nurseryStaffCount,
      'adminsCount': adminsCount,
      'entryTodayCount': entryTodayCount,
      'exitTodayCount': exitTodayCount,
      'insideNowCount': insideNowCount,
      'nurseryUpdatesToday': nurseryUpdatesToday,
      'kindergartenUpdatesToday': kindergartenUpdatesToday,
      'childSectionById': childSectionById,
      'latestLogByChild': latestLogByChild,
    };
  }

  Future<List<Map<String, dynamic>>> fetchRecentAdminActivities() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final entryExitSnapshot = await _firestore.collection('entry_exit_logs').get();
    final updatesSnapshot = await _firestore.collection('updates').get();

    final List<Map<String, dynamic>> activities = [];

    for (final doc in entryExitSnapshot.docs) {
      final data = doc.data();

      final Timestamp? ts = data['time'] is Timestamp
          ? data['time'] as Timestamp
          : data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : null;

      if (ts == null) continue;
      if (ts.toDate().isBefore(startOfDay)) continue;

      final eventType = (data['eventType'] ?? '').toString();
      final childName = (data['childName'] ?? 'طفل').toString();
      final section = (data['section'] ?? '').toString();
      final createdByName = (data['createdByName'] ?? '').toString();

      activities.add({
        'time': ts,
        'title': eventType == 'entry' ? 'دخول' : 'خروج',
        'target': childName,
        'subtitle': createdByName.trim().isNotEmpty
            ? '${section.isNotEmpty ? '$section • ' : ''}بواسطة $createdByName'
            : section,
        'icon': eventType == 'entry'
            ? Icons.login_rounded
            : Icons.logout_rounded,
        'color': eventType == 'entry' ? Colors.green : Colors.red,
      });
    }

    for (final doc in updatesSnapshot.docs) {
      final data = doc.data();

      final Timestamp? ts = data['time'] is Timestamp
          ? data['time'] as Timestamp
          : data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : null;

      if (ts == null) continue;
      if (ts.toDate().isBefore(startOfDay)) continue;

      final childName = (data['childName'] ?? 'طفل').toString();
      final type = (data['type'] ?? 'تحديث').toString();
      final section = (data['section'] ?? '').toString();
      final createdByName = (data['createdByName'] ?? '').toString();

      activities.add({
        'time': ts,
        'title': type,
        'target': childName,
        'subtitle': createdByName.trim().isNotEmpty
            ? '${section.isNotEmpty ? '$section • ' : ''}بواسطة $createdByName'
            : section,
        'icon': Icons.notifications_active_outlined,
        'color': AppColors.primary,
      });
    }

    activities.sort((a, b) {
      final aTime = a['time'] as Timestamp?;
      final bTime = b['time'] as Timestamp?;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return activities.take(8).toList();
  }

  Future<List<String>> fetchAdminAlerts(Map<String, dynamic> stats) async {
    final childrenSnapshot = await _firestore.collection('children').get();
    final childSectionById =
        (stats['childSectionById'] as Map<String, dynamic>? ?? {});
    final latestLogByChild =
        (stats['latestLogByChild'] as Map<String, dynamic>? ?? {});

    final List<String> alerts = [];

    for (final doc in childrenSnapshot.docs) {
      final data = doc.data();
      final name = (data['name'] ?? 'طفل').toString();
      final isActive = data['isActive'] == true;
      if (!isActive) continue;

      final childId = doc.id;
      final section = (childSectionById[childId] ?? '').toString();
      final latest = latestLogByChild[childId] as Map<String, dynamic>?;

      if (section == 'Nursery') {
        if (latest == null) {
          alerts.add('$name لا يوجد له أي سجل دخول/خروج بعد');
          continue;
        }

        final latestType = (latest['eventType'] ?? '').toString();
        if (latestType == 'entry') {
          alerts.add('$name ما زال مسجلًا كداخل الآن');
        }
      }
    }

    return alerts.take(6).toList();
  }

  String formatTime(Timestamp? ts) {
    if (ts == null) return 'غير محدد';
    final d = ts.toDate();
    return '${d.year}/${d.month}/${d.day} - ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الرئيسية - الإدارة',
      actions: [
        IconButton(
          tooltip: 'تسجيل الخروج',
          onPressed: () => logout(context),
          icon: const Icon(Icons.logout),
        ),
      ],
      child: FutureBuilder<Map<String, dynamic>>(
        future: fetchAdminStats(),
        builder: (context, statsSnapshot) {
          if (statsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (statsSnapshot.hasError) {
            return Center(
              child: Text('حدث خطأ أثناء تحميل بيانات الإدارة: ${statsSnapshot.error}'),
            );
          }

          final stats = statsSnapshot.data ?? {};

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchRecentAdminActivities(),
            builder: (context, activitiesSnapshot) {
              if (activitiesSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final activities = activitiesSnapshot.data ?? [];

              return FutureBuilder<List<String>>(
                future: fetchAdminAlerts(stats),
                builder: (context, alertsSnapshot) {
                  final alerts = alertsSnapshot.data ?? [];

                  return ListView(
                    children: [
                      _buildWelcomeHeader(context),
                      const SizedBox(height: 16),
                      _buildOverviewStats(stats),
                      const SizedBox(height: 16),
                      _buildTodayStats(stats),
                      const SizedBox(height: 16),
                      _buildAlertsSection(alerts),
                      const SizedBox(height: 16),
                      _buildQuickActions(context),
                      const SizedBox(height: 16),
                      _buildRecentActivitiesSection(activities),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أهلاً بكِ في لوحة الإدارة',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'من هنا يمكنك متابعة وضع النظام، مراقبة الأنشطة، والوصول السريع لإدارة المستخدمين والأطفال والصفوف.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStats(Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نظرة عامة',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'الأطفال',
                value: '${stats['childrenCount'] ?? 0}',
                icon: Icons.child_care,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'أولياء الأمور',
                value: '${stats['parentsCount'] ?? 0}',
                icon: Icons.family_restroom,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'المعلمات',
                value: '${stats['teachersCount'] ?? 0}',
                icon: Icons.school_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'موظفات الحضانة',
                value: '${stats['nurseryStaffCount'] ?? 0}',
                icon: Icons.health_and_safety_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayStats(Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إحصائيات اليوم',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'دخول اليوم',
                value: '${stats['entryTodayCount'] ?? 0}',
                icon: Icons.login_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'خروج اليوم',
                value: '${stats['exitTodayCount'] ?? 0}',
                icon: Icons.logout_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'داخل الآن',
                value: '${stats['insideNowCount'] ?? 0}',
                icon: Icons.how_to_reg_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'تحديثات الحضانة',
                value: '${stats['nurseryUpdatesToday'] ?? 0}',
                icon: Icons.favorite_border_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'تحديثات الروضة',
                value: '${stats['kindergartenUpdatesToday'] ?? 0}',
                icon: Icons.menu_book_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'الأطفال النشطون',
                value: '${stats['activeChildrenCount'] ?? 0}',
                icon: Icons.verified_user_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlertsSection(List<String> alerts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.orange.withOpacity(0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'تنبيهات الإدارة',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (alerts.isEmpty)
            const Text(
              'لا توجد تنبيهات مهمة حاليًا.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textLight,
              ),
            )
          else
            ...alerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $alert',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        _AdminActionCard(
          icon: Icons.group,
          title: 'إدارة المستخدمين',
          subtitle: 'إضافة وتعديل وتنظيم حسابات النظام',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageUsersPage()),
            );
          },
        ),
        _AdminActionCard(
          icon: Icons.child_care,
          title: 'إدارة الأطفال',
          subtitle: 'عرض بيانات الأطفال وتعديلها وأرشفتها',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageChildrenPage()),
            );
          },
        ),
        _AdminActionCard(
          icon: Icons.class_,
          title: 'إدارة الصفوف والأقسام',
          subtitle: 'تنظيم الصفوف والمجموعات والربط بينها',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageClassesPage()),
            );
          },
        ),
        _AdminActionCard(
          icon: Icons.bar_chart,
          title: 'التقارير العامة',
          subtitle: 'لوحات وتقارير أوسع سيتم تطويرها لاحقًا',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('صفحة التقارير العامة سنطوّرها لاحقًا ✅'),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentActivitiesSection(List<Map<String, dynamic>> activities) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'آخر النشاطات اليوم',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ملخص لأحدث الحركات والتحديثات المسجلة في النظام.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (activities.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'لا توجد نشاطات اليوم بعد.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                ),
              ),
            )
          else
            ...activities.map((activity) {
              final title = (activity['title'] ?? '').toString();
              final target = (activity['target'] ?? '').toString();
              final subtitle = (activity['subtitle'] ?? '').toString();
              final color = activity['color'] as Color? ?? AppColors.primary;
              final icon =
                  activity['icon'] as IconData? ?? Icons.notifications_none;
              final time = activity['time'] as Timestamp?;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecentActivityTile(
                  title: title,
                  target: target,
                  subtitle: subtitle,
                  timeText: formatTime(time),
                  color: color,
                  icon: icon,
                ),
              );
            }),
        ],
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
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 26,
                ),
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
                        color: AppColors.textDark,
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
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
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

class _RecentActivityTile extends StatelessWidget {
  final String title;
  final String target;
  final String subtitle;
  final String timeText;
  final Color color;
  final IconData icon;

  const _RecentActivityTile({
    required this.title,
    required this.target,
    required this.subtitle,
    required this.timeText,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title - $target',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  timeText,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
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