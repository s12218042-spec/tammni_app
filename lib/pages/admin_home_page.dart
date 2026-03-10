import 'package:flutter/material.dart';

import 'manage_users_page.dart';
import 'manage_children_page.dart';
import 'manage_classes_page.dart';
import '../widgets/app_bar_widget.dart';
class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
       appBar: const AppBarWidget(
  title: 'إدارة الأطفال',
),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const Text(
                'أهلاً 👩‍💼',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'إدارة الأطفال/المستخدمين/الصفوف',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),

              _adminBtn(
                context: context,
                icon: Icons.group,
                title: 'إدارة المستخدمين',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageUsersPage()),
                  );
                },
              ),

              _adminBtn(
                context: context,
                icon: Icons.child_care,
                title: 'إدارة الأطفال',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageChildrenPage()),
                  );
                },
              ),

              _adminBtn(
                context: context,
                icon: Icons.class_,
                title: 'إدارة الصفوف/الأقسام',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageClassesPage()),
                  );
                },
              ),

              _adminBtn(
                context: context,
                icon: Icons.bar_chart,
                title: 'تقارير عامة',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('صفحة التقارير لاحقًا ✅')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adminBtn({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8E97FD),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}