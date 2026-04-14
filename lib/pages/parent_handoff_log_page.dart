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

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.year}/${d.month}/${d.day} - $hour:$minute';
  }

  Color _handoffColor(String type) {
    final cleanType = type.trim().toLowerCase();

    if (cleanType == 'pickup' || cleanType == 'exit') {
      return Colors.orange;
    }

    if (cleanType == 'delivery' ||
        cleanType == 'dropoff' ||
        cleanType == 'entry') {
      return Colors.green;
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
      return 'استلام';
    }

    if (cleanType == 'delivery' ||
        cleanType == 'dropoff' ||
        cleanType == 'entry') {
      return 'تسليم';
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
      data['message'],
      data['body'],
      data['description'],
      data['details'],
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

  Timestamp? _resolveTimestamp(Map<String, dynamic> data) {
    final candidates = [
      data['time'],
      data['createdAt'],
      data['timestamp'],
      data['updatedAt'],
    ];

    for (final value in candidates) {
      if (value is Timestamp) return value;
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> fetchHandoffs() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('child_handoffs')
        .where('childId', isEqualTo: child.id)
        .get();

    final items = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'handoffType': _resolveHandoffType(data),
        'personName': _resolvePersonName(data),
        'relation': _resolveRelation(data),
        'note': _resolveNote(data),
        'createdByName': _resolveCreatedByName(data),
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
      title: 'سجل الاستلام والتسليم',
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
                    'سجل استلام وتسليم الطفل ${child.name}',
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
              future: fetchHandoffs(),
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

                final docs = snapshot.data ?? [];

                if (docs.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 44,
                            color: AppColors.textLight,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'لا توجد سجلات استلام/تسليم لعرضها حالياً',
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
                    final createdAt = data['displayTime'] as Timestamp?;
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
                                    _formatDate(createdAt),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.person_outline,
                              label: 'الشخص',
                              value: personName.isEmpty ? '-' : personName,
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              icon: Icons.people_outline,
                              label: 'صلة القرابة',
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