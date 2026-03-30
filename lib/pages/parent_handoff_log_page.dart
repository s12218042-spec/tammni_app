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
    return '${d.year}/${d.month}/${d.day} - ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _handoffColor(String type) {
    if (type == 'pickup') return Colors.orange;
    return Colors.green;
  }

  IconData _handoffIcon(String type) {
    if (type == 'pickup') return Icons.logout_outlined;
    return Icons.login_outlined;
  }

  String _handoffLabel(String type) {
    if (type == 'pickup') return 'استلام';
    if (type == 'dropoff') return 'تسليم';
    return type;
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('child_handoffs')
                  .where('childId', isEqualTo: child.id)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
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

                final docs = snapshot.data?.docs ?? [];

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
                    final data = docs[index].data() as Map<String, dynamic>;
                    final handoffType =
                        (data['handoffType'] ?? '').toString();
                    final personName = (data['personName'] ?? '').toString();
                    final relation = (data['relation'] ?? '').toString();
                    final note = (data['note'] ?? '').toString();
                    final createdByName =
                        (data['createdByName'] ?? '').toString();
                    final createdAt = data['createdAt'] as Timestamp?;
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
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.notes_outlined,
                                label: 'ملاحظة',
                                value: note,
                              ),
                            ],
                            if (createdByName.isNotEmpty) ...[
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