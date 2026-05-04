import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

bool isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

bool isThisWeek(DateTime date) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = startOfToday.difference(target).inDays;
  return diff >= 0 && diff <= 7;
}

class NurseryCareLogPage extends StatefulWidget {
  final ChildModel child;

  const NurseryCareLogPage({
    super.key,
    required this.child,
  });

  @override
  State<NurseryCareLogPage> createState() => _NurseryCareLogPageState();
}

class _NurseryCareLogPageState extends State<NurseryCareLogPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedTypeFilter = 'all';
  String selectedDateFilter = 'all';

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

    return 'ملاحظة';
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

  String _resolveCreatedByName(Map<String, dynamic> data) {
    final candidates = [
      data['createdByName'],
      data['senderName'],
      data['byName'],
      data['staffName'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  Timestamp? _resolveTimestamp(Map<String, dynamic> data) {
    final candidates = [
      data['eventAt'],
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

  bool _resolveHasMedia(Map<String, dynamic> data) {
    final mediaUrl = (data['mediaUrl'] ?? '').toString().trim();
    final mediaPath = (data['mediaPath'] ?? '').toString().trim();
    final mediaUrls = data['mediaUrls'];

    return data['hasMedia'] == true ||
        mediaUrl.isNotEmpty ||
        mediaPath.isNotEmpty ||
        (mediaUrls is List && mediaUrls.isNotEmpty);
  }

  String _resolveMediaType(Map<String, dynamic> data) {
    final directType = (data['mediaType'] ?? '').toString().trim().toLowerCase();
    if (directType.isNotEmpty) return directType;

    final mediaUrl = (data['mediaUrl'] ?? '').toString().trim().toLowerCase();
    final mediaPath = (data['mediaPath'] ?? '').toString().trim().toLowerCase();
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

  Future<List<Map<String, dynamic>>> fetchCareLog() async {
    final updatesSnapshot = await _firestore
        .collection('updates')
        .where('childId', isEqualTo: widget.child.id)
        .get();

    final updates = updatesSnapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'source': 'update',
        'type': _resolveType(data),
        'note': _resolveNote(data),
        'displayTime': _resolveTimestamp(data),
        'hasMedia': _resolveHasMedia(data),
        'mediaType': _resolveMediaType(data),
        'createdByName': _resolveCreatedByName(data),
      };
    }).toList();

    updates.sort((a, b) {
      final aTime = a['displayTime'] as Timestamp?;
      final bTime = b['displayTime'] as Timestamp?;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return updates;
  }

  Future<void> refreshPage() async {
    if (!mounted) return;
    setState(() {});
  }

  String formatDateTime(dynamic rawTime) {
    if (rawTime is Timestamp) {
      final t = rawTime.toDate();
      final y = t.year;
      final m = t.month.toString().padLeft(2, '0');
      final d = t.day.toString().padLeft(2, '0');
      final h = t.hour.toString().padLeft(2, '0');
      final min = t.minute.toString().padLeft(2, '0');
      return '$y/$m/$d - $h:$min';
    }
    return 'غير محدد';
  }

  String itemTypeLabel(String type) {
    switch (type) {
      case 'وجبة':
        return 'وجبة';
      case 'نوم':
        return 'نوم';
      case 'حفاض':
        return 'حفاض';
      case 'صحة':
        return 'صحة';
      case 'نشاط':
        return 'نشاط';
      case 'ملاحظة':
        return 'ملاحظة';
      case 'وسائط':
        return 'وسائط';
      default:
        return type.isEmpty ? 'ملاحظة' : type;
    }
  }

  IconData itemIcon(String type) {
    switch (type) {
      case 'وجبة':
        return Icons.restaurant_outlined;
      case 'نوم':
        return Icons.bedtime_outlined;
      case 'حفاض':
        return Icons.child_friendly_outlined;
      case 'صحة':
        return Icons.health_and_safety_outlined;
      case 'نشاط':
        return Icons.palette_outlined;
      case 'ملاحظة':
        return Icons.edit_note_outlined;
      case 'كاميرا':
        return Icons.photo_camera_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  Color itemColor(String type) {
    switch (type) {
      case 'وجبة':
        return const Color(0xFFFFB74D);
      case 'نوم':
        return const Color(0xFF9575CD);
      case 'حفاض':
        return const Color(0xFF4FC3F7);
      case 'صحة':
        return AppColors.success;
      case 'نشاط':
        return AppColors.primary;
      case 'ملاحظة':
        return AppColors.textLight;
      case 'كاميرا':
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  List<Map<String, dynamic>> applyFilter(List<Map<String, dynamic>> items) {
    List<Map<String, dynamic>> result = List.from(items);

    if (selectedTypeFilter != 'all') {
      result = result.where((item) {
        final itemType = (item['type'] ?? '').toString();
        return itemType == selectedTypeFilter;
      }).toList();
    }

    if (selectedDateFilter != 'all') {
      result = result.where((item) {
        final ts = item['displayTime'] as Timestamp?;
        if (ts == null) return false;

        final date = ts.toDate();

        if (selectedDateFilter == 'today') {
          return isToday(date);
        }

        if (selectedDateFilter == 'week') {
          return isThisWeek(date) && !isToday(date);
        }

        if (selectedDateFilter == 'older') {
          return !isThisWeek(date);
        }

        return true;
      }).toList();
    }

    return result;
  }

  Map<String, int> buildStats(List<Map<String, dynamic>> items) {
    int total = items.length;
    int todayCount = 0;

    for (final item in items) {
      final ts = item['displayTime'] as Timestamp?;
      final date = ts?.toDate();

      if (date != null && isToday(date)) {
        todayCount++;
      }
    }

    return {
      'total': total,
      'todayCount': todayCount,
    };
  }

  bool isNewItem(Map<String, dynamic> item) {
    final ts = item['displayTime'] as Timestamp?;
    if (ts == null) return false;
    return isToday(ts.toDate());
  }

  List<Map<String, dynamic>> getTodayItems(List<Map<String, dynamic>> items) {
    return items.where((item) {
      final ts = item['displayTime'] as Timestamp?;
      if (ts == null) return false;
      return isToday(ts.toDate());
    }).toList();
  }

  List<Map<String, dynamic>> getPreviousItems(List<Map<String, dynamic>> items) {
    return items.where((item) {
      final ts = item['displayTime'] as Timestamp?;
      if (ts == null) return true;
      return !isToday(ts.toDate());
    }).toList();
  }

  void clearFilters() {
    setState(() {
      selectedTypeFilter = 'all';
      selectedDateFilter = 'all';
    });
  }

  String dateFilterLabel(String value) {
    switch (value) {
      case 'today':
        return 'اليوم';
      case 'week':
        return 'هذا الأسبوع';
      case 'older':
        return 'الأقدم';
      default:
        return 'كل الأوقات';
    }
  }

  IconData dateFilterIcon(String value) {
    switch (value) {
      case 'today':
        return Icons.today_rounded;
      case 'week':
        return Icons.date_range_rounded;
      case 'older':
        return Icons.archive_outlined;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'سجل الرعاية',
      child: RefreshIndicator(
        onRefresh: refreshPage,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchCareLog(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل سجل الرعاية',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              );
            }

            final allItems = snapshot.data ?? [];
            final stats = buildStats(allItems);
            final filteredItems = applyFilter(allItems);
            final todayItems = getTodayItems(filteredItems);
            final previousItems = getPreviousItems(filteredItems);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildInfoNotice(),
                const SizedBox(height: 18),
                _buildStatsSection(stats),
                const SizedBox(height: 16),
                _buildTypeFilterSection(),
                const SizedBox(height: 12),
                _buildDateFilterSection(),
                const SizedBox(height: 12),
                _buildActiveFiltersSummary(),
                const SizedBox(height: 16),
                if (filteredItems.isEmpty) ...[
                  _buildEmptyState(),
                ] else ...[
                  _buildSectionHeader(
                    title: 'سجلات اليوم',
                    subtitle: 'كل السجلات التي تمت إضافتها اليوم',
                    icon: Icons.wb_sunny_outlined,
                  ),
                  const SizedBox(height: 12),
                  if (todayItems.isEmpty)
                    _buildMiniEmptyState('لا توجد سجلات اليوم')
                  else
                    ...todayItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CareLogCard(
                          type: itemTypeLabel(item['type'] ?? ''),
                          note: item['note'] ?? '',
                          createdByName: item['createdByName'] ?? '',
                          timeText: formatDateTime(item['displayTime']),
                          icon: itemIcon(item['type'] ?? ''),
                          color: itemColor(item['type'] ?? ''),
                          isNew: true,
                          hasMedia: item['hasMedia'] == true,
                          mediaType: (item['mediaType'] ?? '').toString(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  _buildSectionHeader(
                    title: 'السجلات السابقة',
                    subtitle: 'كل السجلات الأقدم بحسب الفلاتر المختارة',
                    icon: Icons.history_rounded,
                  ),
                  const SizedBox(height: 12),
                  if (previousItems.isEmpty)
                    _buildMiniEmptyState('لا توجد سجلات سابقة مطابقة')
                  else
                    ...previousItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CareLogCard(
                          type: itemTypeLabel(item['type'] ?? ''),
                          note: item['note'] ?? '',
                          createdByName: item['createdByName'] ?? '',
                          timeText: formatDateTime(item['displayTime']),
                          icon: itemIcon(item['type'] ?? ''),
                          color: itemColor(item['type'] ?? ''),
                          isNew: isNewItem(item),
                          hasMedia: item['hasMedia'] == true,
                          mediaType: (item['mediaType'] ?? '').toString(),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.16),
            AppColors.secondary.withOpacity(0.12),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'سجل رعاية ${widget.child.name}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'عرض منظم ومريح لمتابعة رعاية الطفل اليومية، مع فلاتر أوضح وسجلات مرتبة بشكل أسهل.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
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
              'ملاحظة: هذا السجل خاص بالرعاية اليومية فقط، أما تسجيل الدخول والخروج فهو إداري وليس جزءًا من سجل الرعاية.',
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

  Widget _buildStatsSection(Map<String, int> stats) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'كل السجلات',
            value: '${stats['total'] ?? 0}',
            icon: Icons.list_alt_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: 'اليوم',
            value: '${stats['todayCount'] ?? 0}',
            icon: Icons.today_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeFilterSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.tune_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'فلترة حسب نوع السجل',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TypeFilterChipItem(
                label: 'الكل',
                icon: Icons.apps_rounded,
                color: AppColors.primary,
                isSelected: selectedTypeFilter == 'all',
                onTap: () {
                  setState(() {
                    selectedTypeFilter = 'all';
                  });
                },
              ),
              _TypeFilterChipItem(
                label: 'وجبة',
                icon: Icons.restaurant_outlined,
                color: const Color(0xFFFFB74D),
                isSelected: selectedTypeFilter == 'وجبة',
                onTap: () {
                  setState(() {
                    selectedTypeFilter = 'وجبة';
                  });
                },
              ),
              _TypeFilterChipItem(
                label: 'نوم',
                icon: Icons.bedtime_outlined,
                color: const Color(0xFF9575CD),
                isSelected: selectedTypeFilter == 'نوم',
                onTap: () {
                  setState(() {
                    selectedTypeFilter = 'نوم';
                  });
                },
              ),
              _TypeFilterChipItem(
                label: 'حفاض',
                icon: Icons.child_friendly_outlined,
                color: const Color(0xFF4FC3F7),
                isSelected: selectedTypeFilter == 'حفاض',
                onTap: () {
                  setState(() {
                    selectedTypeFilter = 'حفاض';
                  });
                },
              ),
              _TypeFilterChipItem(
                label: 'صحة',
                icon: Icons.health_and_safety_outlined,
                color: AppColors.success,
                isSelected: selectedTypeFilter == 'صحة',
                onTap: () {
                  setState(() {
                    selectedTypeFilter = 'صحة';
                  });
                },
              ),
              _TypeFilterChipItem(
                label: 'نشاط',
                icon: Icons.palette_outlined,
                color: AppColors.primary,
                isSelected: selectedTypeFilter == 'نشاط',
                onTap: () {
                  setState(() {
                    selectedTypeFilter = 'نشاط';
                  });
                },
              ),
              _TypeFilterChipItem(
                label: 'ملاحظة',
                icon: Icons.edit_note_outlined,
                color: AppColors.textLight,
                isSelected: selectedTypeFilter == 'ملاحظة',
                onTap: () {
                  setState(() {
                    selectedTypeFilter = 'ملاحظة';
                  });
                },
              ),
              _TypeFilterChipItem(
                label: 'كاميرا',
                icon: Icons.photo_camera_outlined,
                color: AppColors.secondary,
                isSelected: selectedTypeFilter == 'كاميرا',
                onTap: () {
                  setState(() {
                    selectedTypeFilter = 'كاميرا';
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: AppColors.secondary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'فلترة حسب الوقت',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChipItem(
                label: 'الكل',
                icon: Icons.apps_rounded,
                isSelected: selectedDateFilter == 'all',
                onTap: () {
                  setState(() {
                    selectedDateFilter = 'all';
                  });
                },
              ),
              _FilterChipItem(
                label: 'اليوم',
                icon: Icons.today_rounded,
                isSelected: selectedDateFilter == 'today',
                onTap: () {
                  setState(() {
                    selectedDateFilter = 'today';
                  });
                },
              ),
              _FilterChipItem(
                label: 'هذا الأسبوع',
                icon: Icons.date_range_rounded,
                isSelected: selectedDateFilter == 'week',
                onTap: () {
                  setState(() {
                    selectedDateFilter = 'week';
                  });
                },
              ),
              _FilterChipItem(
                label: 'الأقدم',
                icon: Icons.archive_outlined,
                isSelected: selectedDateFilter == 'older',
                onTap: () {
                  setState(() {
                    selectedDateFilter = 'older';
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersSummary() {
    final hasFilters =
        selectedTypeFilter != 'all' || selectedDateFilter != 'all';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasFilters ? AppColors.primary.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasFilters
              ? AppColors.primary.withOpacity(0.16)
              : AppColors.border.withOpacity(0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFilters
                    ? Icons.filter_alt_rounded
                    : Icons.filter_alt_off_rounded,
                color: hasFilters ? AppColors.primary : AppColors.textLight,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                hasFilters ? 'الفلاتر النشطة' : 'لا توجد فلاتر مفعلة',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color:
                      hasFilters ? AppColors.textDark : AppColors.textLight,
                ),
              ),
              const Spacer(),
              if (hasFilters)
                TextButton.icon(
                  onPressed: clearFilters,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('مسح'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
          if (hasFilters) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (selectedTypeFilter != 'all')
                  _Badge(
                    text: itemTypeLabel(selectedTypeFilter),
                    background: itemColor(selectedTypeFilter).withOpacity(0.10),
                    foreground: itemColor(selectedTypeFilter),
                  ),
                if (selectedDateFilter != 'all')
                  _Badge(
                    text: dateFilterLabel(selectedDateFilter),
                    background: AppColors.secondary.withOpacity(0.10),
                    foreground: AppColors.secondary,
                    icon: dateFilterIcon(selectedDateFilter),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
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
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniEmptyState(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 40,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'لا توجد سجلات مطابقة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'جرّبي تغيير نوع الفلترة أو وقت السجل.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CareLogCard extends StatelessWidget {
  final String type;
  final String note;
  final String createdByName;
  final String timeText;
  final IconData icon;
  final Color color;
  final bool isNew;
  final bool hasMedia;
  final String mediaType;

  const _CareLogCard({
    required this.type,
    required this.note,
    required this.createdByName,
    required this.timeText,
    required this.icon,
    required this.color,
    required this.isNew,
    required this.hasMedia,
    required this.mediaType,
  });

  @override
  Widget build(BuildContext context) {
    final noteText = note.trim().isEmpty ? 'لا توجد ملاحظة' : note;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNew ? color.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isNew
              ? color.withOpacity(0.28)
              : AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Badge(
                          text: type,
                          background: color.withOpacity(0.10),
                          foreground: color,
                        ),
                        if (isNew)
                          _Badge(
                            text: 'جديد',
                            background: AppColors.success.withOpacity(0.10),
                            foreground: AppColors.success,
                          ),
                        if (hasMedia)
                          _Badge(
                            text: mediaType == 'video' ? 'فيديو' : 'وسائط',
                            background: AppColors.secondary.withOpacity(0.10),
                            foreground: AppColors.secondary,
                            icon: mediaType == 'video'
                                ? Icons.videocam_outlined
                                : Icons.image_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoTile(
            title: 'الوقت',
            value: timeText,
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(height: 10),
          _InfoTile(
            title: 'التفاصيل',
            value: noteText,
            icon: Icons.notes_rounded,
          ),
          if (createdByName.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'أضيف بواسطة',
              value: createdByName,
              icon: Icons.person_outline_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const _Badge({
    required this.text,
    required this.background,
    required this.foreground,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: foreground,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
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
      width: double.infinity,
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

class _FilterChipItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? AppColors.primary : AppColors.textLight,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withOpacity(0.15),
      backgroundColor: AppColors.background,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textDark,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.primary.withOpacity(0.30)
            : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _TypeFilterChipItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeFilterChipItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.10) : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.35) : AppColors.border,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : AppColors.textLight,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}