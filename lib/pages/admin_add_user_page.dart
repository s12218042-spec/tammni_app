import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AdminAddUserPage extends StatefulWidget {
  const AdminAddUserPage({super.key});

  @override
  State<AdminAddUserPage> createState() => _AdminAddUserPageState();
}

class _AdminAddUserPageState extends State<AdminAddUserPage> {
  final _formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final sectionCtrl = TextEditingController();
  final groupCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedRole = 'teacher';
  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    nameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    sectionCtrl.dispose();
    groupCtrl.dispose();
    phoneCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  bool get showSectionField =>
      selectedRole == 'teacher' || selectedRole == 'nursery_staff';

  bool get showGroupField => selectedRole == 'teacher';

  String get roleLabel {
    switch (selectedRole) {
      case 'teacher':
        return 'معلمة';
      case 'nursery_staff':
        return 'موظفة حضانة';
      case 'admin':
        return 'أدمن';
      default:
        return selectedRole;
    }
  }

  IconData get roleIcon {
    switch (selectedRole) {
      case 'teacher':
        return Icons.menu_book_rounded;
      case 'nursery_staff':
        return Icons.child_friendly_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Color get roleAccentColor {
    switch (selectedRole) {
      case 'teacher':
        return AppColors.kindergarten;
      case 'nursery_staff':
        return AppColors.nursery;
      case 'admin':
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  String normalizeRole(String role) {
    if (role == 'nursery_staff') return 'nursery_staff';
    if (role == 'teacher') return 'teacher';
    if (role == 'admin') return 'admin';
    return role;
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

  Future<void> createUser() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);

    try {
      final cleanUsername = usernameCtrl.text.trim().toLowerCase();
      final cleanEmail = emailCtrl.text.trim();
      final cleanName = nameCtrl.text.trim();
      final cleanPassword = passwordCtrl.text.trim();
      final cleanSection = sectionCtrl.text.trim();
      final cleanGroup = groupCtrl.text.trim();
      final cleanPhone = phoneCtrl.text.trim();
      final cleanNotes = notesCtrl.text.trim();

      final existingUsername = await _firestore
          .collection('users')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();

      if (existingUsername.docs.isNotEmpty) {
        throw Exception('اسم المستخدم مستخدم مسبقًا');
      }

      final existingEmail = await _firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (existingEmail.docs.isNotEmpty) {
        throw Exception('البريد الإلكتروني مستخدم مسبقًا');
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPassword,
      );

      final uid = userCredential.user!.uid;

      final userData = <String, dynamic>{
        'uid': uid,
        'name': cleanName,
        'displayName': cleanName,
        'username': cleanUsername,
        'email': cleanEmail,
        'role': normalizeRole(selectedRole),
        'isActive': true,
        'invitationVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (cleanPhone.isNotEmpty) {
        userData['phone'] = cleanPhone;
      }

      if (cleanNotes.isNotEmpty) {
        userData['notes'] = cleanNotes;
      }

      if (showSectionField && cleanSection.isNotEmpty) {
        userData['section'] = cleanSection;
      }

      if (showGroupField && cleanGroup.isNotEmpty) {
        userData['assignedGroups'] = [cleanGroup];
      }

      await _firestore.collection('users').doc(uid).set(userData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء حساب $roleLabel بنجاح'),
        ),
      );

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      String msg = 'حدث خطأ أثناء إنشاء الحساب';

      if (e.code == 'email-already-in-use') {
        msg = 'البريد الإلكتروني مستخدم مسبقًا';
      } else if (e.code == 'invalid-email') {
        msg = 'البريد الإلكتروني غير صالح';
      } else if (e.code == 'weak-password') {
        msg = 'كلمة المرور ضعيفة جدًا';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  InputDecoration customDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textLight),
      suffixIcon: suffixIcon,
    );
  }

  Widget buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            roleAccentColor.withOpacity(0.18),
            AppColors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: roleAccentColor.withOpacity(0.18),
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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              shape: BoxShape.circle,
            ),
            child: Icon(
              roleIcon,
              color: roleAccentColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إنشاء حساب موظف جديد',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'هذه الصفحة مخصصة للإدارة لإنشاء حسابات الموظفين فقط. أما أولياء الأمور فسيتم تسجيلهم لاحقًا عبر طلب تسجيل منفصل وموافقة من الإدارة.',
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

  Widget buildInfoCard() {
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
              'إنشاء الحسابات هنا متاح فقط للمعلمات وموظفات الحضانة والأدمن. احرصي على إدخال البيانات الأساسية بدقة، مع القسم والمجموعة عند الحاجة.',
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

  Widget buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textLight,
              ),
        ),
      ],
    );
  }

  Widget buildRoleOption({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = selectedRole == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            selectedRole = value;

            if (selectedRole == 'admin') {
              sectionCtrl.clear();
              groupCtrl.clear();
            } else if (selectedRole == 'nursery_staff') {
              groupCtrl.clear();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    isSelected ? color.withOpacity(0.15) : AppColors.background,
                child: Icon(
                  icon,
                  color: isSelected ? color : AppColors.textLight,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : AppColors.textDark,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMainCard({required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إضافة موظف',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            buildHeaderCard(),
            const SizedBox(height: 16),
            buildInfoCard(),
            const SizedBox(height: 18),

            buildMainCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSectionTitle(
                    'نوع الحساب',
                    'اختاري نوع الموظف الذي سيتم إنشاء الحساب له.',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      buildRoleOption(
                        value: 'teacher',
                        label: 'معلمة',
                        icon: Icons.menu_book_rounded,
                        color: AppColors.kindergarten,
                      ),
                      const SizedBox(width: 10),
                      buildRoleOption(
                        value: 'nursery_staff',
                        label: 'موظفة حضانة',
                        icon: Icons.child_friendly_rounded,
                        color: AppColors.nursery,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      buildRoleOption(
                        value: 'admin',
                        label: 'أدمن',
                        icon: Icons.admin_panel_settings_rounded,
                        color: AppColors.secondary,
                      ),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            buildMainCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSectionTitle(
                    'البيانات الأساسية',
                    'هذه البيانات مطلوبة لكل أنواع الموظفين.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: customDecoration(
                      label: 'الاسم الكامل',
                      icon: Icons.badge_rounded,
                      hint: 'مثال: آية محمد',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'أدخلي الاسم الكامل';
                      }
                      if (value.trim().length < 3) {
                        return 'الاسم قصير جدًا';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: customDecoration(
                      label: 'اسم المستخدم',
                      icon: Icons.alternate_email_rounded,
                      hint: 'مثال: aya_teacher',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'أدخلي اسم المستخدم';
                      }
                      if (text.length < 3) {
                        return 'اسم المستخدم قصير جدًا';
                      }
                      if (text.contains(' ')) {
                        return 'اسم المستخدم يجب أن يكون بدون مسافات';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: customDecoration(
                      label: 'البريد الإلكتروني',
                      icon: Icons.email_outlined,
                      hint: 'example@email.com',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'أدخلي البريد الإلكتروني';
                      }
                      if (!isValidEmail(text)) {
                        return 'أدخلي بريدًا إلكترونيًا صالحًا';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: customDecoration(
                      label: 'رقم الجوال',
                      icon: Icons.phone_rounded,
                      hint: 'اختياري',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscurePassword,
                    decoration: customDecoration(
                      label: 'كلمة المرور',
                      icon: Icons.lock_outline_rounded,
                      hint: '8 أحرف أو أكثر',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'أدخلي كلمة المرور';
                      }
                      if (!isValidPassword(text)) {
                        return 'يجب أن تكون 8 أحرف على الأقل وتحتوي حرف كبير وحرف صغير ورقم';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            if (showSectionField || showGroupField) ...[
              const SizedBox(height: 14),
              buildMainCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSectionTitle(
                      'بيانات العمل',
                      'تظهر هذه الحقول حسب نوع الموظف المختار.',
                    ),
                    const SizedBox(height: 14),
                    if (showSectionField)
                      TextFormField(
                        controller: sectionCtrl,
                        decoration: customDecoration(
                          label: 'القسم',
                          icon: Icons.apartment_rounded,
                          hint: selectedRole == 'teacher'
                              ? 'Kindergarten'
                              : 'Nursery',
                        ),
                        validator: (value) {
                          if (!showSectionField) return null;

                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'أدخلي القسم';
                          }
                          return null;
                        },
                      ),
                    if (showSectionField && showGroupField)
                      const SizedBox(height: 14),
                    if (showGroupField)
                      TextFormField(
                        controller: groupCtrl,
                        decoration: customDecoration(
                          label: 'المجموعة / الصف',
                          icon: Icons.groups_rounded,
                          hint: 'مثال: KG1',
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            buildMainCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSectionTitle(
                    'ملاحظات إدارية',
                    'اختياري: ملاحظات داخلية حول هذا الموظف.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 4,
                    decoration: customDecoration(
                      label: 'ملاحظات',
                      icon: Icons.notes_rounded,
                      hint: 'أي ملاحظات إضافية...',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

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
                        backgroundColor: roleAccentColor.withOpacity(0.15),
                        child: Icon(
                          roleIcon,
                          color: roleAccentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'سيتم إنشاء حساب من نوع: $roleLabel',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : createUser,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.3),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        isLoading ? 'جارٍ إنشاء الحساب...' : 'إنشاء الحساب',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'هذه الصفحة مخصصة للموظفين فقط. سيتم لاحقًا إضافة طلبات تسجيل أولياء الأمور في مسار منفصل مع موافقة الإدارة.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textLight,
                  ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}