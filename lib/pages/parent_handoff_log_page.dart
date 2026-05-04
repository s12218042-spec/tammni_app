import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentHandoffLogPage extends StatelessWidget {
  final ChildModel child;

  const ParentHandoffLogPage({
    super.key,
    required this.child,
  });

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime? _resolveDateTime(Map<String, dynamic> data) {
    final candidates = [
      data['time'],
      data['eventAt'],
      data['createdAt'],
      data['timestamp'],
      data['updatedAt'],
    ];

    for (final value in candidates) {
      final date = _dateFromDynamic(value);
      if (date != null) return date;
    }

    return null;
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();

    int hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$year/$month/$day - $hour:$minute $period';
  }

  Color _handoffColor(String type) {
    final cleanType = type.trim().toLowerCase();

    if (cleanType == 'pickup' || cleanType == 'exit') {
      return Colors.deepOrange;
    }

    if (cleanType == 'delivery' ||
        cleanType == 'dropoff' ||
        cleanType == 'entry') {
      return Colors.teal;
    }

    return AppColors.primary;
  }

  IconData _handoffIcon(String type) {
    final cleanType = type.trim().toLowerCase();

    if (cleanType == 'pickup' || cleanType == 'exit') {
      return Icons.logout_outlined;
    }

    if (cleanType == 'delivery' ||
        cleanType == 'dropoff' ||
        cleanType == 'entry') {
      return Icons.login_outlined;
    }

    return Icons.swap_horiz_outlined;
  }

  String _handoffLabel(String type) {
    final cleanType = type.trim().toLowerCase();

    if (cleanType == 'pickup' || cleanType == 'exit') {
      return 'استلام من الحضانة';
    }

    if (cleanType == 'delivery' ||
        cleanType == 'dropoff' ||
        cleanType == 'entry') {
      return 'تسليم للحضانة';
    }

    return cleanType.isEmpty ? 'سجل' : type;
  }

  String _resolveHandoffType(Map<String, dynamic> data) {
    final candidates = [
      data['handoffType'],
      data['type'],
      data['action'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  String _resolvePersonName(Map<String, dynamic> data) {
    final candidates = [
      data['personName'],
      data['receiverName'],
      data['handoffPersonName'],
      data['person'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  String _resolveRelation(Map<String, dynamic> data) {
    final candidates = [
      data['relation'],
      data['kinship'],
      data['relationship'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  String _resolveNote(Map<String, dynamic> data) {
    final candidates = [
      data['note'],
      data['details'],
      data['adminNote'],
      data['staffNote'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  String _resolveCreatedByName(Map<String, dynamic> data) {
    final candidates = [
      data['createdByName'],
      data['byName'],
      data['staffName'],
      data['adminName'],
      data['senderName'],
    ];

    for (final value in candidates) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  List<Map<String, dynamic>> _prepareHandoffs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final items = docs.map((doc) {
      final data = doc.data();
      final displayDateTime = _resolveDateTime(data);

      return {
        'id': doc.id,
        'handoffType': _resolveHandoffType(data),
        'personName': _resolvePersonName(data),
        'relation': _resolveRelation(data),
        'note': _resolveNote(data),
        'createdByName': _resolveCreatedByName(data),
        'displayDateTime': displayDateTime,
        'isCorrected': data['isCorrected'] == true,
      };
    }).toList();

    items.sort((a, b) {
      final aTime = a['displayDateTime'] as DateTime?;
      final bTime = b['displayDateTime'] as DateTime?;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return items;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _handoffsStream() {
    return FirebaseFirestore.instance
        .collection('child_handoffs')
        .where('childId', isEqualTo: child.id)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'سجل التسليم والاستلام',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: const Icon(
                    Icons.how_to_reg_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    child.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _handoffsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'حدث خطأ أثناء تحميل السجل\n${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rawDocs = snapshot.data?.docs ?? [];
                final docs = _prepareHandoffs(rawDocs);

                if (docs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 44,
                            color: AppColors.textLight,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'لا توجد سجلات حالياً',
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

                    final handoffType = (data['handoffType'] ?? '').toString();
                    final personName = (data['personName'] ?? '').toString();
                    final relation = (data['relation'] ?? '').toString();
                    final note = (data['note'] ?? '').toString();
                    final createdByName =
                        (data['createdByName'] ?? '').toString();
                    final displayDateTime =
                        data['displayDateTime'] as DateTime?;
                    final isCorrected = data['isCorrected'] == true;

                    final color = _handoffColor(handoffType);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: color.withOpacity(0.12),
                                  child: Icon(
                                    _handoffIcon(handoffType),
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _handoffLabel(handoffType),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatDateTime(displayDateTime),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (isCorrected) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.amber.withOpacity(0.35),
                                    ),
                                  ),
                                  child: Text(
                                    'تم تعديل السجل',
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.person_outline,
                              label: 'الشخص',
                              value: personName.isEmpty ? '-' : personName,
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              icon: Icons.people_outline,
                              label: 'القرابة/الصفة',
                              value: relation.isEmpty ? '-' : relation,
                            ),
                            if (note.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.notes_outlined,
                                label: 'ملاحظة',
                                value: note,
                              ),
                            ],
                            if (createdByName.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.badge_outlined,
                                label: 'تم بواسطة',
                                value: createdByName,
                              ),
                            ],
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textLight),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textLight,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}