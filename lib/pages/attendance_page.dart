import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AttendancePage extends StatefulWidget {
  final String sectionFilter; // Nursery / Kindergarten / All

  const AttendancePage({
    super.key,
    this.sectionFilter = 'All',
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<ChildModel> get list {
    if (widget.sectionFilter == 'All') return DummyData.children;
    return DummyData.children
        .where((c) => c.section == widget.sectionFilter)
        .toList();
  }

  String sectionLabel(String section) {
    switch (section) {
      case 'Nursery':
        return 'حضانة';
      case 'Kindergarten':
        return 'روضة';
      default:
        return 'الكل';
    }
  }

  String pageDescription() {
    if (widget.sectionFilter == 'All') {
      return 'عرض وتسجيل حضور جميع الأطفال';
    }
    return 'عرض وتسجيل حضور أطفال قسم ${sectionLabel(widget.sectionFilter)}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateText = '${today.year}/${today.month}/${today.day}';

    return AppPageScaffold(
      title: 'تسجيل الحضور',
      child: ListView(
        children: [
          Text(
            'الحضور اليومي',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            pageDescription(),
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
                      Icons.calendar_today_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تاريخ اليوم: $dateText',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: const Icon(
                      Icons.filter_list,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.sectionFilter == 'All'
                          ? 'يتم الآن عرض جميع الأطفال'
                          : 'القسم الحالي: ${sectionLabel(widget.sectionFilter)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (list.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'لا يوجد أطفال في هذا القسم حاليًا.',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 15,
                  ),
                ),
              ),
            )
          else
            ...list.map(
              (child) => _AttendanceChildCard(
                child: child,
                isPresent: DummyData.isPresentToday(child.id),
                sectionText: sectionLabel(child.section),
                onChanged: (value) {
                  setState(() {
                    DummyData.setPresentToday(child.id, value);
                  });
                },
              ),
            ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم حفظ الحضور ✅'),
                ),
              );
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('حفظ الحضور'),
          ),
        ],
      ),
    );
  }
}

class _AttendanceChildCard extends StatelessWidget {
  final ChildModel child;
  final bool isPresent;
  final String sectionText;
  final ValueChanged<bool> onChanged;

  const _AttendanceChildCard({
    required this.child,
    required this.isPresent,
    required this.sectionText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: const Icon(
                Icons.child_care,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$sectionText • ${child.group}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: isPresent,
                  onChanged: onChanged,
                ),
                Text(
                  isPresent ? 'حاضر' : 'غائب',
                  style: TextStyle(
                    fontSize: 12,
                    color: isPresent ? Colors.green : Colors.redAccent,
                    fontWeight: FontWeight.w600,
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