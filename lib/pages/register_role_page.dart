import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'register_parent_page.dart';
import 'register_employee_page.dart';

class RegisterRolePage extends StatelessWidget {
  const RegisterRolePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إنشاء حساب',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اختيار نوع الحساب',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'اختاري نوع الحساب الذي تريدين إنشاءه',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
          const SizedBox(height: 20),

          _RoleCard(
            title: 'ولي أمر',
            subtitle: 'متابعة الأطفال والاطلاع على التحديثات والتقارير',
            icon: Icons.family_restroom,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegisterParentPage(),
                ),
              );
            },
          ),

          _RoleCard(
            title: 'موظفة حضانة',
            subtitle: 'تسجيل الحضور وإضافة التحديثات اليومية للأطفال',
            icon: Icons.child_care,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegisterEmployeePage(role: 'nursery'),
                ),
              );
            },
          ),

          _RoleCard(
            title: 'معلمة روضة',
            subtitle: 'إضافة الأنشطة والخطط اليومية ومتابعة الأطفال',
            icon: Icons.school,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegisterEmployeePage(role: 'teacher'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
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