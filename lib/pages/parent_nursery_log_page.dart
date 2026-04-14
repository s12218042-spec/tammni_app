import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentNurseryLogPage extends StatelessWidget {
  final ChildModel child;

  const ParentNurseryLogPage({
    super.key,
    required this.child,
  });

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  Timestamp? _firstTimestamp(List<dynamic> values) {
    for (final value in values) {
      if (value is Timestamp) return value;
    }
    return null;
  }

  String formatDateTime(dynamic time) {
    if (time is Timestamp) {
      final date = time.toDate();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} - $hour:$minute';
    }
    return 'غير محدد';
  }

  String eventLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'entry':
        return 'دخول موثّق';
      case 'exit':
        return 'خروج موثّق';
      default:
        return value.trim().isEmpty ? 'حدث' : value;
    }
  }

  Color eventColor(String value) {
    switch (value.trim().toLowerCase()) {
      case 'entry':
        return Colors.green;
      case 'exit':
        return Colors.red;
      default:
        return AppColors.textLight;
    }
  }

  IconData eventIcon(String value) {
    switch (value.trim().toLowerCase()) {
      case 'entry':
        return Icons.login_rounded;
      case 'exit':
        return Icons.logout_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  String roleLabel(String value) {
    final role = value.trim().toLowerCase();

    if (role == 'admin') return 'الإدارة';
    if (role == 'teacher') return 'المعلمة';
    if (role == 'nursery_staff' ||
        role == 'nursery staff' ||
        role == 'nursery') {
      return 'موظفة الحضانة';
    }
    if (role == 'parent') return 'وليّ الأمر';

    return value.trim().isEmpty ? '' : value;
  }

  String _resolveEventType(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['eventType'],
      data['type'],
      data['action'],
    ]);
  }

  String _resolveNote(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['note'],
      data['message'],
      data['body'],
      data['description'],
      data['details'],
    ]);
  }

  String _resolveCreatedByName(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['createdByName'],
      data['byName'],
      data['staffName'],
      data['adminName'],
      data['senderName'],
    ]);
  }

  String _resolveCreatedByRole(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['createdByRole'],
      data['byRole'],
      data['senderRole'],
      data['role'],
    ]);
  }

  Timestamp? _resolveTimestamp(Map<String, dynamic> data) {
    return _firstTimestamp([
      data['time'],
      data['createdAt'],
      data['timestamp'],
      data['updatedAt'],
      data['eventAt'],
    ]);
  }

  Future<List<Map<String, dynamic>>> fetchLogs() async {
    final firestore = FirebaseFirestore.instance;

    final snapshot = await firestore
        .collection('entry_exit_logs')
        .where('childId', isEqualTo: child.id)
        .get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'eventType': _resolveEventType(data),
        'note': _resolveNote(data),
        'createdByName': _resolveCreatedByName(data),
        'createdByRole': _resolveCreatedByRole(data),
        'displayTime': _resolveTimestamp(data),
      };
    }).toList();

    items.sort((a, b) {
      final aTime = a['displayTime'] as Timestamp?;
      final bTime = b['displayTime'] as Timestamp?;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'السجل الإداري للدخول والخروج',
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchLogs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل السجل',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                final docs = snapshot.data ?? [];

                if (docs.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 50),
                      _buildEmptyState(),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index];

                    final eventType = (data['eventType'] ?? '').toString();
                    final note = (data['note'] ?? '').toString();
                    final createdByName = (data['createdByName'] ?? '').toString();
                    final createdByRole = (data['createdByRole'] ?? '').toString();
                    final time = data['displayTime'];

                    final createdByText = [
                      if (createdByName.trim().isNotEmpty) createdByName.trim(),
                      if (roleLabel(createdByRole).trim().isNotEmpty)
                        roleLabel(createdByRole).trim(),
                    ].join(' - ');

                    return _NurseryLogCard(
                      eventText: eventLabel(eventType),
                      timeText: formatDateTime(time),
                      note: note,
                      createdByText: createdByText,
                      color: eventColor(eventType),
                      icon: eventIcon(eventType),
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
            'سجل ${child.name}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'يمكنك متابعة السجل الإداري الموثّق لدخول وخروج الطفل من الحضانة.',
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
            Icons.history_toggle_off_rounded,
            size: 40,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'لا يوجد سجل دخول أو خروج بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'عند تسجيل أول حدث إداري سيظهر هنا مباشرة.',
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

class _NurseryLogCard extends StatelessWidget {
  final String eventText;
  final String timeText;
  final String note;
  final String createdByText;
  final Color color;
  final IconData icon;

  const _NurseryLogCard({
    required this.eventText,
    required this.timeText,
    required this.note,
    required this.createdByText,
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
                  eventText,
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
            title: 'الوقت',
            value: timeText,
          ),
          if (createdByText.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'سُجّل بواسطة',
              value: createdByText,
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