import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentIncidentReportsPage extends StatelessWidget {
  final ChildModel child;

  const ParentIncidentReportsPage({
    super.key,
    required this.child,
  });

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    return '${d.year}/${d.month}/${d.day} - ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.redAccent;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return 'عالية';
      case 'medium':
        return 'متوسطة';
      case 'low':
        return 'منخفضة';
      default:
        return priority.isEmpty ? 'غير محددة' : priority;
    }
  }

  String _incidentTypeLabel(String type) {
    switch (type) {
      case 'health':
        return 'ملاحظة صحية';
      case 'injury':
        return 'إصابة';
      case 'behavior':
        return 'سلوك';
      case 'accident':
        return 'حادث';
      default:
        return type.isEmpty ? 'بلاغ' : type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'بلاغات الحوادث',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red.withOpacity(0.12),
                  child: const Icon(
                    Icons.report_problem_outlined,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'بلاغات الحوادث والملاحظات المهمة للطفل ${child.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incident_reports')
                  .where('childId', isEqualTo: child.id)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'حدث خطأ أثناء تحميل البلاغات\n${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.description_outlined,
                            size: 44,
                            color: AppColors.textLight,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'لا توجد بلاغات حوادث أو ملاحظات مهمة حالياً',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final incidentType =
                        (data['incidentType'] ?? '').toString();
                    final priority = (data['priority'] ?? '').toString();
                    final details = (data['details'] ?? '').toString();
                    final actionTaken =
                        (data['actionTaken'] ?? '').toString();
                    final parentNotified =
                        (data['parentNotified'] ?? false) == true;
                    final createdByName =
                        (data['createdByName'] ?? '').toString();
                    final createdAt = data['createdAt'] as Timestamp?;
                    final priorityColor = _priorityColor(priority);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      priorityColor.withOpacity(0.12),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    color: priorityColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _incidentTypeLabel(incidentType),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(createdAt),
                                        style: const TextStyle(
                                          color: AppColors.textLight,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: priorityColor.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'الأولوية: ${_priorityLabel(priority)}',
                                    style: TextStyle(
                                      color: priorityColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (details.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'التفاصيل',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                details,
                                style: const TextStyle(height: 1.45),
                              ),
                            ],
                            if (actionTaken.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'الإجراء المتخذ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                actionTaken,
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  height: 1.45,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (parentNotified
                                            ? Colors.green
                                            : Colors.grey)
                                        .withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    parentNotified
                                        ? 'تم إشعار ولي الأمر'
                                        : 'لم يتم إشعار ولي الأمر',
                                    style: TextStyle(
                                      color: parentNotified
                                          ? Colors.green
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (createdByName.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'بواسطة: $createdByName',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
}