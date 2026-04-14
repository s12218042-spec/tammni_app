import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentAttendanceDetailsPage extends StatelessWidget {
  final ChildModel child;

  const ParentAttendanceDetailsPage({
    super.key,
    required this.child,
  });

  String _safeText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  Timestamp? _resolveTimestamp(Map<String, dynamic> data) {
    final candidates = [
      data['updatedAt'],
      data['time'],
      data['createdAt'],
    ];

    for (final value in candidates) {
      if (value is Timestamp) return value;
    }

    return null;
  }

  String _resolveStatus(Map<String, dynamic> data) {
    final explicitStatus = _safeText(data['status']).toLowerCase();

    if (explicitStatus.isNotEmpty) {
      switch (explicitStatus) {
        case 'present':
          return 'present';
        case 'absent':
          return 'absent';
        case 'late':
          return 'late';
        case 'excused':
          return 'excused';
      }
    }

    final present = data['present'];
    if (present == true) return 'present';
    if (present == false) return 'absent';

    return 'غير_محدد';
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
    final firestore = FirebaseFirestore.instance;

    return AppPageScaffold(
      title: 'حضور الطفل',
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('attendance')
                  .where('childId', isEqualTo: child.id)
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

                final rawDocs = snapshot.data?.docs ?? [];

                final docs = [...rawDocs]
                  ..sort((a, b) {
                    final aTime = _resolveTimestamp(a.data());
                    final bTime = _resolveTimestamp(b.data());

                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;

                    return bTime.compareTo(aTime);
                  });

                if (docs.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 60),
                      _buildEmptyState(),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();

                    final status = _resolveStatus(data);
                    final time = _resolveTimestamp(data);
                    final note = _safeText(data['note']);
                    final recordedByName = _safeText(data['recordedByName']);
                    final recordedByRole = _safeText(data['recordedByRole']);

                    final recordedBy = recordedByName.isEmpty
                        ? ''
                        : recordedByRole.isEmpty
                            ? recordedByName
                            : '$recordedByName - $recordedByRole';

                    return _AttendanceCard(
                      statusText: statusLabel(status),
                      dateText: formatDate(time),
                      note: note,
                      recordedByName: recordedBy,
                      color: statusColor(status),
                      icon: statusIcon(status),
                    );
                  },
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حضور ${child.name}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك متابعة سجل حضور الطفل بالتفصيل.',
            style: const TextStyle(
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
  final String statusText;
  final String dateText;
  final String note;
  final String recordedByName;
  final Color color;
  final IconData icon;

  const _AttendanceCard({
    required this.statusText,
    required this.dateText,
    required this.note,
    required this.recordedByName,
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
                child: Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoTile(
            title: 'التاريخ',
            value: dateText,
          ),
          if (recordedByName.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'تم التسجيل بواسطة',
              value: recordedByName,
            ),
          ],
          if (note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'ملاحظة',
              value: note,
            ),
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