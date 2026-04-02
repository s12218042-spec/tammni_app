import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'add_update_page.dart';
import 'camera_checkin_page.dart';
import 'child_handoff_log_page.dart';
import 'incident_report_page.dart';
import 'nursery_care_log_page.dart';
import 'quick_care_update_page.dart';
import 'send_parent_notification_page.dart';

class NurseryStaffHomePage extends StatefulWidget {
  const NurseryStaffHomePage({super.key});

  @override
  State<NurseryStaffHomePage> createState() => _NurseryStaffHomePageState();
}

class _NurseryStaffHomePageState extends State<NurseryStaffHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GalleryService _galleryService = GalleryService();

  String searchQuery = '';
  String selectedStatusFilter = 'all'; // all / needUpdate / updatedToday

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
              final matchesSearch = child.name
                  .toLowerCase()
                  .contains(localSearch.toLowerCase());

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
      MaterialPageRoute(
        builder: (_) => ChildHandoffLogPage(child: child),
      ),
    );
    setState(() {});
  }

  Future<void> openIncidentReport(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncidentReportPage(child: child),
      ),
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

  Future<void> openAddUpdate(ChildModel child) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddUpdatePage(
          child: child,
          byRole: 'nursery',
        ),
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
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ التحديث بالكاميرا: $e'),
          ),
        );
      }
    }
  }

  Future<void> openQuickCareUpdate(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickCareUpdatePage(child: child),
      ),
    );
    setState(() {});
  }

  Future<void> openCareLog(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NurseryCareLogPage(child: child),
      ),
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
      final matchesSearch =
          child.name.toLowerCase().contains(searchQuery.toLowerCase());

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

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الرئيسية - موظفة الحضانة',
      child: FutureBuilder<List<ChildModel>>(
        future: fetchNurseryChildren(),
        builder: (context, childrenSnapshot) {
          if (childrenSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (childrenSnapshot.hasError) {
            return Center(
              child: Text('حدث خطأ: ${childrenSnapshot.error}'),
            );
          }

          final nurseryChildren = childrenSnapshot.data ?? [];

          return FutureBuilder<Map<String, dynamic>>(
            future: fetchTodayStats(nurseryChildren),
            builder: (context, statsSnapshot) {
              if (statsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (statsSnapshot.hasError) {
                return const Center(
                  child: Text('حدث خطأ أثناء تحميل الإحصائيات'),
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
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (extraSnapshot.hasError) {
                    return const Center(
                      child: Text('حدث خطأ أثناء تحميل بيانات الصفحة'),
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

                  final filteredChildren = applyChildrenFilters(
                    nurseryChildren,
                    latestUpdateByChild,
                  );

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
                        if (childrenNeedingUpdate.isNotEmpty)
                          const SizedBox(height: 16),
                        _buildQuickActions(nurseryChildren),
                        const SizedBox(height: 16),
                        _buildSearchAndFilterBar(),
                        const SizedBox(height: 16),
                        _buildRecentActivitiesSection(activities),
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
                                careStatusText: hasUpdateToday
                                    ? 'تمت متابعته اليوم'
                                    : 'يحتاج تحديث اليوم',
                                careStatusColor: hasUpdateToday
                                    ? Colors.green
                                    : Colors.orange,
                                careStatusIcon: hasUpdateToday
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.warning_amber_rounded,
                                hasUpdateToday: hasUpdateToday,
                                latestUpdateType:
                                    (latestUpdate?['type'] ?? '').toString(),
                                latestUpdateTime:
                                    latestUpdate?['time'] as Timestamp?,
                                latestUpdateNote:
                                    (latestUpdate?['note'] ?? '').toString(),
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
                },
              );
            },
          );
        },
      ),
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
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
        ),
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
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.secondary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'ملاحظة: تسجيل دخول وخروج أطفال الحضانة لم يعد من صلاحيات موظفات الحضانة، وأصبح من مسؤولية الإدارة فقط. دور موظفة الحضانة هنا يركز على الرعاية والتحديثات والمتابعة اليومية.',
              style: TextStyle(
                color: AppColors.textDark,
                height: 1.5,
              ),
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
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...childrenNeedingUpdate.map((child) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${child.name} يحتاج متابعة أو تحديث اليوم',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickActions(List<ChildModel> children) {
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuickActionChip(
                  icon: Icons.flash_on_rounded,
                  label: 'رعاية سريعة',
                  onTap: () async {
                    final child = await pickChild(children);
                    if (child != null) {
                      openQuickCareUpdate(child);
                    }
                  },
                ),
                _QuickActionChip(
                  icon: Icons.camera_alt_outlined,
                  label: 'كاميرا',
                  onTap: () async {
                    final child = await pickChild(children);
                    if (child != null) {
                      openCameraCheckin(child);
                    }
                  },
                ),
                _QuickActionChip(
                  icon: Icons.menu_book_outlined,
                  label: 'سجل الرعاية',
                  onTap: () async {
                    final child = await pickChild(children);
                    if (child != null) {
                      openCareLog(child);
                    }
                  },
                ),
                _QuickActionChip(
                  icon: Icons.how_to_reg_outlined,
                  label: 'تسليم/استلام',
                  onTap: () async {
                    final child = await pickChild(children);
                    if (child != null) {
                      openChildHandoffLog(child);
                    }
                  },
                ),
                _QuickActionChip(
                  icon: Icons.report_problem_outlined,
                  label: 'حادث/ملاحظة',
                  onTap: () async {
                    final child = await pickChild(children);
                    if (child != null) {
                      openIncidentReport(child);
                    }
                  },
                ),
              ],
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
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
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
                  child: const Icon(
                    Icons.child_care,
                    color: Colors.white,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasUpdateToday)
                    Text(
                      latestUpdateNote.trim().isNotEmpty
                          ? 'آخر تحديث اليوم: $latestUpdateType - ${_formatUpdateTime(latestUpdateTime)}\n$latestUpdateNote'
                          : 'آخر تحديث اليوم: $latestUpdateType - ${_formatUpdateTime(latestUpdateTime)}',
                      style: const TextStyle(
                        color: AppColors.textLight,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Container(
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
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('كاميرا'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAddUpdate,
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('تحديث'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onQuickCare,
                    icon: const Icon(Icons.flash_on_rounded),
                    label: const Text('رعاية سريعة'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCareLog,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('سجل الرعاية'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onHandoffLog,
                    icon: const Icon(Icons.how_to_reg_outlined),
                    label: const Text('تسليم/استلام'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onIncidentReport,
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('حادث/ملاحظة'),
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

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border.withOpacity(0.8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
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