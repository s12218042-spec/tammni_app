import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentAssignmentsPage extends StatelessWidget {
  final ChildModel child;

  const ParentAssignmentsPage({
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
      data['dueDate'],
      data['time'],
      data['createdAt'],
      data['updatedAt'],
    ];

    for (final value in candidates) {
      if (value is Timestamp) return value;
    }

    return null;
  }

  String _formatDate(dynamic raw) {
    if (raw is Timestamp) {
      final date = raw.toDate();
      return '${date.year}/${date.month}/${date.day}';
    }
    return 'غير محدد';
  }

  String _resolveDescription(Map<String, dynamic> data) {
    final candidates = [
      data['description'],
      data['message'],
      data['details'],
      data['body'],
      data['note'],
    ];

    for (final value in candidates) {
      final text = _safeText(value);
      if (text.isNotEmpty) return text;
    }

    return '';
  }

  String _resolveStatus(Map<String, dynamic> data) {
    final raw = _safeText(data['status'], fallback: 'نشط');

    switch (raw) {
      case 'active':
        return 'نشط';
      case 'closed':
        return 'مغلق';
      case 'completed':
        return 'مكتمل';
      default:
        return raw;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'نشط':
        return AppColors.primary;
      case 'مغلق':
        return Colors.red;
      case 'مكتمل':
        return Colors.green;
      default:
        return AppColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return AppPageScaffold(
      title: 'واجبات الطفل',
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('assignments')
                  .where('group', isEqualTo: child.group)
                  .where('section', isEqualTo: child.section)
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
                      'حدث خطأ أثناء تحميل الواجبات',
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

                    final title = _safeText(
                      data['title'],
                      fallback: 'واجب بدون عنوان',
                    );
                    final description = _resolveDescription(data);
                    final subject = _safeText(
                      data['subject'],
                      fallback: 'مادة غير محددة',
                    );
                    final group = _safeText(data['group']);
                    final dueDate = _resolveTimestamp(data);
                    final status = _resolveStatus(data);
                    final note = _safeText(data['note']);
                    final createdByName = _safeText(data['createdByName']);

                    return _AssignmentCard(
                      title: title,
                      description: description,
                      subject: subject,
                      group: group,
                      dueDateText: _formatDate(dueDate),
                      status: status,
                      statusColor: _statusColor(status),
                      note: note,
                      createdByName: createdByName,
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
            'واجبات ${child.name}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            child.group.trim().isEmpty
                ? 'متابعة واجبات الطفل الحالية.'
                : 'المجموعة: ${child.group}',
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
            Icons.assignment_outlined,
            size: 40,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'لا توجد واجبات مضافة بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'عند إضافة أول واجب سيظهر هنا مباشرة.',
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

class _AssignmentCard extends StatelessWidget {
  final String title;
  final String description;
  final String subject;
  final String group;
  final String dueDateText;
  final String status;
  final Color statusColor;
  final String note;
  final String createdByName;

  const _AssignmentCard({
    required this.title,
    required this.description,
    required this.subject,
    required this.group,
    required this.dueDateText,
    required this.status,
    required this.statusColor,
    required this.note,
    required this.createdByName,
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
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.assignment_rounded,
                  color: statusColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoTile(
            title: 'الوصف',
            value: description.isEmpty ? 'لا يوجد وصف' : description,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  title: 'المادة',
                  value: subject,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoTile(
                  title: 'موعد التسليم',
                  value: dueDateText,
                ),
              ),
            ],
          ),
          if (group.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'المجموعة',
              value: group,
            ),
          ],
          if (createdByName.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'أضيف بواسطة',
              value: createdByName,
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