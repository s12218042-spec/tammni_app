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
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');

    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} - $hour:$minute';
  }

  Color _priorityColor(String priority) {
    switch (priority.trim().toLowerCase()) {
      case 'high':
      case 'urgent':
      case 'عالية':
      case 'عاجل':
        return Colors.red;
      case 'medium':
      case 'important':
      case 'متوسطة':
      case 'مهم':
        return Colors.orange;
      case 'low':
      case 'normal':
      case 'منخفضة':
      case 'عادي':
        return Colors.green;
      default:
        return Colors.redAccent;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority.trim().toLowerCase()) {
      case 'high':
      case 'urgent':
      case 'عالية':
      case 'عاجل':
        return 'عالية';
      case 'medium':
      case 'important':
      case 'متوسطة':
      case 'مهم':
        return 'متوسطة';
      case 'low':
      case 'normal':
      case 'منخفضة':
      case 'عادي':
        return 'منخفضة';
      default:
        return priority.trim().isEmpty ? 'غير محددة' : priority;
    }
  }

  String _incidentTypeLabel(String type) {
    switch (type.trim().toLowerCase()) {
      case 'health':
        return 'ملاحظة صحية';
      case 'injury':
        return 'إصابة';
      case 'behavior':
        return 'سلوك';
      case 'accident':
        return 'حادث';
      case 'incident':
        return 'بلاغ';
      case 'سقوط بسيط':
        return 'سقوط بسيط';
      case 'إصابة':
        return 'إصابة';
      case 'حادث':
        return 'حادث';
      case 'ملاحظة':
        return 'ملاحظة';
      default:
        return type.trim().isEmpty ? 'بلاغ' : type;
    }
  }

  String _roleLabel(String role) {
    final clean = role.trim().toLowerCase();

    if (clean == 'nursery' || clean == 'nursery_staff') {
      return 'موظفة الحضانة';
    }
    if (clean == 'teacher') {
      return 'المعلمة';
    }
    if (clean == 'admin') {
      return 'الإدارة';
    }
    if (clean == 'parent') {
      return 'وليّ الأمر';
    }

    return role.trim().isEmpty ? '' : role;
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  String _resolveIncidentType(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['incidentType'],
      data['type'],
      data['reportType'],
      data['title'],
    ]);
  }

  String _resolvePriority(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['priority'],
      data['severity'],
      data['level'],
      data['autoRisk'],
    ]);
  }

  String _resolveDetails(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['details'],
      data['note'],
      data['message'],
      data['body'],
      data['description'],
    ]);
  }

  String _resolveActionTaken(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['actionTaken'],
      data['action'],
      data['response'],
      data['actionNote'],
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

  bool _resolveParentNotified(Map<String, dynamic> data) {
    final candidates = [
      data['parentNotified'],
      data['notifiedParent'],
      data['isParentNotified'],
    ];

    for (final value in candidates) {
      if (value is bool) return value;
    }

    return false;
  }

  Timestamp? _resolveTimestamp(Map<String, dynamic> data) {
    final candidates = [
      data['eventAt'],
      data['createdAt'],
      data['time'],
      data['timestamp'],
      data['updatedAt'],
    ];

    for (final value in candidates) {
      if (value is Timestamp) return value;
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> fetchIncidentReports() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('incident_reports')
        .where('childId', isEqualTo: child.id)
        .get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'incidentType': _resolveIncidentType(data),
        'priority': _resolvePriority(data),
        'details': _resolveDetails(data),
        'actionTaken': _resolveActionTaken(data),
        'parentNotified': _resolveParentNotified(data),
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
      title: 'بلاغات الحوادث',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.red.withOpacity(0.14),
              ),
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
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchIncidentReports(),
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
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data ?? [];

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
                    final data = docs[index];
                    final incidentType = (data['incidentType'] ?? '').toString();
                    final priority = (data['priority'] ?? '').toString();
                    final details = (data['details'] ?? '').toString();
                    final actionTaken = (data['actionTaken'] ?? '').toString();
                    final parentNotified = data['parentNotified'] == true;
                    final createdByName =
                        (data['createdByName'] ?? '').toString();
                    final createdByRole =
                        (data['createdByRole'] ?? '').toString();
                    final createdAt = data['displayTime'] as Timestamp?;
                    final priorityColor = _priorityColor(priority);

                    final senderText = [
                      if (createdByName.trim().isNotEmpty)
                        createdByName.trim(),
                      if (_roleLabel(createdByRole).trim().isNotEmpty)
                        _roleLabel(createdByRole).trim(),
                    ].join(' - ');

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
                            if (details.trim().isNotEmpty) ...[
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
                            if (actionTaken.trim().isNotEmpty) ...[
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
                                if (senderText.trim().isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.primary.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'بواسطة: $senderText',
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