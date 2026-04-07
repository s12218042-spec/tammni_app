import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../services/auth_service.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'add_update_page.dart';
import 'camera_checkin_page.dart';
import 'child_handoff_log_page.dart';
import 'incident_report_page.dart';
import 'nursery_care_log_page.dart';
import 'nursery_chats_page.dart';
import 'quick_care_update_page.dart';
import 'send_parent_notification_page.dart';
import 'welcome_page.dart';

class NurseryStaffHomePage extends StatefulWidget {
  const NurseryStaffHomePage({super.key});

  @override
  State<NurseryStaffHomePage> createState() => _NurseryStaffHomePageState();
}

class _NurseryStaffHomePageState extends State<NurseryStaffHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GalleryService _galleryService = GalleryService();

  int selectedIndex = 0;
  bool isArabic = true;
  bool isDarkMode = false;

  String searchQuery = '';
  String selectedStatusFilter = 'all'; // all / needUpdate / updatedToday

  String get _pageTitle {
    switch (selectedIndex) {
      case 0:
        return 'الرئيسية - موظفة الحضانة';
      case 1:
        return 'المتابعة';
      case 2:
        return 'الرسائل';
      case 3:
        return 'الإعدادات';
      default:
        return 'الرئيسية - موظفة الحضانة';
    }
  }

  Future<List<ChildModel>> fetchNurseryChildren() async {
    final snapshot = await _firestore
        .collection('children')
        .where('section', isEqualTo: 'Nursery')
        .where('isActive', isEqualTo: true)
        .get();

    final children = snapshot.docs.map((doc) {
      final data = doc.data();
      return ChildModel.fromMap(data, docId: doc.id);
    }).toList();

    children.sort((a, b) => a.name.compareTo(b.name));
    return children;
  }

  Future<ChildModel?> pickChild(List<ChildModel> children) async {
    return showModalBottomSheet<ChildModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String localSearch = '';
        String selectedGroup = 'all';

        final groups = {
          'all',
          ...children.map((c) => c.group.isEmpty ? 'بدون مجموعة' : c.group),
        };

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = children.where((child) {
              final matchesSearch = child.name.toLowerCase().contains(
                    localSearch.toLowerCase(),
                  );

              final groupName =
                  child.group.isEmpty ? 'بدون مجموعة' : child.group;

              final matchesGroup =
                  selectedGroup == 'all' || groupName == selectedGroup;

              return matchesSearch && matchesGroup;
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'اختاري الطفل',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'بحث باسم الطفل...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          localSearch = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: groups.map((group) {
                          final isSelected = group == selectedGroup;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(group),
                              selected: isSelected,
                              onSelected: (_) {
                                setModalState(() {
                                  selectedGroup = group;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('لا يوجد نتائج'),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final child = filtered[index];
                            final groupName = child.group.isEmpty
                                ? 'بدون مجموعة'
                                : child.group;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.15),
                                child: const Icon(Icons.child_care),
                              ),
                              title: Text(child.name),
                              subtitle: Text(groupName),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: () {
                                Navigator.pop(context, child);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> openChildHandoffLog(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChildHandoffLogPage(child: child)),
    );
    setState(() {});
  }

  Future<void> openIncidentReport(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IncidentReportPage(child: child)),
    );
    setState(() {});
  }

  Future<Map<String, dynamic>> fetchTodayStats(List<ChildModel> children) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final updatesSnapshot = await _firestore
        .collection('updates')
        .where('section', isEqualTo: 'Nursery')
        .get();

    final childIds = children.map((e) => e.id).toSet();

    int careUpdatesCount = 0;
    int mediaUpdatesCount = 0;
    int childrenUpdatedTodayCount = 0;

    final Set<String> updatedChildrenIds = {};

    for (final doc in updatesSnapshot.docs) {
      final data = doc.data();
      final childId = (data['childId'] ?? '').toString();
      if (!childIds.contains(childId)) continue;

      final Timestamp? ts = data['time'] is Timestamp
          ? data['time'] as Timestamp
          : data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : null;

      if (ts == null) continue;
      if (ts.toDate().isBefore(startOfDay)) continue;

      careUpdatesCount++;
      updatedChildrenIds.add(childId);

      if (data['hasMedia'] == true) {
        mediaUpdatesCount++;
      }
    }

    childrenUpdatedTodayCount = updatedChildrenIds.length;

    return {
      'childrenCount': children.length,
      'careUpdatesCount': careUpdatesCount,
      'mediaUpdatesCount': mediaUpdatesCount,
      'childrenUpdatedTodayCount': childrenUpdatedTodayCount,
    };
  }

  Future<Map<String, Map<String, dynamic>>> fetchTodayUpdatesSummary(
    List<ChildModel> children,
  ) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final childIds = children.map((e) => e.id).toSet();

    final updatesSnapshot = await _firestore
        .collection('updates')
        .where('section', isEqualTo: 'Nursery')
        .get();

    final Map<String, Map<String, dynamic>> latestUpdateByChild = {};

    for (final doc in updatesSnapshot.docs) {
      final data = doc.data();
      final childId = (data['childId'] ?? '').toString();

      if (!childIds.contains(childId)) continue;

      final Timestamp? ts = data['time'] is Timestamp
          ? data['time'] as Timestamp
          : data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : null;

      if (ts == null) continue;
      if (ts.toDate().isBefore(startOfDay)) continue;

      final old = latestUpdateByChild[childId];
      if (old == null) {
        latestUpdateByChild[childId] = {
          'type': (data['type'] ?? 'تحديث').toString(),
          'note': (data['note'] ?? '').toString(),
          'time': ts,
        };
      } else {
        final oldTs = old['time'] as Timestamp?;
        if (oldTs == null || ts.compareTo(oldTs) > 0) {
          latestUpdateByChild[childId] = {
            'type': (data['type'] ?? 'تحديث').toString(),
            'note': (data['note'] ?? '').toString(),
            'time': ts,
          };
        }
      }
    }

    return latestUpdateByChild;
  }

  Future<List<ChildModel>> getChildrenNeedingUpdate(
    List<ChildModel> children,
  ) async {
    final latestUpdateByChild = await fetchTodayUpdatesSummary(children);
    return children
        .where((child) => !latestUpdateByChild.containsKey(child.id))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchRecentNurseryActivities() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final updatesSnapshot = await _firestore
        .collection('updates')
        .where('section', isEqualTo: 'Nursery')
        .get();

    final List<Map<String, dynamic>> activities = [];

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
      final note = (data['note'] ?? '').toString();
      final createdByName = (data['createdByName'] ?? '').toString();

      activities.add({
        'time': ts,
        'title': type,
        'childName': childName,
        'subtitle': note.trim().isNotEmpty
            ? note
            : createdByName.trim().isNotEmpty
                ? 'بواسطة $createdByName'
                : 'تمت إضافة تحديث جديد',
        'color': AppColors.primary,
        'icon': data['hasMedia'] == true
            ? Icons.photo_camera_outlined
            : Icons.favorite_border_rounded,
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

    return activities.take(6).toList();
  }

  Future<List<Map<String, dynamic>>> fetchRecentSentNotifications() async {
    final snapshot = await _firestore
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(40)
        .get();

    final items = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final createdByRole = (data['createdByRole'] ?? '').toString().toLowerCase();
      final byRole = (data['byRole'] ?? '').toString().toLowerCase();

      final isNurseryNotification = createdByRole.contains('nursery') ||
          byRole.contains('nursery');

      if (!isNurseryNotification) continue;

      items.add({
        'title': (data['title'] ?? 'إشعار').toString(),
        'body': (data['body'] ?? data['message'] ?? '').toString(),
        'createdAt': data['createdAt'],
        'childName': (data['childName'] ?? '').toString(),
      });
    }

    return items;
  }

  Future<void> openAddUpdate(ChildModel child) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddUpdatePage(child: child, byRole: 'nursery'),
      ),
    );

    if (res == true) {
      setState(() {});
    }
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

      try {
        final mediaUrl = await _galleryService.uploadChildMedia(
          childId: child.id,
          localPath: path,
          mediaType: type,
        );

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
          'byRole': 'nursery',
          'mediaPath': path,
          'mediaType': type,
          'mediaUrl': mediaUrl,
          'hasMedia': true,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال التحديث بالكاميرا')),
        );
        setState(() {});
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء حفظ التحديث بالكاميرا: $e')),
        );
      }
    }
  }

  Future<void> openQuickCareUpdate(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuickCareUpdatePage(child: child)),
    );
    setState(() {});
  }

  Future<void> openCareLog(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NurseryCareLogPage(child: child)),
    );
    setState(() {});
  }

  Future<void> openSendNotification(List<ChildModel> children) async {
    final child = await pickChild(children);
    if (child == null) return;

    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendParentNotificationPage(child: child),
      ),
    );

    if (res == true) {
      setState(() {});
    }
  }

  Future<void> _openNotificationsPage(List<ChildModel> children) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NurseryNotificationsPage(
          children: children,
          onSendPressed: () => openSendNotification(children),
          fetchRecentNotifications: fetchRecentSentNotifications,
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

  String formatTime(Timestamp? ts) {
    if (ts == null) return 'غير محدد';
    final d = ts.toDate();
    return '${d.year}/${d.month}/${d.day} - ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  List<ChildModel> applyChildrenFilters(
    List<ChildModel> children,
    Map<String, Map<String, dynamic>> latestUpdateByChild,
  ) {
    return children.where((child) {
      final matchesSearch = child.name.toLowerCase().contains(
            searchQuery.toLowerCase(),
          );

      final hasUpdateToday = latestUpdateByChild.containsKey(child.id);

      bool matchesStatus = true;
      if (selectedStatusFilter == 'needUpdate') {
        matchesStatus = !hasUpdateToday;
      } else if (selectedStatusFilter == 'updatedToday') {
        matchesStatus = hasUpdateToday;
      }

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Widget _buildBody({
    required List<ChildModel> nurseryChildren,
    required Map<String, dynamic> stats,
    required List<ChildModel> childrenNeedingUpdate,
    required List<Map<String, dynamic>> activities,
    required Map<String, Map<String, dynamic>> latestUpdateByChild,
  }) {
    final filteredChildren = applyChildrenFilters(
      nurseryChildren,
      latestUpdateByChild,
    );

    switch (selectedIndex) {
      case 0:
        return _buildDashboardTab(
          nurseryChildren: nurseryChildren,
          stats: stats,
          childrenNeedingUpdate: childrenNeedingUpdate,
          activities: activities,
        );
      case 1:
        return _buildFollowUpTab(
          nurseryChildren: nurseryChildren,
          filteredChildren: filteredChildren,
          latestUpdateByChild: latestUpdateByChild,
        );
      case 2:
  return _buildMessagesTab(nurseryChildren);
      case 3:
        return _buildSettingsTab(nurseryChildren);
      default:
        return _buildDashboardTab(
          nurseryChildren: nurseryChildren,
          stats: stats,
          childrenNeedingUpdate: childrenNeedingUpdate,
          activities: activities,
        );
    }
  }

  Widget _buildDashboardTab({
    required List<ChildModel> nurseryChildren,
    required Map<String, dynamic> stats,
    required List<ChildModel> childrenNeedingUpdate,
    required List<Map<String, dynamic>> activities,
  }) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildWelcomeHeader(),
          const SizedBox(height: 16),
          _buildInfoNotice(),
          const SizedBox(height: 16),
          _buildStatsSection(stats),
          const SizedBox(height: 16),
          _buildAlertsSection(childrenNeedingUpdate),
          if (childrenNeedingUpdate.isNotEmpty) const SizedBox(height: 16),
          _buildQuickActions(nurseryChildren),
          const SizedBox(height: 16),
          _buildRecentActivitiesSection(activities),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildFollowUpTab({
    required List<ChildModel> nurseryChildren,
    required List<ChildModel> filteredChildren,
    required Map<String, Map<String, dynamic>> latestUpdateByChild,
  }) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSearchAndFilterBar(),
          const SizedBox(height: 16),
          if (filteredChildren.isEmpty)
            _buildEmptyChildrenState()
          else
            ...filteredChildren.map((child) {
              final latestUpdate = latestUpdateByChild[child.id];
              final hasUpdateToday = latestUpdate != null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _NurseryChildDashboardCard(
                  childModel: child,
                  careStatusText:
                      hasUpdateToday ? 'تمت متابعته اليوم' : 'يحتاج تحديث اليوم',
                  careStatusColor:
                      hasUpdateToday ? Colors.green : Colors.orange,
                  careStatusIcon: hasUpdateToday
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  hasUpdateToday: hasUpdateToday,
                  latestUpdateType: (latestUpdate?['type'] ?? '').toString(),
                  latestUpdateTime: latestUpdate?['time'] as Timestamp?,
                  latestUpdateNote: (latestUpdate?['note'] ?? '').toString(),
                  onCamera: () => openCameraCheckin(child),
                  onAddUpdate: () => openAddUpdate(child),
                  onQuickCare: () => openQuickCareUpdate(child),
                  onCareLog: () => openCareLog(child),
                  onHandoffLog: () => openChildHandoffLog(child),
                  onIncidentReport: () => openIncidentReport(child),
                ),
              );
            }),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => openSendNotification(nurseryChildren),
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('إرسال إشعار للأهل'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesTab(List<ChildModel> nurseryChildren) {
  return NurseryChatsPage(children: nurseryChildren);
}

  Widget _buildSettingsTab(List<ChildModel> nurseryChildren) {
    return ListView(
      children: [
        Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withOpacity(0.10),
              child: const Icon(
                Icons.badge_outlined,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            title: const Text(
              'موظفة الحضانة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('متابعة الرعاية اليومية'),
            trailing: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child:
                  const Icon(Icons.edit, size: 18, color: AppColors.primary),
            ),
            onTap: () {},
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
                subtitle: const Text('سيتم تطوير هذه الصفحة لاحقًا'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('قيد التطوير')),
                  );
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
              SwitchListTile(
                secondary: CircleAvatar(
                  backgroundColor: Colors.purple.withOpacity(0.12),
                  child:
                      const Icon(Icons.palette_outlined, color: Colors.purple),
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
                subtitle: const Text('عرض الإشعارات المرسلة وفتح صفحة الإشعارات'),
                onTap: () => _openNotificationsPage(nurseryChildren),
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text('رعاية سريعة'),
                subtitle: const Text('اختيار طفل وإضافة رعاية سريعة'),
                onTap: () async {
                  final child = await pickChild(nurseryChildren);
                  if (child != null) openQuickCareUpdate(child);
                },
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
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textLight),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChildModel>>(
      future: fetchNurseryChildren(),
      builder: (context, childrenSnapshot) {
        if (childrenSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: AppPageScaffold(
              title: _pageTitle,
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (childrenSnapshot.hasError) {
          return Scaffold(
            body: AppPageScaffold(
              title: _pageTitle,
              child: Center(
                child: Text('حدث خطأ: ${childrenSnapshot.error}'),
              ),
            ),
          );
        }

        final nurseryChildren = childrenSnapshot.data ?? [];

        return FutureBuilder<Map<String, dynamic>>(
          future: fetchTodayStats(nurseryChildren),
          builder: (context, statsSnapshot) {
            if (statsSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                body: AppPageScaffold(
                  title: _pageTitle,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (statsSnapshot.hasError) {
              return Scaffold(
                body: AppPageScaffold(
                  title: _pageTitle,
                  child: const Center(
                    child: Text('حدث خطأ أثناء تحميل الإحصائيات'),
                  ),
                ),
              );
            }

            final stats = statsSnapshot.data ?? {};

            return FutureBuilder<List<dynamic>>(
              future: Future.wait([
                getChildrenNeedingUpdate(nurseryChildren),
                fetchRecentNurseryActivities(),
                fetchTodayUpdatesSummary(nurseryChildren),
              ]),
              builder: (context, extraSnapshot) {
                if (extraSnapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    body: AppPageScaffold(
                      title: _pageTitle,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (extraSnapshot.hasError) {
                  return Scaffold(
                    body: AppPageScaffold(
                      title: _pageTitle,
                      child: const Center(
                        child: Text('حدث خطأ أثناء تحميل بيانات الصفحة'),
                      ),
                    ),
                  );
                }

                final childrenNeedingUpdate =
                    (extraSnapshot.data?[0] as List<ChildModel>? ?? []);
                final activities =
                    (extraSnapshot.data?[1] as List<Map<String, dynamic>>? ??
                        []);
                final latestUpdateByChild =
                    (extraSnapshot.data?[2]
                            as Map<String, Map<String, dynamic>>? ??
                        {});

                return Scaffold(
                  body: AppPageScaffold(
                    title: _pageTitle,
                    actions: selectedIndex == 0
                        ? [
                            IconButton(
                              icon: const Icon(Icons.notifications_none_rounded),
                              tooltip: 'الإشعارات',
                              onPressed: () =>
                                  _openNotificationsPage(nurseryChildren),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded),
                              tooltip: 'تحديث الصفحة',
                              onPressed: () => setState(() {}),
                            ),
                          ]
                        : selectedIndex == 1
                            ? [
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded),
                                  tooltip: 'تحديث الصفحة',
                                  onPressed: () => setState(() {}),
                                ),
                              ]
                            : selectedIndex == 2
                                ? [
                                    IconButton(
                                      icon: const Icon(Icons.notifications_none_rounded),
                                      tooltip: 'الإشعارات',
                                      onPressed: () =>
                                          _openNotificationsPage(nurseryChildren),
                                    ),
                                  ]
                                : [
                                    IconButton(
                                      icon: const Icon(Icons.notifications_none_rounded),
                                      tooltip: 'الإشعارات',
                                      onPressed: () =>
                                          _openNotificationsPage(nurseryChildren),
                                    ),
                                  ],
                    child: _buildBody(
                      nurseryChildren: nurseryChildren,
                      stats: stats,
                      childrenNeedingUpdate: childrenNeedingUpdate,
                      activities: activities,
                      latestUpdateByChild: latestUpdateByChild,
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
          },
        );
      },
    );
  }

  Widget _buildWelcomeHeader() {
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
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أهلاً بكِ',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'تابعي أطفال الحضانة من خلال الرعاية اليومية، الصور، الملاحظات السريعة، الحوادث، والتواصل مع الأهل.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.secondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'ملاحظة: تسجيل دخول وخروج أطفال الحضانة لم يعد من صلاحيات موظفات الحضانة، وأصبح من مسؤولية الإدارة فقط. دور موظفة الحضانة هنا يركز على الرعاية والتحديثات والمتابعة اليومية.',
              style: TextStyle(color: AppColors.textDark, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> stats) {
    return Column(
      children: [
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
                title: 'تمت متابعتهم اليوم',
                value: '${stats['childrenUpdatedTodayCount'] ?? 0}',
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'تحديثات اليوم',
                value: '${stats['careUpdatesCount'] ?? 0}',
                icon: Icons.favorite_border_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'وسائط اليوم',
                value: '${stats['mediaUpdatesCount'] ?? 0}',
                icon: Icons.photo_camera_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlertsSection(List<ChildModel> childrenNeedingUpdate) {
    if (childrenNeedingUpdate.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'تنبيهات اليوم',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...childrenNeedingUpdate.map((child) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${child.name} يحتاج متابعة أو تحديث اليوم',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickActions(List<ChildModel> children) {
    final actions = [
      _QuickActionItem(
        icon: Icons.flash_on_rounded,
        label: 'رعاية سريعة',
        onTap: () async {
          final child = await pickChild(children);
          if (child != null) openQuickCareUpdate(child);
        },
      ),
      _QuickActionItem(
        icon: Icons.camera_alt_outlined,
        label: 'كاميرا',
        onTap: () async {
          final child = await pickChild(children);
          if (child != null) openCameraCheckin(child);
        },
      ),
      _QuickActionItem(
        icon: Icons.menu_book_outlined,
        label: 'سجل الرعاية',
        onTap: () async {
          final child = await pickChild(children);
          if (child != null) openCareLog(child);
        },
      ),
      _QuickActionItem(
        icon: Icons.how_to_reg_outlined,
        label: 'تسليم/استلام',
        onTap: () async {
          final child = await pickChild(children);
          if (child != null) openChildHandoffLog(child);
        },
      ),
      _QuickActionItem(
        icon: Icons.report_problem_outlined,
        label: 'حادث/ملاحظة',
        onTap: () async {
          final child = await pickChild(children);
          if (child != null) openIncidentReport(child);
        },
      ),
      _QuickActionItem(
        icon: Icons.notifications_outlined,
        label: 'إرسال إشعار',
        onTap: () => openSendNotification(children),
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إجراءات سريعة',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
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
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
              ),
              itemBuilder: (context, index) {
                final item = actions[index];
                return _QuickActionCard(
                  icon: item.icon,
                  label: item.label,
                  onTap: item.onTap,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
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
                    isSelected: selectedStatusFilter == 'all',
                    onTap: () {
                      setState(() {
                        selectedStatusFilter = 'all';
                      });
                    },
                  ),
                  _FilterChipItem(
                    label: 'تم تحديثهم اليوم',
                    isSelected: selectedStatusFilter == 'updatedToday',
                    onTap: () {
                      setState(() {
                        selectedStatusFilter = 'updatedToday';
                      });
                    },
                  ),
                  _FilterChipItem(
                    label: 'يحتاج تحديث',
                    isSelected: selectedStatusFilter == 'needUpdate',
                    onTap: () {
                      setState(() {
                        selectedStatusFilter = 'needUpdate';
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitiesSection(List<Map<String, dynamic>> activities) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
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
            'أحدث التحديثات والرعاية والوسائط الخاصة بأطفال الحضانة.',
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
              final childName = (activity['childName'] ?? '').toString();
              final subtitle = (activity['subtitle'] ?? '').toString();
              final color = activity['color'] as Color? ?? AppColors.primary;
              final icon =
                  activity['icon'] as IconData? ?? Icons.notifications_none;
              final time = activity['time'] as Timestamp?;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecentActivityTile(
                  title: title,
                  childName: childName,
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

  Widget _buildEmptyChildrenState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, size: 34, color: AppColors.textLight),
          SizedBox(height: 10),
          Text(
            'لا يوجد أطفال مطابقون للبحث أو الفلترة الحالية.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _NurseryChildDashboardCard extends StatelessWidget {
  final ChildModel childModel;
  final String careStatusText;
  final Color careStatusColor;
  final IconData careStatusIcon;
  final bool hasUpdateToday;
  final String latestUpdateType;
  final Timestamp? latestUpdateTime;
  final String latestUpdateNote;
  final VoidCallback onCamera;
  final VoidCallback onAddUpdate;
  final VoidCallback onQuickCare;
  final VoidCallback onCareLog;
  final VoidCallback onHandoffLog;
  final VoidCallback onIncidentReport;

  const _NurseryChildDashboardCard({
    required this.childModel,
    required this.careStatusText,
    required this.careStatusColor,
    required this.careStatusIcon,
    required this.hasUpdateToday,
    required this.latestUpdateType,
    required this.latestUpdateTime,
    required this.latestUpdateNote,
    required this.onCamera,
    required this.onAddUpdate,
    required this.onQuickCare,
    required this.onCareLog,
    required this.onHandoffLog,
    required this.onIncidentReport,
  });

  String _formatUpdateTime(Timestamp? ts) {
    if (ts == null) return 'غير محدد';
    final d = ts.toDate();
    return '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

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
                  child: const Icon(Icons.child_care, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        childModel.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        childModel.group.isEmpty
                            ? 'بدون مجموعة'
                            : childModel.group,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: careStatusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(careStatusIcon, color: careStatusColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        careStatusText,
                        style: TextStyle(
                          color: careStatusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: hasUpdateToday
                  ? Text(
                      latestUpdateNote.trim().isNotEmpty
                          ? 'آخر تحديث اليوم: $latestUpdateType - ${_formatUpdateTime(latestUpdateTime)}\n$latestUpdateNote'
                          : 'آخر تحديث اليوم: $latestUpdateType - ${_formatUpdateTime(latestUpdateTime)}',
                      style: const TextStyle(
                        color: AppColors.textLight,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'يحتاج تحديث اليوم',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAddUpdate,
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('تحديث'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('كاميرا'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
              children: [
                _ChildActionMiniCard(
                  icon: Icons.flash_on_rounded,
                  label: 'رعاية سريعة',
                  onTap: onQuickCare,
                ),
                _ChildActionMiniCard(
                  icon: Icons.menu_book_outlined,
                  label: 'سجل الرعاية',
                  onTap: onCareLog,
                ),
                _ChildActionMiniCard(
                  icon: Icons.how_to_reg_outlined,
                  label: 'تسليم/استلام',
                  onTap: onHandoffLog,
                ),
                _ChildActionMiniCard(
                  icon: Icons.report_problem_outlined,
                  label: 'حادث/ملاحظة',
                  onTap: onIncidentReport,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NurseryNotificationsPage extends StatelessWidget {
  final List<ChildModel> children;
  final Future<void> Function() onSendPressed;
  final Future<List<Map<String, dynamic>>> Function() fetchRecentNotifications;

  const _NurseryNotificationsPage({
    required this.children,
    required this.onSendPressed,
    required this.fetchRecentNotifications,
  });

  String _formatTimestamp(dynamic raw) {
    if (raw is Timestamp) {
      final d = raw.toDate();
      return '${d.year}/${d.month}/${d.day} - ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    return 'غير محدد';
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الإشعارات',
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchRecentNotifications(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];

          return ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const _InfoPanel(
                        icon: Icons.notifications_active_outlined,
                        title: 'إشعارات موظفة الحضانة',
                        message:
                            'من هنا يمكنك إرسال إشعار جديد للأهل ومراجعة آخر الإشعارات المرسلة.',
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onSendPressed,
                          icon: const Icon(Icons.add_alert_outlined),
                          label: const Text('إرسال إشعار جديد'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'آخر الإشعارات المرسلة',
                style: TextStyle(
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
                      'لا توجد إشعارات مرسلة بعد.',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  ),
                )
              else
                ...items.map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withOpacity(0.12),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.primary,
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
                                const SizedBox(height: 4),
                                if ((item['childName'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty)
                                  Text(
                                    'الطفل: ${item['childName']}',
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 13,
                                    ),
                                  ),
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
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withOpacity(0.8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildActionMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ChildActionMiniCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
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

class _RecentActivityTile extends StatelessWidget {
  final String title;
  final String childName;
  final String subtitle;
  final String timeText;
  final Color color;
  final IconData icon;

  const _RecentActivityTile({
    required this.title,
    required this.childName,
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
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title - $childName',
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
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
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
            child: Icon(icon, color: AppColors.primary),
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