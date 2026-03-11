import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_role_page.dart';
import 'parent_home_page.dart';
import 'nursery_staff_home_page.dart';
import 'teacher_home_page.dart';
import 'admin_home_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool isCheckingUser = true;

  @override
  void initState() {
    super.initState();
    checkLoggedInUser();
  }

  Future<void> checkLoggedInUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        isCheckingUser = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        setState(() {
          isCheckingUser = false;
        });
        return;
      }

      final data = doc.data()!;
      final role = data['role'] ?? '';
      final username = data['username'] ?? '';

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
    } catch (e) {
      setState(() {
        isCheckingUser = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isCheckingUser) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF23D9D4),
                Color(0xFF5EE6C4),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.child_care,
                    size: 120,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "مرحباً في تطبيق طمّني",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "تطبيق يساعد الأهل على متابعة أطفالهم في الحضانة والروضة بسهولة وأمان",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 60),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "تسجيل الدخول",
                        style: TextStyle(fontSize: 18),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "إنشاء حساب جديد",
                        style: TextStyle(fontSize: 18),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterRolePage(),
                          ),
                        );
                      },
                    ),
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