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
              return const Center(
                child: Text('لا يوجد إشعارات بعد'),
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
                'body': (data['body'] ?? '').toString(),
                'childName': (data['childName'] ?? '').toString(),
                'time': time,
                'createdAt': createdAt,
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

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final data = items[index];

                final title = (data['title'] ?? '').toString();
                final body = (data['body'] ?? '').toString();
                final childName = (data['childName'] ?? '').toString();
                final Timestamp? rawTime =
                    (data['time'] as Timestamp?) ??
                    (data['createdAt'] as Timestamp?);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      title.isEmpty ? 'إشعار جديد' : title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (childName.isNotEmpty)
                            Text(
                              'الطفل: $childName',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(body),
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
                  ),
                );
              },
            );
          },
        ),
      ),
    );
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