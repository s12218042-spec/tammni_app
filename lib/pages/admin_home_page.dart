import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'manage_users_page.dart';
import 'manage_children_page.dart';
import 'manage_classes_page.dart';
import 'welcome_page.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  Future<void> logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكدة أنك تريدين تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );

    if (shouldLogout != true) return;

    await AuthService().logout();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الرئيسية - الإدارة',
      actions: [
        IconButton(
          tooltip: 'تسجيل الخروج',
          onPressed: () => logout(context),
          icon: const Icon(Icons.logout),
        ),
      ],
      child: ListView(
        children: [
          Text(
            'أهلاً 👩‍💼',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'من هنا يمكنك إدارة المستخدمين والأطفال والصفوف ومتابعة النظام',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
          const SizedBox(height: 20),

          _AdminActionCard(
            icon: Icons.group,
            title: 'إدارة المستخدمين',
            subtitle: 'إضافة وتعديل وحذف حسابات المستخدمين',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageUsersPage()),
              );
            },
          ),

          _AdminActionCard(
            icon: Icons.child_care,
            title: 'إدارة الأطفال',
            subtitle: 'عرض بيانات الأطفال وتعديلها وتنظيمها',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageChildrenPage()),
              );
            },
          ),

          _AdminActionCard(
            icon: Icons.class_,
            title: 'إدارة الصفوف والأقسام',
            subtitle: 'تنظيم الصفوف والمجموعات وربط الأطفال بها',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageClassesPage()),
              );
            },
          ),

          _AdminActionCard(
            icon: Icons.bar_chart,
            title: 'التقارير العامة',
            subtitle: 'إحصائيات وتقارير شاملة عن النظام',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('صفحة التقارير العامة سنطوّرها لاحقًا ✅'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}