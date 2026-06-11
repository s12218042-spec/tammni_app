import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'add_nursery_staff_page.dart';
import 'add_admin_page.dart';

class AdminAddUserPage extends StatelessWidget {
  const AdminAddUserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إنشاء حسابات الموظفين',
      child: ListView(
        children: [
          const SizedBox(height: 16),

          Text(
            'اختيار نوع الحساب',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 16),
          _AccountTypeCard(
            title: 'إضافة موظف حضانة',
            subtitle:
                '',
            icon: Icons.child_friendly_rounded,
            color: AppColors.nursery,
            onTap: () async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const AddNurseryStaffPage(),
    ),
  );

  if (context.mounted && result == true) {
    Navigator.pop(context, true);
  }
},
          ),
          _AccountTypeCard(
            title: 'إضافة أدمن',
            subtitle:
                '',
            icon: Icons.admin_panel_settings_rounded,
            color: AppColors.secondary,
            onTap: () async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const AddAdminPage(),
    ),
  );

  if (context.mounted && result == true) {
    Navigator.pop(context, true);
  }
},
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

}

class _AccountTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(
                  icon,
                  color: color,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.8,
                        color: Colors.black54,
                        height: 1.4,
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