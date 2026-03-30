import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'bulk_attendance_page.dart';

class DetailedAttendancePage extends StatefulWidget {
  const DetailedAttendancePage({super.key});

  @override
  State<DetailedAttendancePage> createState() => _DetailedAttendancePageState();
}

class _DetailedAttendancePageState extends State<DetailedAttendancePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> refreshPage() async {
    setState(() {});
  }

  String formatDate(dynamic time) {
    if (time is Timestamp) {
      final date = time.toDate();
      return '${date.year}/${date.month}/${date.day}';
    }
    return 'غير محدد';
  }

  Color statusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      case 'excused':
        return Colors.blue;
      default:
        return AppColors.textLight;
    }
  }

  String statusLabel(String status) {
    switch (status) {
      case 'present':
        return 'حاضر';
      case 'absent':
        return 'غائب';
      case 'late':
        return 'متأخر';
      case 'excused':
        return 'غياب مبرر';
      default:
        return 'غير محدد';
    }
  }

  IconData statusIcon(String status) {
    switch (status) {
      case 'present':
        return Icons.check_circle_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      case 'late':
        return Icons.access_time_filled_rounded;
      case 'excused':
        return Icons.info_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الحضور التفصيلي',
      actions: [
        IconButton(
          tooltip: 'إدخال حضور جماعي',
          onPressed: () async {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BulkAttendancePage(),
              ),
            );

            if (res == true) {
              setState(() {});
            }
          },
          icon: const Icon(Icons.playlist_add_check_circle_outlined),
        ),
      ],
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('attendance')
                  .where('section', isEqualTo: 'Kindergarten')
                  .orderBy('time', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل سجل الحضور',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: refreshPage,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 60),
                        _buildEmptyState(),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: refreshPage,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;

                      final childName = data['childName'] ?? 'طفل غير محدد';
                      final group = data['group'] ?? '';
                      final status = data['status'] ?? '';
                      final note = data['note'] ?? '';
                      final recordedBy = data['recordedByName'] ?? '';
                      final time = data['time'];

                      return _AttendanceCard(
                        childName: childName,
                        group: group,
                        statusText: statusLabel(status),
                        dateText: formatDate(time),
                        note: note,
                        recordedBy: recordedBy,
                        color: statusColor(status),
                        icon: statusIcon(status),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.14),
            AppColors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سجل الحضور التفصيلي',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'يمكنكِ من هنا متابعة حالة حضور الأطفال بشكل مفصل.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.fact_check_outlined,
            size: 40,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'لا يوجد سجل حضور بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'عند تسجيل الحضور سيظهر هنا مباشرة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final String childName;
  final String group;
  final String statusText;
  final String dateText;
  final String note;
  final String recordedBy;
  final Color color;
  final IconData icon;

  const _AttendanceCard({
    required this.childName,
    required this.group,
    required this.statusText,
    required this.dateText,
    required this.note,
    required this.recordedBy,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      childName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.isEmpty ? 'بدون مجموعة' : group,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoTile(title: 'التاريخ', value: dateText),
          if (recordedBy.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(title: 'تم التسجيل بواسطة', value: recordedBy),
          ],
          if (note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(title: 'ملاحظة', value: note),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTile({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}