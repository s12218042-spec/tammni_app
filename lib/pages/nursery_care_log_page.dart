import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

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

  String selectedFilter = 'all'; // all / care / entryExit / media

  Future<List<Map<String, dynamic>>> fetchCareLog() async {
    final updatesSnapshot = await _firestore
        .collection('updates')
        .where('childId', isEqualTo: widget.child.id)
        .get();

    final entryExitSnapshot = await _firestore
        .collection('entry_exit_logs')
        .where('childId', isEqualTo: widget.child.id)
        .get();

    final updates = updatesSnapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'source': 'update',
        'type': data['type'] ?? 'تحديث',
        'note': data['note'] ?? '',
        'time': data['time'] as Timestamp?,
        'createdAt': data['createdAt'] as Timestamp?,
        'hasMedia': data['hasMedia'] ?? false,
        'mediaType': data['mediaType'] ?? '',
        'createdByName': data['createdByName'] ?? '',
      };
    }).toList();

    final entryExit = entryExitSnapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'source': 'entry_exit',
        'type': data['eventType'] == 'entry' ? 'دخول' : 'خروج',
        'note': data['note'] ?? '',
        'time': data['time'] as Timestamp?,
        'createdAt': data['createdAt'] as Timestamp?,
        'hasMedia': false,
        'mediaType': '',
        'createdByName': data['createdByName'] ?? '',
      };
    }).toList();

    final allItems = [...updates, ...entryExit];

    allItems.sort((a, b) {
      final aTime = (a['time'] as Timestamp?) ?? (a['createdAt'] as Timestamp?);
      final bTime = (b['time'] as Timestamp?) ?? (b['createdAt'] as Timestamp?);

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return allItems;
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
      case 'دخول':
        return Icons.login_rounded;
      case 'خروج':
        return Icons.logout_rounded;
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
      case 'دخول':
        return Colors.green;
      case 'خروج':
        return Colors.redAccent;
      default:
        return AppColors.primary;
    }
  }

  String mediaLabel(bool hasMedia, String mediaType) {
    if (!hasMedia) return '';
    if (mediaType == 'video') return '• مرفق فيديو';
    return '• مرفق صورة';
  }

  List<Map<String, dynamic>> applyFilter(List<Map<String, dynamic>> items) {
    if (selectedFilter == 'care') {
      return items.where((item) => item['source'] == 'update').toList();
    }

    if (selectedFilter == 'entryExit') {
      return items.where((item) => item['source'] == 'entry_exit').toList();
    }

    if (selectedFilter == 'media') {
      return items.where((item) => item['hasMedia'] == true).toList();
    }

    return items;
  }

  Map<String, int> buildStats(List<Map<String, dynamic>> items) {
    int total = items.length;
    int careCount = 0;
    int entryExitCount = 0;
    int mediaCount = 0;

    for (final item in items) {
      if (item['source'] == 'update') careCount++;
      if (item['source'] == 'entry_exit') entryExitCount++;
      if (item['hasMedia'] == true) mediaCount++;
    }

    return {
      'total': total,
      'careCount': careCount,
      'entryExitCount': entryExitCount,
      'mediaCount': mediaCount,
    };
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

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildStatsSection(stats),
                const SizedBox(height: 16),
                _buildFilterSection(),
                const SizedBox(height: 16),
                if (filteredItems.isEmpty)
                  _buildEmptyState()
                else
                  ...filteredItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CareLogCard(
                        type: item['type'] ?? '',
                        source: item['source'] ?? '',
                        note: item['note'] ?? '',
                        createdByName: item['createdByName'] ?? '',
                        timeText: formatDateTime(
                          item['time'] ?? item['createdAt'],
                        ),
                        icon: itemIcon(item['type'] ?? ''),
                        color: itemColor(item['type'] ?? ''),
                        mediaText: mediaLabel(
                          item['hasMedia'] == true,
                          item['mediaType'] ?? '',
                        ),
                      ),
                    ),
                  ),
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
            'سجل رعاية ${widget.child.name}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'يعرض آخر ما يتعلق بالطفل من وجبات ونوم وصحة وملاحظات وصور ودخول وخروج.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Map<String, int> stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'كل السجل',
                value: '${stats['total'] ?? 0}',
                icon: Icons.list_alt_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'الرعاية',
                value: '${stats['careCount'] ?? 0}',
                icon: Icons.favorite_border_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'دخول/خروج',
                value: '${stats['entryExitCount'] ?? 0}',
                icon: Icons.swap_horiz_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'وسائط',
                value: '${stats['mediaCount'] ?? 0}',
                icon: Icons.perm_media_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChipItem(
              label: 'الكل',
              isSelected: selectedFilter == 'all',
              onTap: () {
                setState(() {
                  selectedFilter = 'all';
                });
              },
            ),
            _FilterChipItem(
              label: 'الرعاية',
              isSelected: selectedFilter == 'care',
              onTap: () {
                setState(() {
                  selectedFilter = 'care';
                });
              },
            ),
            _FilterChipItem(
              label: 'دخول/خروج',
              isSelected: selectedFilter == 'entryExit',
              onTap: () {
                setState(() {
                  selectedFilter = 'entryExit';
                });
              },
            ),
            _FilterChipItem(
              label: 'وسائط',
              isSelected: selectedFilter == 'media',
              onTap: () {
                setState(() {
                  selectedFilter = 'media';
                });
              },
            ),
          ],
        ),
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
            'لا يوجد عناصر مطابقة في سجل الرعاية',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'جرّبي تغيير الفلتر أو أضيفي أول حدث للطفل.',
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
  final String source;
  final String note;
  final String createdByName;
  final String timeText;
  final String mediaText;
  final IconData icon;
  final Color color;

  const _CareLogCard({
    required this.type,
    required this.source,
    required this.note,
    required this.createdByName,
    required this.timeText,
    required this.mediaText,
    required this.icon,
    required this.color,
  });

  String sourceLabel() {
    if (source == 'entry_exit') return 'سجل حركة';
    return 'رعاية';
  }

  Color sourceColor() {
    if (source == 'entry_exit') return Colors.blueGrey;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final noteText = note.trim().isEmpty ? 'لا توجد ملاحظة' : note;

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
                child: Text(
                  type,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: sourceColor().withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sourceLabel(),
                  style: TextStyle(
                    color: sourceColor(),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoTile(
            title: 'الوقت',
            value: timeText,
          ),
          const SizedBox(height: 10),
          _InfoTile(
            title: 'التفاصيل',
            value: mediaText.isEmpty ? noteText : '$noteText\n$mediaText',
          ),
          if (createdByName.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'أضيف بواسطة',
              value: createdByName,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTile({
    required this.title,
    required this.value,
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