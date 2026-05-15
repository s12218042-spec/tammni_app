import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/employee_account_creation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AddNurseryStaffPage extends StatefulWidget {
  const AddNurseryStaffPage({super.key});

  @override
  State<AddNurseryStaffPage> createState() => _AddNurseryStaffPageState();
}

class _AddNurseryStaffPageState extends State<AddNurseryStaffPage> {
  final _formKey = GlobalKey<FormState>();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EmployeeAccountCreationService _accountCreationService =
      EmployeeAccountCreationService();

  // بيانات الحساب
  final fullNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  // البيانات الشخصية
  final nationalIdCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final alternativePhoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  // البيانات المهنية / التعليمية
  final jobTitleCtrl = TextEditingController(text: 'موظفة حضانة');
  final specializationCtrl = TextEditingController();
  final universityCtrl = TextEditingController();
  final collegeCtrl = TextEditingController();
  final graduationYearCtrl = TextEditingController();
  final yearsOfExperienceCtrl = TextEditingController();
  final responsibilitiesCtrl = TextEditingController();
  final certificationsCtrl = TextEditingController();
  final cvNotesCtrl = TextEditingController();

  // ملاحظات إدارية
  final extraPermissionsCtrl = TextEditingController();
  final adminNotesCtrl = TextEditingController();

  DateTime? birthDate;
  DateTime? hireDate;

  String gender = 'أنثى';
  String qualification = 'بكالوريوس';
  String employmentType = 'دوام كامل';

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  static const String fixedSection = 'Nursery';

  @override
  void dispose() {
    fullNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();

    nationalIdCtrl.dispose();
    phoneCtrl.dispose();
    alternativePhoneCtrl.dispose();
    addressCtrl.dispose();

    jobTitleCtrl.dispose();
    specializationCtrl.dispose();
    universityCtrl.dispose();
    collegeCtrl.dispose();
    graduationYearCtrl.dispose();
    yearsOfExperienceCtrl.dispose();
    responsibilitiesCtrl.dispose();
    certificationsCtrl.dispose();
    cvNotesCtrl.dispose();

    extraPermissionsCtrl.dispose();
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
            AppColors.nursery.withOpacity(0.18),
            AppColors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.nursery.withOpacity(0.18),
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
              Icons.child_friendly_rounded,
              color: AppColors.nursery,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة موظفة حضانة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'إنشاء حساب موظفة حضانة بالبيانات الأساسية والمهنية اللازمة فقط.',
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

  Future<void> pickBirthDate() async {
    final now = DateTime.now();
    final initial = birthDate ?? DateTime(now.year - 22, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 70),
      lastDate: DateTime(now.year - 18),
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
      firstDate: DateTime(now.year - 30),
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
        now.month > birth.month || (now.month == birth.month && now.day >= birth.day);

    if (!hadBirthdayThisYear) age--;

    return age;
  }

  bool isValidPalestinianId(String value) {
    final clean = value.trim();
    if (!RegExp(r'^\d{9}$').hasMatch(clean)) return false;
    if (RegExp(r'^(\d)\1{8}$').hasMatch(clean)) return false;
    return true;
  }

  bool isValidPalestinianMobile(String value) {
    final clean = value.replaceAll(' ', '');
    return RegExp(r'^(059|056|052)\d{7}$').hasMatch(clean) ||
        RegExp(r'^(\+97059|\+97056|\+97052)\d{7}$').hasMatch(clean);
  }

  bool isValidEmail(String value) {
    return RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
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

    if (age < 18) {
      return 'عمر موظفة الحضانة يجب أن يكون 18 سنة فأكثر';
    }

    if (age > 70) {
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
        birthDate!.year + 18,
        birthDate!.month,
        birthDate!.day,
      );

      if (hireDate!.isBefore(minimumWorkingDate)) {
        return 'تاريخ التعيين غير منطقي مقارنة بتاريخ الميلاد';
      }
    }

    return null;
  }

  Future<void> createNurseryStaff() async {
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

    try {
      final cleanName = fullNameCtrl.text.trim();
      final cleanUsername = usernameCtrl.text.trim().toLowerCase();
      final cleanEmail = emailCtrl.text.trim().toLowerCase();
      final cleanPassword = passwordCtrl.text.trim();
      final cleanNationalId = nationalIdCtrl.text.trim();
      final cleanPhone = phoneCtrl.text.trim();
      final cleanAlternativePhone = alternativePhoneCtrl.text.trim();
      final cleanAddress = addressCtrl.text.trim();

      final cleanJobTitle = jobTitleCtrl.text.trim();
      final cleanSpecialization = specializationCtrl.text.trim();
      final cleanUniversity = universityCtrl.text.trim();
      final cleanCollege = collegeCtrl.text.trim();
      final cleanGraduationYear = graduationYearCtrl.text.trim();
      final cleanExperience = yearsOfExperienceCtrl.text.trim();
      final cleanResponsibilities = splitCommaValues(responsibilitiesCtrl.text);
      final cleanCertifications = splitCommaValues(certificationsCtrl.text);
      final cleanCvNotes = cvNotesCtrl.text.trim();

      final cleanExtraPermissions = splitCommaValues(extraPermissionsCtrl.text);
      final cleanAdminNotes = adminNotesCtrl.text.trim();

      await _accountCreationService.validateCommonUniqueness(
        username: cleanUsername,
        email: cleanEmail,
        nationalId: cleanNationalId,
        phone: cleanPhone,
      );

      final currentAdmin = _auth.currentUser;
      if (currentAdmin == null) {
        throw Exception('يجب أن يكون الأدمن مسجل الدخول أولاً');
      }

      final createdByName = await _accountCreationService.getCurrentAdminName();

      final userData = <String, dynamic>{
        'name': cleanName,
        'displayName': cleanName,
        'role': 'nursery_staff',
        'section': fixedSection,
        'group': '',
        'groupId': '',
        'groupName': '',
        'assignedGroups': [],
        'assignedStaffGroupId': '',
        'assignedStaffGroupName': '',
        'isActive': true,
        'accountStatus': 'active',
        'invitationVerified': true,
        'createdByUid': currentAdmin.uid,
        'createdByName': createdByName,
        'personalInfo': {
          'nationalId': cleanNationalId,
          'gender': gender,
          'birthDate': Timestamp.fromDate(birthDate!),
          'phone': cleanPhone,
          'alternativePhone': cleanAlternativePhone,
          'address': cleanAddress,
        },
        'professionalInfo': {
          'jobTitle': cleanJobTitle,
          'section': fixedSection,
          'qualification': qualification,
          'specialization': cleanSpecialization,
          'university': cleanUniversity,
          'college': cleanCollege,
          'graduationYear': cleanGraduationYear.isEmpty
              ? null
              : int.tryParse(cleanGraduationYear),
          'yearsOfExperience':
              cleanExperience.isEmpty ? 0 : int.tryParse(cleanExperience) ?? 0,
          'hireDate': Timestamp.fromDate(hireDate!),
          'employmentType': employmentType,
          'responsibilities': cleanResponsibilities,
          'certifications': cleanCertifications,
          'cvNotes': cleanCvNotes,
        },
        'adminNotes': {
          'internalNotes': cleanAdminNotes,
          'extraPermissions': cleanExtraPermissions,
        },
      };

      await _accountCreationService.createEmployeeAccount(
        secondaryAppName:
            'nurseryStaffCreationApp_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanName,
        username: cleanUsername,
        email: cleanEmail,
        password: cleanPassword,
        role: 'nursery_staff',
        userData: userData,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء حساب موظفة الحضانة بنجاح')),
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
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
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
      onTap: isLoading ? null : onTap,
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
      title: 'إضافة موظفة حضانة',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            buildHeaderCard(),
            const SizedBox(height: 18),

            buildMainCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSectionTitle(
                    'بيانات الحساب',
                    'هذه البيانات تستخدم لتسجيل دخول الموظفة إلى التطبيق.',
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: fullNameCtrl,
                    enabled: !isLoading,
                    decoration: customDecoration(
                      label: 'الاسم الكامل',
                      icon: Icons.badge_rounded,
                      hint: 'مثال: آية عبد الحق',
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
                    enabled: !isLoading,
                    decoration: customDecoration(
                      label: 'اسم المستخدم',
                      icon: Icons.alternate_email_rounded,
                      hint: 'مثال: aya.nursery',
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
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    decoration: customDecoration(
                      label: 'البريد الإلكتروني',
                      icon: Icons.email_outlined,
                      hint: 'nursery@example.com',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي البريد الإلكتروني';
                      if (!isValidEmail(text)) {
                        return 'أدخلي بريدًا إلكترونيًا صالحًا';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: passwordCtrl,
                    enabled: !isLoading,
                    obscureText: obscurePassword,
                    decoration: customDecoration(
                      label: 'كلمة المرور',
                      icon: Icons.lock_outline_rounded,
                      hint: '8 أحرف فأكثر',
                      suffixIcon: IconButton(
                        onPressed: isLoading
                            ? null
                            : () {
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
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: confirmPasswordCtrl,
                    enabled: !isLoading,
                    obscureText: obscureConfirmPassword,
                    decoration: customDecoration(
                      label: 'تأكيد كلمة المرور',
                      icon: Icons.lock_reset_rounded,
                      hint: 'أعيدي كتابة كلمة المرور',
                      suffixIcon: IconButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                setState(() {
                                  obscureConfirmPassword =
                                      !obscureConfirmPassword;
                                });
                              },
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي تأكيد كلمة المرور';
                      if (text != passwordCtrl.text.trim()) {
                        return 'كلمة المرور وتأكيدها غير متطابقين';
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
                    'معلومات الهوية والتواصل الأساسية.',
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: nationalIdCtrl,
                    enabled: !isLoading,
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
                    onChanged: isLoading
                        ? null
                        : (value) {
                            if (value != null) setState(() => gender = value);
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

                  TextFormField(
                    controller: phoneCtrl,
                    enabled: !isLoading,
                    keyboardType: TextInputType.phone,
                    decoration: customDecoration(
                      label: 'رقم الجوال',
                      icon: Icons.phone_rounded,
                      hint: '059xxxxxxx أو 056xxxxxxx أو 052xxxxxxx',
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
                    controller: alternativePhoneCtrl,
                    enabled: !isLoading,
                    keyboardType: TextInputType.phone,
                    decoration: customDecoration(
                      label: 'رقم جوال بديل',
                      icon: Icons.phone_in_talk_rounded,
                      hint: 'اختياري',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      if (!isValidPalestinianMobile(text)) {
                        return 'رقم الجوال البديل غير صالح';
                      }
                      if (text == phoneCtrl.text.trim()) {
                        return 'رقم الجوال البديل يجب أن يختلف عن الرقم الأساسي';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: addressCtrl,
                    enabled: !isLoading,
                    maxLines: 2,
                    decoration: customDecoration(
                      label: 'العنوان',
                      icon: Icons.home_outlined,
                      hint: 'مثال: نابلس - رفيديا',
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
                    'البيانات المهنية والتعليمية',
                    'بيانات العمل والمؤهل والخبرة. يتم تحديد المجموعة لاحقًا من إدارة المجموعات.',
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: jobTitleCtrl,
                    enabled: !isLoading,
                    decoration: customDecoration(
                      label: 'المسمى الوظيفي',
                      icon: Icons.work_outline_rounded,
                      hint: 'مثال: مشرفة حضانة / مقدمة رعاية',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي المسمى الوظيفي';
                      return null;
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
                      DropdownMenuItem(
                        value: 'ثانوية عامة',
                        child: Text('ثانوية عامة'),
                      ),
                      DropdownMenuItem(
                        value: 'دبلوم',
                        child: Text('دبلوم'),
                      ),
                      DropdownMenuItem(
                        value: 'بكالوريوس',
                        child: Text('بكالوريوس'),
                      ),
                      DropdownMenuItem(
                        value: 'ماجستير',
                        child: Text('ماجستير'),
                      ),
                    ],
                    onChanged: isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => qualification = value);
                            }
                          },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: universityCtrl,
                    enabled: !isLoading,
                    decoration: customDecoration(
                      label: 'الجامعة',
                      icon: Icons.account_balance_rounded,
                      hint: 'مثال: جامعة النجاح الوطنية',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي اسم الجامعة';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: collegeCtrl,
                    enabled: !isLoading,
                    decoration: customDecoration(
                      label: 'الكلية',
                      icon: Icons.apartment_rounded,
                      hint: 'مثال: كلية التربية',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي اسم الكلية';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: specializationCtrl,
                    enabled: !isLoading,
                    decoration: customDecoration(
                      label: 'التخصص',
                      icon: Icons.auto_stories_rounded,
                      hint: 'مثال: تربية طفل / رياض أطفال / تمريض',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي التخصص';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: graduationYearCtrl,
                    enabled: !isLoading,
                    keyboardType: TextInputType.number,
                    decoration: customDecoration(
                      label: 'سنة التخرج',
                      icon: Icons.calendar_today_rounded,
                      hint: 'مثال: 2021',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'أدخلي سنة التخرج';

                      final year = int.tryParse(text);
                      final currentYear = DateTime.now().year;

                      if (year == null || year < 1970 || year > currentYear) {
                        return 'سنة التخرج غير صالحة';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: yearsOfExperienceCtrl,
                    enabled: !isLoading,
                    keyboardType: TextInputType.number,
                    decoration: customDecoration(
                      label: 'سنوات الخبرة',
                      icon: Icons.workspace_premium_rounded,
                      hint: 'مثال: 2',
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

                  TextFormField(
                    controller: responsibilitiesCtrl,
                    enabled: !isLoading,
                    maxLines: 2,
                    decoration: customDecoration(
                      label: 'المسؤوليات / المهام',
                      icon: Icons.checklist_rounded,
                      hint: 'مثال: رعاية, متابعة نوم, متابعة وجبات',
                    ),
                    validator: (value) {
                      final items = splitCommaValues(value ?? '');
                      if (items.isEmpty) {
                        return 'أدخلي مسؤولية واحدة على الأقل';
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
                      DropdownMenuItem(
                        value: 'دوام كامل',
                        child: Text('دوام كامل'),
                      ),
                      DropdownMenuItem(
                        value: 'دوام جزئي',
                        child: Text('دوام جزئي'),
                      ),
                      DropdownMenuItem(
                        value: 'دوام صباحي',
                        child: Text('دوام صباحي'),
                      ),
                      DropdownMenuItem(
                        value: 'دوام مسائي',
                        child: Text('دوام مسائي'),
                      ),
                    ],
                    onChanged: isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => employmentType = value);
                            }
                          },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: certificationsCtrl,
                    enabled: !isLoading,
                    maxLines: 2,
                    decoration: customDecoration(
                      label: 'الدورات / الشهادات',
                      icon: Icons.card_membership_rounded,
                      hint: 'مثال: سلامة أطفال, رعاية مبكرة',
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: cvNotesCtrl,
                    enabled: !isLoading,
                    maxLines: 2,
                    decoration: customDecoration(
                      label: 'ملاحظات السيرة الذاتية / CV',
                      icon: Icons.description_outlined,
                      hint: 'ملاحظات مختصرة حول الخبرة أو السيرة الذاتية',
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
                    'ملاحظات إدارية',
                    'ملاحظات داخلية وصلاحيات إضافية إن لزم.',
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: extraPermissionsCtrl,
                    enabled: !isLoading,
                    maxLines: 2,
                    decoration: customDecoration(
                      label: 'صلاحيات إضافية',
                      icon: Icons.admin_panel_settings_outlined,
                      hint: 'مثال: تقارير خاصة, صلاحيات متابعة محددة',
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: adminNotesCtrl,
                    enabled: !isLoading,
                    maxLines: 4,
                    decoration: customDecoration(
                      label: 'ملاحظات إدارية',
                      icon: Icons.notes_rounded,
                      hint: 'أي ملاحظات إضافية حول هذه الموظفة...',
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
                        backgroundColor: AppColors.nursery.withOpacity(0.15),
                        child: const Icon(
                          Icons.child_friendly_rounded,
                          color: AppColors.nursery,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'سيتم إنشاء حساب من نوع: موظفة حضانة',
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
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : createNurseryStaff,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        isLoading
                            ? 'جارٍ إنشاء الحساب...'
                            : 'إنشاء حساب موظفة الحضانة',
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