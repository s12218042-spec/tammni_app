import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'add_teacher_page.dart';
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
          _buildHeaderCard(context),
          const SizedBox(height: 16),
          _buildInfoCard(context),
          const SizedBox(height: 20),

          Text(
            'اختيار نوع الحساب',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'اختاري نوع الموظف الذي تريد الإدارة إنشاء حساب له، وسيتم فتح نموذج مخصص لكل نوع.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 16),

          _AccountTypeCard(
            title: 'إضافة معلمة',
            subtitle:
                'إنشاء حساب معلمة مع بياناتها الشخصية والمهنية والمواد والصفوف المسؤولة عنها.',
            icon: Icons.menu_book_rounded,
            color: AppColors.kindergarten,
            onTap: () async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const AddTeacherPage(),
    ),
  );

  if (context.mounted && result == true) {
    Navigator.pop(context, true);
  }
},
          ),
          _AccountTypeCard(
            title: 'إضافة موظفة حضانة',
            subtitle:
                'إنشاء حساب موظفة حضانة مع بياناتها الشخصية والمهنية والطوارئ والمهام المرتبطة بالحضانة.',
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
                'إنشاء حساب إداري بصلاحيات واضحة وبيانات مهنية وتنظيمية مخصصة للإدارة.',
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

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.10),
                      child: const Icon(
                        Icons.rule_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ملاحظات مهمة',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _bullet('هذه الصفحة مخصصة لحسابات الموظفين فقط.'),
                _bullet('أولياء الأمور لا يتم إنشاؤهم من هنا، بل عبر طلب تسجيل وموافقة الإدارة.'),
                _bullet('إدارة المستخدمين ستكون للمراجعة والتعديل فقط، وليس للإضافة.'),
                _bullet('سيكون لكل نوع موظف فورم مستقل لأن البيانات المطلوبة مختلفة.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.16),
            AppColors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إنشاء حسابات الموظفين',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'تم فصل إنشاء حسابات الموظفين عن إدارة المستخدمين حتى يصبح النظام أوضح وأكثر مهنية وتنظيماً.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLight,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'لن يتم إنشاء كل أنواع الموظفين بنفس الفورم بعد الآن. لكل نوع صفحة خاصة به تحتوي على الحقول والتحقق المناسبين له.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textDark,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              size: 7,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textDark,
                height: 1.45,
              ),
            ),
          ),
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