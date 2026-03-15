import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class WeeklyReportPage extends StatefulWidget {
  final ChildModel child;

  const WeeklyReportPage({
    super.key,
    required this.child,
  });

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String sectionLabel(String section) {
    if (section == 'Nursery') return 'حضانة';
    if (section == 'Kindergarten') return 'روضة';
    return section;
  }

  Color sectionColor(String section) {
    return section == 'Nursery'
        ? const Color(0xFFEFA7C8)
        : const Color(0xFF7BB6FF);
  }

  String firstLetter(String name) {
    if (name.trim().isEmpty) return 'ط';
    return name.trim().substring(0, 1);
  }

  String childAgeText(DateTime birthDate) {
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

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '--/--';
    final t = timestamp.toDate();
    return '${t.year}/${t.month}/${t.day}';
  }

  Future<Map<String, dynamic>?> fetchChildDetails() async {
    final doc = await _firestore.collection('children').doc(widget.child.id).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return {
      'name': data['name'] ?? widget.child.name,
      'section': data['section'] ?? widget.child.section,
      'group': data['group'] ?? widget.child.group,
      'birthDate': data['birthDate'] ?? Timestamp.fromDate(widget.child.birthDate),
      'isActive': data['isActive'] ?? true,
      'status': data['status'] ?? 'active',
    };
  }

Future<List<Map<String, dynamic>>> fetchWeeklyUpdates() async {
  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 6));

  final snapshot = await _firestore
      .collection('updates')
      .where('childId', isEqualTo: widget.child.id)
      .get();

  final items = snapshot.docs.map((doc) {
    final data = doc.data();
    return {
      'id': doc.id,
      'type': data['type'] ?? '',
      'note': data['note'] ?? '',
      'time': data['time'] as Timestamp?,
      'createdAt': data['createdAt'] as Timestamp?,
    };
  }).where((item) {
    final ts =
        (item['time'] as Timestamp?) ?? (item['createdAt'] as Timestamp?);

    if (ts == null) return false;

    return !ts.toDate().isBefore(startDate);
  }).toList();

  items.sort((a, b) {
    final aTime = (a['time'] as Timestamp?) ?? (a['createdAt'] as Timestamp?);
    final bTime = (b['time'] as Timestamp?) ?? (b['createdAt'] as Timestamp?);

    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;

    return bTime.compareTo(aTime);
  });

  return items;
}


  Future<int> fetchWeeklyAttendanceCount() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));

    final snapshot = await _firestore
        .collection('attendance')
        .where('childId', isEqualTo: widget.child.id)
        .get();

    int count = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final dateKey = (data['dateKey'] ?? '').toString();
      final present = data['present'] == true;

      if (!present || dateKey.isEmpty) continue;

      final parts = dateKey.split('-');
      if (parts.length != 3) continue;

      final date = DateTime(
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 0,
        int.tryParse(parts[2]) ?? 0,
      );

      if (!date.isBefore(start)) {
        count++;
      }
    }

    return count;
  }

  int countByTypes(List<Map<String, dynamic>> updates, List<String> types) {
    return updates.where((u) => types.contains((u['type'] ?? '').toString())).length;
  }

  Map<String, int> buildTypeMap(List<Map<String, dynamic>> updates) {
    final map = <String, int>{};

    for (final u in updates) {
      final type = (u['type'] ?? 'غير محدد').toString();
      map[type] = (map[type] ?? 0) + 1;
    }

    return map;
  }

  String topTypeText(List<Map<String, dynamic>> updates) {
    if (updates.isEmpty) return 'لا يوجد';
    final map = buildTypeMap(updates);
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;

    return AppPageScaffold(
      title: 'التقرير الأسبوعي',
      child: FutureBuilder<Map<String, dynamic>?>(
        future: fetchChildDetails(),
        builder: (context, childSnapshot) {
          final currentData = childSnapshot.data;
          final currentName = (currentData?['name'] ?? child.name).toString();
          final currentSection =
              (currentData?['section'] ?? child.section).toString();
          final currentGroup = (currentData?['group'] ?? child.group).toString();
          final currentBirthRaw = currentData?['birthDate'];
          final currentBirthDate = currentBirthRaw is Timestamp
              ? currentBirthRaw.toDate()
              : child.birthDate;
          final isActive = currentData?['isActive'] ?? true;

          final badgeColor = sectionColor(currentSection);

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchWeeklyUpdates(),
            builder: (context, updatesSnapshot) {
              if (updatesSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (updatesSnapshot.hasError) {
                return const Center(
                  child: Text('حدث خطأ أثناء تحميل التقرير'),
                );
              }

              final updates = updatesSnapshot.data ?? [];

              final mealsCount = countByTypes(updates, ['وجبة']);
              final sleepCount = countByTypes(updates, ['نوم']);
              final healthCount = countByTypes(updates, ['صحة']);
              final activitiesCount = countByTypes(updates, ['نشاط']);
              final homeworkCount = countByTypes(updates, ['واجب']);
              final evaluationCount = countByTypes(updates, ['تقييم']);
              final planCount = countByTypes(updates, ['خطة اليوم']);
              final cameraCount = countByTypes(updates, ['كاميرا']);

              return ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.secondary,
                        ],
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
                                'ملخص آخر 7 أيام للطفل',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'مؤرشف',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _InfoMiniCard(
                                  icon: Icons.cake_outlined,
                                  title: 'العمر',
                                  value: childAgeText(currentBirthDate),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _InfoMiniCard(
                                  icon: Icons.groups_outlined,
                                  title: 'المجموعة',
                                  value: currentGroup.isEmpty
                                      ? 'غير محدد'
                                      : currentGroup,
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
                                Icon(
                                  Icons.apartment_outlined,
                                  color: badgeColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'القسم الحالي: ${sectionLabel(currentSection)}',
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ملخص الأسبوع',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'كل التحديثات',
                          value: '${updates.length}',
                          icon: Icons.notifications_none,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          title: 'الأكثر تكرارًا',
                          value: topTypeText(updates),
                          icon: Icons.insights_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (currentSection == 'Kindergarten')
                    FutureBuilder<int>(
                      future: fetchWeeklyAttendanceCount(),
                      builder: (context, attendanceSnapshot) {
                        final attendance = attendanceSnapshot.data ?? 0;
                        return _WideInfoCard(
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                          title: 'الحضور خلال آخر 7 أيام',
                          value: '$attendance أيام حضور',
                        );
                      },
                    )
                  else
                    const _WideInfoCard(
                      icon: Icons.info_outline,
                      color: AppColors.primary,
                      title: 'نظام المتابعة',
                      value: 'الحضانة تعتمد على الزيارات والتحديثات وليس الحضور اليومي الثابت',
                    ),
                  const SizedBox(height: 18),
                  Text(
                    currentSection == 'Nursery'
                        ? 'تفاصيل الحضانة'
                        : 'تفاصيل الروضة',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (currentSection == 'Nursery') ...[
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'الوجبات',
                            value: '$mealsCount',
                            icon: Icons.restaurant_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            title: 'النوم',
                            value: '$sleepCount',
                            icon: Icons.bedtime_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'الصحة',
                            value: '$healthCount',
                            icon: Icons.health_and_safety_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            title: 'الأنشطة',
                            value: '$activitiesCount',
                            icon: Icons.toys_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _WideInfoCard(
                      icon: Icons.camera_alt_outlined,
                      color: AppColors.secondary,
                      title: 'وسائط الكاميرا',
                      value: '$cameraCount مرفقات هذا الأسبوع',
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'الأنشطة',
                            value: '$activitiesCount',
                            icon: Icons.toys_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            title: 'الواجبات',
                            value: '$homeworkCount',
                            icon: Icons.menu_book_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'التقييمات',
                            value: '$evaluationCount',
                            icon: Icons.star_outline,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            title: 'خطة اليوم',
                            value: '$planCount',
                            icon: Icons.event_note_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'أحدث تحديثات الأسبوع',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (updates.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.12),
                              child: const Icon(
                                Icons.description_outlined,
                                color: AppColors.primary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'لا توجد بيانات أسبوعية بعد',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...updates.take(5).map(
                      (u) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
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
                                  formatDate((u['time'] as Timestamp?) ??
                                      (u['createdAt'] as Timestamp?)),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${u['type']}: ${u['note']}',
                                  style: const TextStyle(fontSize: 14),
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
          );
        },
      ),
    );
  }
}

class _InfoMiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoMiniCard({
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
            child: Icon(
              icon,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 13,
            ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideInfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _WideInfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.14),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$title: $value',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: color == AppColors.primary ? AppColors.textDark : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
