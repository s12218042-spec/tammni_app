import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../services/account_settings_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'account_history_page.dart';
import 'add_update_page.dart';
import 'child_handoff_log_page.dart';
import 'incident_report_page.dart';
import 'nursery_care_log_page.dart';
import 'nursery_chats_page.dart';
import 'send_group_update_page.dart';
import 'staff_my_tasks_page.dart';
import 'profile_details_page.dart';
import 'staff_employee_file_page.dart';
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

  late Future<_NurseryHomeData> _homeDataFuture;
  late Future<_StaffGroupInfo?> _staffGroupFuture;

  @override
  void initState() {
    super.initState();
    _resetHomeDataFutures();
  }

  void _resetHomeDataFutures() {
    _staffGroupFuture = fetchCurrentStaffGroup();
    _homeDataFuture = _fetchHomeData();
  }

  Future<void> _refreshHomeData() async {
    setState(() {
      _resetHomeDataFutures();
    });

    await _homeDataFuture;
  }

  Future<_NurseryHomeData> _fetchHomeData() async {
    final nurseryChildren = await fetchNurseryChildren();

    final results = await Future.wait<dynamic>([
      fetchTodayStats(nurseryChildren),
      getChildrenNeedingUpdate(nurseryChildren),
      fetchRecentNurseryActivities(nurseryChildren),
      fetchTodayUpdatesSummary(nurseryChildren),
    ]);

    return _NurseryHomeData(
      nurseryChildren: nurseryChildren,
      stats: results[0] as Map<String, dynamic>,
      childrenNeedingUpdate: results[1] as List<ChildModel>,
      activities: results[2] as List<Map<String, dynamic>>,
      latestUpdateByChild:
          results[3] as Map<String, Map<String, dynamic>>,
    );
  }
  
  DateTime get _todayDateOnly {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _currentWeekStart {
    final d = _todayDateOnly;
    final daysFromSunday = d.weekday == DateTime.sunday ? 0 : d.weekday;
    return d.subtract(Duration(days: daysFromSunday));
  }

  DateTime get _currentWeekEnd {
    return _currentWeekStart.add(const Duration(days: 6));
  }

  String get _currentWeekKey {
    final firstDay = DateTime(_todayDateOnly.year, 1, 1);
    final diff = _todayDateOnly.difference(firstDay).inDays;
    final week = ((diff + firstDay.weekday) / 7).ceil();
    return '${_todayDateOnly.year}-W${week.toString().padLeft(2, '0')}';
  }

  String _formatDateKey(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get _pageTitle {
    switch (selectedIndex) {
      case 0:
        return 'الرئيسية - موظف الحضانة';
      case 1:
        return 'المتابعة';
      case 2:
        return ' ';
      case 3:
        return 'الإعدادات';
      default:
        return 'الرئيسية - موظف الحضانة';
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

    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> docsById = {};

    final byGroupId = await _firestore
        .collection('children')
        .where('groupId', isEqualTo: staffGroup.id)
        .get();

    for (final doc in byGroupId.docs) {
      docsById[doc.id] = doc;
    }

    final byGroupName = await _firestore
        .collection('children')
        .where('groupName', isEqualTo: staffGroup.name)
        .get();

    for (final doc in byGroupName.docs) {
      docsById[doc.id] = doc;
    }

    final children = docsById.values.where((doc) {
      final data = doc.data();
      final isActive = data['isActive'];
      final status = (data['childStatus'] ?? data['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final childType = (data['childType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (isActive == false) return false;
      if (status == 'withdrawn' ||
          status == 'rejected' ||
          status == 'inactive' ||
          status == 'deleted') {
        return false;
      }

      return status.isEmpty ||
          status == 'active' ||
          status == 'temporary' ||
          status == 'trial' ||
          childType == 'temporary' ||
          childType == 'trial';
    }).map((doc) {
      final data = doc.data();

      final fixedData = <String, dynamic>{
        ...data,
        'section': 'Nursery',
        'group':
            (data['groupName'] ?? data['group'] ?? staffGroup.name).toString(),
        'groupName': (data['groupName'] ?? staffGroup.name).toString(),
        'groupId': (data['groupId'] ?? staffGroup.id).toString(),
      };

      return ChildModel.fromMap(fixedData, docId: doc.id);
    }).toList();

    children.sort((a, b) => a.name.compareTo(b.name));
    return children;
  }

  Future<ChildModel?> pickChild(List<ChildModel> children) async {
    if (children.isEmpty) return null;

    final searchController = TextEditingController();
    final searchFocusNode = FocusNode();

    try {
      return await showModalBottomSheet<ChildModel>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (context) {
          String localSearch = '';
          String selectedGroup = 'all';

          final groups = <String>{
            'all',
            ...children.map((c) => c.group.isEmpty ? 'بدون مجموعة' : c.group),
          }.toList();

          return StatefulBuilder(
            builder: (context, setModalState) {
              final query = localSearch.trim().toLowerCase();

              final filtered = children.where((child) {
                final groupName =
                    child.group.isEmpty ? 'بدون مجموعة' : child.group;

                final searchValues = [
                  child.name,
                  child.parentName,
                  child.parentUsername,
                  groupName,
                ].join(' ').toLowerCase();

                final matchesSearch =
                    query.isEmpty || searchValues.contains(query);
                final matchesGroup =
                    selectedGroup == 'all' || groupName == selectedGroup;

                return matchesSearch && matchesGroup;
              }).toList();

              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.78,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'اختيار الطفل',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: 'بحث',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: localSearch.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    searchController.clear();

                                    setModalState(() {
                                      localSearch = '';
                                    });

                                    searchFocusNode.requestFocus();
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            localSearch = value;
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
                              padding:
                                  const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                label: Text(group == 'all' ? 'الكل' : group),
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
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('لا يوجد نتائج'))
                            : ListView.separated(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final child = filtered[index];
                                  final groupName = child.group.isEmpty
                                      ? 'بدون مجموعة'
                                      : child.group;
                                  final parentName = child.parentName.trim();

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 6,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          AppColors.primary.withOpacity(0.12),
                                      child: const Icon(
                                        Icons.child_care_rounded,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    title: Text(
                                      child.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      parentName.isEmpty
                                          ? groupName
                                          : '$parentName • $groupName',
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                    ),
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
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
    } finally {
      searchController.dispose();
      searchFocusNode.dispose();
    }
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
    await _refreshHomeData();
  }

  Future<void> openIncidentReport(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IncidentReportPage(child: child)),
    );

    if (!mounted) return;
    await _refreshHomeData();
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
      } catch (error) {
        debugPrint('NURSERY NOTIFICATIONS QUERY ERROR: $error');
      }
    }

    if (currentUid.isNotEmpty) {
      await addQuery(
        _firestore
            .collection('notifications')
            .where('targetUid', isEqualTo: currentUid),
      );

      await addQuery(
        _firestore
            .collection('notifications')
            .where('createdByUid', isEqualTo: currentUid),
      );
    }

    const nurseryRoleValues = [
      'nursery_staff',
      'nursery',
      'nursery staff',
      'staff',
      'employee',
      'teacher',
    ];

    for (final role in nurseryRoleValues) {
      await addQuery(
        _firestore
            .collection('notifications')
            .where('targetRole', isEqualTo: role),
      );

      await addQuery(
        _firestore
            .collection('notifications')
            .where('notificationFor', isEqualTo: role),
      );
    }

    final seen = <String>{};
    final unique = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final doc in allDocs) {
      if (seen.add(doc.id)) {
        unique.add(doc);
      }
    }

    unique.sort((a, b) {
      final aTime = _resolveNotificationTimestamp(a.data());
      final bTime = _resolveNotificationTimestamp(b.data());

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
      await _refreshHomeData();
    }
  }

  Future<void> openCareLog(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NurseryCareLogPage(child: child)),
    );

    if (!mounted) return;
    await _refreshHomeData();
  }

  Future<void> _openNotificationsPage(List<ChildModel> children) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NurseryNotificationsPage(
          children: children,
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
  Widget _buildWeeklyDutyMiniCard() {
  final currentUser = AuthService().currentUser;

  if (currentUser == null) {
    return const SizedBox.shrink();
  }

  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _firestore
        .collection('weekly_duties')
        .doc(_currentWeekKey)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: const [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'جاري فحص مناوبة الأسبوع...',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (snapshot.hasError) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.redAccent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تعذر تحميل المناوبة الأسبوعية',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final exists = snapshot.data?.exists == true;
      final data = snapshot.data?.data();

      if (!exists || data == null) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blueGrey.withOpacity(0.10),
                  child: const Icon(
                    Icons.event_available_outlined,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'لا توجد مناوبة محددة لهذا الأسبوع',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final rawDutyStaffUids = data['dutyStaffUids'];

final dutyStaffUids = rawDutyStaffUids is List
    ? rawDutyStaffUids.map((e) => e.toString().trim()).toList()
    : <String>[];

final oldSingleStaffUid = (data['staffUid'] ?? '').toString().trim();

final isMyDuty = dutyStaffUids.isNotEmpty
    ? dutyStaffUids.contains(currentUser.uid)
    : oldSingleStaffUid == currentUser.uid;

final rawDutyStaff = data['dutyStaff'];

String dutyStaffNames = '';

if (rawDutyStaff is List && rawDutyStaff.isNotEmpty) {
  dutyStaffNames = rawDutyStaff
      .map((e) {
        if (e is Map) {
          return (e['name'] ?? e['staffName'] ?? '').toString().trim();
        }
        return '';
      })
      .where((name) => name.isNotEmpty)
      .join('، ');
}

if (dutyStaffNames.isEmpty) {
  dutyStaffNames =
      (data['staffName'] ?? data['dutyStaffName'] ?? 'موظف غير محدد')
          .toString()
          .trim();
}

final start = (data['weekStartDateKey'] ??
        _formatDateKey(_currentWeekStart))
    .toString();

final end = (data['weekEndDateKey'] ??
        _formatDateKey(_currentWeekEnd))
    .toString();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isMyDuty
                    ? Colors.green.withOpacity(0.12)
                    : Colors.blueGrey.withOpacity(0.10),
                child: Icon(
                  isMyDuty
                      ? Icons.verified_user_outlined
                      : Icons.event_note_outlined,
                  color: isMyDuty ? Colors.green : Colors.blueGrey,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMyDuty
                          ? 'أنت المناوب لهذا الأسبوع'
                          : 'لا توجد مناوبة عليك هذا الأسبوع',
                      style: TextStyle(
                        color: isMyDuty ? Colors.green : AppColors.textDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isMyDuty
                          ? 'من $start إلى $end'
                          : 'المناوبة : $dutyStaffNames',
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
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
    },
  );
}

  Widget _buildDashboardTab({
    required List<ChildModel> nurseryChildren,
    required Map<String, dynamic> stats,
    required List<ChildModel> childrenNeedingUpdate,
    required List<Map<String, dynamic>> activities,
  }) {
    return RefreshIndicator(
      onRefresh: _refreshHomeData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildWelcomeHeader(),
          const SizedBox(height: 16),
          _buildMyGroupCard(),
          const SizedBox(height: 12),
          _buildWeeklyDutyMiniCard(),
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
    required Map<String, Map<String, dynamic>> latestUpdateByChild,
  }) {
    return _NurseryFollowUpTab(
      key: const ValueKey('nursery_follow_up_tab'),
      nurseryChildren: nurseryChildren,
      latestUpdateByChild: latestUpdateByChild,
      buildMyGroupCard: _buildMyGroupCard,
      onRefresh: _refreshHomeData,
      onAddUpdate: openAddUpdate,
      onCareLog: openCareLog,
      onHandoffLog: openChildHandoffLog,
      onIncidentReport: openIncidentReport,
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
                  : 'موظف الحضانة';

              final subtitle = data == null
                  ? 'متابعة الرعاية اليومية'
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
                      builder: (_) => const ProfileDetailsPage(),
                    ),
                  );

                  if (!mounted) return;
                  await _refreshHomeData();
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
                  backgroundColor: Colors.green.withOpacity(0.12),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.green,
                  ),
                ),
                title: const Text('الإشعارات'),
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
        const SizedBox(height: 12),
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
    return FutureBuilder<_NurseryHomeData>(
      future: _homeDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Scaffold(
            body: AppPageScaffold(
              title: _pageTitle,
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: AppPageScaffold(
              title: _pageTitle,
              child: Center(
                child: Text('حدث خطأ أثناء تحميل الصفحة: ${snapshot.error}'),
              ),
            ),
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return Scaffold(
            body: AppPageScaffold(
              title: _pageTitle,
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final nurseryChildren = data.nurseryChildren;

        final pageBody = _buildBody(
          nurseryChildren: nurseryChildren,
          stats: data.stats,
          childrenNeedingUpdate: data.childrenNeedingUpdate,
          activities: data.activities,
          latestUpdateByChild: data.latestUpdateByChild,
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
                            onPressed: _refreshHomeData,
                          ),
                        ]
                      : selectedIndex == 1
                          ? [
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded),
                                tooltip: 'تحديث الصفحة',
                                onPressed: _refreshHomeData,
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
  }

  Widget _buildMyGroupCard() {
    return FutureBuilder<_StaffGroupInfo?>(
      future: _staffGroupFuture,
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
                    'لم يتم ربطك بمجموعة بعد.',
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
                      'المجموعة ممتلئة.',
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
        'أهلاً بك',
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
              ? '$count طفل بحاجة إلى تحديث اليوم.'
              : 'لا يوجد أطفال بحاجة إلى تحديث اليوم.',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: hasChildrenNeedUpdate ? AppColors.textDark : Colors.green,
            height: 1.4,
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
              await _refreshHomeData();
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
        content: Text('لا يوجد أطفال داخل مجموعتك.'),
      ),
    );
    return;
  }

  final group = await fetchCurrentStaffGroup();

  if (!mounted) return;

  if (group == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لم يتم ربطك بمجموعة بعد.'),
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
    await _refreshHomeData();
  }
}

  Widget _buildQuickActions(List<ChildModel> children) {
    final actions = [
    _QuickActionItem(
      icon: Icons.assignment_outlined,
      label: 'مهامي',
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const StaffMyTasksPage(),
          ),
        );

        if (!mounted) return;
        await _refreshHomeData();
      },
    ),
    _QuickActionItem(
  icon: Icons.badge_outlined,
  label: 'ملفي الوظيفي',
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StaffEmployeeFilePage(),
      ),
    );

    if (!mounted) return;
    setState(() {});
  },
),

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
        label: 'إضافة تقرير متابعة',
        onTap: () async {
          final child = await pickChild(children);
          if (child != null) openIncidentReport(child);
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


}

class _NurseryHomeData {
  final List<ChildModel> nurseryChildren;
  final Map<String, dynamic> stats;
  final List<ChildModel> childrenNeedingUpdate;
  final List<Map<String, dynamic>> activities;
  final Map<String, Map<String, dynamic>> latestUpdateByChild;

  const _NurseryHomeData({
    required this.nurseryChildren,
    required this.stats,
    required this.childrenNeedingUpdate,
    required this.activities,
    required this.latestUpdateByChild,
  });
}

class _NurseryFollowUpTab extends StatefulWidget {
  final List<ChildModel> nurseryChildren;
  final Map<String, Map<String, dynamic>> latestUpdateByChild;
  final Widget Function() buildMyGroupCard;
  final Future<void> Function() onRefresh;
  final Future<void> Function(ChildModel child) onAddUpdate;
  final Future<void> Function(ChildModel child) onCareLog;
  final Future<void> Function(ChildModel child) onHandoffLog;
  final Future<void> Function(ChildModel child) onIncidentReport;

  const _NurseryFollowUpTab({
    super.key,
    required this.nurseryChildren,
    required this.latestUpdateByChild,
    required this.buildMyGroupCard,
    required this.onRefresh,
    required this.onAddUpdate,
    required this.onCareLog,
    required this.onHandoffLog,
    required this.onIncidentReport,
  });

  @override
  State<_NurseryFollowUpTab> createState() => _NurseryFollowUpTabState();
}

class _NurseryFollowUpTabState extends State<_NurseryFollowUpTab> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  String _selectedStatusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String _normalizeSearchText(dynamic value) {
    var text = (value ?? '').toString().trim().toLowerCase();

    return text
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
        .replaceAll('ـ', '')
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<ChildModel> _filteredChildren() {
    final query = _normalizeSearchText(_searchQuery);

    return widget.nurseryChildren.where((child) {
      final values = [
        child.name,
        child.parentName,
        child.parentUsername,
        child.group,
      ].map(_normalizeSearchText).join(' ');

      final matchesSearch = query.isEmpty || values.contains(query);
      final hasUpdateToday = widget.latestUpdateByChild.containsKey(child.id);

      bool matchesStatus = true;

      if (_selectedStatusFilter == 'needUpdate') {
        matchesStatus = !hasUpdateToday;
      } else if (_selectedStatusFilter == 'updatedToday') {
        matchesStatus = hasUpdateToday;
      }

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Widget _buildSearchAndFilterBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'بحث',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            _searchQuery = '';
                          });

                          _searchFocusNode.requestFocus();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
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
                    isSelected: _selectedStatusFilter == 'all',
                    onTap: () {
                      setState(() {
                        _selectedStatusFilter = 'all';
                      });
                    },
                  ),
                  _FilterChipItem(
                    label: 'تم تحديثهم اليوم',
                    isSelected: _selectedStatusFilter == 'updatedToday',
                    onTap: () {
                      setState(() {
                        _selectedStatusFilter = 'updatedToday';
                      });
                    },
                  ),
                  _FilterChipItem(
                    label: 'يحتاج تحديث',
                    isSelected: _selectedStatusFilter == 'needUpdate',
                    onTap: () {
                      setState(() {
                        _selectedStatusFilter = 'needUpdate';
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
          Icon(
            Icons.search_off_rounded,
            size: 34,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'لا توجد نتائج.',
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

  @override
  Widget build(BuildContext context) {
    final filteredChildren = _filteredChildren();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          widget.buildMyGroupCard(),
          const SizedBox(height: 16),
          _buildSearchAndFilterBar(),
          const SizedBox(height: 16),
          if (filteredChildren.isEmpty)
            _buildEmptyChildrenState()
          else
            ...filteredChildren.map((child) {
              final latestUpdate = widget.latestUpdateByChild[child.id];
              final hasUpdateToday = latestUpdate != null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _NurseryChildDashboardCard(
                  childModel: child,
                  careStatusText: hasUpdateToday
                      ? 'تمت متابعته اليوم'
                      : 'يحتاج تحديث اليوم',
                  careStatusColor:
                      hasUpdateToday ? Colors.green : Colors.orange,
                  careStatusIcon: hasUpdateToday
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  hasUpdateToday: hasUpdateToday,
                  latestUpdateType: (latestUpdate?['type'] ?? '').toString(),
                  latestUpdateTime: latestUpdate?['time'] as Timestamp?,
                  latestUpdateNote: (latestUpdate?['note'] ?? '').toString(),
                  onAddUpdate: () => widget.onAddUpdate(child),
                  onCareLog: () => widget.onCareLog(child),
                  onHandoffLog: () => widget.onHandoffLog(child),
                  onIncidentReport: () => widget.onIncidentReport(child),
                ),
              );
            }),
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
                            '${children.length} طفل بحاجة إلى تحديث اليوم.',
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
                  label: 'إضافة تقرير متابعة',
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
  final Future<List<Map<String, dynamic>>> Function() fetchRecentNotifications;
  final Future<void> Function(String notificationId) markAsRead;

  const _NurseryNotificationsPage({
    required this.children,
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
      case 'supplies':
        return Colors.teal;
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
      case 'supplies':
        return Icons.inventory_2_outlined;
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
                else if (snapshot.hasError)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'تعذر تحميل الإشعارات. اسحب للأسفل للمحاولة مرة أخرى.',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                    ),
                  )
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