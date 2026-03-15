import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'gallery_page.dart';
import 'parent_updates_page.dart';
import 'weekly_report_page.dart';

class ChildProfilePage extends StatefulWidget {
  final ChildModel child;

  const ChildProfilePage({
    super.key,
    required this.child,
  });

  @override
  State<ChildProfilePage> createState() => _ChildProfilePageState();
}

class _ChildProfilePageState extends State<ChildProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String sectionLabel(String section) {
    if (section == 'Nursery') return 'حضانة';
    if (section == 'Kindergarten') return 'روضة';
    return section;
  }

  Color sectionColor(String section) {
    if (section == 'Nursery') return const Color(0xFFEFA7C8);
    if (section == 'Kindergarten') return const Color(0xFF7BB6FF);
    return AppColors.primary;
  }

  String statusLabel(String status, bool isActive) {
    if (!isActive) return 'مؤرشف';
    if (status == 'active') return 'نشط';
    if (status == 'transferred') return 'منقول';
    if (status == 'graduated') return 'متخرج';
    return 'نشط';
  }

  Color statusColor(String status, bool isActive) {
    if (!isActive) return Colors.orange;
    if (status == 'graduated') return Colors.blueGrey;
    if (status == 'transferred') return Colors.deepPurple;
    return Colors.green;
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

  String firstLetter(String name) {
    if (name.trim().isEmpty) return 'ط';
    return name.trim().substring(0, 1);
  }

  String formatDate(dynamic raw) {
    if (raw is Timestamp) {
      final date = raw.toDate();
      return '${date.year}/${date.month}/${date.day}';
    }
    return '-';
  }

  Future<Map<String, dynamic>?> fetchChildDetails() async {
    final doc = await _firestore.collection('children').doc(widget.child.id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    return {
      'id': doc.id,
      'name': data['name'] ?? widget.child.name,
      'section': data['section'] ?? widget.child.section,
      'group': data['group'] ?? widget.child.group,
      'parentName': data['parentName'] ?? widget.child.parentName,
      'parentUsername': data['parentUsername'] ?? widget.child.parentUsername,
      'birthDate': data['birthDate'] ?? Timestamp.fromDate(widget.child.birthDate),
      'isActive': data['isActive'] ?? true,
      'status': data['status'] ?? 'active',
      'createdAt': data['createdAt'],
      'updatedAt': data['updatedAt'],
      'history': (data['history'] as List?) ?? [],
    };
  }

  Future<bool> isPresentToday() async {
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month}-${now.day}';

    final snapshot = await _firestore
        .collection('attendance')
        .where('childId', isEqualTo: widget.child.id)
        .where('dateKey', isEqualTo: dateKey)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return false;
    return snapshot.docs.first.data()['present'] == true;
  }

  Future<List<Map<String, dynamic>>> fetchLastUpdates() async {
    final snapshot = await _firestore
        .collection('updates')
        .where('childId', isEqualTo: widget.child.id)
        .get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'type': data['type'] ?? '',
        'note': data['note'] ?? '',
        'time': data['time'] as Timestamp?,
        'createdAt': data['createdAt'] as Timestamp?,
      };
    }).toList();

    items.sort((a, b) {
      final aTime = (a['createdAt'] as Timestamp?) ?? (a['time'] as Timestamp?);
      final bTime = (b['createdAt'] as Timestamp?) ?? (b['time'] as Timestamp?);

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return items.take(3).toList();
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

  Widget buildHistorySection(List history) {
    if (history.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'لا يوجد سجل انتقالات بعد',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final items = history.map((e) => Map<String, dynamic>.from(e)).toList();

    return Column(
      children: items.reversed.map((item) {
        final section = (item['section'] ?? '').toString();
        final group = (item['group'] ?? '').toString();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sectionLabel(section)} • $group',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'من: ${formatDate(item['from'])}',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['to'] == null ? 'حتى الآن' : 'إلى: ${formatDate(item['to'])}',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;

    return AppPageScaffold(
      title: 'ملف الطفل',
      child: FutureBuilder<Map<String, dynamic>?>(
        future: fetchChildDetails(),
        builder: (context, childSnapshot) {
          final currentData = childSnapshot.data;

          final currentName = (currentData?['name'] ?? child.name).toString();
          final currentSection = (currentData?['section'] ?? child.section).toString();
          final currentGroup = (currentData?['group'] ?? child.group).toString();
          final currentParentName =
              (currentData?['parentName'] ?? child.parentName).toString();
          final isActive = currentData?['isActive'] ?? true;
          final status = (currentData?['status'] ?? 'active').toString();
          final history = (currentData?['history'] as List?) ?? [];
          final birthDateRaw = currentData?['birthDate'];
          final currentBirthDate = birthDateRaw is Timestamp
              ? birthDateRaw.toDate()
              : child.birthDate;

          final badgeColor = sectionColor(currentSection);
          final currentStatusColor = statusColor(status, isActive);

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
                            'متابعة مخصصة لكل ما يتعلق بالطفل',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        statusLabel(status, isActive),
                        style: const TextStyle(
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
                            child: _ProfileInfoBox(
                              icon: Icons.cake_outlined,
                              title: 'العمر',
                              value: childAgeText(currentBirthDate),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ProfileInfoBox(
                              icon: Icons.groups_outlined,
                              title: 'المجموعة الحالية',
                              value: currentGroup.isEmpty ? 'غير محدد' : currentGroup,
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
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: currentStatusColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.check_circle_outline
                                  : Icons.archive_outlined,
                              color: currentStatusColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'الحالة الحالية: ${statusLabel(status, isActive)}',
                              style: TextStyle(
                                color: currentStatusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ولي الأمر: ${currentParentName.isEmpty ? "غير محدد" : currentParentName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
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
              if (currentSection == 'Kindergarten')
                FutureBuilder<bool>(
                  future: isPresentToday(),
                  builder: (context, snapshot) {
                    final present = snapshot.data ?? false;
                    return _StatusCard(
                      icon: present ? Icons.check_circle : Icons.cancel_outlined,
                      color: present ? Colors.green : Colors.redAccent,
                      title: 'الحضور اليوم',
                      value: present ? 'حاضر' : 'غائب',
                    );
                  },
                )
              else
                const _StatusCard(
                  icon: Icons.info_outline,
                  color: AppColors.primary,
                  title: 'نظام المتابعة',
                  value: 'مرن حسب الزيارة والتحديثات',
                ),
              const SizedBox(height: 18),
              Text(
                'آخر التحديثات',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchLastUpdates(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('حدث خطأ أثناء تحميل التحديثات'),
                      ),
                    );
                  }

                  final updates = snapshot.data ?? [];

                  if (updates.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'لا توجد تحديثات مسجلة لهذا الطفل بعد',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: updates
                        .map(
                          (u) => _RecentUpdateTile(
                            time: timeText(u['time'] ?? u['createdAt']),
                            type: (u['type'] ?? '').toString(),
                            note: (u['note'] ?? '').toString(),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                'سجل القسم والمجموعة',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              buildHistorySection(history),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ParentUpdatesPage(child: child),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('كل التحديثات'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WeeklyReportPage(child: child),
                          ),
                        );
                      },
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('التقرير الأسبوعي'),
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GalleryPage(child: child),
                      ),
                    );
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('معرض الصور'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileInfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProfileInfoBox({
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

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _StatusCard({
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
                  fontSize: 15,
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

class _RecentUpdateTile extends StatelessWidget {
  final String time;
  final String type;
  final String note;

  const _RecentUpdateTile({
    required this.time,
    required this.type,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$type: $note',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
