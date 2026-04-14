import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'add_grade_page.dart';
import 'bulk_grade_entry_page.dart';

class GradesPage extends StatefulWidget {
  const GradesPage({super.key});

  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> refreshPage() async {
    setState(() {});
  }

  String _formatGrade(dynamic grade) {
    if (grade == null) return '-';
    return grade.toString();
  }

  String _formatTotal(dynamic total) {
    if (total == null) return '-';
    return total.toString();
  }

  Timestamp? _extractTimestamp(Map<String, dynamic> data) {
    final dynamic primary = data['time'];
    final dynamic fallback = data['createdAt'];

    if (primary is Timestamp) return primary;
    if (fallback is Timestamp) return fallback;

    return null;
  }

  String _formatDate(dynamic time) {
    if (time is Timestamp) {
      final date = time.toDate();
      return '${date.year}/${date.month}/${date.day}';
    }
    return 'غير محدد';
  }

  String _extractRecordedBy(Map<String, dynamic> data) {
    final candidates = [
      data['createdByName'],
      data['recordedByName'],
      data['teacherName'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
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

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'التقييمات والدرجات',
      actions: [
        IconButton(
          tooltip: 'إدخال درجات جماعي',
          onPressed: () async {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BulkGradeEntryPage(),
              ),
            );

            if (res == true) {
              setState(() {});
            }
          },
          icon: const Icon(Icons.playlist_add_check_circle_outlined),
        ),
        IconButton(
          tooltip: 'إضافة تقييم',
          onPressed: () async {
            final res = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddGradePage(),
              ),
            );

            if (res == true) {
              setState(() {});
            }
          },
          icon: const Icon(Icons.add),
        ),
      ],
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('grades')
                  .where('section', isEqualTo: 'Kindergarten')
                  .orderBy('time', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('grades')
                        .where('section', isEqualTo: 'Kindergarten')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, fallbackSnapshot) {
                      if (fallbackSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (fallbackSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'حدث خطأ أثناء تحميل التقييمات',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        );
                      }

                      final docs = fallbackSnapshot.data?.docs ?? [];
                      return _buildGradesList(docs);
                    },
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                return _buildGradesList(docs);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradesList(List<QueryDocumentSnapshot> docs) {
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
          final subject = data['subject'] ?? 'مادة غير محددة';
          final type = data['type'] ?? 'تقييم';
          final grade = data['grade'];
          final total = data['total'];
          final note = data['note'] ?? '';
          final time = _extractTimestamp(data);
          final recordedBy = _extractRecordedBy(data);

          return _GradeCard(
            childName: childName.toString(),
            group: group.toString(),
            subject: subject.toString(),
            type: type.toString(),
            gradeText: _formatGrade(grade),
            totalText: _formatTotal(total),
            note: note.toString(),
            dateText: _formatDate(time),
            recordedBy: recordedBy,
            typeColor: _gradeTypeColor(type.toString()),
          );
        },
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
            'درجات أطفال الروضة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'يمكنكِ من هنا متابعة كل التقييمات والدرجات المضافة للأطفال، سواء الفردية أو الجماعية.',
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
            Icons.grade_outlined,
            size: 40,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'لا توجد تقييمات مضافة بعد',
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
  final String childName;
  final String group;
  final String subject;
  final String type;
  final String gradeText;
  final String totalText;
  final String note;
  final String dateText;
  final String recordedBy;
  final Color typeColor;

  const _GradeCard({
    required this.childName,
    required this.group,
    required this.subject,
    required this.type,
    required this.gradeText,
    required this.totalText,
    required this.note,
    required this.dateText,
    required this.recordedBy,
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
                  title: 'المادة',
                  value: subject,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoTile(
                  title: 'الدرجة',
                  value: '$gradeText / $totalText',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoTile(
            title: 'التاريخ',
            value: dateText,
          ),
          if (recordedBy.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              title: 'تم الإدخال بواسطة',
              value: recordedBy,
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