import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/app_page_scaffold.dart';
import 'welcome_page.dart';

class RegisterEmployeePage extends StatefulWidget {
  final String role; // nursery / teacher

  const RegisterEmployeePage({
    super.key,
    required this.role,
  });

  @override
  State<RegisterEmployeePage> createState() => _RegisterEmployeePageState();
}

class _RegisterEmployeePageState extends State<RegisterEmployeePage> {
  final displayNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  final invitationCodeCtrl = TextEditingController();

  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    displayNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    invitationCodeCtrl.dispose();
    super.dispose();
  }

  bool isValidUsername(String value) {
    return value.trim().length >= 4 && !value.contains(' ');
  }

  bool isValidEmail(String value) {
    return value.contains('@') && value.contains('.');
  }

  bool isValidPassword(String value) {
    final hasUpper = value.contains(RegExp(r'[A-Z]'));
    final hasLower = value.contains(RegExp(r'[a-z]'));
    final hasNumber = value.contains(RegExp(r'[0-9]'));
    return value.length >= 8 && hasUpper && hasLower && hasNumber;
  }

  Future<bool> usernameExists(String username) async {
    final result = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    return result.docs.isNotEmpty;
  }

  String get expectedInvitationCode {
    if (widget.role == 'nursery') {
      return 'NURSERY2026';
    }
    return 'TEACHER2026';
  }

  String get title {
    return widget.role == 'nursery'
        ? 'إنشاء حساب موظفة حضانة'
        : 'إنشاء حساب معلمة روضة';
  }

  String get roleLabel {
    return widget.role == 'nursery' ? 'موظفة حضانة' : 'معلمة روضة';
  }

  Future<void> register() async {
    final displayName = displayNameCtrl.text.trim();
    final username = usernameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text;
    final confirmPassword = confirmPasswordCtrl.text;
    final code = invitationCodeCtrl.text.trim();

    if (displayName.isEmpty) {
      _show('اكتبي الاسم');
      return;
    }

    if (!isValidUsername(username)) {
      _show('اسم المستخدم يجب أن يكون 4 أحرف على الأقل وبدون مسافات');
      return;
    }

    if (!isValidEmail(email)) {
      _show('الإيميل غير صالح');
      return;
    }

    if (!isValidPassword(password)) {
      _show(
        'كلمة المرور يجب أن تكون 8 أحرف على الأقل وتحتوي حرف كبير وحرف صغير ورقم',
      );
      return;
    }

    if (password != confirmPassword) {
      _show('تأكيد كلمة المرور غير مطابق');
      return;
    }

    if (code.isEmpty) {
      _show('أدخلي Invitation Code');
      return;
    }

    if (code != expectedInvitationCode) {
      _show('Invitation Code غير صحيح');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final exists = await usernameExists(username);
      if (exists) {
        _show('اسم المستخدم مستخدم مسبقًا');
        setState(() {
          isLoading = false;
        });
        return;
      }

      final user = await _authService.register(
        email: email,
        password: password,
      );

      if (user == null) {
        _show('فشل إنشاء الحساب');
        setState(() {
          isLoading = false;
        });
        return;
      }

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'displayName': displayName,
        'username': username,
        'email': email,
        'role': widget.role,
        'invitationVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إنشاء حساب $roleLabel بنجاح ✅')),
      );

      Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (_) => const WelcomePage()),
  (route) => false,
);

    } on FirebaseException catch (e) {
      String message = 'حدث خطأ أثناء إنشاء الحساب';

      if (e.code == 'email-already-in-use') {
        message = 'هذا الإيميل مستخدم مسبقًا';
      } else if (e.code == 'invalid-email') {
        message = 'الإيميل غير صالح';
      } else if (e.code == 'weak-password') {
        message = 'كلمة المرور ضعيفة';
      }

      _show(message);
    } catch (e) {
      _show('حدث خطأ: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: title,
      child: ListView(
        children: [
          TextField(
            controller: displayNameCtrl,
            decoration: const InputDecoration(
              labelText: 'الاسم',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: usernameCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم المستخدم',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
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
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmPasswordCtrl,
            obscureText: obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'تأكيد كلمة المرور',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    obscureConfirmPassword = !obscureConfirmPassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: invitationCodeCtrl,
            decoration: const InputDecoration(
              labelText: 'Invitation Code',
              prefixIcon: Icon(Icons.verified_user_outlined),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : register,
              child: isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('إنشاء الحساب'),
            ),
          ),
        ],
      ),
    );
  }
}