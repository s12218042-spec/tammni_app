import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
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

  @override
  Widget build(BuildContext context) {
    final updates = DummyData.updatesForChild(child.id);
    final top3 = updates.take(3).toList();

    return AppPageScaffold(
      title: 'التقرير الأسبوعي',
      child: ListView(
        children: [
          Text(
            'ملخص أسبوعي',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'ملخص مبسط عن حالة الطفل وآخر التحديثات المسجلة',
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
            value: child.group,
            icon: Icons.groups_outlined,
          ),
          _ReportInfoCard(
            title: 'عدد التحديثات المسجلة',
            value: '${updates.length}',
            icon: Icons.analytics_outlined,
          ),

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
                  'لا يوجد تحديثات بعد.',
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
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: const Icon(
                          Icons.notes,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${u.type}: ${u.note}',
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
                  const Expanded(
                    child: Text(
                      'ملاحظة عامة: هذا تقرير تجريبي (Demo)، ويمكن لاحقًا ربطه بقاعدة بيانات وإضافة تفاصيل أكثر مثل الحضور، النشاطات، والمهارات.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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