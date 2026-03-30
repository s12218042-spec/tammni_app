import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentNotificationsPage extends StatelessWidget {
  final ChildModel child;

  const ParentNotificationsPage({
    super.key,
    required this.child,
  });

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    return '${d.year}/${d.month}/${d.day} - ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'entry':
        return Colors.green;
      case 'exit':
        return Colors.orange;
      case 'health':
        return Colors.redAccent;
      case 'supplies':
        return Colors.deepPurple;
      case 'media':
        return Colors.blue;
      default:
        return AppColors.primary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'entry':
        return Icons.login_outlined;
      case 'exit':
        return Icons.logout_outlined;
      case 'health':
        return Icons.health_and_safety_outlined;
      case 'supplies':
        return Icons.inventory_2_outlined;
      case 'media':
        return Icons.photo_camera_back_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'entry':
        return 'دخول';
      case 'exit':
        return 'خروج';
      case 'health':
        return 'صحة';
      case 'supplies':
        return 'مستلزمات';
      case 'media':
        return 'وسائط';
      case 'custom':
        return 'إشعار خاص';
      default:
        return type.isEmpty ? 'إشعار' : type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الإشعارات',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withOpacity(0.18),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'إشعارات الحضانة الخاصة بالطفل ${child.name}',
                    style: const TextStyle(
                      color: Colors.white,
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('childId', isEqualTo: child.id)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'حدث خطأ أثناء تحميل الإشعارات\n${snapshot.error}',
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
                            Icons.notifications_none_outlined,
                            size: 44,
                            color: AppColors.textLight,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'لا توجد إشعارات لعرضها حالياً',
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
                    final type = (data['type'] ?? '').toString();
                    final title = (data['title'] ?? '').toString();
                    final message = (data['message'] ?? '').toString();
                    final createdAt = data['createdAt'] as Timestamp?;
                    final createdByName =
                        (data['createdByName'] ?? '').toString();
                    final color = _typeColor(type);

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
                                    _typeIcon(type),
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title.isEmpty
                                            ? _typeLabel(type)
                                            : title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
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
                                    color: color.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _typeLabel(type),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                message,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                              ),
                            ],
                            if (createdByName.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                'من: $createdByName',
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
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