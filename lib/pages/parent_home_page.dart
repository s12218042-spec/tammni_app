import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../services/account_settings_service.dart';
import '../services/auth_service.dart';
import '../services/live_stream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'account_history_page.dart';
import 'add_child_request_page.dart';
import 'child_profile_page.dart';
import 'live_stream_viewer_page.dart';
import 'parent_chats_page.dart';
import 'parent_complaints_page.dart';
import 'profile_details_page.dart';
import 'parent_consultations_page.dart';
import 'parent_invoice_page.dart';
import 'parent_notifications_page.dart';
import 'parent_updates_page.dart';
import 'welcome_page.dart';
import 'parent_support_center_page.dart';


class ParentHomePage extends StatefulWidget {
  final String parentUsername;

  const ParentHomePage({
    super.key,
    required this.parentUsername,
  });

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LiveStreamService _liveStreamService = LiveStreamService();
  final AccountSettingsService _accountSettingsService =
      AccountSettingsService();

  int selectedIndex = 0;

  late Future<List<ChildModel>> _childrenFuture;

  @override
  void initState() {
    super.initState();
    _childrenFuture = fetchChildren();
  }

  @override
  void didUpdateWidget(covariant ParentHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.parentUsername.trim().toLowerCase() !=
        widget.parentUsername.trim().toLowerCase()) {
      _childrenFuture = fetchChildren();
    }
  }

  Future<void> _refreshPage() async {
    final newFuture = fetchChildren();

    if (!mounted) return;

    setState(() {
      _childrenFuture = newFuture;
    });

    try {
      await newFuture;
    } catch (_) {
      // سيعرض FutureBuilder رسالة الخطأ داخل الصفحة.
    }
  }

  String childAgeText(DateTime? birthDate) {
    if (birthDate == null) return 'غير محدد';

    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;

    if (now.day < birthDate.day) {
      months--;
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    if (years <= 0) return '$months شهر';
    if (months == 0) return '$years سنة';

    return '$years سنة و $months شهر';
  }

  Future<List<ChildModel>> fetchChildren() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cleanParentUsername = widget.parentUsername.trim().toLowerCase();

    QuerySnapshot<Map<String, dynamic>> snapshot;

    if (uid != null) {
      snapshot = await _firestore
          .collection('children')
          .where('parentUid', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final children = snapshot.docs.map((doc) {
          return ChildModel.fromMap(doc.data(), docId: doc.id);
        }).toList();

        children.sort((a, b) => a.name.compareTo(b.name));
        return children;
      }
    }

    snapshot = await _firestore
        .collection('children')
        .where('parentUsername', isEqualTo: cleanParentUsername)
        .where('isActive', isEqualTo: true)
        .get();

    final children = snapshot.docs.map((doc) {
      return ChildModel.fromMap(doc.data(), docId: doc.id);
    }).toList();

    children.sort((a, b) => a.name.compareTo(b.name));
    return children;
  }

  bool _isIncidentUpdate(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().trim().toLowerCase();
    final updateType =
        (data['updateType'] ?? '').toString().trim().toLowerCase();
    final category =
        (data['category'] ?? '').toString().trim().toLowerCase();

    return type == 'incident' ||
        type == 'incident_report' ||
        type == 'accident' ||
        type == 'accident_report' ||
        updateType == 'incident' ||
        updateType == 'incident_report' ||
        category == 'incident' ||
        category == 'incident_report';
  }

  Future<List<Map<String, dynamic>>> fetchLastUpdates(String childId) async {
    final snapshot = await _firestore
        .collection('updates')
        .where('childId', isEqualTo: childId)
        .get();

    final items = snapshot.docs.where((doc) {
      return !_isIncidentUpdate(doc.data());
    }).map((doc) {
      final data = doc.data();

      final isGroupUpdate =
          data['isGroupUpdate'] == true ||
          data['source'] == 'group_update' ||
          data['type'] == 'group_update' ||
          data['updateSource'] == 'group_update' ||
          data['groupUpdateId'] != null;

      return {
        'id': doc.id,
        'type': data['type'] ?? '',
        'note': data['note'] ??
            data['description'] ??
            data['body'] ??
            data['message'] ??
            '',
        'time': data['time'],
        'createdAt': data['createdAt'],
        'eventAt': data['eventAt'],
        'updatedAt': data['updatedAt'],
        'isGroupUpdate': isGroupUpdate,
        'groupUpdateId': data['groupUpdateId'],
        'groupId': data['groupId'],
        'groupName': data['groupName'],
        'updateScope': data['updateScope'] ?? data['scope'] ?? '',
      };
    }).toList();

    items.sort((a, b) {
      final aTime = (a['eventAt'] as Timestamp?) ??
          (a['time'] as Timestamp?) ??
          (a['createdAt'] as Timestamp?) ??
          (a['updatedAt'] as Timestamp?);

      final bTime = (b['eventAt'] as Timestamp?) ??
          (b['time'] as Timestamp?) ??
          (b['createdAt'] as Timestamp?) ??
          (b['updatedAt'] as Timestamp?);

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return items.take(60).toList();
  }

  String firstLetter(String name) {
    if (name.trim().isEmpty) return 'ط';
    return name.trim().substring(0, 1);
  }

  String get _pageTitle {
    switch (selectedIndex) {
      case 0:
        return 'الرئيسية';
      case 1:
        return 'المتابعة';
      case 2:
        return 'الرسائل';
      case 3:
        return 'الإعدادات';
      default:
        return 'الرئيسية';
    }
  }

  Future<void> _openChildProfile(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChildProfilePage(child: child)),
    );

    if (!mounted) return;
    await _refreshPage();
  }

  Future<void> _openUpdates(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ParentUpdatesPage(child: child)),
    );

    if (!mounted) return;
    await _refreshPage();
  }

  Future<void> _openAddChildRequest() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddChildRequestPage()),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب إضافة الطفل بنجاح')),
      );
    }

    if (!mounted) return;
    await _refreshPage();
  }

  Future<void> _openInvoices() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentInvoicesPage(
          parentUsername: widget.parentUsername,
        ),
      ),
    );

    if (!mounted) return;
    await _refreshPage();
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentNotificationsPage(
          parentUsername: widget.parentUsername,
        ),
      ),
    );

    if (!mounted) return;
    await _refreshPage();
  }

  Future<void> _openConsultations() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentConsultationsPage(
          parentUsername: widget.parentUsername,
        ),
      ),
    );

    if (!mounted) return;
    await _refreshPage();
  }


  Future<ChildModel?> _chooseChildForLiveStream(
  List<ChildModel> children,
) async {
  if (children.isEmpty) return null;

  if (children.length == 1) {
    return children.first;
  }

  return showDialog<ChildModel>(
    context: context,
    builder: (_) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر الطفل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: children.map((child) {
              return ListTile(
                leading: const Icon(Icons.child_care_rounded),
                title: Text(child.name),
                onTap: () => Navigator.pop(context, child),
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

Future<void> _requestLiveStreamForChildren(
  List<ChildModel> children,
) async {
  if (children.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لا يوجد أطفال مرتبطون بهذا الحساب'),
      ),
    );
    return;
  }

  final child = await _chooseChildForLiveStream(children);

  if (child == null) return;

  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('يجب تسجيل الدخول أولًا'),
      ),
    );
    return;
  }

  try {
    final result = await _liveStreamService.requestLiveStreamForChild(
        childId: child.id,
        childName: child.name,
        parentUid: currentUser.uid,
        parentUsername: widget.parentUsername,
        parentName: '',
        section: 'Nursery',
        group: child.groupName,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveStreamViewerPage(
            roomId: LiveStreamService.nurseryMainStreamId,
            title: 'بث مباشر من الحضانة',
            startedByName: 'الحضانة',
            liveStreamRequestId: result.requestId,
          ),
        ),
      );
  } catch (e) {
    if (!mounted) return;

    final errorText = e.toString();

    final message = errorText.contains('permission-denied') ||
            errorText.contains('permission_denied') ||
            errorText.contains('missing or insufficient permissions')
        ? 'لا توجد صلاحية لاستخدام البث المباشر.'
        : errorText.replaceFirst('Exception: ', '');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

  Future<void> _openComplaints() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentComplaintsPage(
          parentUsername: widget.parentUsername,
        ),
      ),
    );

    if (!mounted) return;
    await _refreshPage();
  }

  Future<void> _logout() async {
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

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  List<Widget> _buildPageActions() {
    return [
      IconButton(
        icon: const Icon(Icons.refresh_rounded),
        tooltip: 'تحديث الصفحة',
        onPressed: _refreshPage,
      ),
      if (selectedIndex == 0)
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'الإشعارات',
          onPressed: _openNotifications,
        ),
    ];
  }

  Widget _buildBody(List<ChildModel> children) {
    switch (selectedIndex) {
      case 0:
        return _buildDashboardTab(children);
      case 1:
        return _buildFollowUpTab(children);
      case 2:
        return _buildMessagesTab(children);
      case 3:
        return _buildSettingsTab();
      default:
        return _buildDashboardTab(children);
    }
  }

  Widget _buildDashboardTab(List<ChildModel> children) {
    return RefreshIndicator(
      onRefresh: _refreshPage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _WelcomeHeader(),
          const SizedBox(height: 16),
          _SummaryCard(
            totalChildren: children.length,
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            title: children.length == 1 ? 'لمحة عن طفلك' : 'لمحة عن أطفالك',
            icon: Icons.child_care_rounded,
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            const _EmptyStateBox(
              icon: Icons.child_care,
              title: 'لا يوجد أطفال مرتبطون بهذا الحساب',
              subtitle: 'يمكنك إرسال طلب إضافة طفل.',
            )
          else
            ...children.take(2).map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ChildPreviewCard(
                      childModel: child,
                      ageText: childAgeText(child.birthDate),
                      letter: firstLetter(child.name),
                      onOpenProfile: () => _openChildProfile(child),
                    ),
                  ),
                ),
          if (children.length > 2) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  selectedIndex = 1;
                });
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('عرض جميع الأطفال في قسم المتابعة'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const _SectionTitle(
            title: 'إجراءات',
            icon: Icons.flash_on_rounded,
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _QuickActionCard(
                icon: Icons.wifi_tethering_rounded,
                title: 'البث المباشر',
                subtitle: '',
                onTap: () => _requestLiveStreamForChildren(children),
              ),
              _QuickActionCard(
                icon: Icons.person_add_alt_1_rounded,
                title: 'طلب إضافة طفل',
                subtitle: '',
                onTap: _openAddChildRequest,
              ),
              _QuickActionCard(
                icon: Icons.receipt_long_rounded,
                title: 'الفواتير',
                subtitle: '',
                onTap: _openInvoices,
              ),
              _QuickActionCard(
                icon: Icons.report_problem_outlined,
                title: 'الشكاوى',
                subtitle: '',
                onTap: _openComplaints,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFollowUpTab(List<ChildModel> children) {
    return RefreshIndicator(
      onRefresh: _refreshPage,
      child: children.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                _EmptyStateBox(
                  icon: Icons.child_care,
                  title: 'لا يوجد أطفال للمتابعة حالياً',
                  subtitle: 'ستظهر المتابعة هنا.',
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _SectionTitle(
                  title: children.length == 1 ? 'طفلك' : 'أطفالك',
                  icon: Icons.groups_2_rounded,
                ),
                const SizedBox(height: 12),
                ...children.map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ChildFollowUpCard(
                      childModel: child,
                      ageText: childAgeText(child.birthDate),
                      letter: firstLetter(child.name),
                      onOpenProfile: () => _openChildProfile(child),
                      onOpenUpdates: () => _openUpdates(child),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _SectionTitle(
                  title: 'التحديثات',
                  icon: Icons.calendar_month_rounded,
                ),
                const SizedBox(height: 12),
                _AllChildrenUpdatesList(
                  children: children,
                  fetchUpdates: fetchLastUpdates,
                ),
              ],
            ),
    );
  }

  Widget _buildMessagesTab(List<ChildModel> children) {
    if (children.isEmpty) {
      return const _EmptyStateBox(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'لا توجد محادثات',
        subtitle: '',
      );
    }

    return ParentChatsPage(
      key: const ValueKey('parent_chats_tab'),
      children: children,
    );
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
                  : 'وليّ الأمر';

              final subtitle = data == null
                  ? widget.parentUsername.trim().toLowerCase()
                  : data.username.isNotEmpty
                      ? data.username
                      : widget.parentUsername.trim().toLowerCase();

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                  child: Text(
                    displayName.trim().isNotEmpty ? displayName.trim()[0] : 'و',
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
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
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
                  await _refreshPage();
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.psychology_alt_rounded,
                    color: Colors.deepPurple,
                  ),
                ),
                title: const Text('الاستشارات'),
                onTap: _openConsultations,
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.withValues(alpha: 0.12),
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
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.red,
                  ),
                ),
                title: const Text('مركز الدعم'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ParentSupportCenterPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
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
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChildModel>>(
      future: _childrenFuture,
      builder: (context, snapshot) {
        final children = snapshot.data ?? <ChildModel>[];
        Widget child;

        if (snapshot.connectionState == ConnectionState.waiting) {
          child = const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          child = Center(
            child: Text(
              'حدث خطأ أثناء تحميل البيانات: ${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        } else {
          child = _buildBody(children);
        }

        return Scaffold(
          body: AppPageScaffold(
            title: _pageTitle,
            actions: _buildPageActions(),
            child: child,
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
}

class _WelcomeHeader extends StatelessWidget {
  String greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 18) return 'مساء الخير';
    return 'أهلًا بك';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greetingText(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يسعدنا متابعتك لأطفالك بكل سهولة واطمئنان',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalChildren;

  const _SummaryCard({
    required this.totalChildren,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _MiniStatItem(
          title: 'إجمالي الأطفال',
          value: '$totalChildren',
          icon: Icons.child_friendly,
        ),
      ),
    );
  }
}

class _MiniStatItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniStatItem({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textLight,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
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

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildPreviewCard extends StatelessWidget {
  final ChildModel childModel;
  final String ageText;
  final String letter;
  final VoidCallback onOpenProfile;

  const _ChildPreviewCard({
    required this.childModel,
    required this.ageText,
    required this.letter,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpenProfile,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 16.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'العمر: $ageText',
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildFollowUpCard extends StatelessWidget {
  final ChildModel childModel;
  final String ageText;
  final String letter;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenUpdates;

  const _ChildFollowUpCard({
    required this.childModel,
    required this.ageText,
    required this.letter,
    required this.onOpenProfile,
    required this.onOpenUpdates,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    letter,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'العمر: $ageText',
                        style: const TextStyle(
                          color: AppColors.textLight,
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
                  child: ElevatedButton.icon(
                    onPressed: onOpenProfile,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('ملف الطفل'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenUpdates,
                    icon: const Icon(Icons.notifications_none_outlined),
                    label: const Text('التحديثات'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
}

class _AllChildrenUpdatesList extends StatelessWidget {
  final List<ChildModel> children;
  final Future<List<Map<String, dynamic>>> Function(String childId) fetchUpdates;

  const _AllChildrenUpdatesList({
    required this.children,
    required this.fetchUpdates,
  });

  Future<List<Map<String, dynamic>>> _loadAllUpdates() async {
    final allUpdates = <Map<String, dynamic>>[];

    for (final child in children) {
      final updates = await fetchUpdates(child.id);

      for (final update in updates) {
        allUpdates.add({
          ...update,
          'childName': child.name,
        });
      }
    }

    allUpdates.sort((a, b) {
      final aDate = _dateFromDynamic(
        a['eventAt'] ?? a['time'] ?? a['createdAt'] ?? a['updatedAt'],
      );
      final bDate = _dateFromDynamic(
        b['eventAt'] ?? b['time'] ?? b['createdAt'] ?? b['updatedAt'],
      );

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return allUpdates;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadAllUpdates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final updates = snapshot.data ?? [];

        if (updates.isEmpty) {
          return const _EmptyStateBox(
            icon: Icons.notifications_none_outlined,
            title: 'لا توجد تحديثات',
            subtitle: '',
          );
        }

        final grouped = <String, List<Map<String, dynamic>>>{};

        for (final update in updates) {
          final date = _dateFromDynamic(
            update['eventAt'] ??
                update['time'] ??
                update['createdAt'] ??
                update['updatedAt'],
          );

          final key = _dateKey(date);
          grouped.putIfAbsent(key, () => []).add(update);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: grouped.entries.map((entry) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...entry.value.map(_buildUpdateLine),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _dateKey(DateTime? date) {
    if (date == null) return 'بدون تاريخ';

    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }

  static String _updateText(Map<String, dynamic> update) {
    final type = (update['type'] ?? '').toString().trim();
    final note = (update['note'] ?? '').toString().trim();
    final cleanType = type == 'group_update' ? 'تحديث' : type;

    if (note.isEmpty) return cleanType.isEmpty ? 'تحديث جديد' : cleanType;
    return '${cleanType.isEmpty ? 'تحديث' : cleanType}: $note';
  }

  static Widget _buildUpdateLine(Map<String, dynamic> update) {
    final rawTime = update['eventAt'] ??
        update['time'] ??
        update['createdAt'] ??
        update['updatedAt'];

    final childName = (update['childName'] ?? '').toString().trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _timeText(rawTime),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (childName.isNotEmpty)
                  Text(
                    childName,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  _updateText(update),
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _timeText(dynamic rawTime) {
    if (rawTime is Timestamp) {
      final t = rawTime.toDate();
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    return '--:--';
  }
}

class _EmptyStateBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyStateBox({
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
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (subtitle.trim().isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
