import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'gallery_page.dart';
import 'parent_handoff_log_page.dart';
import 'parent_incident_reports_page.dart';
import 'parent_nursery_log_page.dart';
import 'parent_updates_page.dart';
import 'weekly_report_page.dart';

class ChildProfilePage extends StatefulWidget {
  final ChildModel child;

  const ChildProfilePage({
    super.key,
    required this.child,
  });

  @override
  State<ChildProfilePage> createState() => _ChildProfilePageState();
}

class _ChildProfilePageState extends State<ChildProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int selectedTabIndex = 0;

  String sectionLabel(String section) {
    if (section == 'Nursery') return 'حضانة';
    if (section == 'Kindergarten') return 'روضة';
    return section;
  }

  Color sectionColor(String section) {
    if (section == 'Nursery') return const Color(0xFFEFA7C8);
    if (section == 'Kindergarten') return const Color(0xFF7BB6FF);
    return AppColors.primary;
  }

  String statusLabel(String status, bool isActive) {
    if (!isActive) return 'مؤرشف';
    if (status == 'active') return 'نشط';
    if (status == 'transferred') return 'منقول';
    if (status == 'graduated') return 'متخرج';
    return 'نشط';
  }

  Color statusColor(String status, bool isActive) {
    if (!isActive) return Colors.orange;
    if (status == 'graduated') return Colors.blueGrey;
    if (status == 'transferred') return Colors.deepPurple;
    return Colors.green;
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

    if (years <= 0) {
      return '$months شهر';
    }
    if (months == 0) {
      return '$years سنة';
    }
    return '$years سنة و $months شهر';
  }

  String firstLetter(String name) {
    if (name.trim().isEmpty) return 'ط';
    return name.trim().substring(0, 1).toUpperCase();
  }

  String formatDate(dynamic raw) {
    if (raw is Timestamp) {
      final date = raw.toDate();
      return '${date.year}/${date.month}/${date.day}';
    }
    return '-';
  }

  String timeText(dynamic rawTime) {
    if (rawTime is Timestamp) {
      final t = rawTime.toDate();
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '--:--';
  }

  String _resolveNote(Map<String, dynamic> data) {
    final candidates = [
      data['note'],
      data['message'],
      data['body'],
      data['description'],
      data['details'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  String _resolveType(Map<String, dynamic> data) {
    final candidates = [
      data['type'],
      data['updateType'],
      data['category'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return 'تحديث';
  }

  Timestamp? _resolveTimestamp(Map<String, dynamic> data) {
    final candidates = [
      data['time'],
      data['createdAt'],
      data['timestamp'],
      data['updatedAt'],
    ];

    for (final value in candidates) {
      if (value is Timestamp) return value;
    }

    return null;
  }

  bool _isUsableRemoteUrl(String value) {
  final trimmed = value.trim().toLowerCase();
  return trimmed.startsWith('http://') || trimmed.startsWith('https://');
}

String _resolveMediaUrl(Map<String, dynamic> data) {
  final directUrl = (data['mediaUrl'] ?? '').toString().trim();
  if (_isUsableRemoteUrl(directUrl)) return directUrl;

  final mediaUrls = data['mediaUrls'];
  if (mediaUrls is List && mediaUrls.isNotEmpty) {
    for (final item in mediaUrls) {
      final candidate = item?.toString().trim() ?? '';
      if (_isUsableRemoteUrl(candidate)) return candidate;
    }
  }

  return '';
}

String _resolveMediaPath(Map<String, dynamic> data) {
  final path = (data['mediaPath'] ?? '').toString().trim();

  if (path.startsWith('blob:')) return '';
  return path;
}

String _resolveMediaType(Map<String, dynamic> data) {
  final mediaType = (data['mediaType'] ?? '').toString().trim().toLowerCase();
  if (mediaType.isNotEmpty) return mediaType;

  final mediaUrl = _resolveMediaUrl(data).toLowerCase();
  final mediaPath = _resolveMediaPath(data).toLowerCase();
  final source = mediaUrl.isNotEmpty ? mediaUrl : mediaPath;

  if (source.endsWith('.mp4') ||
      source.endsWith('.mov') ||
      source.endsWith('.avi') ||
      source.endsWith('.mkv') ||
      source.contains('video')) {
    return 'video';
  }

  if (source.endsWith('.jpg') ||
      source.endsWith('.jpeg') ||
      source.endsWith('.png') ||
      source.endsWith('.webp') ||
      source.contains('image')) {
    return 'image';
  }

  return '';
}

  Future<Map<String, dynamic>?> fetchChildDetails() async {
    final doc = await _firestore.collection('children').doc(widget.child.id).get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    return {
      'id': doc.id,
      'name': data['name'] ?? widget.child.name,
      'section': data['section'] ?? widget.child.section,
      'group': data['group'] ?? widget.child.group,
      'birthDate': data['birthDate'] ??
          (widget.child.birthDate != null
              ? Timestamp.fromDate(widget.child.birthDate!)
              : null),
      'isActive': data['isActive'] ?? true,
      'status': data['status'] ?? 'active',
      'createdAt': data['createdAt'],
      'updatedAt': data['updatedAt'],
    };
  }

  Future<List<Map<String, dynamic>>> fetchLastUpdates() async {
    final snapshot = await _firestore
        .collection('updates')
        .where('childId', isEqualTo: widget.child.id)
        .get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();
      final displayTime = _resolveTimestamp(data);

      return {
        'type': _resolveType(data),
        'note': _resolveNote(data),
        'displayTime': displayTime,
      };
    }).toList();

    items.sort((a, b) {
      final aTime = a['displayTime'] as Timestamp?;
      final bTime = b['displayTime'] as Timestamp?;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return items.take(3).toList();
  }

  Future<List<Map<String, dynamic>>> fetchLatestMedia() async {
  final snapshot = await _firestore
      .collection('updates')
      .where('childId', isEqualTo: widget.child.id)
      .get();

  final items = <Map<String, dynamic>>[];

  for (final doc in snapshot.docs) {
    final data = doc.data();

    final mediaUrl = _resolveMediaUrl(data);
    final mediaPath = _resolveMediaPath(data);
    final mediaType = _resolveMediaType(data);
    final displayTime = _resolveTimestamp(data);

    final resolvedSource = mediaUrl.isNotEmpty ? mediaUrl : mediaPath;

    final hasAnyMedia = resolvedSource.isNotEmpty && mediaType.isNotEmpty;

    if (hasAnyMedia) {
      items.add({
        'mediaUrl': mediaUrl,
        'mediaPath': mediaPath,
        'resolvedSource': resolvedSource,
        'mediaType': mediaType,
        'note': _resolveNote(data),
        'type': _resolveType(data),
        'displayTime': displayTime,
      });
    }
  }

  items.sort((a, b) {
    final aTime = a['displayTime'] as Timestamp?;
    final bTime = b['displayTime'] as Timestamp?;

    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;

    return bTime.compareTo(aTime);
  });

  return items.take(4).toList();
}

  List<_ProfileTabItem> getTabs(String currentSection) {
    if (currentSection == 'Nursery') {
      return const [
        _ProfileTabItem(label: 'نظرة عامة', icon: Icons.dashboard_outlined),
        _ProfileTabItem(label: 'التحديثات', icon: Icons.notifications_none_outlined),
        _ProfileTabItem(label: 'السجلات', icon: Icons.assignment_outlined),
        _ProfileTabItem(label: 'الوسائط', icon: Icons.photo_library_outlined),
      ];
    }

    return const [
      _ProfileTabItem(label: 'نظرة عامة', icon: Icons.dashboard_outlined),
      _ProfileTabItem(label: 'التحديثات', icon: Icons.notifications_none_outlined),
      _ProfileTabItem(label: 'التقرير', icon: Icons.description_outlined),
      _ProfileTabItem(label: 'الوسائط', icon: Icons.photo_library_outlined),
    ];
  }

  Widget buildTabBar(List<_ProfileTabItem> tabs) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = tabs[index];
          final selected = selectedTabIndex == index;

          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                selectedTabIndex = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.14),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 18,
                    color: selected ? Colors.white : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildOverviewTab({
    required String currentName,
    required String currentSection,
    required String currentGroup,
    required DateTime? currentBirthDate,
    required bool isActive,
    required String status,
    required Color badgeColor,
    required Color currentStatusColor,
  }) {
    return ListView(
      children: [
        const _ProfileSectionHeader(
          title: 'النظرة العامة',
          icon: Icons.dashboard_outlined,
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ProfileInfoBox(
                        icon: Icons.cake_outlined,
                        title: 'العمر',
                        value: childAgeText(currentBirthDate),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProfileInfoBox(
                        icon: Icons.groups_outlined,
                        title: 'المجموعة الحالية',
                        value: currentSection == 'Nursery'
                            ? 'غير مطبق'
                            : (currentGroup.isEmpty ? 'غير محدد' : currentGroup),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.apartment_outlined, color: badgeColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'القسم الحالي: ${sectionLabel(currentSection)}',
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: currentStatusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isActive
                            ? Icons.check_circle_outline
                            : Icons.archive_outlined,
                        color: currentStatusColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الحالة الحالية: ${statusLabel(status, isActive)}',
                          style: TextStyle(
                            color: currentStatusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _ProfileSectionHeader(
          title: 'آخر التحديثات',
          icon: Icons.notifications_none_outlined,
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchLastUpdates(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('حدث خطأ أثناء تحميل التحديثات'),
                ),
              );
            }

            final updates = snapshot.data ?? [];

            if (updates.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'لا توجد تحديثات مسجلة لهذا الطفل بعد',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 15,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: updates
                  .map(
                    (u) => _RecentUpdateTile(
                      time: timeText(u['displayTime']),
                      type: (u['type'] ?? '').toString(),
                      note: (u['note'] ?? '').toString(),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        const _ProfileSectionHeader(
          title: 'الوسائط',
          icon: Icons.photo_library_outlined,
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchLatestMedia(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('حدث خطأ أثناء تحميل الوسائط'),
                ),
              );
            }

            final mediaItems = snapshot.data ?? [];

            if (mediaItems.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'لا توجد وسائط مضافة بعد',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GalleryPage(child: widget.child),
                              ),
                            );
                          },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('فتح معرض الصور'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                ...mediaItems.map(
                  (item) => _MediaPreviewTile(
                    type: (item['mediaType'] ?? '').toString(),
                    note: (item['note'] ?? '').toString(),
                    time: timeText(item['displayTime']),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GalleryPage(child: widget.child),
                        ),
                      );
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('فتح معرض الصور'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget buildUpdatesTab(ChildModel child) {
    return ListView(
      children: [
        const _ProfileSectionHeader(
          title: 'التحديثات',
          icon: Icons.notifications_none_outlined,
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const _ActionIntroBox(
                  title: 'كل التحديثات',
                  subtitle: 'الوصول إلى جميع تحديثات الطفل اليومية بشكل منظم وواضح.',
                  icon: Icons.notifications_active_outlined,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ParentUpdatesPage(child: child),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('فتح كل التحديثات'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _ProfileSectionHeader(
          title: 'آخر التحديثات المختصرة',
          icon: Icons.history_rounded,
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchLastUpdates(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('حدث خطأ أثناء تحميل التحديثات'),
                ),
              );
            }

            final updates = snapshot.data ?? [];

            if (updates.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'لا توجد تحديثات مسجلة لهذا الطفل بعد',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                ),
              );
            }

            return Column(
              children: updates
                  .map(
                    (u) => _RecentUpdateTile(
                      time: timeText(u['displayTime']),
                      type: (u['type'] ?? '').toString(),
                      note: (u['note'] ?? '').toString(),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget buildNurseryRecordsTab(ChildModel child) {
    return ListView(
      children: [
        const _ProfileSectionHeader(
          title: 'السجلات الإدارية',
          icon: Icons.assignment_outlined,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionFeatureCard(
                title: 'السجل الإداري للدخول والخروج',
                subtitle: 'مراجعة أوقات الدخول والخروج الموثقة',
                icon: Icons.login_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ParentNurseryLogPage(child: child),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionFeatureCard(
                title: 'سجل الاستلام والتسليم',
                subtitle: 'متابعة عمليات الاستلام والتسليم',
                icon: Icons.how_to_reg_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ParentHandoffLogPage(child: child),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ActionFeatureCard(
          title: 'بلاغات الحوادث',
          subtitle: 'الاطلاع على الحوادث والملاحظات المهمة',
          icon: Icons.report_problem_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ParentIncidentReportsPage(child: child),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget buildReportTab(ChildModel child) {
    return ListView(
      children: [
        const _ProfileSectionHeader(
          title: 'التقرير الأسبوعي',
          icon: Icons.description_outlined,
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const _ActionIntroBox(
                  title: 'التقرير الأسبوعي',
                  subtitle: 'عرض ملخص أسبوعي منظم لمتابعة الطفل وأنشطته.',
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WeeklyReportPage(child: child),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('فتح التقرير الأسبوعي'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMediaTab(ChildModel child) {
    return ListView(
      children: [
        const _ProfileSectionHeader(
          title: 'الوسائط',
          icon: Icons.photo_library_outlined,
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchLatestMedia(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('حدث خطأ أثناء تحميل الوسائط'),
                ),
              );
            }

            final mediaItems = snapshot.data ?? [];

            if (mediaItems.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const _ActionIntroBox(
                        title: 'معرض الصور',
                        subtitle: 'لا توجد وسائط مضافة بعد لهذا الطفل.',
                        icon: Icons.photo_library_outlined,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GalleryPage(child: child),
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('فتح معرض الصور'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                ...mediaItems.map(
                  (item) => _MediaPreviewTile(
                    type: (item['mediaType'] ?? '').toString(),
                    note: (item['note'] ?? '').toString(),
                    time: timeText(item['displayTime']),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GalleryPage(child: child),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('فتح معرض الصور'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget buildCurrentTabBody({
    required String currentSection,
    required String currentName,
    required String currentGroup,
    required DateTime? currentBirthDate,
    required bool isActive,
    required String status,
    required Color badgeColor,
    required Color currentStatusColor,
    required ChildModel child,
  }) {
    if (currentSection == 'Nursery') {
      switch (selectedTabIndex) {
        case 0:
          return buildOverviewTab(
            currentName: currentName,
            currentSection: currentSection,
            currentGroup: currentGroup,
            currentBirthDate: currentBirthDate,
            isActive: isActive,
            status: status,
            badgeColor: badgeColor,
            currentStatusColor: currentStatusColor,
          );
        case 1:
          return buildUpdatesTab(child);
        case 2:
          return buildNurseryRecordsTab(child);
        case 3:
          return buildMediaTab(child);
        default:
          return buildOverviewTab(
            currentName: currentName,
            currentSection: currentSection,
            currentGroup: currentGroup,
            currentBirthDate: currentBirthDate,
            isActive: isActive,
            status: status,
            badgeColor: badgeColor,
            currentStatusColor: currentStatusColor,
          );
      }
    }

    switch (selectedTabIndex) {
      case 0:
        return buildOverviewTab(
          currentName: currentName,
          currentSection: currentSection,
          currentGroup: currentGroup,
          currentBirthDate: currentBirthDate,
          isActive: isActive,
          status: status,
          badgeColor: badgeColor,
          currentStatusColor: currentStatusColor,
        );
      case 1:
        return buildUpdatesTab(child);
      case 2:
        return buildReportTab(child);
      case 3:
        return buildMediaTab(child);
      default:
        return buildOverviewTab(
          currentName: currentName,
          currentSection: currentSection,
          currentGroup: currentGroup,
          currentBirthDate: currentBirthDate,
          isActive: isActive,
          status: status,
          badgeColor: badgeColor,
          currentStatusColor: currentStatusColor,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;

    return AppPageScaffold(
      title: 'ملف الطفل',
      child: FutureBuilder<Map<String, dynamic>?>(
        future: fetchChildDetails(),
        builder: (context, childSnapshot) {
          final currentData = childSnapshot.data;
          final currentName = (currentData?['name'] ?? child.name).toString();
          final currentSection =
              (currentData?['section'] ?? child.section).toString();
          final currentGroup = (currentData?['group'] ?? child.group).toString();
          final isActive = currentData?['isActive'] ?? true;
          final status = (currentData?['status'] ?? 'active').toString();
          final birthDateRaw = currentData?['birthDate'];
          final currentBirthDate =
              birthDateRaw is Timestamp ? birthDateRaw.toDate() : child.birthDate;

          final badgeColor = sectionColor(currentSection);
          final currentStatusColor = statusColor(status, isActive);
          final tabs = getTabs(currentSection);

          if (selectedTabIndex >= tabs.length) {
            selectedTabIndex = 0;
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.18),
                      child: Text(
                        firstLetter(currentName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'متابعة منظمة لكل ما يتعلق بالطفل',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 13.5,
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
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        sectionLabel(currentSection),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              buildTabBar(tabs),
              const SizedBox(height: 16),
              Expanded(
                child: buildCurrentTabBody(
                  currentSection: currentSection,
                  currentName: currentName,
                  currentGroup: currentGroup,
                  currentBirthDate: currentBirthDate,
                  isActive: isActive,
                  status: status,
                  badgeColor: badgeColor,
                  currentStatusColor: currentStatusColor,
                  child: child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileTabItem {
  final String label;
  final IconData icon;

  const _ProfileTabItem({
    required this.label,
    required this.icon,
  });
}

class _ProfileSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _ProfileSectionHeader({
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

class _ProfileInfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProfileInfoBox({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentUpdateTile extends StatelessWidget {
  final String time;
  final String type;
  final String note;

  const _RecentUpdateTile({
    required this.time,
    required this.type,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final displayType = type.trim().isEmpty ? 'تحديث' : type;
    final displayText = note.trim().isEmpty ? displayType : '$displayType: $note';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayText,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreviewTile extends StatelessWidget {
  final String type;
  final String note;
  final String time;

  const _MediaPreviewTile({
    required this.type,
    required this.note,
    required this.time,
  });

  IconData _iconForType() {
    if (type.toLowerCase().contains('video')) {
      return Icons.videocam_outlined;
    }
    return Icons.image_outlined;
  }

  String _labelForType() {
    if (type.toLowerCase().contains('video')) {
      return 'فيديو';
    }
    return 'صورة';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Icon(_iconForType(), color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelForType(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.isEmpty ? 'وسائط مضافة للطفل' : note,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIntroBox extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ActionIntroBox({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 13,
                    height: 1.35,
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

class _ActionFeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withOpacity(0.16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}