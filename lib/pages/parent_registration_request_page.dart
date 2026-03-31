import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentRegistrationRequestPage extends StatefulWidget {
  const ParentRegistrationRequestPage({super.key});

  @override
  State<ParentRegistrationRequestPage> createState() =>
      _ParentRegistrationRequestPageState();
}

class _ParentRegistrationRequestPageState
    extends State<ParentRegistrationRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // بيانات الحساب
  final fullNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  // البيانات الشخصية
  final nationalIdCtrl = TextEditingController();
  final birthDateCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  // التواصل
  final phoneCtrl = TextEditingController();
  final alternatePhoneCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final jobTitleCtrl = TextEditingController();
  final workPlaceCtrl = TextEditingController();
  final workPhoneCtrl = TextEditingController();
  final preferredContactTimeCtrl = TextEditingController();

  // الطوارئ
  final emergencyNameCtrl = TextEditingController();
  final emergencyRelationCtrl = TextEditingController();
  final emergencyPhoneCtrl = TextEditingController();

  // ملاحظات
  final notesCtrl = TextEditingController();

  String selectedGender = 'female';
  String selectedRelationship = 'mother';
  String selectedMaritalStatus = 'married';
  String selectedEmploymentStatus = 'working';

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isSubmitting = false;

  // التحقق بالبريد
  String? generatedVerificationCode;
  DateTime? verificationSentAt;
  DateTime? verificationExpiresAt;
  bool emailVerified = false;
  final verificationCodeCtrl = TextEditingController();

  final List<_ChildDraft> children = [_ChildDraft()];

  @override
  void dispose() {
    fullNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    nationalIdCtrl.dispose();
    birthDateCtrl.dispose();
    addressCtrl.dispose();
    phoneCtrl.dispose();
    alternatePhoneCtrl.dispose();
    cityCtrl.dispose();
    jobTitleCtrl.dispose();
    workPlaceCtrl.dispose();
    workPhoneCtrl.dispose();
    preferredContactTimeCtrl.dispose();
    emergencyNameCtrl.dispose();
    emergencyRelationCtrl.dispose();
    emergencyPhoneCtrl.dispose();
    notesCtrl.dispose();
    verificationCodeCtrl.dispose();

    for (final child in children) {
      child.dispose();
    }
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

  Widget buildMainCard({required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }

  Widget buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.18),
            AppColors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.18),
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
              Icons.family_restroom_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلب إنشاء حساب ولي أمر',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'املئي البيانات الأساسية بدقة، ثم أرسلي الطلب ليتم مراجعته من الإدارة والموافقة عليه.',
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
              'هذا الطلب لا ينشئ الحساب مباشرة. بعد التحقق من البريد ومراجعة الإدارة، سيتم اعتماد الحساب وربطه بالطفل أو الأطفال.',
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

  String normalizeUsername(String value) {
    return value.trim().toLowerCase();
  }

  String _generateCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<bool> _usernameExistsAnywhere(String username) async {
    final clean = normalizeUsername(username);

    final users = await _firestore
        .collection('users')
        .where('username', isEqualTo: clean)
        .limit(1)
        .get();

    if (users.docs.isNotEmpty) return true;

    final requests = await _firestore
        .collection('registration_requests')
        .where('parentInfo.username', isEqualTo: clean)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return requests.docs.isNotEmpty;
  }

  Future<bool> _emailExistsAnywhere(String email) async {
    final clean = email.trim().toLowerCase();

    final users = await _firestore
        .collection('users')
        .where('email', isEqualTo: clean)
        .limit(1)
        .get();

    if (users.docs.isNotEmpty) return true;

    final requests = await _firestore
        .collection('registration_requests')
        .where('parentInfo.email', isEqualTo: clean)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return requests.docs.isNotEmpty;
  }

  bool _isValidEmail(String value) {
    return value.contains('@') && value.contains('.');
  }

  bool _isValidPassword(String value) {
    final hasUpper = value.contains(RegExp(r'[A-Z]'));
    final hasLower = value.contains(RegExp(r'[a-z]'));
    final hasNumber = value.contains(RegExp(r'[0-9]'));
    return value.length >= 8 && hasUpper && hasLower && hasNumber;
  }

  Future<void> _pickParentBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 18),
    );

    if (picked == null) return;

    birthDateCtrl.text =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickChildBirthDate(_ChildDraft child) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 4),
      firstDate: DateTime(2015),
      lastDate: now,
    );

    if (picked == null) return;

    setState(() {
      child.birthDate = picked;
      child.birthDateCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  void addChild() {
    setState(() {
      children.add(_ChildDraft());
    });
  }

  void removeChild(int index) {
    if (children.length == 1) return;

    setState(() {
      children[index].dispose();
      children.removeAt(index);
    });
  }

  void addPickupContact(_ChildDraft child) {
    setState(() {
      child.pickupContacts.add(_PickupContactDraft());
    });
  }

  void removePickupContact(_ChildDraft child, int index) {
    if (child.pickupContacts.length == 1) return;

    setState(() {
      child.pickupContacts[index].dispose();
      child.pickupContacts.removeAt(index);
    });
  }

  Future<void> sendVerificationCode() async {
    final email = emailCtrl.text.trim().toLowerCase();
    final username = usernameCtrl.text.trim();

    if (email.isEmpty || !_isValidEmail(email)) {
      _showSnack('أدخلي بريدًا إلكترونيًا صالحًا أولًا');
      return;
    }

    if (username.isEmpty) {
      _showSnack('أدخلي اسم المستخدم أولًا');
      return;
    }

    final usernameTaken = await _usernameExistsAnywhere(username);
    if (usernameTaken) {
      _showSnack('اسم المستخدم مستخدم مسبقًا أو يوجد طلب معلق بنفس الاسم');
      return;
    }

    final emailTaken = await _emailExistsAnywhere(email);
    if (emailTaken) {
      _showSnack('البريد الإلكتروني مستخدم مسبقًا أو يوجد طلب معلق بنفس البريد');
      return;
    }

    final code = _generateCode();

    setState(() {
      generatedVerificationCode = code;
      verificationSentAt = DateTime.now();
      verificationExpiresAt = DateTime.now().add(const Duration(minutes: 10));
      emailVerified = false;
      verificationCodeCtrl.clear();
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('كود التحقق'),
          content: Text(
            'هذه نسخة مشروع أولية.\n\n'
            'تم توليد كود التحقق التالي:\n\n$code\n\n'
            'لاحقًا سنربطه بإرسال فعلي إلى البريد الإلكتروني.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.6),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تم'),
            ),
          ],
        ),
      ),
    );
  }

  void verifyCode() {
    final code = verificationCodeCtrl.text.trim();

    if (generatedVerificationCode == null) {
      _showSnack('أرسلي كود التحقق أولًا');
      return;
    }

    if (verificationExpiresAt != null &&
        DateTime.now().isAfter(verificationExpiresAt!)) {
      _showSnack('انتهت صلاحية الكود، أرسلي كودًا جديدًا');
      return;
    }

    if (code != generatedVerificationCode) {
      _showSnack('كود التحقق غير صحيح');
      return;
    }

    setState(() {
      emailVerified = true;
    });

    _showSnack('تم التحقق من البريد الإلكتروني بنجاح');
  }

  Future<void> submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (!emailVerified) {
      _showSnack('يجب التحقق من البريد الإلكتروني قبل إرسال الطلب');
      return;
    }

    for (final child in children) {
      if (!child.isValid()) {
        _showSnack('تأكدي من تعبئة بيانات جميع الأطفال والمخولين بالاستلام');
        return;
      }
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final cleanUsername = normalizeUsername(usernameCtrl.text);
      final cleanEmail = emailCtrl.text.trim().toLowerCase();

      final usernameTaken = await _usernameExistsAnywhere(cleanUsername);
      if (usernameTaken) {
        throw Exception('اسم المستخدم مستخدم مسبقًا أو يوجد طلب معلق بنفس الاسم');
      }

      final emailTaken = await _emailExistsAnywhere(cleanEmail);
      if (emailTaken) {
        throw Exception('البريد الإلكتروني مستخدم مسبقًا أو يوجد طلب معلق بنفس البريد');
      }

      final requestData = <String, dynamic>{
        'requestType': 'parent_account',
        'status': 'pending',
        'emailVerified': true,
        'verificationCode': generatedVerificationCode,
        'verificationCodeSentAt': verificationSentAt == null
            ? null
            : Timestamp.fromDate(verificationSentAt!),
        'verificationExpiresAt': verificationExpiresAt == null
            ? null
            : Timestamp.fromDate(verificationExpiresAt!),
        'parentInfo': {
          'fullName': fullNameCtrl.text.trim(),
          'username': cleanUsername,
          'email': cleanEmail,
          'password': passwordCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
          'alternatePhone': alternatePhoneCtrl.text.trim(),
          'nationalId': nationalIdCtrl.text.trim(),
          'gender': selectedGender,
          'birthDate': birthDateCtrl.text.trim().isEmpty
              ? null
              : birthDateCtrl.text.trim(),
          'relationshipToChild': selectedRelationship,
          'maritalStatus': selectedMaritalStatus,
          'city': cityCtrl.text.trim(),
          'address': addressCtrl.text.trim(),
          'jobTitle': jobTitleCtrl.text.trim(),
          'workPlace': workPlaceCtrl.text.trim(),
          'workPhone': workPhoneCtrl.text.trim(),
          'employmentStatus': selectedEmploymentStatus,
          'preferredContactTime': preferredContactTimeCtrl.text.trim(),
          'emergencyContact': {
            'name': emergencyNameCtrl.text.trim(),
            'relation': emergencyRelationCtrl.text.trim(),
            'phone': emergencyPhoneCtrl.text.trim(),
          },
          'notes': notesCtrl.text.trim(),
        },
        'childrenInfo': children.map((child) => child.toMap()).toList(),
        'reviewNote': '',
        'reviewedByUid': '',
        'reviewedByName': '',
        'reviewedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('registration_requests').add(requestData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب التسجيل بنجاح، وسيتم مراجعته من الإدارة'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget buildAccountSection() {
    return buildMainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle(
            'بيانات الحساب',
            'هذه البيانات ستُستخدم لاحقًا عند اعتماد الحساب.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: fullNameCtrl,
            decoration: customDecoration(
              label: 'الاسم الكامل',
              icon: Icons.badge_rounded,
              hint: 'مثال: آية محمد عبد الله',
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
              hint: 'مثال: aya_parent',
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'أدخلي اسم المستخدم';
              if (text.length < 3) return 'اسم المستخدم قصير جدًا';
              if (text.contains(' ')) return 'اسم المستخدم يجب أن يكون بدون مسافات';
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
              if (text.isEmpty) return 'أدخلي البريد الإلكتروني';
              if (!_isValidEmail(text)) return 'أدخلي بريدًا إلكترونيًا صالحًا';
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
              if (text.isEmpty) return 'أدخلي كلمة المرور';
              if (!_isValidPassword(text)) {
                return 'يجب أن تكون 8 أحرف على الأقل وتحتوي حرف كبير وحرف صغير ورقم';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: confirmPasswordCtrl,
            obscureText: obscureConfirmPassword,
            decoration: customDecoration(
              label: 'تأكيد كلمة المرور',
              icon: Icons.lock_reset_rounded,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    obscureConfirmPassword = !obscureConfirmPassword;
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
              if ((value ?? '').trim().isEmpty) {
                return 'أدخلي تأكيد كلمة المرور';
              }
              if (value!.trim() != passwordCtrl.text.trim()) {
                return 'كلمتا المرور غير متطابقتين';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget buildPersonalSection() {
    return buildMainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle(
            'البيانات الشخصية',
            'بيانات ولي الأمر الأساسية.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: nationalIdCtrl,
            keyboardType: TextInputType.number,
            decoration: customDecoration(
              label: 'رقم الهوية',
              icon: Icons.credit_card_rounded,
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'أدخلي رقم الهوية';
              if (text.length < 6) return 'رقم الهوية غير صحيح';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: birthDateCtrl,
            readOnly: true,
            onTap: _pickParentBirthDate,
            decoration: customDecoration(
              label: 'تاريخ الميلاد',
              icon: Icons.calendar_month_rounded,
              hint: 'اختاري التاريخ',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedGender,
            decoration: customDecoration(
              label: 'الجنس',
              icon: Icons.wc_rounded,
            ),
            items: const [
              DropdownMenuItem(value: 'female', child: Text('أنثى')),
              DropdownMenuItem(value: 'male', child: Text('ذكر')),
            ],
            onChanged: (value) {
              setState(() {
                selectedGender = value ?? 'female';
              });
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedRelationship,
            decoration: customDecoration(
              label: 'صلة القرابة',
              icon: Icons.family_restroom_rounded,
            ),
            items: const [
              DropdownMenuItem(value: 'mother', child: Text('أم')),
              DropdownMenuItem(value: 'father', child: Text('أب')),
              DropdownMenuItem(value: 'guardian', child: Text('ولي أمر قانوني')),
              DropdownMenuItem(value: 'other', child: Text('أخرى')),
            ],
            onChanged: (value) {
              setState(() {
                selectedRelationship = value ?? 'mother';
              });
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedMaritalStatus,
            decoration: customDecoration(
              label: 'الحالة الاجتماعية',
              icon: Icons.favorite_border_rounded,
            ),
            items: const [
              DropdownMenuItem(value: 'married', child: Text('متزوج/ة')),
              DropdownMenuItem(value: 'single', child: Text('أعزب/عزباء')),
              DropdownMenuItem(value: 'divorced', child: Text('مطلق/ة')),
              DropdownMenuItem(value: 'widowed', child: Text('أرمل/ة')),
            ],
            onChanged: (value) {
              setState(() {
                selectedMaritalStatus = value ?? 'married';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget buildContactSection() {
    return buildMainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle(
            'بيانات التواصل والعمل',
            'وسائل التواصل والبيانات الإضافية المفيدة.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: customDecoration(
              label: 'رقم الجوال الأساسي',
              icon: Icons.phone_rounded,
            ),
            validator: (value) {
              if ((value?.trim() ?? '').isEmpty) {
                return 'أدخلي رقم الجوال';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: alternatePhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: customDecoration(
              label: 'رقم جوال بديل',
              icon: Icons.phone_callback_rounded,
              hint: 'اختياري',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: cityCtrl,
            decoration: customDecoration(
              label: 'المدينة / المنطقة',
              icon: Icons.location_city_rounded,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: addressCtrl,
            maxLines: 2,
            decoration: customDecoration(
              label: 'العنوان التفصيلي',
              icon: Icons.home_rounded,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedEmploymentStatus,
            decoration: customDecoration(
              label: 'حالة العمل',
              icon: Icons.work_outline_rounded,
            ),
            items: const [
              DropdownMenuItem(value: 'working', child: Text('يعمل/تعمل')),
              DropdownMenuItem(value: 'not_working', child: Text('لا يعمل/لا تعمل')),
            ],
            onChanged: (value) {
              setState(() {
                selectedEmploymentStatus = value ?? 'working';
              });
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: jobTitleCtrl,
            decoration: customDecoration(
              label: 'المهنة',
              icon: Icons.badge_outlined,
              hint: 'اختياري',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: workPlaceCtrl,
            decoration: customDecoration(
              label: 'جهة العمل',
              icon: Icons.business_center_rounded,
              hint: 'اختياري',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: workPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: customDecoration(
              label: 'هاتف العمل',
              icon: Icons.call_rounded,
              hint: 'اختياري',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: preferredContactTimeCtrl,
            decoration: customDecoration(
              label: 'أفضل وقت للتواصل',
              icon: Icons.schedule_rounded,
              hint: 'مثال: بعد الساعة 3 مساءً',
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmergencySection() {
    return buildMainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle(
            'بيانات الطوارئ والملاحظات',
            'معلومات مهمة للإدارة في الحالات العاجلة.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: emergencyNameCtrl,
            decoration: customDecoration(
              label: 'اسم شخص للطوارئ',
              icon: Icons.emergency_rounded,
            ),
            validator: (value) {
              if ((value?.trim() ?? '').isEmpty) {
                return 'أدخلي اسم شخص للطوارئ';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: emergencyRelationCtrl,
            decoration: customDecoration(
              label: 'صلة القرابة',
              icon: Icons.family_restroom_rounded,
            ),
            validator: (value) {
              if ((value?.trim() ?? '').isEmpty) {
                return 'أدخلي صلة القرابة';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: emergencyPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: customDecoration(
              label: 'رقم هاتف الطوارئ',
              icon: Icons.phone_in_talk_rounded,
            ),
            validator: (value) {
              if ((value?.trim() ?? '').isEmpty) {
                return 'أدخلي رقم هاتف الطوارئ';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: notesCtrl,
            maxLines: 4,
            decoration: customDecoration(
              label: 'ملاحظات عامة',
              icon: Icons.notes_rounded,
              hint: 'أي ظروف خاصة أو تنبيهات مهمة...',
            ),
          ),
        ],
      ),
    );
  }

  Widget buildChildSection(int index, _ChildDraft child) {
    return buildMainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: buildSectionTitle(
                  'بيانات الطفل ${index + 1}',
                  'أدخلي بيانات الطفل والمخولين باستلامه.',
                ),
              ),
              if (children.length > 1)
                IconButton(
                  onPressed: () => removeChild(index),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.redAccent,
                  tooltip: 'حذف الطفل',
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: child.fullNameCtrl,
            decoration: customDecoration(
              label: 'الاسم الكامل للطفل',
              icon: Icons.child_care_rounded,
            ),
            validator: (value) {
              if ((value?.trim() ?? '').isEmpty) {
                return 'أدخلي اسم الطفل';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: child.birthDateCtrl,
            readOnly: true,
            onTap: () => _pickChildBirthDate(child),
            decoration: customDecoration(
              label: 'تاريخ الميلاد',
              icon: Icons.calendar_month_rounded,
            ),
            validator: (value) {
              if ((value?.trim() ?? '').isEmpty) {
                return 'اختاري تاريخ الميلاد';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: child.gender,
            decoration: customDecoration(
              label: 'الجنس',
              icon: Icons.wc_rounded,
            ),
            items: const [
              DropdownMenuItem(value: 'female', child: Text('أنثى')),
              DropdownMenuItem(value: 'male', child: Text('ذكر')),
            ],
            onChanged: (value) {
              setState(() {
                child.gender = value ?? 'female';
              });
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: child.section,
            decoration: customDecoration(
              label: 'القسم',
              icon: Icons.apartment_rounded,
            ),
            items: const [
              DropdownMenuItem(value: 'Nursery', child: Text('حضانة')),
              DropdownMenuItem(value: 'Kindergarten', child: Text('روضة')),
            ],
            onChanged: (value) {
              setState(() {
                child.section = value ?? 'Nursery';
              });
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: child.groupCtrl,
            decoration: customDecoration(
              label: 'المجموعة / الصف',
              icon: Icons.groups_rounded,
              hint: 'اختياري',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: child.allergiesCtrl,
            decoration: customDecoration(
              label: 'الحساسية',
              icon: Icons.warning_amber_rounded,
              hint: 'اختياري',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: child.medicationsCtrl,
            decoration: customDecoration(
              label: 'الأدوية',
              icon: Icons.medication_outlined,
              hint: 'اختياري',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: child.healthNotesCtrl,
            maxLines: 3,
            decoration: customDecoration(
              label: 'ملاحظات صحية / تعليمات خاصة',
              icon: Icons.health_and_safety_rounded,
              hint: 'اختياري',
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'المخولون بالاستلام',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 10),
          ...List.generate(child.pickupContacts.length, (pickupIndex) {
            final pickup = child.pickupContacts[pickupIndex];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'الشخص ${pickupIndex + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (child.pickupContacts.length > 1)
                        IconButton(
                          onPressed: () => removePickupContact(child, pickupIndex),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.redAccent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: pickup.nameCtrl,
                    decoration: customDecoration(
                      label: 'الاسم',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      if ((value?.trim() ?? '').isEmpty) {
                        return 'أدخلي الاسم';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pickup.relationCtrl,
                    decoration: customDecoration(
                      label: 'صلة القرابة',
                      icon: Icons.family_restroom_rounded,
                    ),
                    validator: (value) {
                      if ((value?.trim() ?? '').isEmpty) {
                        return 'أدخلي صلة القرابة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pickup.phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: customDecoration(
                      label: 'رقم الجوال',
                      icon: Icons.phone_rounded,
                    ),
                    validator: (value) {
                      if ((value?.trim() ?? '').isEmpty) {
                        return 'أدخلي رقم الجوال';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => addPickupContact(child),
              icon: const Icon(Icons.add),
              label: const Text('إضافة شخص مخوّل آخر'),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildVerificationSection() {
    final sent = generatedVerificationCode != null;

    return buildMainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle(
            'التحقق من البريد الإلكتروني',
            'أرسلي الكود ثم أدخليه قبل إرسال الطلب.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: sendVerificationCode,
                  icon: const Icon(Icons.mark_email_read_rounded),
                  label: const Text('إرسال كود التحقق'),
                ),
              ),
            ],
          ),
          if (sent) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: verificationCodeCtrl,
              keyboardType: TextInputType.number,
              decoration: customDecoration(
                label: 'أدخلي كود التحقق',
                icon: Icons.verified_user_rounded,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: verifyCode,
                    icon: Icon(
                      emailVerified
                          ? Icons.verified_rounded
                          : Icons.check_circle_outline_rounded,
                    ),
                    label: Text(
                      emailVerified ? 'تم التحقق' : 'تأكيد الكود',
                    ),
                  ),
                ),
              ],
            ),
            if (verificationExpiresAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'صلاحية الكود حتى: '
                '${verificationExpiresAt!.year}-${verificationExpiresAt!.month.toString().padLeft(2, '0')}-${verificationExpiresAt!.day.toString().padLeft(2, '0')} '
                '${verificationExpiresAt!.hour.toString().padLeft(2, '0')}:${verificationExpiresAt!.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textLight,
                    ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget buildSubmitSection() {
    return Container(
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
                backgroundColor: AppColors.primary.withOpacity(0.15),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  emailVerified
                      ? 'البريد الإلكتروني تم التحقق منه ويمكنك الآن إرسال الطلب'
                      : 'أكملي التحقق من البريد الإلكتروني قبل إرسال الطلب',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              onPressed: isSubmitting ? null : submitRequest,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.3),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                isSubmitting ? 'جارٍ إرسال الطلب...' : 'إرسال طلب التسجيل',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'طلب تسجيل ولي أمر',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            buildHeaderCard(),
            const SizedBox(height: 16),
            buildInfoCard(),
            const SizedBox(height: 18),
            buildAccountSection(),
            const SizedBox(height: 14),
            buildPersonalSection(),
            const SizedBox(height: 14),
            buildContactSection(),
            const SizedBox(height: 14),
            buildEmergencySection(),
            const SizedBox(height: 14),
            ...List.generate(children.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: buildChildSection(index, children[index]),
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: addChild,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('إضافة طفل آخر'),
              ),
            ),
            const SizedBox(height: 14),
            buildVerificationSection(),
            const SizedBox(height: 18),
            buildSubmitSection(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ChildDraft {
  final fullNameCtrl = TextEditingController();
  final birthDateCtrl = TextEditingController();
  final groupCtrl = TextEditingController();
  final allergiesCtrl = TextEditingController();
  final medicationsCtrl = TextEditingController();
  final healthNotesCtrl = TextEditingController();

  DateTime? birthDate;
  String gender = 'female';
  String section = 'Nursery';

  final List<_PickupContactDraft> pickupContacts = [_PickupContactDraft()];

  bool isValid() {
    if (fullNameCtrl.text.trim().isEmpty) return false;
    if (birthDateCtrl.text.trim().isEmpty) return false;
    if (pickupContacts.isEmpty) return false;

    for (final pickup in pickupContacts) {
      if (!pickup.isValid()) return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullNameCtrl.text.trim(),
      'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),
      'gender': gender,
      'section': section,
      'group': groupCtrl.text.trim(),
      'allergies': allergiesCtrl.text.trim(),
      'medications': medicationsCtrl.text.trim(),
      'healthNotes': healthNotesCtrl.text.trim(),
      'pickupContacts': pickupContacts.map((e) => e.toMap()).toList(),
    };
  }

  void dispose() {
    fullNameCtrl.dispose();
    birthDateCtrl.dispose();
    groupCtrl.dispose();
    allergiesCtrl.dispose();
    medicationsCtrl.dispose();
    healthNotesCtrl.dispose();
    for (final pickup in pickupContacts) {
      pickup.dispose();
    }
  }
}

class _PickupContactDraft {
  final nameCtrl = TextEditingController();
  final relationCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  bool isValid() {
    return nameCtrl.text.trim().isNotEmpty &&
        relationCtrl.text.trim().isNotEmpty &&
        phoneCtrl.text.trim().isNotEmpty;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': nameCtrl.text.trim(),
      'relation': relationCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
    };
  }

  void dispose() {
    nameCtrl.dispose();
    relationCtrl.dispose();
    phoneCtrl.dispose();
  }
}