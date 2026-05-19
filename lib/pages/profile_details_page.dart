import 'package:flutter/material.dart';

import '../services/account_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'account_settings_page.dart';

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({super.key});

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  final AccountSettingsService _accountSettingsService =
      AccountSettingsService();

  Future<void> _openEditPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AccountSettingsPage(),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
    Color? color,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (color ?? AppColors.primary).withOpacity(0.12),
          child: Icon(
            icon,
            color: color ?? AppColors.primary,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          value.trim().isEmpty ? 'غير محدد' : value,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الملف الشخصي',
      child: FutureBuilder<AccountSettingsData>(
        future: _accountSettingsService.getCurrentUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ أثناء تحميل بيانات الملف الشخصي:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final data = snapshot.data;

          if (data == null) {
            return const Center(
              child: Text('لم يتم العثور على بيانات الحساب'),
            );
          }

          final displayName =
              data.name.trim().isNotEmpty ? data.name.trim() : 'مستخدم';

          return ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: Text(
                          displayName.isNotEmpty ? displayName[0] : 'م',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.roleLabel,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _infoTile(
                icon: Icons.person_outline_rounded,
                title: 'الاسم',
                value: data.name,
                color: Colors.orange,
              ),
              _infoTile(
                icon: Icons.alternate_email_rounded,
                title: 'اسم المستخدم',
                value: data.username,
                color: Colors.blue,
              ),
              _infoTile(
                icon: Icons.email_outlined,
                title: 'البريد الإلكتروني',
                value: data.email,
                color: Colors.green,
              ),
              _infoTile(
                icon: Icons.verified_user_outlined,
                title: 'الدور',
                value: data.roleLabel,
                color: Colors.purple,
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('رجوع'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openEditPage,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تعديل'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}