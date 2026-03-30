import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'add_update_page.dart';
import 'camera_checkin_page.dart';
import 'entry_exit_log_page.dart';
import 'nursery_care_log_page.dart';
import 'quick_care_update_page.dart';

class NurseryStaffHomePage extends StatefulWidget {
  const NurseryStaffHomePage({super.key});

  @override
  State<NurseryStaffHomePage> createState() => _NurseryStaffHomePageState();
}

class _NurseryStaffHomePageState extends State<NurseryStaffHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GalleryService _galleryService = GalleryService();

  Future<List<ChildModel>> fetchNurseryChildren() async {
    final snapshot = await _firestore
        .collection('children')
        .where('section', isEqualTo: 'Nursery')
        .where('isActive', isEqualTo: true)
        .get();

    final children = snapshot.docs.map((doc) {
      final data = doc.data();

      return ChildModel(
        id: doc.id,
        name: data['name'] ?? '',
        section: data['section'] ?? 'Nursery',
        group: data['group'] ?? '',
        parentName: data['parentName'] ?? '',
        parentUsername: data['parentUsername'] ?? '',
        birthDate: data['birthDate'] is Timestamp
            ? (data['birthDate'] as Timestamp).toDate()
            : DateTime.now(),
      );
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
      String search = '';
      String selectedGroup = 'all';

      final groups = {
        'all',
        ...children.map((c) => c.group.isEmpty ? 'بدون مجموعة' : c.group),
      };

      return StatefulBuilder(
        builder: (context, setState) {
          List<ChildModel> filtered = children.where((child) {
            final matchesSearch =
                child.name.toLowerCase().contains(search.toLowerCase());

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

                  // 🔍 البحث
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'بحث باسم الطفل...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        search = val;
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  // 📊 الفلترة حسب المجموعة
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
                              setState(() {
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
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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

Future<List<ChildModel>> getChildrenWithoutEntryToday(List<ChildModel> children) async {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);

  final snapshot = await _firestore.collection('entry_exit_logs').get();

  final Set<String> enteredToday = {};

  for (final doc in snapshot.docs) {
    final data = doc.data();

    final Timestamp? ts = data['time'] is Timestamp
        ? data['time']
        : data['createdAt'];

    if (ts == null) continue;

    final date = ts.toDate();
    if (date.isBefore(startOfDay)) continue;

    if ((data['eventType'] ?? '') == 'entry') {
      enteredToday.add((data['childId'] ?? '').toString());
    }
  }

  return children.where((child) => !enteredToday.contains(child.id)).toList();
}

  Future<Map<String, dynamic>> fetchTodayStats(List<ChildModel> children) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final entryExitSnapshot = await _firestore.collection('entry_exit_logs').get();
    final updatesSnapshot = await _firestore
        .collection('updates')
        .where('section', isEqualTo: 'Nursery')
        .get();

    int entryCount = 0;
    int exitCount = 0;
    int careUpdatesCount = 0;
    int insideNowCount = 0;

    final childIds = children.map((e) => e.id).toSet();

    final Map<String, Map<String, dynamic>> latestLogByChild = {};

    for (final doc in entryExitSnapshot.docs) {
      final data = doc.data();
      final childId = (data['childId'] ?? '').toString();
      if (!childIds.contains(childId)) continue;

      final Timestamp? ts = data['time'] is Timestamp
          ? data['time'] as Timestamp
          : data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : null;

      if (ts == null) continue;

      final date = ts.toDate();
      final eventType = (data['eventType'] ?? '').toString();

      if (!date.isBefore(startOfDay)) {
        if (eventType == 'entry') entryCount++;
        if (eventType == 'exit') exitCount++;
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

    for (final child in children) {
      final latest = latestLogByChild[child.id];
      if (latest != null && latest['eventType'] == 'entry') {
        insideNowCount++;
      }
    }

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
    }

    return {
      'childrenCount': children.length,
      'insideNowCount': insideNowCount,
      'entryCount': entryCount,
      'exitCount': exitCount,
      'careUpdatesCount': careUpdatesCount,
      'latestLogByChild': latestLogByChild,
    };
  }

  Future<List<Map<String, dynamic>>> fetchRecentNurseryActivities() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final entryExitSnapshot = await _firestore.collection('entry_exit_logs').get();
    final updatesSnapshot = await _firestore
        .collection('updates')
        .where('section', isEqualTo: 'Nursery')
        .get();

    final List<Map<String, dynamic>> activities = [];

    for (final doc in entryExitSnapshot.docs) {
      final data = doc.data();

      if ((data['section'] ?? '').toString() != 'Nursery') continue;

      final Timestamp? ts = data['time'] is Timestamp
          ? data['time'] as Timestamp
          : data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : null;

      if (ts == null) continue;

      final date = ts.toDate();
      if (date.isBefore(startOfDay)) continue;

      final eventType = (data['eventType'] ?? '').toString();
      final childName = (data['childName'] ?? 'طفل').toString();
      final createdByName = (data['createdByName'] ?? '').toString();
      final note = (data['note'] ?? '').toString();

      activities.add({
        'time': ts,
        'title': eventType == 'entry' ? 'تم تسجيل دخول' : 'تم تسجيل خروج',
        'childName': childName,
        'subtitle': note.trim().isNotEmpty
            ? note
            : createdByName.trim().isNotEmpty
                ? 'بواسطة $createdByName'
                : '',
        'color': eventType == 'entry' ? Colors.green : Colors.red,
        'icon': eventType == 'entry'
            ? Icons.login_rounded
            : Icons.logout_rounded,
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

      final date = ts.toDate();
      if (date.isBefore(startOfDay)) continue;

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
        'icon': Icons.favorite_border_rounded,
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
        builder: (context) => AddUpdatePage(
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
          const SnackBar(
            content: Text('تم إرسال التحديث بالكاميرا'),
          ),
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

  Future<void> openEntryExitLog(ChildModel child) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryExitLogPage(child: child),
      ),
    );
    setState(() {});
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

  void sendNotificationPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ميزة إرسال الإشعار للأهل سنطوّرها لاحقًا'),
      ),
    );
  }

  String statusLabel(String? eventType) {
    if (eventType == 'entry') return 'داخل الآن';
    if (eventType == 'exit') return 'خرج';
    return 'لا يوجد سجل بعد';
  }

  Color statusColor(String? eventType) {
    if (eventType == 'entry') return Colors.green;
    if (eventType == 'exit') return Colors.red;
    return AppColors.textLight;
  }

  IconData statusIcon(String? eventType) {
    if (eventType == 'entry') return Icons.login_rounded;
    if (eventType == 'exit') return Icons.logout_rounded;
    return Icons.help_outline_rounded;
  }

  String formatTime(Timestamp? ts) {
    if (ts == null) return 'غير محدد';
    final d = ts.toDate();
    return '${d.year}/${d.month}/${d.day} - ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  // 🔴 فقط الجزء المعدل داخل build (الباقي خليه زي ما هو)

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
              return Center(
                child: Text('حدث خطأ أثناء تحميل الإحصائيات'),
              );
            }

            final stats = statsSnapshot.data ?? {};
            final latestLogByChild =
                (stats['latestLogByChild'] as Map<String, dynamic>? ?? {});

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchRecentNurseryActivities(),
              builder: (context, activitySnapshot) {
                if (activitySnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final activities = activitySnapshot.data ?? [];

                return FutureBuilder<List<ChildModel>>(
                  future: getChildrenWithoutEntryToday(nurseryChildren),
                  builder: (context, alertSnapshot) {
                    final missingChildren = alertSnapshot.data ?? [];

                    return ListView(
                      children: [
                        _buildWelcomeHeader(),

                        const SizedBox(height: 16),

                        // ⭐ تنبيهات
                        _buildAlertsSection(missingChildren),

                        const SizedBox(height: 16),

                        _buildStatsSection(stats),

                        const SizedBox(height: 16),

                        _buildQuickActions(nurseryChildren),

                        const SizedBox(height: 16),

                        _buildRecentActivitiesSection(activities),

                        const SizedBox(height: 16),

                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      AppColors.primary.withOpacity(0.12),
                                  child: const Icon(
                                    Icons.info_outline,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'في قسم الحضانة لا يتم اعتماد حضور يومي ثابت مثل الروضة، بل متابعة مرنة تعتمد على الدخول والخروج، التحديثات، الصور، وسجل الرعاية.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (nurseryChildren.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'لا يوجد أطفال نشطون في قسم الحضانة حاليًا.',
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          )
                        else
                          ...nurseryChildren.map((child) {
                            final latest =
                                latestLogByChild[child.id] as Map<String, dynamic>?;
                            final currentEventType =
                                latest?['eventType']?.toString();
                            final currentTs =
                                latest?['time'] as Timestamp?;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _NurseryChildDashboardCard(
                                childModel: child,
                                statusText: statusLabel(currentEventType),
                                statusColor: statusColor(currentEventType),
                                statusIcon: statusIcon(currentEventType),
                                lastEventTime: formatTime(currentTs),
                                onCamera: () => openCameraCheckin(child),
                                onAddUpdate: () => openAddUpdate(child),
                                onEntryExitLog: () => openEntryExitLog(child),
                                onQuickCare: () =>
                                    openQuickCareUpdate(child),
                                onCareLog: () => openCareLog(child),
                              ),
                            );
                          }),

                        const SizedBox(height: 10),

                        OutlinedButton.icon(
                          onPressed: sendNotificationPlaceholder,
                          icon: const Icon(Icons.notifications_outlined),
                          label: const Text('إرسال إشعار للأهل'),
                        ),
                      ],
                    );
                  },
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
            'تابعي أطفال الحضانة من خلال الرعاية اليومية، سجل الدخول والخروج، الصور، والملاحظات السريعة.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                  height: 1.5,
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
                title: 'داخل الآن',
                value: '${stats['insideNowCount'] ?? 0}',
                icon: Icons.how_to_reg_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'دخول اليوم',
                value: '${stats['entryCount'] ?? 0}',
                icon: Icons.login_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'خروج اليوم',
                value: '${stats['exitCount'] ?? 0}',
                icon: Icons.logout_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _StatCard(
          title: 'تحديثات اليوم',
          value: '${stats['careUpdatesCount'] ?? 0}',
          icon: Icons.favorite_border_rounded,
          fullWidth: true,
        ),
      ],
    );
  }

Widget _buildAlertsSection(List<ChildModel> missingChildren) {
  if (missingChildren.isEmpty) return const SizedBox();

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
        ...missingChildren.map((child) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '• ${child.name} لم يسجل دخول اليوم',
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
                icon: Icons.login_rounded,
                label: 'دخول وخروج',
                onTap: () async {
                  final child = await pickChild(children);
                  if (child != null) {
                    openEntryExitLog(child);
                  }
                },
              ),
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
            ],
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
            'أحدث الحركات والتحديثات الخاصة بأطفال الحضانة.',
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
}

class _NurseryChildDashboardCard extends StatelessWidget {
  final ChildModel childModel;
  final String statusText;
  final Color statusColor;
  final IconData statusIcon;
  final String lastEventTime;
  final VoidCallback onCamera;
  final VoidCallback onAddUpdate;
  final VoidCallback onEntryExitLog;
  final VoidCallback onQuickCare;
  final VoidCallback onCareLog;

  const _NurseryChildDashboardCard({
    required this.childModel,
    required this.statusText,
    required this.statusColor,
    required this.statusIcon,
    required this.lastEventTime,
    required this.onCamera,
    required this.onAddUpdate,
    required this.onEntryExitLog,
    required this.onQuickCare,
    required this.onCareLog,
  });

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
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'آخر حدث: $lastEventTime',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
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
                    onPressed: onEntryExitLog,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('الدخول/الخروج'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onQuickCare,
                    icon: const Icon(Icons.flash_on_rounded),
                    label: const Text('رعاية سريعة'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCareLog,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('سجل الرعاية'),
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
  final bool fullWidth;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
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