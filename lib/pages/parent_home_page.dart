import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/child_model.dart';
import 'parent_updates_page.dart';
import 'weekly_report_page.dart';
import '../widgets/app_bar_widget.dart';

class ParentHomePage extends StatefulWidget {
  final String parentUsername;
  const ParentHomePage({super.key, required this.parentUsername});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final children = DummyData.childrenForParent(widget.parentUsername);

    if (children.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: const AppBarWidget(
  title: 'إدارة الأطفال',
),
          body: const Center(
            child: Text('لا يوجد أطفال مرتبطون بهذا الحساب'),
          ),
        ),
      );
    }

    final ChildModel child = children[selectedIndex >= children.length ? 0 : selectedIndex];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AppBarWidget(
  title: 'إدارة الأطفال',
),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const Text(
                'أهلًا 👋',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'هنا بتقدري تتابعي أطفالك بسهولة 💙',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                value: selectedIndex,
                decoration: const InputDecoration(
                  labelText: 'اختيار الطفل',
                  border: OutlineInputBorder(),
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

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _QuickCard(
                      title: 'الحضور',
                      value: DummyData.isPresentToday(child.id)
                          ? 'داخل المؤسسة ✅'
                          : 'غائب ❌',
                      icon: Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickCard(
                      title: 'القسم',
                      value: child.section == 'Nursery' ? 'حضانة' : 'روضة',
                      icon: Icons.apartment,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _QuickCard(
                title: 'الصف/المجموعة',
                value: child.group,
                icon: Icons.groups,
              ),

              const SizedBox(height: 20),

              const Text(
                'آخر تحديثات اليوم',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      icon: const Icon(Icons.chat),
                      label: const Text('التحديثات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E97FD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
                      icon: const Icon(Icons.description),
                      label: const Text('التقارير'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLastUpdates(String childId) {
    final updates = DummyData.updatesForChild(childId).take(3).toList();

    if (updates.isEmpty) {
      return const [
        Text('لا يوجد تحديثات اليوم بعد.',
            style: TextStyle(color: Colors.black54)),
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

class _QuickCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _QuickCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8E97FD)),
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
                Text(value, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF8E97FD).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              time,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}