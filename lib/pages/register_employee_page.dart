import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/account_model.dart';
import 'login_page.dart';
import '../widgets/app_bar_widget.dart';

class RegisterEmployeePage extends StatefulWidget {
  final String role; // nursery / teacher
  const RegisterEmployeePage({super.key, required this.role});

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

  void register() {
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
    if (DummyData.usernameExists(username)) {
      _show('اسم المستخدم مستخدم مسبقاً');
      return;
    }
    if (!isValidEmail(email)) {
      _show('الإيميل غير صالح');
      return;
    }
    if (!isValidPassword(password)) {
      _show('كلمة المرور يجب أن تكون 8 أحرف على الأقل وتحتوي حرف كبير وحرف صغير ورقم');
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

    final expectedCode = widget.role == 'nursery'
        ? DummyData.nurseryInvitationCode
        : DummyData.teacherInvitationCode;

    if (code != expectedCode) {
      _show('Invitation Code غير صحيح');
      return;
    }

    DummyData.addAccount(
      AccountModel(
        id: DummyData.newId('acc'),
        username: username,
        password: password,
        role: widget.role,
        displayName: displayName,
        email: email,
        invitationVerified: true,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إنشاء حساب الموظف بنجاح ✅')),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String get title =>
      widget.role == 'nursery' ? 'إنشاء حساب موظف/ة حضانة' : 'إنشاء حساب موظف/ة روضة';

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
              TextField(
                controller: displayNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'الإيميل',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: invitationCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Invitation Code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E97FD),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('إنشاء الحساب'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}