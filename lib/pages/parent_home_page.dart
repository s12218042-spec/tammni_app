import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String sectionLabel(String section) {
    return section == 'Nursery' ? 'حضانة' : 'روضة';
  }

  Future<List<ChildModel>> fetchChildren() async {
    final snapshot = await _firestore
        .collection('children')
        .where('parentUsername', isEqualTo: widget.parentUsername)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return ChildModel(
        id: doc.id,
        name: data['name'] ?? '',
        section: data['section'] ?? 'Nursery',
        group: data['group'] ?? '',
        parentName: data['parentName'] ?? '',
        parentUsername: data['parentUsername'] ?? '',
        birthDate: data['birthDate'] is Timestamp
            ? (data['birthDate'] as Timestamp).toDate()
            : DateTime.now(),
      );
    }).toList();
  }

  Future<bool> isPresentToday(String childId) async {
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month}-${now.day}';

    final snapshot = await _firestore
        .collection('attendance')
        .where('childId', isEqualTo: childId)
        .where('dateKey', isEqualTo: dateKey)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return false;

    return snapshot.docs.first.data()['present'] == true;
  }

  Future<List<Map<String, dynamic>>> fetchLastUpdates(String childId) async {
    final snapshot = await _firestore
        .collection('updates')
        .where('childId', isEqualTo: childId)
        .orderBy('time', descending: true)
        .limit(3)
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

  String timeText(dynamic rawTime) {
    if (rawTime is Timestamp) {
      final t = rawTime.toDate();
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '--:--';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChildModel>>(
      future: fetchChildren(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppPageScaffold(
            title: 'الرئيسية - ولي الأمر',
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return AppPageScaffold(
            title: 'الرئيسية - ولي الأمر',
            child: Center(
              child: Text('حدث خطأ: ${snapshot.error}'),
            ),
          );
        }

        final children = snapshot.data ?? [];

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

        final currentIndex = selectedIndex >= children.length ? 0 : selectedIndex;
        final child = children[currentIndex];
        final isNursery = child.section == 'Nursery';

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
                    value: currentIndex,
                    decoration: const InputDecoration(
                      labelText: 'اختيار الطفل',
                      prefixIcon: Icon(Icons.child_care),
                    ),
                    items: List.generate(
                      children.length,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(
                          '${children[i].name} - ${sectionLabel(children[i].section)}',
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

              if (isNursery)
                Row(
                  children: [
                    Expanded(
                      child: _QuickInfoCard(
                        title: 'نظام الحضور',
                        value: 'مرن حسب الزيارة',
                        icon: Icons.access_time,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickInfoCard(
                        title: 'القسم',
                        value: sectionLabel(child.section),
                        icon: Icons.apartment,
                      ),
                    ),
                  ],
                )
              else
                FutureBuilder<bool>(
                  future: isPresentToday(child.id),
                  builder: (context, attendanceSnapshot) {
                    final present = attendanceSnapshot.data ?? false;

                    return Row(
                      children: [
                        Expanded(
                          child: _QuickInfoCard(
                            title: 'الحضور اليوم',
                            value: present ? 'حاضر' : 'غائب',
                            icon: present ? Icons.check_circle : Icons.cancel,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickInfoCard(
                            title: 'القسم',
                            value: sectionLabel(child.section),
                            icon: Icons.apartment,
                          ),
                        ),
                      ],
                    );
                  },
                ),

              const SizedBox(height: 12),

              _QuickInfoCard(
                title: 'الصف / المجموعة',
                value: child.group.isEmpty ? 'غير محدد' : child.group,
                icon: Icons.groups,
              ),

              const SizedBox(height: 20),

              Text(
                'آخر التحديثات',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchLastUpdates(child.id),
                builder: (context, updatesSnapshot) {
                  if (updatesSnapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (updatesSnapshot.hasError) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('حدث خطأ أثناء تحميل التحديثات'),
                      ),
                    );
                  }

                  final updates = updatesSnapshot.data ?? [];

                  if (updates.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'لا يوجد تحديثات بعد.',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: updates
                        .map(
                          (u) => _UpdateTile(
                            time: timeText(u['time']),
                            text: '${u['type']}: ${u['note']}',
                          ),
                        )
                        .toList(),
                  );
                },
              ),

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
      },
    );
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