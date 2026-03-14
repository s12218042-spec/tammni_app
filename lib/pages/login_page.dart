import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/app_primary_button.dart';
import 'parent_home_page.dart';
import 'nursery_staff_home_page.dart';
import 'teacher_home_page.dart';
import 'admin_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  final AuthService _authService = AuthService();

  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> onLogin() async {
    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب الإيميل وكلمة المرور')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = await _authService.login(
        email: email,
        password: password,
      );

      if (user == null) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تسجيل الدخول')),
        );
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('بيانات المستخدم غير موجودة في قاعدة البيانات')),
        );
        return;
      }

      final data = doc.data()!;
      final role = data['role'] ?? '';
      final username = data['username'] ?? '';

      await NotificationService.instance.saveCurrentUserToken();

      Widget nextPage;

      if (role == 'parent') {
        nextPage = ParentHomePage(parentUsername: username);
      } else if (role == 'nursery') {
        nextPage = const NurseryStaffHomePage();
      } else if (role == 'teacher') {
        nextPage = const TeacherHomePage();
      } else {
        nextPage = const AdminHomePage();
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextPage),
      );
    } on FirebaseException catch (e) {
      String message = 'حدث خطأ أثناء تسجيل الدخول';

      if (e.code == 'user-not-found') {
        message = 'لا يوجد حساب بهذا الإيميل';
      } else if (e.code == 'wrong-password') {
        message = 'كلمة المرور غير صحيحة';
      } else if (e.code == 'invalid-email') {
        message = 'الإيميل غير صالح';
      } else if (e.code == 'invalid-credential') {
        message = 'بيانات الدخول غير صحيحة';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'تسجيل الدخول',
      child: Center(
        child: SingleChildScrollView(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.child_care,
                    size: 90,
                    color: Color(0xFF8E97FD),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'أهلًا بك في طمّني',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سجّل الدخول للوصول إلى حسابك',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'الإيميل',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppPrimaryButton(
                    text: 'دخول',
                    onPressed: isLoading ? null : onLogin,
                    child: isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('دخول'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}