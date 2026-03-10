import 'package:flutter/material.dart';
import 'register_parent_page.dart';
import 'register_employee_page.dart';
import '../widgets/app_bar_widget.dart';

class RegisterRolePage extends StatelessWidget {
  const RegisterRolePage({super.key});

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
          child: Column(
            children: [

              const Text(
                "اختر نوع الحساب",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              _roleButton(
                context,
                title: "ولي أمر",
                icon: Icons.family_restroom,
                page: const RegisterParentPage(),
              ),

              _roleButton(
                context,
                title: "موظف/ة حضانة",
                icon: Icons.child_care,
                page: const RegisterEmployeePage(role: "nursery"),
              ),

              _roleButton(
                context,
                title: "موظف/ة روضة",
                icon: Icons.school,
                page: const RegisterEmployeePage(role: "teacher"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleButton(
      BuildContext context,
      {required String title,
      required IconData icon,
      required Widget page}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8E97FD),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
      ),
    );
  }
}