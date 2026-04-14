import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentGradesPage extends StatelessWidget {
  final ChildModel child;

  const ParentGradesPage({
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
      data['time'],
      data['createdAt'],
      data['updatedAt'],
    ];

    for (final value in candidates) {
      if (value is Timestamp) return value;
    }

    return null;
  }

  String _formatGrade(dynamic grade) {
    if (grade == null) return '-';

    if (grade is num) {
      if (grade % 1 == 0) {
        return grade.toInt().toString();
      }
      return grade.toString();
    }

    return grade.toString();
  }

  String _formatTotal(dynamic total) {
    if (total == null) return '-';

    if (total is num) {
      if (total % 1 == 0) {
        return total.toInt().toString();
      }
      return total.toString();
    }

    return total.toString();
  }

  String _formatDate(dynamic time) {
    if (time is Timestamp) {
      final date = time.toDate();
      return '${date.year}/${date.month}/${date.day}';
    }
    return 'غير محدد';
  }

  Color _gradeTypeColor(String type) {
    switch (type) {
      case 'امتحان':
        return AppColors.primary;
      case 'يومي':
        return AppColors.secondary;
      case 'مشاركة':
        return Colors.green;
      case 'واجب':
        return Colors.orange;
      case 'نشاط':
        return Colors.purple;
      default:
        return AppColors.textLight;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = [...docs];

    sorted.sort((a, b) {
      final aTime = _resolveTimestamp(a.data());
      final bTime = _resolveTimestamp(b.data());

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return AppPageScaffold(
      title: 'درجات الطفل',
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('grades')
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
                      'حدث خطأ أثناء تحميل الدرجات',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                final docs = _sortDocs(snapshot.data?.docs ?? []);

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

                    final subject =
                        _safeText(data['subject'], fallback: 'مادة غير محددة');
                    final type = _safeText(data['type'], fallback: 'تقييم');
                    final grade = data['grade'];
                    final total = data['total'];
                    final note = _safeText(data['note']);
                    final displayTime = _resolveTimestamp(data);
                    final createdByName = _safeText(data['createdByName']);

                    return _GradeCard(
                      subject: subject,
                      type: type,
                      gradeText: _formatGrade(grade),
                      totalText: _formatTotal(total),
                      note: note,
                      dateText: _formatDate(displayTime),
                      createdByName: createdByName,
                      typeColor: _gradeTypeColor(type),
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
            'درجات ${child.name}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            child.group.isEmpty
                ? 'متابعة درجات الطفل وتقييماته المختلفة.'
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
            Icons.grade_outlined,
            size: 40,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'لا توجد درجات مضافة بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'عند إضافة أول تقييم سيظهر هنا مباشرة.',
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

class _GradeCard extends StatelessWidget {
  final String subject;
  final String type;
  final String gradeText;
  final String totalText;
  final String note;
  final String dateText;
  final String createdByName;
  final Color typeColor;

  const _GradeCard({
    required this.subject,
    required this.type,
    required this.gradeText,
    required this.totalText,
    required this.note,
    required this.dateText,
    required this.createdByName,
    required this.typeColor,
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
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.grade_rounded,
                  color: typeColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  subject,
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
                  color: typeColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: typeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  title: 'الدرجة',
                  value: '$gradeText / $totalText',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoTile(
                  title: 'التاريخ',
                  value: dateText,
                ),
              ),
            ],
          ),
          if (createdByName.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'أضيفت بواسطة',
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