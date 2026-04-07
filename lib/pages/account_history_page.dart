import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/account_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AccountHistoryPage extends StatelessWidget {
  const AccountHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AccountSettingsService();

    return AppPageScaffold(
      title: 'سجل تغييرات الحساب',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.currentUserHistoryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('لا يوجد سجل تغييرات حتى الآن'),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final title = (data['title'] ?? '').toString();
              final message = (data['message'] ?? '').toString();
              final status = (data['status'] ?? 'info').toString();
              final createdAt = data['createdAt'];

              Color color;
              IconData icon;

              switch (status) {
                case 'success':
                  color = AppColors.success;
                  icon = Icons.check_circle_outline_rounded;
                  break;
                case 'warning':
                  color = AppColors.warning;
                  icon = Icons.warning_amber_rounded;
                  break;
                case 'danger':
                  color = AppColors.danger;
                  icon = Icons.error_outline_rounded;
                  break;
                default:
                  color = AppColors.primary;
                  icon = Icons.info_outline_rounded;
              }

              String dateText = 'غير محدد';
              if (createdAt is Timestamp) {
                final d = createdAt.toDate();
                dateText =
                    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} - ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withOpacity(0.12),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.isEmpty ? 'تغيير في الحساب' : title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              message.isEmpty ? 'لا توجد تفاصيل إضافية' : message,
                              style: const TextStyle(
                                color: AppColors.textLight,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dateText,
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
    );
  }
}