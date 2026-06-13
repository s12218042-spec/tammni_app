import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/account_settings_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'admin_add_child_requests_page.dart';
import 'admin_add_user_page.dart';
import 'admin_chats_page.dart';
import 'admin_complaints_page.dart';
import 'admin_groups_page.dart';
import 'admin_invoice_page.dart';
import 'admin_registration_requests_page.dart';
import 'admin_updates_feed_page.dart';
import 'manage_users_page.dart';
import 'manage_children_page.dart';
import 'welcome_page.dart';
import 'admin_daily_tasks_table_page.dart';
import 'admin_weekly_duty__page.dart';
import 'admin_staff_tasks_review_page.dart';
import 'profile_details_page.dart';
import 'account_history_page.dart';
import 'admin_staff_evaluations_page.dart';
import 'admin_staff_attendance_page.dart';
import 'admin_staff_payroll_page.dart';
import 'admin_offers_page.dart';
import 'admin_consultations_page.dart';
import 'admin_general_reports_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AccountSettingsService _accountSettingsService =
      AccountSettingsService();

  int selectedIndex = 0;

  Future<void> logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
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

    final updatesSnapshot = await _firestore
        .collection('updates')
        .limit(100)
        .get();

    final requestsSnapshot = await _firestore
        .collection('registration_requests')
        .limit(100)
        .get();

    final addChildRequestsSnapshot = await _firestore
        .collection('add_child_requests')
        .limit(100)
        .get();

    final complaintsSnapshot = await _firestore
        .collection('complaints')
        .limit(200)
        .get();


    final users = usersSnapshot.docs.map((e) => e.data()).toList();
    final children = childrenSnapshot.docs.map((e) => e.data()).toList();
    final updates = updatesSnapshot.docs.map((e) => e.data()).toList();
    final requests = requestsSnapshot.docs.map((e) => e.data()).toList();
    final addChildRequests =
        addChildRequestsSnapshot.docs.map((e) => e.data()).toList();
    final complaints = complaintsSnapshot.docs.map((e) => e.data()).toList();

    int activeChildren = 0;
    int archivedChildren = 0;
    int nurseryChildren = 0;

    for (final child in children) {
      final isActive = (child['isActive'] ?? true) == true;
      final section = (child['section'] ?? '').toString().trim();

      if (isActive) {
        activeChildren++;
      } else {
        archivedChildren++;
      }

      if (section == 'Nursery' || section.isEmpty) {
        nurseryChildren++;
      }
    }

    int parentsCount = 0;
    int staffCount = 0;
    int adminsCount = 0;

    for (final user in users) {
      final role = (user['role'] ?? '').toString().trim().toLowerCase();
      final accountType =
          (user['accountType'] ?? '').toString().trim().toLowerCase();
      final isActive = user['isActive'] != false;

      if (!isActive) continue;

      final isTemporaryOrTrialParent =
          accountType == 'temporary_parent' ||
          accountType == 'trial_parent' ||
          user['isTemporaryAccount'] == true ||
          user['isTrialAccount'] == true;

      if (role == 'parent' && !isTemporaryOrTrialParent) {
        parentsCount++;
      }

      if (role == 'nursery' ||
          role == 'nursery staff' ||
          role == 'nursery_staff') {
        staffCount++;
      }

      if (role == 'admin') {
        adminsCount++;
      }
    }

    int pendingRequests = 0;
    int approvedRequests = 0;
    int rejectedRequests = 0;

    for (final request in requests) {
      final status = (request['status'] ?? 'pending').toString().trim();

      if (status == 'pending') pendingRequests++;
      if (status == 'approved') approvedRequests++;
      if (status == 'rejected') rejectedRequests++;
    }

    int pendingAddChildRequests = 0;
    int approvedAddChildRequests = 0;
    int rejectedAddChildRequests = 0;

    for (final request in addChildRequests) {
      final status = (request['status'] ?? 'pending').toString().trim();

      if (status == 'pending') pendingAddChildRequests++;
      if (status == 'approved') approvedAddChildRequests++;
      if (status == 'rejected') rejectedAddChildRequests++;
    }

    int totalComplaints = 0;
    int pendingComplaints = 0;
    int inReviewComplaints = 0;
    int resolvedComplaints = 0;
    int rejectedComplaints = 0;

    for (final complaint in complaints) {
      totalComplaints++;

      final status = (complaint['status'] ?? 'pending').toString().trim();

      if (status == 'pending') pendingComplaints++;
      if (status == 'in_review') inReviewComplaints++;
      if (status == 'resolved') resolvedComplaints++;
      if (status == 'rejected') rejectedComplaints++;
    }

    final alerts = <_AdminAlertItem>[];

    if (archivedChildren > 0) {
      alerts.add(
        _AdminAlertItem(
          title: 'يوجد $archivedChildren طفل/أطفال مؤرشفون',
          subtitle:
              'راجع الحالات غير النشطة.',
          icon: Icons.archive_outlined,
          color: Colors.blueGrey,
        ),
      );
    }

    if (pendingRequests > 0) {
      alerts.add(
        _AdminAlertItem(
          title: 'يوجد $pendingRequests طلب/طلبات تسجيل بانتظار المراجعة',
          subtitle: ' ',
          icon: Icons.how_to_reg_rounded,
          color: Colors.teal,
        ),
      );
    }

    if (pendingAddChildRequests > 0) {
      alerts.add(
        _AdminAlertItem(
          title:
              'يوجد $pendingAddChildRequests طلب/طلبات إضافة طفل بانتظار المراجعة',
          subtitle: ' ',
          icon: Icons.person_add_alt_1_rounded,
          color: Colors.indigo,
        ),
      );
    }

    if (pendingComplaints > 0 || inReviewComplaints > 0) {
      final openComplaints = pendingComplaints + inReviewComplaints;

      alerts.add(
        _AdminAlertItem(
          title: 'يوجد $openComplaints شكوى/شكاوى تحتاج متابعة',
          subtitle: ' ',
          icon: Icons.report_problem_outlined,
          color: Colors.deepPurple,
        ),
      );
    }


    if (users.isEmpty) {
      alerts.add(
        const _AdminAlertItem(
          title: 'لا يوجد مستخدمون في النظام',
          subtitle: ' ',
          icon: Icons.person_add_alt_1_rounded,
          color: Colors.redAccent,
        ),
      );
    }

    final recentActivities = updates.map((item) {
      final time = _extractDate(item);

      return _AdminActivityItem(
        title: _buildActivityTitle(item),
        subtitle: _buildActivitySubtitle(item),
        time: time,
        icon: _activityIcon((item['type'] ?? '').toString()),
      );
    }).toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    return _AdminDashboardData(
      totalUsers: users.length,
      totalChildren: children.length,
      activeChildren: activeChildren,
      archivedChildren: archivedChildren,
      nurseryChildren: nurseryChildren,
      parentsCount: parentsCount,
      staffCount: staffCount,
      adminsCount: adminsCount,
      pendingRequests: pendingRequests,
      approvedRequests: approvedRequests,
      rejectedRequests: rejectedRequests,
      pendingAddChildRequests: pendingAddChildRequests,
      approvedAddChildRequests: approvedAddChildRequests,
      rejectedAddChildRequests: rejectedAddChildRequests,
      totalComplaints: totalComplaints,
      pendingComplaints: pendingComplaints,
      inReviewComplaints: inReviewComplaints,
      resolvedComplaints: resolvedComplaints,
      rejectedComplaints: rejectedComplaints,
      alerts: alerts,
      recentActivities: recentActivities.take(20).toList(),
    );
  }

  static DateTime _extractDate(Map<String, dynamic> data) {
    final dynamic value =
        data['eventAt'] ?? data['time'] ?? data['createdAt'] ?? data['updatedAt'];

    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _buildActivityTitle(Map<String, dynamic> item) {
    final type = (item['type'] ?? 'update').toString();
    final childName = (item['childName'] ?? item['name'] ?? 'طفل').toString();

    switch (type) {
      case 'وجبة':
      case 'meal':
        return 'تمت إضافة تحديث وجبة للطفل $childName';
      case 'نوم':
      case 'sleep':
        return 'تمت إضافة تحديث نوم للطفل $childName';
      case 'حفاض':
      case 'diaper':
        return 'تمت إضافة تحديث حفاض للطفل $childName';
      case 'صحة':
      case 'health':
        return 'تمت إضافة تحديث صحي للطفل $childName';
      case 'نشاط':
      case 'activity':
        return 'تمت إضافة نشاط للطفل $childName';
      case 'ملاحظة':
      case 'note':
        return 'تمت إضافة ملاحظة للطفل $childName';
      case 'كاميرا':
      case 'media':
        return 'تمت إضافة وسائط للطفل $childName';
      default:
        return 'تمت إضافة تحديث جديد للطفل $childName';
    }
  }

  static String _buildActivitySubtitle(Map<String, dynamic> item) {
    final createdByName =
        (item['createdByName'] ?? 'مستخدم غير معروف').toString();

    final section = (item['section'] ?? '').toString();

    final details = <String>[
      '$createdByName',
      if (section == 'Nursery') '',
    ];

    return details.join(' • ');
  }

  static IconData _activityIcon(String type) {
    switch (type) {
      case 'وجبة':
      case 'meal':
        return Icons.restaurant_rounded;
      case 'نوم':
      case 'sleep':
        return Icons.bedtime_rounded;
      case 'حفاض':
      case 'diaper':
        return Icons.child_friendly_rounded;
      case 'صحة':
      case 'health':
        return Icons.medical_services_rounded;
      case 'نشاط':
      case 'activity':
        return Icons.extension_rounded;
      case 'كاميرا':
      case 'media':
        return Icons.photo_camera_rounded;
      case 'ملاحظة':
      case 'note':
        return Icons.edit_note_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _formatDateTime(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'بدون وقت';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'م' : 'ص';

    return '$year/$month/$day - $hour:$minute $period';
  }

  String get _pageTitle {
    switch (selectedIndex) {
      case 0:
        return 'لوحة تحكم الإدارة';
      case 1:
        return 'المتابعة';
      case 2:
        return 'الرسائل';
      case 3:
        return 'الإعدادات';
      default:
        return 'لوحة تحكم الإدارة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AdminDashboardData>(
      future: _loadDashboardData(),
      builder: (context, snapshot) {
        return Scaffold(
          body: AppPageScaffold(
            title: _pageTitle,
            actions: [
              IconButton(
                tooltip: 'آخر الأنشطة',
                onPressed: snapshot.hasData
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _AdminActivitiesPage(
                              activities: snapshot.data!.recentActivities,
                              formatDateTime: _formatDateTime,
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.history_rounded),
              ),
              IconButton(
                tooltip: 'الإشعارات',
                onPressed: snapshot.hasData
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _AdminNotificationsPage(
                              alerts: snapshot.data!.alerts,
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const _AdminNotificationsBell(),
              ),
            ],
            child: _buildBody(snapshot),
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
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
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

  Widget _buildBody(AsyncSnapshot<_AdminDashboardData> snapshot) {
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
            'حدث خطأ أثناء تحميل البيانات:\n${snapshot.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    final data = snapshot.data;

    if (data == null) {
      return const Center(child: Text('لا توجد بيانات'));
    }

    switch (selectedIndex) {
      case 0:
        return _buildDashboardTab(data);
      case 1:
        return _buildFollowUpTab();
      case 2:
        return _buildMessagesTab();
      case 3:
        return _buildSettingsTab();
      default:
        return _buildDashboardTab(data);
    }
  }

  Widget _buildDashboardTab(_AdminDashboardData data) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: ListView(
          children: [
          const SizedBox(height: 8),
          Text(
            '',
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
                    'أدمن ${data.adminsCount} • أولياء ${data.parentsCount} • موظفين ${data.staffCount}',
                icon: Icons.groups_rounded,
              ),
              _DashboardStatCard(
                title: 'الأطفال النشطون',
                value: '${data.activeChildren}',
                subtitle: '',
                icon: Icons.child_care_rounded,
              ),
              _DashboardStatCard(
                title: 'الأطفال المؤرشفون',
                value: '${data.archivedChildren}',
                subtitle: 'مراجعة الحالات غير النشطة',
                icon: Icons.archive_rounded,
              ),
              _DashboardStatCard(
                title: 'طلبات التسجيل',
                value: '${data.pendingRequests}',
                subtitle:
                    'معلقة ${data.pendingRequests} • مقبولة ${data.approvedRequests}',
                icon: Icons.how_to_reg_rounded,
              ),
              _DashboardStatCard(
                title: 'طلبات إضافة الأطفال',
                value: '${data.pendingAddChildRequests}',
                subtitle:
                    'معلقة ${data.pendingAddChildRequests} • مقبولة ${data.approvedAddChildRequests}',
                icon: Icons.person_add_alt_1_rounded,
              ),
              _DashboardStatCard(
                title: 'شكاوى أولياء الأمور',
                value: '${data.totalComplaints}',
                subtitle:
                   'محلولة ${data.resolvedComplaints}',
                icon: Icons.report_problem_outlined,
              ),
              
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle(
            title: 'الإشعارات',
            icon: Icons.notifications_active_rounded,
          ),
          const SizedBox(height: 12),
          if (data.alerts.isEmpty)
            const _EmptyDashboardBox(
              icon: Icons.verified_rounded,
              title: 'لا توجد إشعارات',
              subtitle: ' ',
            )
          else
            ...data.alerts.take(3).map((alert) => _AlertCard(item: alert)),
          const SizedBox(height: 24),
          const _SectionTitle(
            title: 'آخر الأنشطة',
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: 12),
          if (data.recentActivities.isEmpty)
            const _EmptyDashboardBox(
              icon: Icons.history_toggle_off_rounded,
              title: 'لا توجد أنشطة',
              subtitle: ' ',
            )
          else
            ...data.recentActivities.take(4).map(
                  (activity) => _ActivityCard(
                    item: activity,
                    formattedTime: _formatDateTime(activity.time),
                  ),
                ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFollowUpTab() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: ListView(
        children: [
        const _SectionTitle(
          title: 'الإجراءات الأساسية',
          icon: Icons.fact_check_rounded,
        ),
        const SizedBox(height: 12),

        _AdminActionCard(
          icon: Icons.how_to_reg_rounded,
          title: 'طلبات تسجيل أولياء الأمور',
          subtitle: ' ',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminRegistrationRequestsPage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),

        _AdminActionCard(
          icon: Icons.person_add_alt_1_outlined,
          title: 'طلبات إضافة الأطفال',
          subtitle: ' ',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminAddChildRequestsPage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),

        _AdminActionCard(
          icon: Icons.report_problem_outlined,
          title: 'شكاوى أولياء الأمور',
          subtitle: ' ',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminComplaintsPage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),

        _AdminActionCard(
          icon: Icons.group_rounded,
          title: 'إدارة المستخدمين',
          subtitle: ' ',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManageUsersPage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),

        _AdminActionCard(
          icon: Icons.child_care_rounded,
          title: 'إدارة الأطفال',
          subtitle: ' ',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManageChildrenPage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),

        _AdminActionCard(
          icon: Icons.groups_2_rounded,
          title: 'إدارة المجموعات',
          subtitle: ' ',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminGroupsPage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),

        _AdminActionCard(
          icon: Icons.assignment_turned_in_outlined,
          title: 'تحديد مهام الموظفين',
          subtitle: ' ',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminDailyTasksTablePage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),

        _AdminActionCard(
          icon: Icons.fact_check_outlined,
          title: 'متابعة مهام الموظفين',
          subtitle: ' ',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminStaffTasksReviewPage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),

        _AdminActionCard(
          icon: Icons.calendar_month_outlined,
          title: 'المناوبة الأسبوعية',
          subtitle: ' ',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminWeeklyDutyPage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),
        _AdminActionCard(
  icon: Icons.star_rate_outlined,
  title: 'تقييم الموظفين',
  subtitle: ' ',
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminStaffEvaluationsPage(),
      ),
    );

    if (!mounted) return;
    setState(() {});
  },
),
_AdminActionCard(
  icon: Icons.access_time_outlined,
  title: 'دوام الموظفين',
  subtitle: ' ',
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminStaffAttendancePage(),
      ),
    );

    if (!mounted) return;
    setState(() {});
  },
),
_AdminActionCard(
  icon: Icons.payments_outlined,
  title: 'رواتب الموظفين',
  subtitle: ' ',
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminStaffPayrollPage(),
      ),
    );

    if (!mounted) return;
    setState(() {});
  },
),
        _AdminActionCard(
          icon: Icons.person_add_alt_1_rounded,
          title: 'إنشاء حسابات الموظفين',
          subtitle: ' ',
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
          icon: Icons.receipt_long_rounded,
          title: 'إدارة الفواتير',
          subtitle: ' ',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminInvoicesPage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),

        _AdminActionCard(
          icon: Icons.local_offer_rounded,
          title: 'العروض والاشتراكات',
          subtitle: ' ',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminOffersPage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),

        _AdminActionCard(
          icon: Icons.psychology_alt_rounded,
          title: 'الاستشارات',
          subtitle: ' ',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminConsultationsPage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),

        const SizedBox(height: 24),

        const _SectionTitle(
          title: 'أدوات إضافية',
          icon: Icons.admin_panel_settings_rounded,
        ),
        const SizedBox(height: 12),

        _AdminActionCard(
          icon: Icons.dynamic_feed_rounded,
          title: 'سجل المتابعة الإداري',
          subtitle: ' ',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminUpdatesFeedPage(),
              ),
            );

            if (!mounted) return;
            setState(() {});
          },
        ),

        _AdminActionCard(
  icon: Icons.bar_chart_rounded,
  title: 'التقارير العامة',
  subtitle: ' ',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminGeneralReportsPage(),
      ),
    );
  },
),
      ],
    ),
  );
}

  Widget _buildMessagesTab() {
    return const AdminChatsPage();
  }

  Widget _buildSettingsTab() {
    return ListView(
        children: [
        Card(
          child: FutureBuilder<AccountSettingsData>(
            future: _accountSettingsService.getCurrentUserData(),
            builder: (context, snapshot) {
              final data = snapshot.data;

              final displayName = data?.name.trim().isNotEmpty == true
                  ? data!.name
                  : 'الأدمن';

              final subtitle = data == null
                  ? ''
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
                    displayName.trim().isNotEmpty ? displayName.trim()[0] : 'أ',
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
      builder: (_) => const ProfileDetailsPage(),
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
                  backgroundColor: Colors.green.withOpacity(0.12),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.green,
                  ),
                ),
                title: const Text('الإشعارات'),
                subtitle: const Text(''),
                onTap: () async {
                  final data = await _loadDashboardData();

                  if (!mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          _AdminNotificationsPage(alerts: data.alerts),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.withOpacity(0.12),
                  child: const Icon(
                    Icons.history_rounded,
                    color: Colors.teal,
                  ),
                ),
                title: const Text('سجل نشاط الحساب'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountHistoryPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      
      const SizedBox(height: 16),
Card(
  child: ListTile(
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
    onTap: () => logout(context),
  ),
),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'الإصدار 1.0.0',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
        children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
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
                        height: 1.35,
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
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
              children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.10),
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
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.8,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
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
        padding: const EdgeInsets.all(20),
        child: Column(
            children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary.withOpacity(0.10),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.45),
            ),
          ],
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: item.color.withOpacity(0.18)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
              children: [
              CircleAvatar(
                backgroundColor: item.color.withOpacity(0.12),
                child: Icon(item.icon, color: item.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.35,
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
            children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.10),
              child: Icon(item.icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formattedTime,
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
    );
  }
}

class _AdminNotificationsBell extends StatelessWidget {
  const _AdminNotificationsBell();

  String _clean(dynamic value) => (value ?? '').toString().trim();

  bool _isUnread(Map<String, dynamic> data) {
    final isRead = data['isRead'];
    final read = data['read'];
    final seen = data['seen'];

    if (isRead is bool) return !isRead;
    if (read is bool) return !read;
    if (seen is bool) return !seen;

    return true;
  }

  bool _isVisibleForCurrentAdmin(Map<String, dynamic> data) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final targetUid = _clean(data['targetUid']);

    if (targetUid.isEmpty) return true;

    return currentUid.isNotEmpty && targetUid == currentUid;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('notificationFor', isEqualTo: 'admin')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];

        final unreadCount = docs.where((doc) {
          final data = doc.data();

          return _isVisibleForCurrentAdmin(data) && _isUnread(data);
        }).length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none_rounded),
            if (unreadCount > 0)
              Positioned(
                top: -7,
                right: -8,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminNotificationsPage extends StatefulWidget {
  final List<_AdminAlertItem> alerts;

  const _AdminNotificationsPage({
    required this.alerts,
  });

  @override
  State<_AdminNotificationsPage> createState() =>
      _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<_AdminNotificationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _markingAllRead = false;

  String _clean(dynamic value) => (value ?? '').toString().trim();

  String _normalizeRole(dynamic value) {
    final role = _clean(value).toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'staff' ||
        role == 'employee' ||
        role == 'teacher') {
      return 'nursery_staff';
    }

    return role;
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final cleanValue = _clean(value);

      if (cleanValue.isNotEmpty) return cleanValue;
    }

    return '';
  }

  bool _firstBool(List<dynamic> values, {bool fallback = false}) {
    for (final value in values) {
      if (value is bool) return value;
    }

    return fallback;
  }

  DateTime _firstDate(List<dynamic> values) {
    for (final value in values) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;

      if (value is String) {
        final parsed = DateTime.tryParse(value);

        if (parsed != null) return parsed;
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _isVisibleForCurrentAdmin(Map<String, dynamic> data) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    final notificationFor = _normalizeRole(
      _firstNonEmpty([
        data['notificationFor'],
        data['targetRole'],
      ]),
    );

    final targetRole = _normalizeRole(
      _firstNonEmpty([
        data['targetRole'],
        data['notificationFor'],
      ]),
    );

    final isAdminNotification =
        notificationFor == 'admin' || targetRole == 'admin';

    if (!isAdminNotification) return false;

    final targetUid = _firstNonEmpty([
      data['targetUid'],
      data['receiverId'],
    ]);

    if (targetUid.isEmpty) return true;

    return currentUid.isNotEmpty && targetUid == currentUid;
  }

  Future<List<_AdminNotificationItem>> _loadNotifications() async {
    final docsById =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    Future<void> collect(
      Query<Map<String, dynamic>> query,
    ) async {
      try {
        final snapshot = await query.limit(300).get();

        for (final doc in snapshot.docs) {
          docsById[doc.id] = doc;
        }
      } catch (_) {
      }
    }

    await collect(
      _firestore
          .collection('notifications')
          .where('notificationFor', isEqualTo: 'admin'),
    );

    await collect(
      _firestore
          .collection('notifications')
          .where('targetRole', isEqualTo: 'admin'),
    );

    final items = docsById.values
        .where((doc) => _isVisibleForCurrentAdmin(doc.data()))
        .map((doc) {
      final data = doc.data();

      return _AdminNotificationItem(
        id: doc.id,
        title: _firstNonEmpty([
          data['title'],
          data['subject'],
          data['notificationTitle'],
          'إشعار جديد',
        ]),
        body: _firstNonEmpty([
          data['body'],
          data['message'],
          data['text'],
          data['description'],
        ]),
        type: _firstNonEmpty([
          data['type'],
          data['notificationType'],
          data['category'],
          'general',
        ]),
        childName: _firstNonEmpty([
          data['childName'],
        ]),
        parentName: _firstNonEmpty([
          data['parentName'],
        ]),
        createdByName: _firstNonEmpty([
          data['createdByName'],
          data['senderName'],
          data['byName'],
        ]),
        createdByRole: _normalizeRole(
          _firstNonEmpty([
            data['createdByRole'],
            data['senderRole'],
            data['byRole'],
          ]),
        ),
        priority: _firstNonEmpty([
          data['priority'],
          data['importance'],
        ]),
        isRead: _firstBool([
          data['isRead'],
          data['read'],
          data['seen'],
        ]),
        time: _firstDate([
          data['createdAt'],
          data['time'],
          data['timestamp'],
          data['updatedAt'],
        ]),
      );
    }).toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    return items;
  }

  Future<void> _markAsRead(String id) async {
    if (id.trim().isEmpty) return;

    try {
      await _firestore.collection('notifications').doc(id).set({
        'isRead': true,
        'read': true,
        'seen': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تعليم الإشعار كمقروء: $e')),
      );
    }
  }

  Future<void> _markAllAsRead(
    List<_AdminNotificationItem> notifications,
  ) async {
    if (_markingAllRead) return;

    final unreadItems =
        notifications.where((item) => !item.isRead).toList();

    if (unreadItems.isEmpty) return;

    setState(() {
      _markingAllRead = true;
    });

    try {
      final batch = _firestore.batch();

      for (final item in unreadItems) {
        final ref = _firestore.collection('notifications').doc(item.id);

        batch.set(
          ref,
          {
            'isRead': true,
            'read': true,
            'seen': true,
            'readAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تعليم الإشعارات كمقروءة: $e')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _markingAllRead = false;
      });
    }
  }

  String _formatDateTime(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'بدون وقت';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'م' : 'ص';

    return '$year/$month/$day - $hour:$minute $period';
  }

  Widget _buildSummary(List<_AdminNotificationItem> notifications) {
    final unreadCount =
        notifications.where((item) => !item.isRead).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                unreadCount > 0
                    ? 'يوجد $unreadCount إشعار غير مقروء'
                    : 'كل إشعارات النظام مقروءة',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (unreadCount > 0)
              TextButton.icon(
                onPressed: _markingAllRead
                    ? null
                    : () => _markAllAsRead(notifications),
                icon: _markingAllRead
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('قراءة الكل'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الإشعارات',
      child: FutureBuilder<List<_AdminNotificationItem>>(
        future: _loadNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'حدث خطأ أثناء تحميل الإشعارات:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final notifications = snapshot.data ?? const [];
          final alerts = widget.alerts;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (notifications.isEmpty && alerts.isEmpty)
                  const _EmptyDashboardBox(
                    icon: Icons.notifications_off_rounded,
                    title: 'لا توجد إشعارات حالياً',
                    subtitle: ' ',
                  ),
                if (notifications.isNotEmpty) ...[
                  _buildSummary(notifications),
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    title: 'إشعارات النظام',
                    icon: Icons.notifications_active_rounded,
                  ),
                  const SizedBox(height: 10),
                  ...notifications.map(
                    (item) => _AdminNotificationCard(
                      item: item,
                      formattedTime: _formatDateTime(item.time),
                      onTap: () => _markAsRead(item.id),
                    ),
                  ),
                ],
                if (alerts.isNotEmpty) ...[
                  if (notifications.isNotEmpty) const SizedBox(height: 18),
                  const _SectionTitle(
                    title: 'تنبيهات لوحة التحكم',
                    icon: Icons.warning_amber_rounded,
                  ),
                  const SizedBox(height: 10),
                  ...alerts.map((alert) => _AlertCard(item: alert)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminNotificationCard extends StatelessWidget {
  final _AdminNotificationItem item;
  final String formattedTime;
  final VoidCallback onTap;

  const _AdminNotificationCard({
    required this.item,
    required this.formattedTime,
    required this.onTap,
  });

  IconData _iconForType(String type) {
    switch (type.trim().toLowerCase()) {
      case 'consultation_approved':
        return Icons.check_circle_outline_rounded;
      case 'consultation_rejected':
        return Icons.cancel_outlined;
      case 'complaint_created':
        return Icons.report_problem_outlined;
      case 'registration_request':
      case 'parent_registration_request':
        return Icons.how_to_reg_rounded;
      case 'add_child_request':
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type.trim().toLowerCase()) {
      case 'consultation_approved':
        return Colors.green;
      case 'consultation_rejected':
        return Colors.redAccent;
      case 'complaint_created':
        return Colors.deepPurple;
      case 'registration_request':
      case 'parent_registration_request':
        return Colors.teal;
      case 'add_child_request':
        return Colors.indigo;
      default:
        return AppColors.primary;
    }
  }

  String _typeLabel(String type) {
    switch (type.trim().toLowerCase()) {
      case 'consultation_approved':
        return 'موافقة استشارة';
      case 'consultation_rejected':
        return 'رفض استشارة';
      case 'complaint_created':
        return 'شكوى جديدة';
      case 'registration_request':
      case 'parent_registration_request':
        return 'طلب تسجيل';
      case 'add_child_request':
        return 'طلب إضافة طفل';
      default:
        return type.trim().isEmpty ? 'إشعار' : type;
    }
  }

  String _senderLabel() {
    final name = item.createdByName.trim();
    final role = item.createdByRole.trim().toLowerCase();

    String roleLabel;

    switch (role) {
      case 'parent':
        roleLabel = 'وليّ الأمر';
        break;
      case 'temporary_parent':
        roleLabel = 'وليّ أمر زائر';
        break;
      case 'admin':
        roleLabel = 'الإدارة';
        break;
      case 'nursery_staff':
        roleLabel = 'موظف الحضانة';
        break;
      default:
        roleLabel = item.createdByRole.trim();
    }

    if (name.isNotEmpty && roleLabel.isNotEmpty) {
      return '$name - $roleLabel';
    }

    if (name.isNotEmpty) return name;
    if (roleLabel.isNotEmpty) return roleLabel;

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(item.type);
    final sender = _senderLabel();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: item.isRead ? 1 : 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(
                  _iconForType(item.type),
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: item.isRead
                                  ? AppColors.textLight
                                  : AppColors.textDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (item.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        item.body,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (item.parentName.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        'ولي الأمر: ${item.parentName}',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    if (item.childName.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        'الطفل: ${item.childName}',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    if (sender.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        'من: $sender',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _typeLabel(item.type),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
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

class _AdminNotificationItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final String childName;
  final String parentName;
  final String createdByName;
  final String createdByRole;
  final String priority;
  final bool isRead;
  final DateTime time;

  const _AdminNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.childName,
    required this.parentName,
    required this.createdByName,
    required this.createdByRole,
    required this.priority,
    required this.isRead,
    required this.time,
  });
}

class _AdminActivitiesPage extends StatelessWidget {
  final List<_AdminActivityItem> activities;
  final String Function(DateTime) formatDateTime;

  const _AdminActivitiesPage({
    required this.activities,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'آخر الأنشطة',
      child: activities.isEmpty
          ? const _EmptyDashboardBox(
              icon: Icons.history_toggle_off_rounded,
              title: 'لا توجد أنشطة',
              subtitle: ' ',
            )
          : ListView(
              children: activities
                  .map(
                    (activity) => _ActivityCard(
                      item: activity,
                      formattedTime: formatDateTime(activity.time),
                    ),
                  )
                  .toList(),
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
  final int parentsCount;
  final int staffCount;
  final int adminsCount;

  final int pendingRequests;
  final int approvedRequests;
  final int rejectedRequests;

  final int pendingAddChildRequests;
  final int approvedAddChildRequests;
  final int rejectedAddChildRequests;

  final int totalComplaints;
  final int pendingComplaints;
  final int inReviewComplaints;
  final int resolvedComplaints;
  final int rejectedComplaints;

  final List<_AdminAlertItem> alerts;
  final List<_AdminActivityItem> recentActivities;

  const _AdminDashboardData({
    required this.totalUsers,
    required this.totalChildren,
    required this.activeChildren,
    required this.archivedChildren,
    required this.nurseryChildren,
    required this.parentsCount,
    required this.staffCount,
    required this.adminsCount,
    required this.pendingRequests,
    required this.approvedRequests,
    required this.rejectedRequests,
    required this.pendingAddChildRequests,
    required this.approvedAddChildRequests,
    required this.rejectedAddChildRequests,
    required this.totalComplaints,
    required this.pendingComplaints,
    required this.inReviewComplaints,
    required this.resolvedComplaints,
    required this.rejectedComplaints,
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
