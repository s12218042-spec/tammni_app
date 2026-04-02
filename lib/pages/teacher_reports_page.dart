import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class TeacherReportsPage extends StatefulWidget {
  const TeacherReportsPage({super.key});

  @override
  State<TeacherReportsPage> createState() => _TeacherReportsPageState();
}

class _TeacherReportsPageState extends State<TeacherReportsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> loadReportData() async {
    final childrenSnapshot = await _firestore
        .collection('children')
        .where('section', isEqualTo: 'Kindergarten')
        .where('isActive', isEqualTo: true)
        .get();

    final gradesSnapshot = await _firestore
        .collection('grades')
        .where('section', isEqualTo: 'Kindergarten')
        .get();

    final assignmentsSnapshot = await _firestore
        .collection('assignments')
        .where('section', isEqualTo: 'Kindergarten')
        .get();

    final rewardsSnapshot = await _firestore
        .collection('rewards')
        .where('section', isEqualTo: 'Kindergarten')
        .get();

    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('section', isEqualTo: 'Kindergarten')
        .get();

     final children = childrenSnapshot.docs.map((doc) {
  final data = doc.data();
  return ChildModel.fromMap(data, docId: doc.id);
}).toList();

    final groups = children
        .map((child) => child.group.trim())
        .where((group) => group.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return {
      'childrenCount': children.length,
      'groupsCount': groups.length,
      'gradesCount': gradesSnapshot.docs.length,
      'assignmentsCount': assignmentsSnapshot.docs.length,
      'rewardsCount': rewardsSnapshot.docs.length,
      'attendanceCount': attendanceSnapshot.docs.length,
      'groups': groups,
    };
  }

  Future<void> refreshPage() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: loadReportData(),
      builder: (context, snapshot) {
        return AppPageScaffold(
          title: 'تقارير المعلمة',
          child: Builder(
            builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'حدث خطأ أثناء تحميل التقارير',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              final data = snapshot.data ?? {};
              final childrenCount = data['childrenCount'] ?? 0;
              final groupsCount = data['groupsCount'] ?? 0;
              final gradesCount = data['gradesCount'] ?? 0;
              final assignmentsCount = data['assignmentsCount'] ?? 0;
              final rewardsCount = data['rewardsCount'] ?? 0;
              final attendanceCount = data['attendanceCount'] ?? 0;
              final groups = (data['groups'] as List<dynamic>? ?? []).cast<String>();

              return RefreshIndicator(
                onRefresh: refreshPage,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    _buildStatsGrid(
                      childrenCount: childrenCount,
                      groupsCount: groupsCount,
                      gradesCount: gradesCount,
                      assignmentsCount: assignmentsCount,
                      rewardsCount: rewardsCount,
                      attendanceCount: attendanceCount,
                    ),
                    const SizedBox(height: 22),
                    _buildGroupsSection(groups),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
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
            'ملخص تقارير الروضة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'يمكنكِ من هنا رؤية نظرة عامة سريعة عن الأطفال والمجموعات والحضور والتقييمات والواجبات.',
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

  Widget _buildStatsGrid({
    required int childrenCount,
    required int groupsCount,
    required int gradesCount,
    required int assignmentsCount,
    required int rewardsCount,
    required int attendanceCount,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ReportStatCard(
          title: 'الأطفال',
          value: '$childrenCount',
          icon: Icons.groups_rounded,
        ),
        _ReportStatCard(
          title: 'المجموعات',
          value: '$groupsCount',
          icon: Icons.groups_2_rounded,
        ),
        _ReportStatCard(
          title: 'التقييمات',
          value: '$gradesCount',
          icon: Icons.grade_rounded,
        ),
        _ReportStatCard(
          title: 'الواجبات',
          value: '$assignmentsCount',
          icon: Icons.assignment_rounded,
        ),
        _ReportStatCard(
          title: 'التعزيزات',
          value: '$rewardsCount',
          icon: Icons.emoji_events_rounded,
        ),
        _ReportStatCard(
          title: 'سجلات الحضور',
          value: '$attendanceCount',
          icon: Icons.fact_check_rounded,
        ),
      ],
    );
  }

  Widget _buildGroupsSection(List<String> groups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'المجموعات الحالية',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.border.withOpacity(0.8),
              ),
            ),
            child: const Text(
              'لا توجد مجموعات حالياً.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: groups
                .map(
                  (group) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_2_rounded,
                          size: 18,
                          color: AppColors.primary.withOpacity(0.9),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          group,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _ReportStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ReportStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 22,
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
                    fontSize: 12.5,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}