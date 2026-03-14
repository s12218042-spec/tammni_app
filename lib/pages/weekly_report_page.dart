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

  bool get isNursery => child.section == 'Nursery';

  Future<List<Map<String, dynamic>>> fetchWeeklyUpdates() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final snapshot = await FirebaseFirestore.instance
        .collection('updates')
        .where('childId', isEqualTo: child.id)
        .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
        .orderBy('time', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'type': data['type'] ?? '',
        'note': data['note'] ?? '',
        'time': data['time'],
      };
    }).toList();
  }

  int countType(List<Map<String, dynamic>> updates, String type) {
    return updates.where((u) => u['type'] == type).length;
  }

  @override
  Widget build(BuildContext context) {
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
          final top3 = updates.take(3).toList();

          return ListView(
            children: [
              Text(
                'ملخص أسبوعي',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'ملخص لآخر 7 أيام حول حالة الطفل والتحديثات المسجلة',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: const Icon(
                          Icons.child_care,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          child.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _ReportInfoCard(
                title: 'القسم',
                value: sectionLabel(child.section),
                icon: Icons.apartment_outlined,
              ),
              _ReportInfoCard(
                title: 'الصف / المجموعة',
                value: child.group.isEmpty ? 'غير محدد' : child.group,
                icon: Icons.groups_outlined,
              ),
              _ReportInfoCard(
                title: 'عدد تحديثات آخر 7 أيام',
                value: '${updates.length}',
                icon: Icons.analytics_outlined,
              ),

              const SizedBox(height: 18),

              Text(
                'ملخص سريع',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),

              if (isNursery) ...[
                _ReportInfoCard(
                  title: 'الوجبات',
                  value: '${countType(updates, 'وجبة')}',
                  icon: Icons.restaurant_outlined,
                ),
                _ReportInfoCard(
                  title: 'النوم',
                  value: '${countType(updates, 'نوم')}',
                  icon: Icons.bedtime_outlined,
                ),
                _ReportInfoCard(
                  title: 'الصحة',
                  value: '${countType(updates, 'صحة')}',
                  icon: Icons.health_and_safety_outlined,
                ),
                _ReportInfoCard(
                  title: 'النشاطات',
                  value: '${countType(updates, 'نشاط')}',
                  icon: Icons.celebration_outlined,
                ),
              ] else ...[
                _ReportInfoCard(
                  title: 'النشاطات',
                  value: '${countType(updates, 'نشاط')}',
                  icon: Icons.celebration_outlined,
                ),
                _ReportInfoCard(
                  title: 'الواجبات',
                  value: '${countType(updates, 'واجب')}',
                  icon: Icons.menu_book_outlined,
                ),
                _ReportInfoCard(
                  title: 'التقييمات',
                  value: '${countType(updates, 'تقييم')}',
                  icon: Icons.grading_outlined,
                ),
                _ReportInfoCard(
                  title: 'خطة اليوم',
                  value: '${countType(updates, 'خطة اليوم')}',
                  icon: Icons.today_outlined,
                ),
              ],

              const SizedBox(height: 18),

              Text(
                'أهم التحديثات',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),

              if (top3.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'لا يوجد تحديثات خلال آخر 7 أيام.',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              else
                ...top3.map(
                  (u) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                AppColors.primary.withOpacity(0.12),
                            child: const Icon(
                              Icons.notes,
                              color: AppColors.primary,
                              size: 18,
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

              const SizedBox(height: 18),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.amber.withOpacity(0.18),
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isNursery
                              ? 'هذا التقرير يعرض ملخصًا أسبوعيًا مرنًا لأطفال الحضانة اعتمادًا على التحديثات اليومية مثل الوجبات والنوم والنشاط والصحة.'
                              : 'هذا التقرير يعرض ملخصًا أسبوعيًا لأطفال الروضة اعتمادًا على التحديثات التعليمية واليومية مثل النشاطات والواجبات والتقييمات.',
                          style: const TextStyle(fontSize: 14, height: 1.5),
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

class _ReportInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ReportInfoCard({
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
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}