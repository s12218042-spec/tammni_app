import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AddAdminPage extends StatefulWidget {
  const AddAdminPage({super.key});

  @override
  State<AddAdminPage> createState() => _AddAdminPageState();
}

class _AddAdminPageState extends State<AddAdminPage> {
  final _formKey = GlobalKey<FormState>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // بيانات الحساب
  final fullNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  // البيانات الشخصية
  final nationalIdCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  // البيانات المهنية
  final jobTitleCtrl = TextEditingController(text: 'أدمن');
  final specializationCtrl = TextEditingController();
  final yearsOfExperienceCtrl = TextEditingController();
  final permissionsCtrl = TextEditingController();
  final cvNotesCtrl = TextEditingController();

  // الطوارئ / الملاحظات
  final emergencyNameCtrl = TextEditingController();
  final emergencyRelationCtrl = TextEditingController();
  final emergencyPhoneCtrl = TextEditingController();
  final adminNotesCtrl = TextEditingController();

  DateTime? birthDate;
  DateTime? hireDate;

  String gender = 'أنثى';
  String maritalStatus = 'أعزب/عزباء';
  String qualification = 'بكالوريوس';
  String employmentType = 'دوام كامل';
  String employmentStatus = 'نشط';
  String adminScope = 'all';

  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    fullNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    nationalIdCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    jobTitleCtrl.dispose();
    specializationCtrl.dispose();
    yearsOfExperienceCtrl.dispose();
    permissionsCtrl.dispose();
    cvNotesCtrl.dispose();
    emergencyNameCtrl.dispose();
    emergencyRelationCtrl.dispose();
    emergencyPhoneCtrl.dispose();
    adminNotesCtrl.dispose();
    super.dispose();
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

  Widget buildMainCard({required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
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

  Widget buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withOpacity(0.18),
            AppColors.primary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.18),
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
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: AppColors.secondary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة أدمن',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'نموذج مخصص لإنشاء حساب إداري مع نطاق الإدارة والصلاحيات والخبرة الإدارية.',
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
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'العمر الأدنى المقترح للأدمن هنا 25 سنة. ويمكن تحديد نطاق الإدارة: كل النظام أو الحضانة فقط أو الروضة فقط.',
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

  Future<void> pickBirthDate() async {
    final now = DateTime.now();
    final initial = birthDate ?? DateTime(now.year - 28, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 75),
      lastDate: DateTime(now.year - 25),
      helpText: 'اختيار تاريخ الميلاد',
    );

    if (picked != null) {
      setState(() {
        birthDate = picked;
      });
    }
  }

  Future<void> pickHireDate() async {
    final now = DateTime.now();
    final initial = hireDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 35),
      lastDate: now,
      helpText: 'اختيار تاريخ التعيين',
    );

    if (picked != null) {
      setState(() {
        hireDate = picked;
      });
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$y/$m/$d';
  }

  int calculateAge(DateTime birth) {
    final now = DateTime.now();
    int age = now.year - birth.year;
    final hadBirthdayThisYear =
        (now.month > birth.month) ||
        (now.month == birth.month && now.day >= birth.day);
    if (!hadBirthdayThisYear) age--;
    return age;
  }

  bool isValidPalestinianId(String value) {
    final clean = value.trim();
    if (!RegExp(r'^\d{9}$').hasMatch(clean)) return false;
    if (clean == '000000000') return false;
    return true;
  }

  bool isValidPalestinianMobile(String value) {
    final clean = value.replaceAll(' ', '');
    return RegExp(r'^(059|056)\d{7}$').hasMatch(clean) ||
        RegExp(r'^(\+97059|\+97056)\d{7}$').hasMatch(clean);
  }

  bool isValidEmail(String value) {
    return RegExp(
      r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$",
    ).hasMatch(value.trim());
  }

  bool isValidUsername(String value) {
    return RegExp(r'^[a-z][a-z0-9._]{3,19}$').hasMatch(value.trim());
  }

  bool isValidPassword(String value) {
    final hasUpper = value.contains(RegExp(r'[A-Z]'));
    final hasLower = value.contains(RegExp(r'[a-z]'));
    final hasNumber = value.contains(RegExp(r'[0-9]'));
    final hasSpecial = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/]'));
    return value.length >= 8 &&
        hasUpper &&
        hasLower &&
        hasNumber &&
        hasSpecial;
  }

  List<String> splitCommaValues(String value) {
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  String? validateBirthDate() {
    if (birthDate == null) {
      return 'اختاري تاريخ الميلاد';
    }
    final age = calculateAge(birthDate!);
    if (age < 25) {
      return 'عمر الأدمن يجب أن يكون 25 سنة فأكثر';
    }
    if (age > 75) {
      return 'العمر المدخل غير منطقي';
    }
    return null;
  }

  String? validateHireDate() {
    if (hireDate == null) {
      return 'اختاري تاريخ التعيين';
    }
    final now = DateTime.now();
    if (hireDate!.isAfter(now)) {
      return 'تاريخ التعيين لا يمكن أن يكون في المستقبل';
    }
    if (birthDate != null) {
      final minimumWorkingDate = DateTime(
        birthDate!.year + 21,
        birthDate!.month,
        birthDate!.day,
      );
      if (hireDate!.isBefore(minimumWorkingDate)) {
        return 'تاريخ التعيين غير منطقي مقارنة بتاريخ الميلاد';
      }
    }
    return null;
  }

  Future<FirebaseApp> _createSecondaryApp() async {
    const appName = 'adminCreationApp';
    try {
      return Firebase.app(appName);
    } catch (_) {
      return Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  Future<void> createAdmin() async {
    final birthError = validateBirthDate();
    final hireError = validateHireDate();

    if (!_formKey.currentState!.validate() ||
        birthError != null ||
        hireError != null) {
      if (birthError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(birthError)),
        );
      } else if (hireError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hireError)),
        );
      }
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);

    FirebaseApp? tempApp;

    try {
      final cleanName = fullNameCtrl.text.trim();
      final cleanUsername = usernameCtrl.text.trim().toLowerCase();
      final cleanEmail = emailCtrl.text.trim().toLowerCase();
      final cleanPassword = passwordCtrl.text.trim();
      final cleanNationalId = nationalIdCtrl.text.trim();
      final cleanPhone = phoneCtrl.text.trim();
      final cleanAddress = addressCtrl.text.trim();
      final cleanJobTitle = jobTitleCtrl.text.trim();
      final cleanSpecialization = specializationCtrl.text.trim();
      final cleanExperience = yearsOfExperienceCtrl.text.trim();
      final cleanPermissions = splitCommaValues(permissionsCtrl.text);
      final cleanCvNotes = cvNotesCtrl.text.trim();
      final cleanEmergencyName = emergencyNameCtrl.text.trim();
      final cleanEmergencyRelation = emergencyRelationCtrl.text.trim();
      final cleanEmergencyPhone = emergencyPhoneCtrl.text.trim();
      final cleanAdminNotes = adminNotesCtrl.text.trim();

      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) {
        throw Exception('يجب أن يكون الأدمن مسجل الدخول أولاً');
      }

      final usernameExists = await _firestore
          .collection('users')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();

      if (usernameExists.docs.isNotEmpty) {
        throw Exception('اسم المستخدم مستخدم مسبقًا');
      }

      final emailExists = await _firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (emailExists.docs.isNotEmpty) {
        throw Exception('البريد الإلكتروني مستخدم مسبقًا');
      }

      tempApp = await _createSecondaryApp();
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      final newUserCredential = await tempAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPassword,
      );

      final newUid = newUserCredential.user!.uid;

      String createdByName = 'الإدارة';
      final adminDoc =
          await _firestore.collection('users').doc(currentAdmin.uid).get();
      if (adminDoc.exists) {
        createdByName =
            (adminDoc.data()?['name'] ??
                    adminDoc.data()?['displayName'] ??
                    'الإدارة')
                .toString();
      }

      final userData = <String, dynamic>{
        'uid': newUid,
        'name': cleanName,
        'displayName': cleanName,
        'username': cleanUsername,
        'email': cleanEmail,
        'role': 'admin',
        'section': adminScope == 'nursery'
            ? 'Nursery'
            : adminScope == 'kindergarten'
                ? 'Kindergarten'
                : 'all',
        'adminScope': adminScope,
        'isActive': true,
        'accountStatus': 'active',
        'invitationVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdByUid': currentAdmin.uid,
        'createdByName': createdByName,

        'personalInfo': {
          'nationalId': cleanNationalId,
          'gender': gender,
          'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),
          'maritalStatus': maritalStatus,
          'phone': cleanPhone,
          'address': cleanAddress,
        },

        'professionalInfo': {
          'jobTitle': cleanJobTitle,
          'qualification': qualification,
          'specialization': cleanSpecialization,
          'yearsOfExperience':
              cleanExperience.isEmpty ? 0 : int.tryParse(cleanExperience) ?? 0,
          'hireDate': hireDate == null ? null : Timestamp.fromDate(hireDate!),
          'employmentType': employmentType,
          'employmentStatus': employmentStatus,
          'adminScope': adminScope,
          'permissions': cleanPermissions,
          'cvNotes': cleanCvNotes,
        },

        'emergencyContact': {
          'name': cleanEmergencyName,
          'relation': cleanEmergencyRelation,
          'phone': cleanEmergencyPhone,
        },

        'adminNotes': {
          'internalNotes': cleanAdminNotes,
        },
      };

      await _firestore.collection('users').doc(newUid).set(userData);

      await tempAuth.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء حساب الأدمن بنجاح'),
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
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (tempApp != null) {
        try {
          await tempApp.delete();
        } catch (_) {}
      }

      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget buildDateTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          color: AppColors.surface,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textLight),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$label: $value',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إضافة أدمن',
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
                    'بيانات الحساب',
                    'هذه البيانات مسؤولة عن إنشاء حساب تسجيل الدخول للإدارة.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: fullNameCtrl,
                    decoration: customDecoration(
                      label: 'الاسم الكامل',
                      icon: Icons.badge_rounded,
                      hint: 'مثال: مجد المصري',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي الاسم الكامل';
                      if (text.length < 3) return 'الاسم قصير جدًا';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: customDecoration(
                      label: 'اسم المستخدم',
                      icon: Icons.alternate_email_rounded,
                      hint: 'مثال: majd.admin',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي اسم المستخدم';
                      if (!isValidUsername(text)) {
                        return 'اسم المستخدم يجب أن يبدأ بحرف صغير ويحتوي فقط على حروف صغيرة/أرقام/./_';
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
                      hint: 'admin@example.com',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي البريد الإلكتروني';
                      if (!isValidEmail(text)) return 'أدخلي بريدًا إلكترونيًا صالحًا';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscurePassword,
                    decoration: customDecoration(
                      label: 'كلمة المرور',
                      icon: Icons.lock_outline_rounded,
                      hint: '8 أحرف فأكثر',
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
                      if (text.isEmpty) return 'أدخلي كلمة المرور';
                      if (!isValidPassword(text)) {
                        return 'يجب أن تحتوي على 8 أحرف على الأقل وحرف كبير وصغير ورقم ورمز خاص';
                      }
                      return null;
                    },
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
                    'البيانات الشخصية',
                    'معلومات الهوية والتواصل الأساسية الخاصة بالأدمن.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nationalIdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: customDecoration(
                      label: 'رقم الهوية',
                      icon: Icons.credit_card_rounded,
                      hint: '9 أرقام',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي رقم الهوية';
                      if (!isValidPalestinianId(text)) {
                        return 'رقم الهوية الفلسطينية غير صالح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: gender,
                    decoration: customDecoration(
                      label: 'الجنس',
                      icon: Icons.wc_rounded,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                      DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => gender = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  buildDateTile(
                    label: 'تاريخ الميلاد',
                    value: formatDate(birthDate),
                    icon: Icons.cake_rounded,
                    onTap: pickBirthDate,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: maritalStatus,
                    decoration: customDecoration(
                      label: 'الحالة الاجتماعية',
                      icon: Icons.favorite_outline_rounded,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'أعزب/عزباء', child: Text('أعزب/عزباء')),
                      DropdownMenuItem(value: 'متزوج/ة', child: Text('متزوج/ة')),
                      DropdownMenuItem(value: 'مطلق/ة', child: Text('مطلق/ة')),
                      DropdownMenuItem(value: 'أرمل/ة', child: Text('أرمل/ة')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => maritalStatus = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: customDecoration(
                      label: 'رقم الجوال',
                      icon: Icons.phone_rounded,
                      hint: '059xxxxxxx أو 056xxxxxxx',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي رقم الجوال';
                      if (!isValidPalestinianMobile(text)) {
                        return 'رقم الجوال الفلسطيني غير صالح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: customDecoration(
                      label: 'العنوان',
                      icon: Icons.home_outlined,
                      hint: 'مثال: نابلس - الجبل الشمالي',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي العنوان';
                      if (text.length < 5) return 'العنوان قصير جدًا';
                      return null;
                    },
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
                    'البيانات المهنية',
                    'بيانات العمل الإداري ونطاق الإدارة والخبرة والصلاحيات.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: jobTitleCtrl,
                    decoration: customDecoration(
                      label: 'المسمى الوظيفي',
                      icon: Icons.work_outline_rounded,
                      hint: 'مثال: مدير نظام / مشرف إداري',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي المسمى الوظيفي';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: adminScope,
                    decoration: customDecoration(
                      label: 'نطاق الإدارة',
                      icon: Icons.admin_panel_settings_rounded,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('كل النظام')),
                      DropdownMenuItem(value: 'nursery', child: Text('الحضانة فقط')),
                      DropdownMenuItem(value: 'kindergarten', child: Text('الروضة فقط')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => adminScope = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: qualification,
                    decoration: customDecoration(
                      label: 'المؤهل العلمي',
                      icon: Icons.school_rounded,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'دبلوم', child: Text('دبلوم')),
                      DropdownMenuItem(value: 'بكالوريوس', child: Text('بكالوريوس')),
                      DropdownMenuItem(value: 'ماجستير', child: Text('ماجستير')),
                      DropdownMenuItem(value: 'دكتوراه', child: Text('دكتوراه')),
                      DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => qualification = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: specializationCtrl,
                    decoration: customDecoration(
                      label: 'التخصص',
                      icon: Icons.auto_stories_rounded,
                      hint: 'مثال: إدارة أعمال / إدارة تربوية / نظم معلومات',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي التخصص';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: yearsOfExperienceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: customDecoration(
                      label: 'سنوات الخبرة الإدارية',
                      icon: Icons.workspace_premium_rounded,
                      hint: 'مثال: 5',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي سنوات الخبرة';
                      final years = int.tryParse(text);
                      if (years == null || years < 0 || years > 50) {
                        return 'سنوات الخبرة غير صالحة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  buildDateTile(
                    label: 'تاريخ التعيين',
                    value: formatDate(hireDate),
                    icon: Icons.event_available_rounded,
                    onTap: pickHireDate,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: employmentType,
                    decoration: customDecoration(
                      label: 'نوع الدوام',
                      icon: Icons.schedule_rounded,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'دوام كامل', child: Text('دوام كامل')),
                      DropdownMenuItem(value: 'دوام جزئي', child: Text('دوام جزئي')),
                      DropdownMenuItem(value: 'دوام صباحي', child: Text('دوام صباحي')),
                      DropdownMenuItem(value: 'دوام مسائي', child: Text('دوام مسائي')),
                      DropdownMenuItem(value: 'تعاقد مؤقت', child: Text('تعاقد مؤقت')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => employmentType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: employmentStatus,
                    decoration: customDecoration(
                      label: 'الحالة الوظيفية',
                      icon: Icons.verified_user_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'نشط', child: Text('نشط')),
                      DropdownMenuItem(value: 'تحت التجربة', child: Text('تحت التجربة')),
                      DropdownMenuItem(value: 'في إجازة', child: Text('في إجازة')),
                      DropdownMenuItem(value: 'موقوف مؤقتًا', child: Text('موقوف مؤقتًا')),
                      DropdownMenuItem(value: 'مؤرشف', child: Text('مؤرشف')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => employmentStatus = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: permissionsCtrl,
                    maxLines: 2,
                    decoration: customDecoration(
                      label: 'الصلاحيات الإدارية',
                      icon: Icons.security_rounded,
                      hint: 'مثال: users.manage, children.approve, reports.view',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: cvNotesCtrl,
                    maxLines: 2,
                    decoration: customDecoration(
                      label: 'ملاحظات السيرة الذاتية / CV',
                      icon: Icons.description_outlined,
                      hint: 'مكان مؤقت لتسجيل ملاحظات CV إلى أن نضيف الرفع الفعلي',
                    ),
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
                    'بيانات الطوارئ',
                    'بيانات التواصل عند الحاجة.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emergencyNameCtrl,
                    decoration: customDecoration(
                      label: 'اسم شخص الطوارئ',
                      icon: Icons.contact_phone_rounded,
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي اسم شخص الطوارئ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emergencyRelationCtrl,
                    decoration: customDecoration(
                      label: 'صلة القرابة / العلاقة',
                      icon: Icons.people_alt_outlined,
                      hint: 'مثال: الأخ / الأخت / الزوج',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي صلة العلاقة';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emergencyPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: customDecoration(
                      label: 'رقم الطوارئ',
                      icon: Icons.phone_in_talk_rounded,
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي رقم الطوارئ';
                      if (!isValidPalestinianMobile(text)) {
                        return 'رقم الطوارئ الفلسطيني غير صالح';
                      }
                      return null;
                    },
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
                    'ملاحظات إدارية',
                    'ملاحظات داخلية تخص هذا الحساب الإداري.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: adminNotesCtrl,
                    maxLines: 4,
                    decoration: customDecoration(
                      label: 'ملاحظات إدارية',
                      icon: Icons.notes_rounded,
                      hint: 'أي ملاحظات إضافية حول هذا الأدمن...',
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
                        backgroundColor: AppColors.secondary.withOpacity(0.15),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'سيتم إنشاء حساب من نوع: أدمن',
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
                      onPressed: isLoading ? null : createAdmin,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.3),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        isLoading ? 'جارٍ إنشاء الحساب...' : 'إنشاء حساب الأدمن',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}