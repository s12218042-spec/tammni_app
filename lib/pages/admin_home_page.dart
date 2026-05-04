import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'account_settings_page.dart';
import 'admin_add_child_requests_page.dart';
import 'admin_add_user_page.dart';
import 'admin_chats_page.dart';
import 'admin_complaints_page.dart';
import 'admin_invoice_page.dart';
import 'admin_registration_requests_page.dart';
import 'admin_updates_feed_page.dart';
import 'manage_children_page.dart';
import 'manage_users_page.dart';
import 'welcome_page.dart';
import 'admin_live_stream_requests_page.dart';
import '../services/account_settings_service.dart';

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
  bool isArabic = true;
  bool isDarkMode = false;

  Future<void> logout(BuildContext context) async {
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

    final deletionRequestsSnapshot = await _firestore
        .collection('account_deletion_requests')
        .limit(100)
        .get();

    final complaintsSnapshot = await _firestore
        .collection('complaints')
        .limit(200)
        .get();

    final currentAdminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

     QuerySnapshot<Map<String, dynamic>>? unreadMessagesSnapshot;

     if (currentAdminUid.trim().isNotEmpty) {
      unreadMessagesSnapshot = await _firestore
      .collection('messages')
      .where('receiverId', isEqualTo: currentAdminUid)
      .where('isRead', isEqualTo: false)
      .limit(200)
      .get();
}

    final users = usersSnapshot.docs.map((e) => e.data()).toList();
    final children = childrenSnapshot.docs.map((e) => e.data()).toList();
    final updates = updatesSnapshot.docs.map((e) => e.data()).toList();
    final requests = requestsSnapshot.docs.map((e) => e.data()).toList();
    final addChildRequests =
        addChildRequestsSnapshot.docs.map((e) => e.data()).toList();
    final deletionRequests =
        deletionRequestsSnapshot.docs.map((e) => e.data()).toList();
    final complaints = complaintsSnapshot.docs.map((e) => e.data()).toList();

    int unreadMessagesCount = 0;

    if (unreadMessagesSnapshot != null) {
  unreadMessagesCount = unreadMessagesSnapshot.docs.where((doc) {
    final data = doc.data();

    final deletedForUserIds =
        (data['deletedForUserIds'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

    return !deletedForUserIds.contains(currentAdminUid);
   }).length;
}

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

      if (role == 'parent') parentsCount++;
      if (role == 'nursery' ||
          role == 'nursery staff' ||
          role == 'nursery_staff') {
        staffCount++;
      }
      if (role == 'admin') adminsCount++;
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

    int pendingDeletionRequests = 0;
    int approvedDeletionRequests = 0;
    int rejectedDeletionRequests = 0;

    for (final request in deletionRequests) {
      final status = (request['status'] ?? 'pending').toString().trim();

      if (status == 'pending') pendingDeletionRequests++;
      if (status == 'approved') approvedDeletionRequests++;
      if (status == 'rejected') rejectedDeletionRequests++;
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
              'راجعي الأطفال المؤرشفين وتحققي إذا كانت حالتهم ما زالت صحيحة.',
          icon: Icons.archive_outlined,
          color: Colors.blueGrey,
        ),
      );
    }

    if (pendingRequests > 0) {
      alerts.add(
        _AdminAlertItem(
          title: 'يوجد $pendingRequests طلب/طلبات تسجيل بانتظار المراجعة',
          subtitle:
              'راجعي طلبات أولياء الأمور الجديدة وحددي الموافقة أو الرفض.',
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
          subtitle:
              'راجعي طلبات إضافة الأطفال الجديدة وحددي الموافقة أو الرفض.',
          icon: Icons.person_add_alt_1_rounded,
          color: Colors.indigo,
        ),
      );
    }

    if (pendingDeletionRequests > 0) {
      alerts.add(
        _AdminAlertItem(
          title:
              'يوجد $pendingDeletionRequests طلب/طلبات حذف حساب بانتظار المراجعة',
          subtitle: 'راجعي طلبات حذف الحسابات وحددي الموافقة أو الرفض.',
          icon: Icons.delete_forever_outlined,
          color: Colors.redAccent,
        ),
      );
    }

    if (pendingComplaints > 0 || inReviewComplaints > 0) {
      final openComplaints = pendingComplaints + inReviewComplaints;

      alerts.add(
        _AdminAlertItem(
          title: 'يوجد $openComplaints شكوى/شكاوى تحتاج متابعة',
          subtitle:
              'راجعي شكاوى أولياء الأمور المفتوحة وحددي حالتها أو أضيفي ردًا إداريًا.',
          icon: Icons.report_problem_outlined,
          color: Colors.deepPurple,
        ),
      );
    }

    if (unreadMessagesCount > 0) {
      alerts.add(
       _AdminAlertItem(
       title: 'يوجد $unreadMessagesCount رسالة/رسائل غير مقروءة',
       subtitle: 'راجعي تبويب الرسائل للرد على أولياء الأمور أو الموظفات.',
       icon: Icons.mark_chat_unread_outlined,
       color: Colors.blue,
       ),
      );
    }

    if (users.isEmpty) {
      alerts.add(
        const _AdminAlertItem(
          title: 'لا يوجد مستخدمون في النظام',
          subtitle:
              'ابدئي بإضافة حسابات الإدارة وموظفات الحضانة، ومراجعة طلبات أولياء الأمور.',
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
      pendingDeletionRequests: pendingDeletionRequests,
      approvedDeletionRequests: approvedDeletionRequests,
      rejectedDeletionRequests: rejectedDeletionRequests,
      totalComplaints: totalComplaints,
      pendingComplaints: pendingComplaints,
      inReviewComplaints: inReviewComplaints,
      resolvedComplaints: resolvedComplaints,
      rejectedComplaints: rejectedComplaints,
      unreadMessagesCount: unreadMessagesCount,
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
      'بواسطة: $createdByName',
      if (section == 'Nursery') 'القسم: حضانة',
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
                icon: const Icon(Icons.notifications_none_rounded),
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
      return const Center(child: Text('لا توجد بيانات متاحة حالياً'));
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
          Text(
            'أهلاً بكِ في لوحة الإدارة 👋',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'هذه الصفحة الرئيسية تعرض لكِ لمحة سريعة عن حالة نظام الحضانة.',
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
                    'أدمن ${data.adminsCount} • أولياء ${data.parentsCount} • موظفات ${data.staffCount}',
                icon: Icons.groups_rounded,
              ),
              _DashboardStatCard(
                title: 'الأطفال النشطون',
                value: '${data.activeChildren}',
                subtitle: 'أطفال الحضانة ${data.nurseryChildren}',
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
                title: 'طلبات حذف الحسابات',
                value: '${data.pendingDeletionRequests}',
                subtitle:
                    'معلقة ${data.pendingDeletionRequests} • مقبولة ${data.approvedDeletionRequests}',
                icon: Icons.delete_forever_outlined,
              ),
              _DashboardStatCard(
                title: 'شكاوى أولياء الأمور',
                value: '${data.totalComplaints}',
                subtitle:
                    'مفتوحة ${data.pendingComplaints + data.inReviewComplaints} • محلولة ${data.resolvedComplaints}',
                icon: Icons.report_problem_outlined,
              ),
              _DashboardStatCard(
                title: 'الرسائل غير المقروءة',
                value: '${data.unreadMessagesCount}',
                subtitle: data.unreadMessagesCount > 0
                  ? 'تحتاج متابعة من تبويب الرسائل'
                  : 'لا توجد رسائل غير مقروءة',
                icon: Icons.mark_chat_unread_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle(
            title: 'تنبيهات مختصرة',
            icon: Icons.notifications_active_rounded,
          ),
          const SizedBox(height: 12),
          if (data.alerts.isEmpty)
            const _EmptyDashboardBox(
              icon: Icons.verified_rounded,
              title: 'لا توجد تنبيهات حالياً',
              subtitle: 'الوضع يبدو جيداً داخل النظام.',
            )
          else
            ...data.alerts.take(3).map((alert) => _AlertCard(item: alert)),
          const SizedBox(height: 24),
          const _SectionTitle(
            title: 'آخر الأنشطة المختصرة',
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: 12),
          if (data.recentActivities.isEmpty)
            const _EmptyDashboardBox(
              icon: Icons.history_toggle_off_rounded,
              title: 'لا توجد أنشطة حديثة',
              subtitle: 'عند إضافة تحديثات للأطفال ستظهر هنا.',
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
            subtitle: 'مراجعة طلبات التسجيل الجديدة والموافقة أو الرفض',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminRegistrationRequestsPage(),
                ),
              );
              setState(() {});
            },
          ),
          _AdminActionCard(
            icon: Icons.person_add_alt_1_outlined,
            title: 'طلبات إضافة الأطفال',
            subtitle: 'مراجعة طلبات إضافة طفل جديد إلى حسابات أولياء الأمور',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminAddChildRequestsPage(),
                ),
              );
              setState(() {});
            },
          ),
          _AdminActionCard(
            icon: Icons.report_problem_outlined,
            title: 'شكاوى أولياء الأمور',
            subtitle: 'متابعة الشكاوى والملاحظات من الأهالي',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminComplaintsPage()),
              );
            },
          ),
          
          _AdminActionCard(
            icon: Icons.group_rounded,
            title: 'إدارة المستخدمين',
            subtitle:
                'مراجعة الحسابات الحالية، تعديلها، تفعيلها أو تعطيلها دون إنشاء حسابات جديدة',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageUsersPage()),
              );
              setState(() {});
            },
          ),
          _AdminActionCard(
            icon: Icons.child_care_rounded,
            title: 'إدارة الأطفال',
            subtitle: 'متابعة بيانات الأطفال، الأرشفة، والحالة الحالية',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageChildrenPage()),
              );
              setState(() {});
            },
          ),
          _AdminActionCard(
            icon: Icons.person_add_alt_1_rounded,
            title: 'إنشاء حسابات الموظفين',
            subtitle: 'إنشاء حسابات موظفات الحضانة والإدارة فقط',
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminAddUserPage()),
              );

              if (result == true) {
                setState(() {});
              }
            },
          ),
          _AdminActionCard(
            icon: Icons.receipt_long_rounded,
            title: 'إدارة الفواتير',
            subtitle: 'عرض الفواتير وإنشاء فاتورة حضانة جديدة من خلال الأدمن',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminInvoicesPage()),
              );
              setState(() {});
            },
          ),
          const SizedBox(height: 24),
          const _SectionTitle(
         title: 'أدوات الإدارة المتقدمة',
         icon: Icons.admin_panel_settings_rounded,
          ),
        const SizedBox(height: 12),
        _AdminActionCard(
         icon: Icons.video_call_outlined,
         title: 'طلبات البث المباشر',
         subtitle: 'مراجعة طلبات أولياء الأمور ومتابعة قائمة الانتظار',
         onTap: () async {
         await Navigator.push(
         context,
         MaterialPageRoute(
         builder: (_) => const AdminLiveStreamRequestsPage(),
        ),
    );

    if (!mounted) return;
    setState(() {});
  },
),
        _AdminActionCard(
  icon: Icons.video_call_rounded,
  title: 'طلبات البث المباشر',
  subtitle: 'مراجعة طلبات أولياء الأمور وبدء بث خاص لكل طفل',
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminLiveStreamRequestsPage(),
      ),
    );

    if (!mounted) return;
    setState(() {});
  },
),

_AdminActionCard(
  icon: Icons.dynamic_feed_rounded,
  title: 'سجل التحديثات الإداري',
  subtitle: 'متابعة آخر تحديثات موظفات الحضانة داخل النظام',
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminUpdatesFeedPage()),
    );
    setState(() {});
  },
),
          _AdminActionCard(
            icon: Icons.bar_chart_rounded,
            title: 'التقارير العامة',
            subtitle: 'تجهيز صفحة تقارير أوسع لاحقًا',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('قيد العمل')),
              );
            },
          ),
          const SizedBox(height: 12),
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
                  ? 'إدارة النظام'
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
                  child: const Icon(Icons.language_rounded, color: Colors.blue),
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
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.12),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.green,
                  ),
                ),
                title: const Text('التنبيهات'),
                subtitle: const Text('عرض وإدارة التنبيهات'),
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
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'المظهر',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textLight,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            secondary: CircleAvatar(
              backgroundColor: Colors.purple.withOpacity(0.12),
              child: const Icon(Icons.palette_outlined, color: Colors.purple),
            ),
            title: const Text('الوضع الليلي'),
            value: isDarkMode,
            onChanged: (value) {
              setState(() {
                isDarkMode = value;
              });
            },
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
                onTap: () {},
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
                onTap: () => logout(context),
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

class _AdminNotificationsPage extends StatelessWidget {
  final List<_AdminAlertItem> alerts;

  const _AdminNotificationsPage({
    required this.alerts,
  });

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الإشعارات',
      child: alerts.isEmpty
          ? const _EmptyDashboardBox(
              icon: Icons.notifications_off_rounded,
              title: 'لا توجد إشعارات حالياً',
              subtitle: 'عند وجود تنبيهات جديدة ستظهر هنا.',
            )
          : ListView(
              children: alerts.map((alert) => _AlertCard(item: alert)).toList(),
            ),
    );
  }
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
              title: 'لا توجد أنشطة حديثة',
              subtitle: 'عند إضافة تحديثات للأطفال ستظهر هنا.',
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

  final int pendingDeletionRequests;
  final int approvedDeletionRequests;
  final int rejectedDeletionRequests;

  final int totalComplaints;
  final int pendingComplaints;
  final int inReviewComplaints;
  final int resolvedComplaints;
  final int rejectedComplaints;
  final int unreadMessagesCount;

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
    required this.pendingDeletionRequests,
    required this.approvedDeletionRequests,
    required this.rejectedDeletionRequests,
    required this.totalComplaints,
    required this.pendingComplaints,
    required this.inReviewComplaints,
    required this.resolvedComplaints,
    required this.rejectedComplaints,
    required this.unreadMessagesCount,
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