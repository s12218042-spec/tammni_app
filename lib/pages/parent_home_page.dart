import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../services/account_settings_service.dart';
import '../services/auth_service.dart';
import '../services/live_stream_service.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'account_history_page.dart';
import 'account_settings_page.dart';
import 'add_child_request_page.dart';
import 'child_profile_page.dart';
import 'live_stream_viewer_page.dart';
import 'parent_chats_page.dart';
import 'parent_complaints_page.dart';
import 'parent_invoice_page.dart';
import 'parent_notifications_page.dart';
import 'parent_updates_page.dart';
import 'welcome_page.dart';

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
  final MessageService _messageService = MessageService();
  final LiveStreamService _liveStreamService = LiveStreamService();
  final AccountSettingsService _accountSettingsService =
      AccountSettingsService();

  final Set<String> _liveStreamRequestingChildIds = {};

  int selectedIndex = 0;
  bool isArabic = true;
  bool isDarkMode = false;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _refreshPage() async {
    if (!mounted) return;
    setState(() {});
  }

  String sectionLabel(String section) {
    return 'حضانة';
  }

  Color sectionColor(String section) {
    return const Color(0xFFEFA7C8);
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

  Future<List<Map<String, dynamic>>> fetchLastUpdates(String childId) async {
    final snapshot = await _firestore
        .collection('updates')
        .where('childId', isEqualTo: childId)
        .get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'type': data['type'] ?? '',
        'note': data['note'] ?? '',
        'time': data['time'],
        'createdAt': data['createdAt'],
      };
    }).toList();

    items.sort((a, b) {
      final aTime = (a['time'] as Timestamp?) ?? (a['createdAt'] as Timestamp?);
      final bTime = (b['time'] as Timestamp?) ?? (b['createdAt'] as Timestamp?);

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return items.take(2).toList();
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
    setState(() {});
  }

  Future<void> _openUpdates(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ParentUpdatesPage(child: child)),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openChats(List<ChildModel> children) async {
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا توجد محادثات متاحة لأنه لا يوجد أطفال مرتبطون بهذا الحساب',
          ),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentChatsPage(children: children),
      ),
    );

    if (!mounted) return;
    setState(() {});
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
    setState(() {});
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
    setState(() {});
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
    setState(() {});
  }

  Future<void> _openLiveStream(Map<String, dynamic> streamData) async {
    final roomId = (streamData['roomId'] ?? '').toString();
    final title = (streamData['title'] ?? 'بث مباشر من الحضانة').toString();
    final startedByName = (streamData['startedByName'] ?? '').toString();

    if (roomId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات البث غير مكتملة')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveStreamViewerPage(
          roomId: roomId,
          title: title,
          startedByName: startedByName,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _cancelLiveStreamRequest(String requestId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولًا')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء طلب البث'),
          content: const Text(
            'هل تريدين إلغاء طلب البث المباشر؟',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إلغاء الطلب'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await _liveStreamService.cancelLiveStreamRequest(
        requestId: requestId,
        cancelledByUid: uid,
        cancelledByRole: 'parent',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء طلب البث المباشر')),
      );

      setState(() {});
    } catch (e) {
      debugPrint('Cancel live stream request error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('permission-denied')
                ? 'لا توجد صلاحية لإلغاء هذا الطلب'
                : 'حدث خطأ أثناء إلغاء الطلب',
          ),
        ),
      );
    }
  }

  Future<void> _requestLiveStreamForChild(ChildModel child) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cleanUsername = widget.parentUsername.trim().toLowerCase();

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولًا')),
      );
      return;
    }

    if (_liveStreamRequestingChildIds.contains(child.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري إرسال الطلب، يرجى الانتظار')),
      );
      return;
    }

    setState(() {
      _liveStreamRequestingChildIds.add(child.id);
    });

    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('طلب بث مباشر'),
            content: Text(
              'هل تريدين إرسال طلب بث مباشر لمشاهدة ${child.name}؟\n\n'
              'سيتم إرسال الطلب للإدارة، ويمكنك إلغاؤه طالما لم يبدأ البث.',
              style: const TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.wifi_tethering_rounded),
                label: const Text('إرسال الطلب'),
              ),
            ],
          ),
        ),
      );

      if (confirm != true) return;

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? <String, dynamic>{};

      final parentName = (userData['displayName'] ??
              userData['name'] ??
              userData['fullName'] ??
              userData['username'] ??
              'ولي الأمر')
          .toString()
          .trim();

      final result = await _liveStreamService.requestLiveStreamForChild(
        childId: child.id,
        childName: child.name,
        parentUid: uid,
        parentUsername: cleanUsername,
        parentName: parentName,
        section: child.section.trim().isEmpty ? 'Nursery' : child.section,
        group: child.group,
      );

      if (!mounted) return;

      String message;

      if (result.status == 'queued') {
        message =
            'تم وضعك ضمن قائمة انتظار لحين انتهاء البث الجاري. رقمك في الانتظار: ${result.queuePosition}';
      } else if (result.status == 'approved') {
        message = 'تمت الموافقة على طلب البث، يرجى متابعة الإشعارات.';
      } else if (result.status == 'active') {
        message = 'يوجد بث مباشر نشط لهذا الطلب، يرجى متابعة الإشعارات.';
      } else {
        message = 'تم إرسال طلب البث المباشر للإدارة';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      setState(() {});
    } catch (e) {
      debugPrint('Parent request live stream error: $e');

      if (!mounted) return;

      final errorText = e.toString();

      String message;

      if (errorText.contains('permission-denied')) {
        message =
            'لا توجد صلاحية لإرسال طلب البث. تأكدي من Firestore Rules أو من عدم وجود استعلام عام على live_streams.';
      } else if (errorText.contains('يوجد طلب بث مباشر نشط')) {
        message = 'يوجد طلب بث مباشر نشط لهذا الطفل بالفعل';
      } else {
        message = errorText.replaceFirst(
          'Exception: ',
          'حدث خطأ أثناء إرسال طلب البث: ',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _liveStreamRequestingChildIds.remove(child.id);
        });
      }
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

  Widget _buildBody(List<ChildModel> children) {
    switch (selectedIndex) {
      case 0:
        return _buildDashboardTab(children);
      case 1:
        return _buildFollowUpTab(children);
      case 2:
        return _buildMessagesTab(children);
      case 3:
        return _buildSettingsTab(children);
      default:
        return _buildDashboardTab(children);
    }
  }

  Widget _buildDashboardTab(List<ChildModel> children) {
    final nurseryChildren = children.length;

    return RefreshIndicator(
      onRefresh: _refreshPage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _WelcomeHeader(
            parentUsername: widget.parentUsername.trim().toLowerCase(),
          ),
          const SizedBox(height: 16),
          _ParentLiveStreamSection(
            parentUid: currentUserId ?? '',
            parentUsername: widget.parentUsername.trim().toLowerCase(),
            onOpenLiveStream: _openLiveStream,
          ),
          const SizedBox(height: 16),
          _SummaryCard(
            totalChildren: children.length,
            nurseryCount: nurseryChildren,
          ),
          const SizedBox(height: 20),
          const _SectionTitle(
            title: 'إجراءات سريعة',
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
                icon: Icons.person_add_alt_1_rounded,
                title: 'طلب إضافة طفل',
                subtitle: 'إرسال طلب جديد',
                onTap: _openAddChildRequest,
              ),
              _QuickActionCard(
                icon: Icons.receipt_long_rounded,
                title: 'الفواتير',
                subtitle: 'عرض الفواتير',
                onTap: _openInvoices,
              ),
              _QuickActionCard(
                icon: Icons.notifications_none_rounded,
                title: 'الإشعارات',
                subtitle: 'متابعة التنبيهات',
                onTap: _openNotifications,
              ),
              _QuickActionCard(
                icon: Icons.report_problem_outlined,
                title: 'الشكاوى',
                subtitle: 'إرسال شكوى أو ملاحظة',
                onTap: _openComplaints,
              ),
              _QuickActionCard(
                icon: Icons.send_outlined,
                title: 'الرسائل',
                subtitle: 'فتح المحادثات',
                onTap: () => _openChats(children),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle(
            title: 'لمحة سريعة عن الأطفال',
            icon: Icons.child_care_rounded,
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            const _EmptyStateBox(
              icon: Icons.child_care,
              title: 'لا يوجد أطفال مرتبطون بهذا الحساب',
              subtitle:
                  'يمكنك مراجعة الإدارة أو إرسال طلب إضافة طفل جديد لربطه بحساب ولي الأمر.',
            )
          else
            ...children.take(2).map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ChildPreviewCard(
                      childModel: child,
                      sectionText: sectionLabel(child.section),
                      sectionBadgeColor: sectionColor(child.section),
                      ageText: childAgeText(child.birthDate),
                      letter: firstLetter(child.name),
                      parentUid: currentUserId ?? '',
                      isSendingLiveStreamRequest:
                          _liveStreamRequestingChildIds.contains(child.id),
                      onOpenProfile: () => _openChildProfile(child),
                      onRequestLiveStream: () =>
                          _requestLiveStreamForChild(child),
                      onCancelLiveStreamRequest: _cancelLiveStreamRequest,
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
                  subtitle:
                      'عند ربط طفل بالحساب ستظهر هنا جميع عناصر المتابعة الخاصة به.',
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const _SectionTitle(
                  title: 'أطفالي',
                  icon: Icons.groups_2_rounded,
                ),
                const SizedBox(height: 12),
                ...children.map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ChildFollowUpCard(
                      childModel: child,
                      sectionText: sectionLabel(child.section),
                      sectionBadgeColor: sectionColor(child.section),
                      ageText: childAgeText(child.birthDate),
                      letter: firstLetter(child.name),
                      updatesFuture: fetchLastUpdates(child.id),
                      parentUid: currentUserId ?? '',
                      isSendingLiveStreamRequest:
                          _liveStreamRequestingChildIds.contains(child.id),
                      onOpenProfile: () => _openChildProfile(child),
                      onOpenUpdates: () => _openUpdates(child),
                      onRequestLiveStream: () =>
                          _requestLiveStreamForChild(child),
                      onCancelLiveStreamRequest: _cancelLiveStreamRequest,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessagesTab(List<ChildModel> children) {
    return RefreshIndicator(
      onRefresh: _refreshPage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const _SectionTitle(
            title: 'المحادثات',
            icon: Icons.chat_bubble_outline_rounded,
          ),
          const SizedBox(height: 12),
          StreamBuilder<int>(
            stream: currentUserId == null
                ? null
                : _messageService.getUnreadMessagesCountForUser(
                    currentUserId: currentUserId!,
                  ),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: const Icon(
                          Icons.send_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'رسائل وليّ الأمر',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        unreadCount > 0
                            ? 'لديك $unreadCount رسالة غير مقروءة'
                            : 'لا توجد رسائل غير مقروءة حالياً',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openChats(children),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('فتح المحادثات'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const _InfoMessageBox(
            icon: Icons.info_outline_rounded,
            title: 'تنظيم الرسائل',
            message:
                'من هنا يمكنكِ الوصول إلى محادثاتك مع الإدارة أو كادر الحضانة المرتبط بأطفالك.',
          ),
        ],
      ),
    );
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
                  : 'وليّ الأمر';

              final subtitle = data == null
                  ? widget.parentUsername.trim().toLowerCase()
                  : '${data.roleLabel} • ${data.username.isNotEmpty ? data.username : widget.parentUsername.trim().toLowerCase()}';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.10),
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
                subtitle:
                    const Text('تعديل الاسم، كلمة المرور، وإدارة الحساب'),
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
                  child: const Icon(
                    Icons.language_rounded,
                    color: Colors.blue,
                  ),
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
                subtitle: const Text('عرض إشعارات وليّ الأمر'),
                onTap: _openNotifications,
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
                subtitle: const Text('عرض تغييرات الحساب والنشاطات الأخيرة'),
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
                  backgroundColor: Colors.indigo.withOpacity(0.12),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.indigo,
                  ),
                ),
                title: const Text('الفواتير'),
                subtitle: const Text('عرض الفواتير المرتبطة بالحساب'),
                onTap: _openInvoices,
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text('طلب إضافة طفل'),
                subtitle: const Text('إرسال طلب جديد للإدارة'),
                onTap: _openAddChildRequest,
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.withOpacity(0.12),
                  child: const Icon(
                    Icons.report_problem_outlined,
                    color: Colors.red,
                  ),
                ),
                title: const Text('الشكاوى والملاحظات'),
                subtitle: const Text('إرسال شكوى أو متابعة رد الإدارة'),
                onTap: _openComplaints,
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey.withOpacity(0.12),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.blueGrey,
                  ),
                ),
                title: const Text('الرسائل'),
                subtitle: const Text('فتح محادثات وليّ الأمر'),
                onTap: () => _openChats(children),
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
                onTap: _openComplaints,
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
      future: fetchChildren(),
      builder: (context, snapshot) {
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
          final children = snapshot.data ?? [];
          child = _buildBody(children);
        }

        return Scaffold(
          body: AppPageScaffold(
            title: _pageTitle,
            actions: selectedIndex == 0
                ? [
                    IconButton(
                      icon: const Icon(Icons.history_rounded),
                      tooltip: 'تحديث الصفحة',
                      onPressed: _refreshPage,
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded),
                      tooltip: 'الإشعارات',
                      onPressed: _openNotifications,
                    ),
                  ]
                : selectedIndex == 2
                    ? [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'تحديث الصفحة',
                          onPressed: _refreshPage,
                        ),
                      ]
                    : selectedIndex == 3
                        ? [
                            IconButton(
                              icon:
                                  const Icon(Icons.notifications_none_rounded),
                              tooltip: 'الإشعارات',
                              onPressed: _openNotifications,
                            ),
                          ]
                        : [
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded),
                              tooltip: 'تحديث الصفحة',
                              onPressed: _refreshPage,
                            ),
                          ],
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
  final String parentUsername;

  const _WelcomeHeader({required this.parentUsername});

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
              color: Colors.white.withOpacity(0.95),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'اسم المستخدم: $parentUsername',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalChildren;
  final int nurseryCount;

  const _SummaryCard({
    required this.totalChildren,
    required this.nurseryCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _MiniStatItem(
                title: 'إجمالي الأطفال',
                value: '$totalChildren',
                icon: Icons.child_friendly,
              ),
            ),
            Expanded(
              child: _MiniStatItem(
                title: 'الحضانة',
                value: '$nurseryCount',
                icon: Icons.baby_changing_station,
              ),
            ),
          ],
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
          backgroundColor: AppColors.primary.withOpacity(0.12),
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
                backgroundColor: AppColors.primary.withOpacity(0.10),
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
  final String sectionText;
  final Color sectionBadgeColor;
  final String ageText;
  final String letter;
  final String parentUid;
  final bool isSendingLiveStreamRequest;
  final VoidCallback onOpenProfile;
  final VoidCallback onRequestLiveStream;
  final Future<void> Function(String requestId) onCancelLiveStreamRequest;

  const _ChildPreviewCard({
    required this.childModel,
    required this.sectionText,
    required this.sectionBadgeColor,
    required this.ageText,
    required this.letter,
    required this.parentUid,
    required this.isSendingLiveStreamRequest,
    required this.onOpenProfile,
    required this.onRequestLiveStream,
    required this.onCancelLiveStreamRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: sectionBadgeColor.withOpacity(0.18),
              child: Text(
                letter,
                style: TextStyle(
                  color: sectionBadgeColor,
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
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: sectionBadgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    sectionText,
                    style: TextStyle(
                      color: sectionBadgeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onOpenProfile,
                  child: const Text('فتح'),
                ),
                _LiveStreamRequestAction(
                  parentUid: parentUid,
                  childId: childModel.id,
                  isSending: isSendingLiveStreamRequest,
                  compact: true,
                  onRequest: onRequestLiveStream,
                  onCancel: onCancelLiveStreamRequest,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildFollowUpCard extends StatelessWidget {
  final ChildModel childModel;
  final String sectionText;
  final Color sectionBadgeColor;
  final String ageText;
  final String letter;
  final Future<List<Map<String, dynamic>>> updatesFuture;
  final String parentUid;
  final bool isSendingLiveStreamRequest;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenUpdates;
  final VoidCallback onRequestLiveStream;
  final Future<void> Function(String requestId) onCancelLiveStreamRequest;

  const _ChildFollowUpCard({
    required this.childModel,
    required this.sectionText,
    required this.sectionBadgeColor,
    required this.ageText,
    required this.letter,
    required this.updatesFuture,
    required this.parentUid,
    required this.isSendingLiveStreamRequest,
    required this.onOpenProfile,
    required this.onOpenUpdates,
    required this.onRequestLiveStream,
    required this.onCancelLiveStreamRequest,
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
                  backgroundColor: sectionBadgeColor.withOpacity(0.18),
                  child: Text(
                    letter,
                    style: TextStyle(
                      color: sectionBadgeColor,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: sectionBadgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    sectionText,
                    style: TextStyle(
                      color: sectionBadgeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'آخر التحديثات',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: updatesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }

                final updates = snapshot.data ?? [];

                if (updates.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'لا يوجد تحديثات بعد',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  );
                }

                final latest = updates.first;
                final latestType = (latest['type'] ?? '').toString().trim();
                final latestNote = (latest['note'] ?? '').toString().trim();
                final latestText = latestNote.isEmpty
                    ? (latestType.isEmpty ? 'تحديث جديد' : latestType)
                    : '${latestType.isEmpty ? 'تحديث' : latestType}: $latestNote';

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _timeText(latest['time'] ?? latest['createdAt']),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          latestText,
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
            const SizedBox(height: 10),
            _LiveStreamRequestAction(
              parentUid: parentUid,
              childId: childModel.id,
              isSending: isSendingLiveStreamRequest,
              compact: false,
              onRequest: onRequestLiveStream,
              onCancel: onCancelLiveStreamRequest,
            ),
          ],
        ),
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
              backgroundColor: AppColors.primary.withOpacity(0.12),
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

class _InfoMessageBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoMessageBox({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
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
      ),
    );
  }
}

class _LiveStreamRequestAction extends StatelessWidget {
  final String parentUid;
  final String childId;
  final bool isSending;
  final bool compact;
  final VoidCallback onRequest;
  final Future<void> Function(String requestId) onCancel;

  const _LiveStreamRequestAction({
    required this.parentUid,
    required this.childId,
    required this.isSending,
    required this.compact,
    required this.onRequest,
    required this.onCancel,
  });

  bool _isOpenStatus(String status) {
    final clean = status.trim().toLowerCase();
    return clean == 'pending' ||
        clean == 'queued' ||
        clean == 'waiting' ||
        clean == 'approved' ||
        clean == 'active';
  }

  String _statusText(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return 'طلبك قيد المراجعة';
      case 'queued':
      case 'waiting':
        return 'طلبك ضمن الانتظار';
      case 'approved':
        return 'تمت الموافقة على الطلب';
      case 'active':
        return 'البث نشط الآن';
      default:
        return 'طلب بث قائم';
    }
  }

  bool _canCancel(String status) {
    final clean = status.trim().toLowerCase();
    return clean == 'pending' || clean == 'queued' || clean == 'waiting';
  }

  @override
  Widget build(BuildContext context) {
    final cleanParentUid = parentUid.trim();
    final cleanChildId = childId.trim();

    if (cleanParentUid.isEmpty || cleanChildId.isEmpty) {
      return _buildRequestButton();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('live_stream_requests')
          .where('parentUid', isEqualTo: cleanParentUid)
          .where('childId', isEqualTo: cleanChildId)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        QueryDocumentSnapshot<Map<String, dynamic>>? openDoc;

        for (final doc in docs) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString();

          if (_isOpenStatus(status)) {
            openDoc = doc;
            break;
          }
        }

        if (openDoc == null) {
          return _buildRequestButton();
        }

        final data = openDoc.data();
        final status = (data['status'] ?? 'pending').toString();
        final canCancel = _canCancel(status);

        if (compact) {
          return Column(
            children: [
              Text(
                _statusText(status),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (canCancel)
                TextButton.icon(
                  onPressed: () => onCancel(openDoc!.id),
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text('إلغاء'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                ),
            ],
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusText(status),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              if (canCancel) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => onCancel(openDoc!.id),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('إلغاء الطلب'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(
                        color: Colors.redAccent.withOpacity(0.35),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestButton() {
    if (compact) {
      return TextButton.icon(
        onPressed: isSending ? null : onRequest,
        icon: isSending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.wifi_tethering_rounded, size: 18),
        label: Text(isSending ? 'جاري الإرسال' : 'طلب بث'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.red,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isSending ? null : onRequest,
        icon: isSending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.wifi_tethering_rounded),
        label: Text(isSending ? 'جاري إرسال الطلب...' : 'طلب بث مباشر للطفل'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: BorderSide(color: Colors.red.withOpacity(0.35)),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _ParentLiveStreamSection extends StatelessWidget {
  final String parentUid;
  final String parentUsername;
  final Future<void> Function(Map<String, dynamic> streamData) onOpenLiveStream;

  const _ParentLiveStreamSection({
    required this.parentUid,
    required this.parentUsername,
    required this.onOpenLiveStream,
  });

  @override
  Widget build(BuildContext context) {
    final cleanParentUid = parentUid.trim();

    if (cleanParentUid.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('live_streams')
          .where('status', isEqualTo: 'active')
          .where('targetParentUid', isEqualTo: cleanParentUid)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Parent live stream query error: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final doc = docs.first;
        final data = {
          ...doc.data(),
          'id': doc.id,
          'streamId': doc.id,
        };

        final title = (data['title'] ?? 'بث مباشر من الحضانة').toString();
        final startedByName = (data['startedByName'] ?? '').toString();
        final startedByRole = (data['startedByRole'] ?? '').toString();
        final photoUrl = (data['startedByPhotoUrl'] ?? '').toString();
        final childName = (data['childName'] ?? '').toString().trim();

        return Card(
          elevation: 0,
          color: Colors.red.withOpacity(0.045),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: Colors.red.withOpacity(0.22),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => onOpenLiveStream(data),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.red,
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 31,
                          backgroundColor: Colors.red.withOpacity(0.12),
                          backgroundImage: photoUrl.trim().isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl.trim().isEmpty
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: Colors.red,
                                  size: 32,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: -4,
                        left: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.wifi_tethering_rounded,
                              color: Colors.red,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'بث مباشر الآن',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title.trim().isEmpty
                              ? 'بث مباشر من الحضانة'
                              : title,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        if (childName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'خاص بالطفل: $childName',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          startedByName.trim().isEmpty
                              ? 'اضغطي لمشاهدة البث'
                              : 'بواسطة: $startedByName',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (startedByRole.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'الدور: $startedByRole',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.red,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}