import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class WeeklyReportPage extends StatelessWidget {
  final ChildModel child;

  const WeeklyReportPage({
    super.key,
    required this.child,
  });

  String sectionLabel(String s) {
    if (s == 'Nursery') return 'حضانة';
    if (s == 'Kindergarten') return 'روضة';
    return s;
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

  String timeText(Timestamp? timestamp) {
    if (timestamp == null) return '--:--';
    final t = timestamp.toDate();
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String dateText(Timestamp? timestamp) {
    if (timestamp == null) return '--/--/----';
    final t = timestamp.toDate();
    return '${t.year}/${t.month}/${t.day}';
  }

  Future<List<Map<String, dynamic>>> fetchWeeklyUpdates() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final snapshot = await FirebaseFirestore.instance
        .collection('updates')
        .where('childId', isEqualTo: child.id)
        .get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'type': data['type'] ?? '',
        'note': data['note'] ?? '',
        'time': data['time'] as Timestamp?,
        'createdAt': data['createdAt'] as Timestamp?,
        'byRole': data['byRole'] ?? '',
      };
    }).where((item) {
      final ts = (item['createdAt'] as Timestamp?) ?? (item['time'] as Timestamp?);
      if (ts == null) return false;
      return ts.toDate().isAfter(sevenDaysAgo) ||
          ts.toDate().isAtSameMomentAs(sevenDaysAgo);
    }).toList();

    items.sort((a, b) {
      final aTime = (a['createdAt'] as Timestamp?) ?? (a['time'] as Timestamp?);
      final bTime = (b['createdAt'] as Timestamp?) ?? (b['time'] as Timestamp?);

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return items;
  }

  Future<int> fetchWeeklyAttendanceCount() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('childId', isEqualTo: child.id)
        .get();

    int count = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final present = data['present'] == true;
      final Timestamp? dateTs = data['date'] as Timestamp?;

      if (present && dateTs != null) {
        final date = dateTs.toDate();
        if (date.isAfter(sevenDaysAgo) || date.isAtSameMomentAs(sevenDaysAgo)) {
          count++;
        }
      }
    }

    return count;
  }

  Map<String, int> buildTypeCounts(List<Map<String, dynamic>> updates) {
    final Map<String, int> counts = {};

    for (final update in updates) {
      final type = (update['type'] ?? '').toString().trim();
      if (type.isEmpty) continue;
      counts[type] = (counts[type] ?? 0) + 1;
    }

    return counts;
  }

  int countTypes(List<Map<String, dynamic>> updates, List<String> targets) {
    int total = 0;
    for (final update in updates) {
      final type = (update['type'] ?? '').toString().trim();
      if (targets.contains(type)) {
        total++;
      }
    }
    return total;
  }

  List<MapEntry<String, int>> topTypes(Map<String, int> counts) {
    final entries = counts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).toList();
  }

  String reportHintBySection() {
    if (child.section == 'Nursery') {
      return 'يركز هذا الملخص على الرعاية اليومية، الأنشطة، النوم، الوجبات، والصحة خلال آخر 7 أيام.';
    }
    return 'يركز هذا الملخص على الحضور، الأنشطة، الواجبات، التقييمات، وخطة اليوم خلال آخر 7 أيام.';
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = sectionColor(child.section);

    return AppPageScaffold(
      title: 'التقرير الأسبوعي',
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchWeeklyUpdates(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ: ${snapshot.error}'),
            );
          }

          final updates = snapshot.data ?? [];
          final counts = buildTypeCounts(updates);
          final topThree = topTypes(counts);

          final nurseryMeals = countTypes(updates, ['وجبة']);
          final nurserySleep = countTypes(updates, ['نوم']);
          final nurseryHealth = countTypes(updates, ['صحة']);
          final nurseryActivities = countTypes(updates, ['نشاط', 'كاميرا']);

          final kgActivities = countTypes(updates, ['نشاط', 'خطة اليوم']);
          final kgHomework = countTypes(updates, ['واجب']);
          final kgEvaluation = countTypes(updates, ['تقييم']);

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
                        firstLetter(child.name),
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
                            child.name,
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
                            child: _ReportInfoMiniCard(
                              icon: Icons.cake_outlined,
                              title: 'العمر',
                              value: childAgeText(child.birthDate),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ReportInfoMiniCard(
                              icon: Icons.groups_outlined,
                              title: 'المجموعة',
                              value: child.group.isEmpty ? 'غير محدد' : child.group,
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
                              'القسم: ${sectionLabel(child.section)}',
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
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: const Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          reportHintBySection(),
                          style: const TextStyle(fontSize: 14.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'ملخص أسبوعي سريع',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          title: 'إجمالي التحديثات',
                          value: '${updates.length}',
                          icon: Icons.analytics_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          title: 'الأنواع المسجلة',
                          value: '${counts.length}',
                          icon: Icons.category_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                child.section == 'Nursery'
                    ? 'مؤشرات الحضانة'
                    : 'مؤشرات الروضة',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              if (child.section == 'Nursery')
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SectionMetricCard(
                            title: 'الوجبات',
                            value: '$nurseryMeals',
                            icon: Icons.restaurant_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SectionMetricCard(
                            title: 'النوم',
                            value: '$nurserySleep',
                            icon: Icons.bedtime_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SectionMetricCard(
                            title: 'الصحة',
                            value: '$nurseryHealth',
                            icon: Icons.health_and_safety_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SectionMetricCard(
                            title: 'الأنشطة',
                            value: '$nurseryActivities',
                            icon: Icons.toys_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    FutureBuilder<int>(
                      future: fetchWeeklyAttendanceCount(),
                      builder: (context, attendanceSnapshot) {
                        final attendanceCount = attendanceSnapshot.data ?? 0;

                        return Row(
                          children: [
                            Expanded(
                              child: _SectionMetricCard(
                                title: 'الحضور',
                                value: '$attendanceCount',
                                icon: Icons.how_to_reg_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SectionMetricCard(
                                title: 'الأنشطة',
                                value: '$kgActivities',
                                icon: Icons.event_note_outlined,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SectionMetricCard(
                            title: 'الواجبات',
                            value: '$kgHomework',
                            icon: Icons.menu_book_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SectionMetricCard(
                            title: 'التقييمات',
                            value: '$kgEvaluation',
                            icon: Icons.star_outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              Text(
                'أكثر التحديثات تكرارًا',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              if (topThree.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'لا توجد بيانات كافية لعرض الأنواع الأكثر تكرارًا',
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                )
              else
                ...topThree.map(
                  (entry) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.12),
                            child: const Icon(
                              Icons.bar_chart_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                'آخر التحديثات الأسبوعية',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              if (updates.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primary.withOpacity(0.12),
                          child: const Icon(
                            Icons.description_outlined,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'لا توجد تحديثات أسبوعية لهذا الطفل بعد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'عند إضافة تحديثات جديدة خلال الأسبوع ستظهر هنا بشكل منظم.',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 13.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...updates.take(5).map(
                  (u) {
                    final Timestamp? displayTime =
                        (u['time'] as Timestamp?) ??
                        (u['createdAt'] as Timestamp?);

                    return _WeeklyUpdateTile(
                      type: u['type'] ?? '',
                      note: u['note'] ?? '',
                      date: dateText(displayTime),
                      time: timeText(displayTime),
                    );
                  },
                ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.amber.withOpacity(0.18),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          child.section == 'Nursery'
                              ? 'يعتمد هذا التقرير على التحديثات المسجلة خلال آخر 7 أيام، ويمكن تطويره لاحقًا ليشمل ملخصًا أدق للنوم، التغذية، الزيارات، والصور.'
                              : 'يعتمد هذا التقرير على التحديثات المسجلة خلال آخر 7 أيام بالإضافة إلى الحضور الأسبوعي، ويمكن تطويره لاحقًا ليشمل تفاصيل تعليمية أوسع.',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
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

class _ReportInfoMiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ReportInfoMiniCard({
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

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatBox({
    required this.title,
    required this.value,
    required this.icon,
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
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
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
    );
  }
}

class _SectionMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SectionMetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Icon(
                icon,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyUpdateTile extends StatelessWidget {
  final String type;
  final String note;
  final String date;
  final String time;

  const _WeeklyUpdateTile({
    required this.type,
    required this.note,
    required this.date,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                    type.isEmpty ? 'تحديث' : type,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    date,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    time,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              note.trim().isEmpty ? 'لا توجد ملاحظة مضافة لهذا التحديث' : note,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
