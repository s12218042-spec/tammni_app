import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'parent_updates_page.dart';
import 'weekly_report_page.dart';

class ParentHomePage extends StatefulWidget {
  final String parentUsername;

  const ParentHomePage({
    super.key,
    required this.parentUsername,
  });

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final children = DummyData.childrenForParent(widget.parentUsername);

    if (children.isEmpty) {
      return const AppPageScaffold(
        title: 'الرئيسية - ولي الأمر',
        child: Center(
          child: Text(
            'لا يوجد أطفال مرتبطون بهذا الحساب',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final ChildModel child =
        children[selectedIndex >= children.length ? 0 : selectedIndex];

    return AppPageScaffold(
      title: 'الرئيسية - ولي الأمر',
      child: ListView(
        children: [
          Text(
            'أهلًا 👋',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'هنا يمكنك متابعة أطفالك بسهولة واطمئنان',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<int>(
                value: selectedIndex,
                decoration: const InputDecoration(
                  labelText: 'اختيار الطفل',
                  prefixIcon: Icon(Icons.child_care),
                ),
                items: List.generate(
                  children.length,
                  (i) => DropdownMenuItem(
                    value: i,
                    child: Text(
                      '${children[i].name} - ${children[i].section == "Nursery" ? "حضانة" : "روضة"}',
                    ),
                  ),
                ),
                onChanged: (v) {
                  setState(() {
                    selectedIndex = v ?? 0;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _QuickInfoCard(
                  title: 'الحضور',
                  value: DummyData.isPresentToday(child.id)
                      ? 'داخل المؤسسة ✅'
                      : 'غائب ❌',
                  icon: Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickInfoCard(
                  title: 'القسم',
                  value: child.section == 'Nursery' ? 'حضانة' : 'روضة',
                  icon: Icons.apartment,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _QuickInfoCard(
            title: 'الصف / المجموعة',
            value: child.group,
            icon: Icons.groups,
          ),

          const SizedBox(height: 20),

          Text(
            'آخر تحديثات اليوم',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),

          ..._buildLastUpdates(child.id),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParentUpdatesPage(child: child),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('التحديثات'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WeeklyReportPage(child: child),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('التقارير'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLastUpdates(String childId) {
    final updates = DummyData.updatesForChild(childId).take(3).toList();

    if (updates.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'لا يوجد تحديثات اليوم بعد.',
              style: TextStyle(color: AppColors.textLight),
            ),
          ),
        ),
      ];
    }

    String timeText(DateTime t) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    return updates
        .map(
          (u) => _UpdateTile(
            time: timeText(u.time),
            text: '${u.type}: ${u.note}',
          ),
        )
        .toList();
  }
}

class _QuickInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _QuickInfoCard({
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
              radius: 22,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Icon(
                icon,
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
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  final String time;
  final String text;

  const _UpdateTile({
    required this.time,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text),
            ),
          ],
        ),
      ),
    );
  }
}