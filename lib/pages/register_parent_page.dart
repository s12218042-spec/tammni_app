import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/account_model.dart';
import '../models/child_model.dart';
import 'login_page.dart';
import '../widgets/app_bar_widget.dart';

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

  int childrenCount = 1;
  List<TextEditingController> childNameCtrls = [];
  List<DateTime?> birthDates = [];

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

  void register() {
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

    final account = AccountModel(
      id: DummyData.newId('acc'),
      username: username,
      password: password,
      role: 'parent',
      displayName: displayName,
      email: email,
    );

    DummyData.addAccount(account);

    for (int i = 0; i < childrenCount; i++) {
      final birthDate = birthDates[i]!;
      final section = DummyData.sectionFromBirthDate(birthDate);
      final group = DummyData.defaultGroupForSection(section);

      DummyData.addChild(
        ChildModel(
          id: DummyData.newId('child'),
          name: childNameCtrls[i].text.trim(),
          section: section,
          group: group,
          parentName: displayName,
          birthDate: birthDate,
          parentUsername: username,
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إنشاء حساب ولي الأمر بنجاح ✅')),
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

  Widget _childCard(int index) {
    final birthDate = birthDates[index];
    final section =
        birthDate == null ? null : DummyData.sectionFromBirthDate(birthDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        color: const Color(0xFFF6F6FF),
      ),
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
              border: OutlineInputBorder(),
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
    );
  }

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
                  labelText: 'اسم ولي الأمر',
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