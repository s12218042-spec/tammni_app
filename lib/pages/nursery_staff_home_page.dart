import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../services/account_settings_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'account_history_page.dart';
import 'account_settings_page.dart';
import 'add_update_page.dart';
import 'child_handoff_log_page.dart';
import 'incident_report_page.dart';
import 'nursery_care_log_page.dart';
import 'nursery_chats_page.dart';
import 'send_parent_notification_page.dart';
import 'send_group_update_page.dart';
import 'start_live_stream_page.dart';
import 'welcome_page.dart';

class NurseryStaffHomePage extends StatefulWidget {
  const NurseryStaffHomePage({super.key});

  @override
  State<NurseryStaffHomePage> createState() => _NurseryStaffHomePageState();
}

class _NurseryStaffHomePageState extends State<NurseryStaffHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AccountSettingsService _accountSettingsService =
      AccountSettingsService();

  int selectedIndex = 0;
  bool isArabic = true;
  bool isDarkMode = false;

  String searchQuery = '';
  String selectedStatusFilter = 'all';

  String get _pageTitle {
    switch (selectedIndex) {
      case 0:
        return 'الرئيسية - موظفة الحضانة';
      case 1:
        return 'المتابعة';
      case 2:
        return ' ';
      case 3:
        return 'الإعدادات';
      default:
        return 'الرئيسية - موظفة الحضانة';
    }
  }

  bool _isNurseryRole(String value) {
    final role = value.trim().toLowerCase();
    return role == 'nursery' ||
        role == 'nursery_staff' ||
        role == 'nursery staff';
  }

  String _normalizeRole(String value) {
    final role = value.trim().toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }

    if (role == 'admin') return 'admin';
    if (role == 'parent') return 'parent';

    return role;
  }

  Timestamp? _resolveTimestamp(Map<String, dynamic> data) {
    final values = [
      data['time'],
      data['eventAt'],
      data['createdAt'],
      data['timestamp'],
      data['updatedAt'],
    ];

    for (final value in values) {
      if (value is Timestamp) return value;
    }

    return null;
  }

  Timestamp? _resolveNotificationTimestamp(Map<String, dynamic> data) {
    final values = [
      data['createdAt'],
      data['time'],
      data['timestamp'],
      data['eventAt'],
      data['updatedAt'],
    ];

    for (final value in values) {
      if (value is Timestamp) return value;
    }

    return null;
  }

  Future<_StaffGroupInfo?> fetchCurrentStaffGroup() async {
    final currentUser = AuthService().currentUser;

    if (currentUser == null) return null;

    final snapshot = await _firestore
        .collection('groups')
        .where('assignedStaffUid', isEqualTo: currentUser.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();

    return _StaffGroupInfo(
      id: doc.id,
      name: (data['groupName'] ?? 'مجموعة بدون اسم').toString(),
      maxChildren: (data['maxChildren'] as num?)?.toInt() ?? 12,
      currentChildrenCount:
          (data['currentChildrenCount'] as num?)?.toInt() ?? 0,
      assignedStaffName: (data['assignedStaffName'] ?? '').toString(),
    );
  }

  Future<List<ChildModel>> fetchNurseryChildren() async {
    final staffGroup = await fetchCurrentStaffGroup();

    if (staffGroup == null) {
      return [];
    }

    final snapshot = await _firestore
        .collection('children')
        .where('groupId', isEqualTo: staffGroup.id)
        .where('isActive', isEqualTo: true)
        .get();

    final children = snapshot.docs.map((doc) {
      final data = doc.data();

      final fixedData = <String, dynamic>{
        ...data,
        'section': 'Nursery',
        'group':
            (data['groupName'] ?? data['group'] ?? staffGroup.name).toString(),
        'groupName': (data['groupName'] ?? staffGroup.name).toString(),
      };

      return ChildModel.fromMap(fixedData, docId: doc.id);
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
    final userInfo = await fetchCurrentUserInfo();

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildHandoffLogPage(
          child: child,
          childId: child.id,
          childName: child.name,
          createdByUid: userInfo['uid'],
          createdByName: userInfo['name'],
          createdByRole: userInfo['role'],
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> openIncidentReport(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IncidentReportPage(child: child)),
    );

    if (!mounted) return;
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

      final ts = _resolveTimestamp(data);

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

      final ts = _resolveTimestamp(data);

      if (ts == null) continue;
      if (ts.toDate().isBefore(startOfDay)) continue;

      final old = latestUpdateByChild[childId];

      if (old == null) {
        latestUpdateByChild[childId] = {
          'type': (data['type'] ?? 'تحديث').toString(),
          'note': (data['note'] ?? data['message'] ?? '').toString(),
          'time': ts,
        };
      } else {
        final oldTs = old['time'] as Timestamp?;

        if (oldTs == null || ts.compareTo(oldTs) > 0) {
          latestUpdateByChild[childId] = {
            'type': (data['type'] ?? 'تحديث').toString(),
            'note': (data['note'] ?? data['message'] ?? '').toString(),
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

  Future<List<Map<String, dynamic>>> fetchRecentNurseryActivities(
    List<ChildModel> children,
  ) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final childIds = children.map((e) => e.id).toSet();

    if (childIds.isEmpty) {
      return [];
    }

    final updatesSnapshot = await _firestore
        .collection('updates')
        .where('section', isEqualTo: 'Nursery')
        .get();

    final List<Map<String, dynamic>> activities = [];

    for (final doc in updatesSnapshot.docs) {
      final data = doc.data();
      final childId = (data['childId'] ?? '').toString();

      if (!childIds.contains(childId)) continue;

      final ts = _resolveTimestamp(data);

      if (ts == null) continue;
      if (ts.toDate().isBefore(startOfDay)) continue;

      final childName = (data['childName'] ?? 'طفل').toString();
      final type = (data['type'] ?? 'تحديث').toString();
      final note = (data['note'] ?? data['message'] ?? '').toString();
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

  Future<int> fetchUnreadNurseryNotificationsCount() async {
    final userInfo = await fetchCurrentUserInfo();
    final currentUid = (userInfo['uid'] ?? '').toString();

    final docs = await _fetchNurseryNotificationDocs(limit: 80);

    return docs.where((doc) {
      final data = doc.data();
      final isRead = data['isRead'] == true ||
          data['read'] == true ||
          data['seen'] == true;

      if (isRead) return false;

      final targetUid = (data['targetUid'] ??
              data['receiverUid'] ??
              data['userUid'] ??
              data['toUid'] ??
              '')
          .toString()
          .trim();

      final targetRole = (data['targetRole'] ??
              data['receiverRole'] ??
              data['roleTarget'] ??
              data['notificationFor'] ??
              '')
          .toString();

      if (currentUid.isNotEmpty && targetUid == currentUid) return true;
      if (_isNurseryRole(targetRole)) return true;

      return false;
    }).length;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _fetchNurseryNotificationDocs({int limit = 60}) async {
    final userInfo = await fetchCurrentUserInfo();
    final currentUid = (userInfo['uid'] ?? '').toString().trim();

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];

    Future<void> addQuery(Query<Map<String, dynamic>> query) async {
      try {
        final snapshot = await query.limit(limit).get();
        allDocs.addAll(snapshot.docs);
      } catch (_) {}
    }

    if (currentUid.isNotEmpty) {
      await addQuery(
        _firestore
            .collection('notifications')
            .where('targetUid', isEqualTo: currentUid)
            .orderBy('createdAt', descending: true),
      );

      await addQuery(
        _firestore
            .collection('notifications')
            .where('receiverUid', isEqualTo: currentUid)
            .orderBy('createdAt', descending: true),
      );

      await addQuery(
        _firestore
            .collection('notifications')
            .where('userUid', isEqualTo: currentUid)
            .orderBy('createdAt', descending: true),
      );
    }

    await addQuery(
      _firestore
          .collection('notifications')
          .where('targetRole', isEqualTo: 'nursery_staff')
          .orderBy('createdAt', descending: true),
    );

    await addQuery(
      _firestore
          .collection('notifications')
          .where('notificationFor', isEqualTo: 'nursery_staff')
          .orderBy('createdAt', descending: true),
    );

    await addQuery(
      _firestore
          .collection('notifications')
          .where('createdByRole', isEqualTo: 'nursery_staff')
          .orderBy('createdAt', descending: true),
    );

    await addQuery(
      _firestore
          .collection('notifications')
          .where('byRole', isEqualTo: 'nursery_staff')
          .orderBy('createdAt', descending: true),
    );

    if (allDocs.isEmpty) {
      final fallback = await _firestore
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      allDocs.addAll(fallback.docs);
    }

    final seen = <String>{};
    final unique = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final doc in allDocs) {
      if (seen.add(doc.id)) {
        unique.add(doc);
      }
    }

    unique.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      final aTime = _resolveNotificationTimestamp(aData);
      final bTime = _resolveNotificationTimestamp(bData);

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return unique.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> fetchRecentSentNotifications() async {
    final docs = await _fetchNurseryNotificationDocs(limit: 80);
    final userInfo = await fetchCurrentUserInfo();
    final currentUid = (userInfo['uid'] ?? '').toString().trim();

    final items = <Map<String, dynamic>>[];

    for (final doc in docs) {
      final data = doc.data();

      final createdByRole = (data['createdByRole'] ?? '').toString();
      final byRole = (data['byRole'] ?? '').toString();

      final targetUid = (data['targetUid'] ??
              data['receiverUid'] ??
              data['userUid'] ??
              data['toUid'] ??
              '')
          .toString()
          .trim();

      final targetRole = (data['targetRole'] ??
              data['receiverRole'] ??
              data['roleTarget'] ??
              data['notificationFor'] ??
              '')
          .toString();

      final isSentByNursery =
          _isNurseryRole(createdByRole) || _isNurseryRole(byRole);

      final isForCurrentStaff =
          currentUid.isNotEmpty && targetUid == currentUid;

      final isForNurseryRole = _isNurseryRole(targetRole);

      if (!isSentByNursery && !isForCurrentStaff && !isForNurseryRole) {
        continue;
      }

      items.add({
        'id': doc.id,
        'title':
            (data['title'] ?? data['subject'] ?? data['notificationTitle'] ?? 'إشعار')
                .toString(),
        'body': (data['body'] ??
                data['message'] ??
                data['text'] ??
                data['description'] ??
                '')
            .toString(),
        'createdAt': _resolveNotificationTimestamp(data),
        'childName': (data['childName'] ?? '').toString(),
        'type': (data['type'] ??
                data['notificationType'] ??
                data['category'] ??
                'notification')
            .toString(),
        'priority':
            (data['priority'] ?? data['importance'] ?? data['level'] ?? '')
                .toString(),
        'isRead': data['isRead'] == true ||
            data['read'] == true ||
            data['seen'] == true,
        'createdByName': (data['createdByName'] ??
                data['senderName'] ??
                data['byName'] ??
                '')
            .toString(),
        'createdByRole': createdByRole.isNotEmpty ? createdByRole : byRole,
        'direction': isSentByNursery ? 'sent' : 'received',
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

    return items.take(50).toList();
  }

  Future<void> markNurseryNotificationAsRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;

    await _firestore.collection('notifications').doc(notificationId).set({
      'isRead': true,
      'read': true,
      'seen': true,
      'readAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> openAddUpdate(ChildModel child) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddUpdatePage(
          child: child,
          byRole: 'nursery_staff',
        ),
      ),
    );

    if (res == true && mounted) {
      setState(() {});
    }
  }

  Future<void> openCareLog(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NurseryCareLogPage(child: child)),
    );

    if (!mounted) return;
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

    if (res == true && mounted) {
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
          markAsRead: markNurseryNotificationAsRead,
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

  Future<Map<String, String>> fetchCurrentUserInfo() async {
    final currentUser = AuthService().currentUser;

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
      'name': (data['displayName'] ??
              data['name'] ??
              data['username'] ??
              'مستخدم')
          .toString(),
      'role': _normalizeRole((data['role'] ?? '').toString()),
    };
  }

  String formatTime(Timestamp? ts) {
    if (ts == null) return 'غير محدد';

    final d = ts.toDate();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');

    return '${d.year}/${d.month}/${d.day} - $hour:$minute';
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

  Widget _buildNotificationActionButton(List<ChildModel> children) {
    return FutureBuilder<int>(
      future: fetchUnreadNurseryNotificationsCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              tooltip: 'الإشعارات',
              onPressed: () => _openNotificationsPage(children),
            ),
            if (count > 0)
              PositionedDirectional(
                top: 6,
                end: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
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
          _buildMyGroupCard(),
          const SizedBox(height: 16),
          _buildStatsSection(stats),
          const SizedBox(height: 16),
          _buildAlertsSection(childrenNeedingUpdate),
          const SizedBox(height: 16),
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
          _buildMyGroupCard(),
          const SizedBox(height: 16),
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
                  onAddUpdate: () => openAddUpdate(child),
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
          child: FutureBuilder<AccountSettingsData>(
            future: _accountSettingsService.getCurrentUserData(),
            builder: (context, snapshot) {
              final data = snapshot.data;

              final displayName = data?.name.trim().isNotEmpty == true
                  ? data!.name
                  : 'موظفة الحضانة';

              final subtitle = data == null
                  ? 'متابعة الرعاية اليومية'
                  : '${data.roleLabel} • ${data.username.isNotEmpty ? data.username : "بدون اسم مستخدم"}';

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.10),
                  child: Text(
                    displayName.trim().isNotEmpty ? displayName.trim()[0] : 'م',
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
                subtitle:
                    const Text('عرض الإشعارات المستلمة والمرسلة للأهل'),
                onTap: () => _openNotificationsPage(nurseryChildren),
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
                fetchRecentNurseryActivities(nurseryChildren),
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

                final pageBody = _buildBody(
  nurseryChildren: nurseryChildren,
  stats: stats,
  childrenNeedingUpdate: childrenNeedingUpdate,
  activities: activities,
  latestUpdateByChild: latestUpdateByChild,
);

return Scaffold(
  body: selectedIndex == 2
      ? pageBody
      : AppPageScaffold(
          title: _pageTitle,
          actions: selectedIndex == 0
              ? [
                  _buildNotificationActionButton(nurseryChildren),
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
                  : [
                      _buildNotificationActionButton(nurseryChildren),
                    ],
          child: pageBody,
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

  Widget _buildMyGroupCard() {
    return FutureBuilder<_StaffGroupInfo?>(
      future: fetchCurrentStaffGroup(),
      builder: (context, snapshot) {
        final group = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          );
        }

        if (group == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.orange.withOpacity(0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.orange),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'لم يتم ربطك بمجموعة بعد. راجعي الإدارة لتحديد المجموعة المسؤولة عنها.',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final current = group.currentChildrenCount;
        final max = group.maxChildren;
        final isFull = max > 0 && current >= max;

        final color = isFull ? Colors.orange : AppColors.primary;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withOpacity(0.12),
                      child: Icon(Icons.groups_2_rounded, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'مجموعتي',
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            group.name,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
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
                      child: _GroupInfoBox(
                        title: 'عدد الأطفال',
                        value: '$current / $max',
                        icon: Icons.child_care_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _GroupInfoBox(
                        title: 'الحالة',
                        value: isFull ? 'ممتلئة' : 'متاحة',
                        icon: isFull
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                      ),
                    ),
                  ],
                ),
                if (isFull) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.22),
                      ),
                    ),
                    child: const Text(
                      'تنبيه: المجموعة وصلت للحد الأقصى أو قريبة من الامتلاء.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
      child: Text(
        'أهلاً بكِ',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
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
  final count = childrenNeedingUpdate.length;
  final hasChildrenNeedUpdate = count > 0;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: hasChildrenNeedUpdate
          ? Colors.orange.withOpacity(0.08)
          : Colors.green.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: hasChildrenNeedUpdate
            ? Colors.orange.withOpacity(0.30)
            : Colors.green.withOpacity(0.25),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              hasChildrenNeedUpdate
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              color: hasChildrenNeedUpdate ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            const Text(
              'تنبيهات اليوم',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          hasChildrenNeedUpdate
              ? 'يوجد $count طفل/أطفال بحاجة إلى تحديث اليوم.'
              : 'لا يوجد أطفال بحاجة إلى تحديث اليوم.',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: hasChildrenNeedUpdate ? AppColors.textDark : Colors.green,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hasChildrenNeedUpdate
              ? 'يمكنكِ عرض الأسماء من الزر أدناه لتجنب ازدحام الصفحة الرئيسية.'
              : 'تم إرسال تحديثات لجميع أطفال مجموعتك لهذا اليوم.',
          style: const TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChildrenNeedUpdatePage(
                    children: childrenNeedingUpdate,
                  ),
                ),
              );

              if (!mounted) return;
              setState(() {});
            },
            icon: Icon(
              hasChildrenNeedUpdate
                  ? Icons.list_alt_rounded
                  : Icons.checklist_rounded,
            ),
            label: Text(
              hasChildrenNeedUpdate
                  ? 'عرض أسماء الأطفال'
                  : 'عرض حالة التحديثات',
            ),
          ),
        ),
      ],
    ),
  );
}

  Future<void> openGroupUpdate(List<ChildModel> children) async {
  if (children.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لا يوجد أطفال داخل مجموعتك لإرسال تحديث جماعي.'),
      ),
    );
    return;
  }

  final group = await fetchCurrentStaffGroup();

  if (!mounted) return;

  if (group == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لم يتم ربطك بمجموعة بعد. راجعي الإدارة.'),
      ),
    );
    return;
  }

  final res = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SendGroupUpdatePage(
        groupId: group.id,
        groupName: group.name,
        children: children,
        byRole: 'nursery_staff',
      ),
    ),
  );

  if (res == true && mounted) {
    setState(() {});
  }
}

  Widget _buildQuickActions(List<ChildModel> children) {
    final actions = [
      _QuickActionItem(
        icon: Icons.groups_2_outlined,
        label: 'تحديث جماعي',
        onTap: () => openGroupUpdate(children),
      ),
      _QuickActionItem(
        icon: Icons.note_add_outlined,
        label: 'إضافة تحديث',
        onTap: () async {
          final child = await pickChild(children);
          if (child != null) openAddUpdate(child);
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
      _QuickActionItem(
        icon: Icons.wifi_tethering_rounded,
        label: 'بث مباشر',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StartLiveStreamPage(),
            ),
          );

          if (!mounted) return;
          setState(() {});
        },
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الإجراءات',
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
class ChildrenNeedUpdatePage extends StatelessWidget {
  final List<ChildModel> children;

  const ChildrenNeedUpdatePage({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'أطفال بحاجة إلى تحديث اليوم',
      child: children.isEmpty
          ? Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 34,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'لا يوجد أطفال بحاجة إلى تحديث اليوم',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'تم إرسال تحديثات لجميع أطفال مجموعتك لهذا اليوم.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.12),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'يوجد ${children.length} طفل/أطفال لم يصلهم تحديث اليوم.',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: children.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final child = children[index];
                      final groupName = child.group.trim().isEmpty
                          ? 'بدون مجموعة'
                          : child.group.trim();

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withOpacity(0.12),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            child.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          subtitle: Text(
                            'المجموعة: $groupName',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.child_care_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
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
  final VoidCallback onAddUpdate;
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
    required this.onAddUpdate,
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddUpdate,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('إضافة تحديث'),
              ),
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

class _NurseryNotificationsPage extends StatefulWidget {
  final List<ChildModel> children;
  final Future<void> Function() onSendPressed;
  final Future<List<Map<String, dynamic>>> Function() fetchRecentNotifications;
  final Future<void> Function(String notificationId) markAsRead;

  const _NurseryNotificationsPage({
    required this.children,
    required this.onSendPressed,
    required this.fetchRecentNotifications,
    required this.markAsRead,
  });

  @override
  State<_NurseryNotificationsPage> createState() =>
      _NurseryNotificationsPageState();
}

class _NurseryNotificationsPageState extends State<_NurseryNotificationsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetchRecentNotifications();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.fetchRecentNotifications();
    });

    await _future;
  }

  String _formatTimestamp(dynamic raw) {
    if (raw is Timestamp) {
      final d = raw.toDate();
      return '${d.year}/${d.month}/${d.day} - ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }

    return 'غير محدد';
  }

  Color _typeColor(String type, String direction, bool isRead) {
    if (!isRead && direction == 'received') return Colors.orange;

    switch (type.trim().toLowerCase()) {
      case 'message':
      case 'new_message':
        return Colors.blueGrey;
      case 'complaint_created':
      case 'complaint_reply':
        return Colors.redAccent;
      case 'live_stream_started':
        return Colors.red;
      case 'live_stream_ended':
        return Colors.grey;
      case 'update_notification':
      case 'nursery_notification':
        return AppColors.primary;
      default:
        return AppColors.secondary;
    }
  }

  IconData _typeIcon(String type, String direction) {
    if (direction == 'sent') return Icons.mark_email_read_outlined;

    switch (type.trim().toLowerCase()) {
      case 'message':
      case 'new_message':
        return Icons.chat_bubble_outline_rounded;
      case 'complaint_created':
      case 'complaint_reply':
        return Icons.report_problem_outlined;
      case 'live_stream_started':
        return Icons.wifi_tethering_rounded;
      case 'live_stream_ended':
        return Icons.stop_circle_outlined;
      case 'update_notification':
      case 'nursery_notification':
        return Icons.notifications_active_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _directionLabel(String direction) {
    return direction == 'sent' ? 'مرسل' : 'وارد';
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الإشعارات',
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await widget.onSendPressed();

                      if (!mounted) return;
                      await _refresh();
                    },
                    icon: const Icon(Icons.add_alert_outlined),
                    label: const Text('إرسال إشعار جديد'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'آخر الإشعارات',
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
                        'لا توجد إشعارات بعد.',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                    ),
                  )
                else
                  ...items.map((item) {
                    final id = (item['id'] ?? '').toString();
                    final title = (item['title'] ?? 'إشعار').toString();
                    final body = (item['body'] ?? '').toString();
                    final childName = (item['childName'] ?? '').toString();
                    final type = (item['type'] ?? '').toString();
                    final priority = (item['priority'] ?? '').toString();
                    final direction = (item['direction'] ?? 'received')
                        .toString()
                        .trim()
                        .toLowerCase();
                    final isRead = item['isRead'] == true;
                    final color = _typeColor(type, direction, isRead);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          if (!isRead && id.trim().isNotEmpty) {
                            await widget.markAsRead(id);

                            if (!mounted) return;
                            await _refresh();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: color.withOpacity(0.12),
                                child: Icon(
                                  _typeIcon(type, direction),
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
                                            title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.5,
                                              color: isRead
                                                  ? AppColors.textLight
                                                  : AppColors.textDark,
                                            ),
                                          ),
                                        ),
                                        if (!isRead && direction == 'received')
                                          Container(
                                            width: 9,
                                            height: 9,
                                            decoration: const BoxDecoration(
                                              color: Colors.orange,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.10),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            _directionLabel(direction),
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (priority.trim().isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange
                                                  .withOpacity(0.10),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              priority,
                                              style: const TextStyle(
                                                color: Colors.orange,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (childName.trim().isNotEmpty) ...[
                                      const SizedBox(height: 7),
                                      Text(
                                        'الطفل: $childName',
                                        style: const TextStyle(
                                          color: AppColors.textLight,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                    if (body.trim().isNotEmpty) ...[
                                      const SizedBox(height: 7),
                                      Text(
                                        body,
                                        style: const TextStyle(
                                          color: AppColors.textLight,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 7),
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
                    );
                  }),
              ],
            ),
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

class _StaffGroupInfo {
  final String id;
  final String name;
  final int maxChildren;
  final int currentChildrenCount;
  final String assignedStaffName;

  const _StaffGroupInfo({
    required this.id,
    required this.name,
    required this.maxChildren,
    required this.currentChildrenCount,
    required this.assignedStaffName,
  });
}

class _GroupInfoBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _GroupInfoBox({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
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