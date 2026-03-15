import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'child_profile_page.dart';
import 'parent_chats_page.dart';
import 'parent_updates_page.dart';
import 'weekly_report_page.dart';
import '../services/message_service.dart';


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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MessageService _messageService = MessageService();

  String sectionLabel(String section) {
    return section == 'Nursery' ? 'حضانة' : 'روضة';
  }

  Color sectionColor(String section) {
    return section == 'Nursery'
        ? const Color(0xFFEFA7C8)
        : const Color(0xFF7BB6FF);
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
        .get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'type': data['type'] ?? '',
        'note': data['note'] ?? '',
        'time': data['time'],
        'createdAt': data['createdAt'],
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

    return items.take(2).toList();
  }

  String firstLetter(String name) {
    if (name.trim().isEmpty) return 'ط';
    return name.trim().substring(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChildModel>>(
      future: fetchChildren(),
      builder: (context, snapshot) {
        return AppPageScaffold(
          title: 'الرئيسية - ولي الأمر',
          actions: [
  StreamBuilder<int>(
    stream: _messageService.getUnreadMessagesCountForParent(
      parentUsername: widget.parentUsername,
    ),
    builder: (context, unreadSnapshot) {
      final unreadCount = unreadSnapshot.data ?? 0;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'المراسلات',
            onPressed: snapshot.connectionState == ConnectionState.waiting
                ? null
                : () {
                    final children = snapshot.data ?? [];

                    if (children.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'لا توجد محادثات متاحة لأنه لا يوجد أطفال مرتبطون بهذا الحساب',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ParentChatsPage(children: children),
                      ),
                    );
                  },
          ),
          if (unreadCount > 0)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  ),
],

          child: Builder(
            builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('حدث خطأ أثناء تحميل البيانات: ${snapshot.error}'),
                );
              }

              final children = snapshot.data ?? [];

              if (children.isEmpty) {
                return ListView(
                  children: [
                    _WelcomeHeader(parentUsername: widget.parentUsername),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.12),
                              child: const Icon(
                                Icons.child_care,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'لا يوجد أطفال مرتبطون بهذا الحساب',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'يمكنك مراجعة الإدارة لإضافة الأطفال وربطهم بحساب ولي الأمر.',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView(
                children: [
                  _WelcomeHeader(parentUsername: widget.parentUsername),
                  const SizedBox(height: 16),
                  _SummaryCard(
                    totalChildren: children.length,
                    nurseryCount:
                        children.where((c) => c.section == 'Nursery').length,
                    kgCount: children
                        .where((c) => c.section == 'Kindergarten')
                        .length,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'أطفالي',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...children.map(
                    (child) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ChildDashboardCard(
                        childModel: child,
                        sectionText: sectionLabel(child.section),
                        sectionBadgeColor: sectionColor(child.section),
                        ageText: childAgeText(child.birthDate),
                        letter: firstLetter(child.name),
                        attendanceFuture: child.section == 'Kindergarten'
                            ? isPresentToday(child.id)
                            : null,
                        updatesFuture: fetchLastUpdates(child.id),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  final String parentUsername;

  const _WelcomeHeader({
    required this.parentUsername,
  });

  String greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 18) return 'مساء الخير';
    return 'أهلًا بك';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${greetingText()} ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يسعدنا متابعتك لأطفالك بكل سهولة واطمئنان',
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'اسم المستخدم: $parentUsername',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalChildren;
  final int nurseryCount;
  final int kgCount;

  const _SummaryCard({
    required this.totalChildren,
    required this.nurseryCount,
    required this.kgCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _MiniStatItem(
                title: 'إجمالي الأطفال',
                value: '$totalChildren',
                icon: Icons.child_friendly,
              ),
            ),
            Expanded(
              child: _MiniStatItem(
                title: 'الحضانة',
                value: '$nurseryCount',
                icon: Icons.baby_changing_station,
              ),
            ),
            Expanded(
              child: _MiniStatItem(
                title: 'الروضة',
                value: '$kgCount',
                icon: Icons.menu_book_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniStatItem({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
          style: const TextStyle(
            color: AppColors.textLight,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ChildDashboardCard extends StatelessWidget {
  final ChildModel childModel;
  final String sectionText;
  final Color sectionBadgeColor;
  final String ageText;
  final String letter;
  final Future<bool>? attendanceFuture;
  final Future<List<Map<String, dynamic>>> updatesFuture;

  const _ChildDashboardCard({
    required this.childModel,
    required this.sectionText,
    required this.sectionBadgeColor,
    required this.ageText,
    required this.letter,
    required this.attendanceFuture,
    required this.updatesFuture,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: sectionBadgeColor.withOpacity(0.18),
                  child: Text(
                    letter,
                    style: TextStyle(
                      color: sectionBadgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        childModel.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'العمر: $ageText',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sectionBadgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    sectionText,
                    style: TextStyle(
                      color: sectionBadgeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InfoPill(
                    icon: Icons.groups_2_outlined,
                    text: childModel.group.isEmpty
                        ? 'لا توجد مجموعة'
                        : childModel.group,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (childModel.section == 'Kindergarten')
              FutureBuilder<bool>(
                future: attendanceFuture,
                builder: (context, snapshot) {
                  final present = snapshot.data ?? false;
                  return _StatusBox(
                    icon: present ? Icons.check_circle : Icons.cancel_outlined,
                    color: present ? Colors.green : Colors.redAccent,
                    title: 'الحضور اليوم',
                    value: present ? 'حاضر' : 'غائب',
                  );
                },
              )
            else
              const _StatusBox(
                icon: Icons.info_outline,
                color: AppColors.primary,
                title: 'نظام المتابعة',
                value: 'مرن حسب الزيارة والتحديثات',
              ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'آخر التحديثات',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: updatesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final updates = snapshot.data ?? [];

                if (updates.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'لا يوجد تحديثات بعد',
                      style: TextStyle(
                        color: AppColors.textLight,
                      ),
                    ),
                  );
                }

                return Column(
                  children: updates.map((u) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                              _timeText(u['time'] ?? u['createdAt']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${u['type']}: ${u['note']}',
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChildProfilePage(child: childModel),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text('ملف الطفل'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ParentUpdatesPage(child: childModel),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('التحديثات'),
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
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WeeklyReportPage(child: childModel),
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
          ],
        ),
      ),
    );
  }

  static String _timeText(dynamic rawTime) {
    if (rawTime is Timestamp) {
      final t = rawTime.toDate();
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '--:--';
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _StatusBox({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.14),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$title: $value',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color == AppColors.primary ? AppColors.textDark : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
