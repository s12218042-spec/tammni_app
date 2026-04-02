import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentNotificationsPage extends StatelessWidget {
  final String parentUsername;

  const ParentNotificationsPage({
    super.key,
    required this.parentUsername,
  });

  @override
  Widget build(BuildContext context) {
    final cleanParentUsername = parentUsername.trim().toLowerCase();

    return AppPageScaffold(
      title: 'الإشعارات',
      child: Container(
        color: AppColors.background,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('parentUsername', isEqualTo: cleanParentUsername)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'حدث خطأ في تحميل الإشعارات:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.notifications_none_outlined,
                          size: 46,
                          color: AppColors.textLight,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'لا يوجد إشعارات بعد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final items = docs.map((doc) {
              final data = doc.data();

              final Timestamp? time =
                  data['time'] is Timestamp ? data['time'] as Timestamp : null;

              final Timestamp? createdAt = data['createdAt'] is Timestamp
                  ? data['createdAt'] as Timestamp
                  : null;

              return {
                'id': doc.id,
                'title': (data['title'] ?? '').toString(),
                'body': (data['body'] ?? data['message'] ?? '').toString(),
                'childName': (data['childName'] ?? '').toString(),
                'type': (data['type'] ?? '').toString(),
                'isRead': data['isRead'] == true,
                'time': time,
                'createdAt': createdAt,
                'createdByName': (data['createdByName'] ?? '').toString(),
              };
            }).toList();

            items.sort((a, b) {
              final Timestamp? aTime =
                  (a['time'] as Timestamp?) ?? (a['createdAt'] as Timestamp?);
              final Timestamp? bTime =
                  (b['time'] as Timestamp?) ?? (b['createdAt'] as Timestamp?);

              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;

              return bTime.compareTo(aTime);
            });

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final data = items[index];

                final title = (data['title'] ?? '').toString();
                final body = (data['body'] ?? '').toString();
                final childName = (data['childName'] ?? '').toString();
                final type = (data['type'] ?? '').toString();
                final createdByName = (data['createdByName'] ?? '').toString();
                final isRead = data['isRead'] == true;

                final Timestamp? rawTime =
                    (data['time'] as Timestamp?) ??
                    (data['createdAt'] as Timestamp?);

                final color = _typeColor(type);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: isRead ? 1 : 2,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: color.withOpacity(0.12),
                          child: Icon(
                            _iconForType(type),
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isEmpty ? _defaultTitle(type) : title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isRead
                                      ? AppColors.textLight
                                      : AppColors.textDark,
                                ),
                              ),
                              if (childName.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'الطفل: $childName',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  body,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                              if (createdByName.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'من: $createdByName',
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                _formatTime(rawTime),
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  static IconData _iconForType(String type) {
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
      case 'update_notification':
        return Icons.campaign_outlined;
      case 'nursery_notification':
        return Icons.notifications_active_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  static Color _typeColor(String type) {
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
      case 'nursery_notification':
        return AppColors.secondary;
      case 'update_notification':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'entry':
        return 'دخول موثّق';
      case 'exit':
        return 'خروج موثّق';
      case 'health':
        return 'صحة';
      case 'supplies':
        return 'مستلزمات';
      case 'media':
        return 'وسائط';
      case 'custom':
        return 'إشعار خاص';
      case 'nursery_notification':
        return 'إشعار';
      case 'update_notification':
        return 'تحديث';
      default:
        return type.isEmpty ? 'إشعار' : type;
    }
  }

  static String _defaultTitle(String type) {
    switch (type) {
      case 'entry':
        return 'تم توثيق دخول الطفل';
      case 'exit':
        return 'تم توثيق خروج الطفل';
      case 'health':
        return 'ملاحظة صحية';
      case 'supplies':
        return 'مستلزمات مطلوبة';
      case 'media':
        return 'تمت إضافة صورة أو فيديو';
      case 'update_notification':
        return 'تحديث جديد';
      case 'nursery_notification':
        return 'إشعار جديد';
      default:
        return 'إشعار جديد';
    }
  }

  static String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'بدون وقت';

    final date = timestamp.toDate();
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$year/$month/$day - $hour:$minute';
  }
}