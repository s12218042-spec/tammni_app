import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/app_page_scaffold.dart';
import 'welcome_page.dart';
import '../services/notification_service.dart';

class RegisterParentPage extends StatefulWidget {
  const RegisterParentPage({super.key});

  @override
  State<RegisterParentPage> createState() => _RegisterParentPageState();
}

class _RegisterParentPageState extends State<RegisterParentPage> {
  final displayNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int childrenCount = 1;
  List<TextEditingController> childNameCtrls = [];
  List<DateTime?> birthDates = [];

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _buildChildFields();
  }

  @override
  void dispose() {
    displayNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    for (final c in childNameCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _buildChildFields() {
    for (final c in childNameCtrls) {
      c.dispose();
    }
    childNameCtrls =
        List.generate(childrenCount, (_) => TextEditingController());
    birthDates = List.generate(childrenCount, (_) => null);
    setState(() {});
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

  Future<void> pickBirthDate(int index) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 2),
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        birthDates[index] = picked;
      });
    }
  }

  String dateText(DateTime? d) {
    if (d == null) return 'اختيار تاريخ الميلاد';
    return '${d.year}/${d.month}/${d.day}';
  }

  String sectionFromBirthDate(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    if (age <= 3) {
      return 'Nursery';
    }
    return 'Kindergarten';
  }

  String defaultGroupForSection(String section) {
    return section == 'Nursery' ? 'حضانة صغار' : 'KG1';
  }

  Future<bool> usernameExists(String username) async {
    final result = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    return result.docs.isNotEmpty;
  }

  Future<void> register() async {
    final displayName = displayNameCtrl.text.trim();
    final username = usernameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text;
    final confirmPassword = confirmPasswordCtrl.text;

    if (displayName.isEmpty) {
      _show('اكتبي اسم ولي الأمر');
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
      _show('كلمة المرور يجب أن تكون 8 أحرف على الأقل وتحتوي حرف كبير وحرف صغير ورقم');
      return;
    }

    if (password != confirmPassword) {
      _show('تأكيد كلمة المرور غير مطابق');
      return;
    }

    for (int i = 0; i < childrenCount; i++) {
      if (childNameCtrls[i].text.trim().isEmpty) {
        _show('اكتبي اسم الطفل رقم ${i + 1}');
        return;
      }
      if (birthDates[i] == null) {
        _show('اختاري تاريخ الميلاد للطفل رقم ${i + 1}');
        return;
      }
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
      'role': 'parent',
      'fcmTokens': [],
      'createdAt': FieldValue.serverTimestamp(),
      });

    await NotificationService.instance.saveCurrentUserToken();

      for (int i = 0; i < childrenCount; i++) {
        final birthDate = birthDates[i]!;
        final section = sectionFromBirthDate(birthDate);
        final group = defaultGroupForSection(section);

        await _firestore.collection('children').add({
          'name': childNameCtrls[i].text.trim(),
          'section': section,
          'group': group,
          'parentName': displayName,
          'parentUsername': username,
          'parentUid': user.uid,
          'birthDate': Timestamp.fromDate(birthDate),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء حساب وليّ الأمر بنجاح ✅')),
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

  Widget _childCard(int index) {
    final birthDate = birthDates[index];
    final section =
        birthDate == null ? null : sectionFromBirthDate(birthDate);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الطفل ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: childNameCtrls[index],
              decoration: const InputDecoration(
                labelText: 'اسم الطفل',
                prefixIcon: Icon(Icons.child_care),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => pickBirthDate(index),
                icon: const Icon(Icons.calendar_month),
                label: Text(dateText(birthDate)),
              ),
            ),
            if (section != null) ...[
              const SizedBox(height: 8),
              Text(
                'القسم التلقائي: ${section == "Nursery" ? "حضانة" : "روضة"}',
                style: const TextStyle(
                  color: Color(0xFF8E97FD),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'تسجيل وليّ أمر',
      child: ListView(
        children: [
          TextField(
            controller: displayNameCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم وليّ الأمر',
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
          const SizedBox(height: 16),

          const Text(
            'عدد الأطفال',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: childrenCount.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$childrenCount',
            onChanged: (v) {
              childrenCount = v.toInt();
              _buildChildFields();
            },
          ),
          Text('عدد الأطفال: $childrenCount'),

          const SizedBox(height: 12),
          ...List.generate(childrenCount, (index) => _childCard(index)),

          const SizedBox(height: 8),
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