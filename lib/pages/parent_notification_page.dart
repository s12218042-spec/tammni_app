import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentNotificationsPage extends StatelessWidget {
  final String parentUsername;

  const ParentNotificationsPage({super.key, required this.parentUsername});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الإشعارات',
      child: Container(
        color: AppColors.background, // 👈 هون استخدمنا الثيم
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('parentUsername', isEqualTo: parentUsername)
              .orderBy('time', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (snapshot.hasError) {
              return const Center(child: Text('حدث خطأ في تحميل الإشعارات'));
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(child: Text('لا يوجد إشعارات بعد'));
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;

                final title = data['title'] ?? '';
                final body = data['body'] ?? '';
                final childName = data['childName'] ?? '';
                final time = data['time'] as Timestamp?;

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
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.15),
                      child: const Icon(
                        Icons.notifications,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (childName.isNotEmpty)
                          Text('بخصوص الطفل: $childName'),
                        Text(body),
                        if (time != null)
                          Text(
                            _formatTime(time),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
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

  String _formatTime(Timestamp time) {
    final dt = time.toDate();
    return '${dt.hour}:${dt.minute}';
  }
}
