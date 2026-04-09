import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/child_section_utils.dart';
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
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // بيانات الحساب
  final fullNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();

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

  bool isSubmitting = false;
  bool isSendingVerification = false;
  bool isCheckingVerification = false;

  bool emailVerificationSent = false;
  bool emailVerified = false;

  String verificationMethod = '';
  String verificationEmail = '';
  String authUid = '';
  String hiddenTempPassword = '';

  final List<_ChildDraft> children = [_ChildDraft()];

  @override
  void initState() {
    super.initState();

    usernameCtrl.addListener(() {
      final lower = usernameCtrl.text.toLowerCase();
      if (usernameCtrl.text != lower) {
        final oldSelection = usernameCtrl.selection;
        usernameCtrl.value = TextEditingValue(
          text: lower,
          selection: oldSelection.copyWith(
            baseOffset: lower.length < oldSelection.baseOffset
                ? lower.length
                : oldSelection.baseOffset,
            extentOffset: lower.length < oldSelection.extentOffset
                ? lower.length
                : oldSelection.extentOffset,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    fullNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
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
                  'املئي البيانات بدقة ثم تحققي من البريد الإلكتروني قبل إرسال الطلب ليتم مراجعته من الإدارة.',
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
              'هذا النموذج مخصص لإرسال طلب إنشاء حساب. يجب أولًا التحقق من البريد الإلكتروني. بعد موافقة الإدارة سيتم إرسال رابط تعيين كلمة المرور إلى البريد نفسه.',
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

  String _generateHiddenTempPassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#\$%&*';
    final random = Random.secure();
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String? _validatePalestinianId(String value) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return 'رقم الهوية مطلوب';
    }

    if (!RegExp(r'^\d{9}$').hasMatch(clean)) {
      return 'رقم الهوية يجب أن يتكون من 9 أرقام';
    }

    return null;
  }

  bool _isValidPalestinianMobile(String value) {
    final clean = value.trim();
    return RegExp(r'^(059|056)\d{7}$').hasMatch(clean);
  }

  String? _validatePalestinianMobile(String value, {required String label}) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return '$label مطلوب';
    }

    if (!RegExp(r'^\d{10}$').hasMatch(clean)) {
      return '$label يجب أن يتكون من 10 أرقام';
    }

    if (!_isValidPalestinianMobile(clean)) {
      return '$label يجب أن يكون رقم جوال فلسطيني صحيحًا (059 أو 056)';
    }

    return null;
  }

  String? _validateAlternatePhone(String value) {
    final clean = value.trim();
    final mainPhone = phoneCtrl.text.trim();

    if (clean.isEmpty) return null;

    if (!RegExp(r'^\d{10}$').hasMatch(clean)) {
      return 'رقم الجوال البديل يجب أن يتكون من 10 أرقام';
    }

    if (!_isValidPalestinianMobile(clean)) {
      return 'رقم الجوال البديل يجب أن يكون رقم جوال فلسطيني صحيحًا (059 أو 056)';
    }

    if (mainPhone.isNotEmpty && clean == mainPhone) {
      return 'رقم الجوال البديل يجب أن يكون مختلفًا عن الأساسي';
    }

    return null;
  }

  String? _validateAdultBirthDate(String value) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return 'تاريخ الميلاد مطلوب';
    }

    final birthDate = DateTime.tryParse(clean);
    if (birthDate == null) {
      return 'تاريخ الميلاد غير صالح';
    }

    final age = ChildSectionUtils.calculateAgeInYears(birthDate);
    if (age < 18) {
      return 'يجب أن يكون عمر ولي الأمر 18 سنة أو أكثر';
    }

    return null;
  }

  String? _validateUsername(String value) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return 'اسم المستخدم مطلوب';
    }

    if (clean != clean.toLowerCase()) {
      return 'ممنوع استخدام الأحرف الكبيرة في اسم المستخدم';
    }

    if (clean.contains(' ')) {
      return 'اسم المستخدم يجب ألا يحتوي على مسافات';
    }

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(clean)) {
      return 'اسم المستخدم يقبل حروفًا إنجليزية صغيرة وأرقامًا و underscore فقط';
    }

    if (clean.length < 4) {
      return 'اسم المستخدم قصير جدًا';
    }

    return null;
  }

  bool _isValidEmailFormat(String value) {
    final clean = value.trim();
    return RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(clean);
  }

  bool _shouldShowGroupField(_ChildDraft child) {
    return ChildSectionUtils.shouldShowGroupField(child.section);
  }

  Future<bool> _usernameExistsAnywhere(String username) async {
  final clean = normalizeUsername(username);

  final lookupDoc = await _firestore
      .collection('login_usernames')
      .doc(clean)
      .get();

  return lookupDoc.exists;
}

  Future<bool> _emailExistsAnywhere(String email) async {
  final clean = email.trim().toLowerCase();

  final snapshot = await _firestore
      .collection('login_usernames')
      .where('email', isEqualTo: clean)
      .limit(1)
      .get();

  return snapshot.docs.isNotEmpty;
}

  bool _isValidEmail(String value) {
    return _isValidEmailFormat(value.trim().toLowerCase());
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

    final sectionResult = ChildSectionUtils.resolveSectionAndGroup(picked);
    final newSection = sectionResult.section;

    setState(() {
      child.birthDate = picked;
      child.birthDateCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';

      child.section = newSection;

      if (!ChildSectionUtils.shouldShowGroupField(newSection)) {
        child.groupCtrl.clear();
      }
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

  Future<void> sendEmailVerificationLink() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      isSendingVerification = true;
    });

    try {
      usernameCtrl.text = normalizeUsername(usernameCtrl.text);
      emailCtrl.text = emailCtrl.text.trim().toLowerCase();

      final cleanUsername = usernameCtrl.text.trim();
      final cleanEmail = emailCtrl.text.trim();

      final usernameTaken = await _usernameExistsAnywhere(cleanUsername);
      if (usernameTaken) {
        throw Exception('اسم المستخدم مستخدم مسبقًا أو يوجد طلب معلق بنفس الاسم');
      }

      final emailTaken = await _emailExistsAnywhere(cleanEmail);
      if (emailTaken) {
        throw Exception('البريد الإلكتروني مستخدم مسبقًا أو يوجد طلب معلق بنفس البريد');
      }

      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email != cleanEmail) {
        await _auth.signOut();
      }

      User? authUser = _auth.currentUser;

      if (authUser == null) {
        hiddenTempPassword = _generateHiddenTempPassword();

        final credential = await _auth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: hiddenTempPassword,
        );

        authUser = credential.user;
      }

      if (authUser == null) {
        throw Exception('تعذر إنشاء حساب التحقق بالبريد');
      }

      if ((authUser.email ?? '').trim().toLowerCase() != cleanEmail) {
        await _auth.signOut();

        hiddenTempPassword = _generateHiddenTempPassword();

        final credential = await _auth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: hiddenTempPassword,
        );

        authUser = credential.user;
      }

      if (authUser == null) {
        throw Exception('تعذر إنشاء حساب التحقق بالبريد');
      }

      await authUser.sendEmailVerification();
      await authUser.reload();

      final refreshedUser = _auth.currentUser;

      setState(() {
        emailVerificationSent = true;
        emailVerified = refreshedUser?.emailVerified ?? false;
        verificationEmail = cleanEmail;
        authUid = refreshedUser?.uid ?? authUser!.uid;
        verificationMethod = 'email_link';
      });

      _showSnack('تم إرسال رابط التحقق إلى بريدك الإلكتروني');
    } on FirebaseAuthException catch (e) {
      String message = 'تعذر إرسال رابط التحقق';

      if (e.code == 'email-already-in-use') {
        message = 'البريد الإلكتروني مستخدم مسبقًا';
      } else if (e.code == 'invalid-email') {
        message = 'البريد الإلكتروني غير صالح';
      } else if (e.code == 'weak-password') {
        message = 'حدث خطأ في إنشاء حساب التحقق، حاولي مرة أخرى';
      } else if (e.message != null && e.message!.trim().isNotEmpty) {
        message = e.message!;
      }

      _showSnack(message);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          isSendingVerification = false;
        });
      }
    }
  }

  Future<void> checkEmailVerificationStatus() async {
    setState(() {
      isCheckingVerification = true;
    });

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('لا يوجد حساب تحقق نشط. أرسلي رابط التحقق أولًا');
      }

      await user.reload();
      final refreshedUser = _auth.currentUser;

      final verified = refreshedUser?.emailVerified ?? false;

      setState(() {
        emailVerified = verified;
        authUid = refreshedUser?.uid ?? '';
      });

      if (verified) {
        _showSnack('تم التحقق من البريد الإلكتروني بنجاح');
      } else {
        _showSnack('لم يتم التحقق من البريد بعد. افتحي الرابط من البريد ثم أعيدي المحاولة');
      }
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          isCheckingVerification = false;
        });
      }
    }
  }

  Future<void> submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    for (final child in children) {
      if (!child.isValid()) {
        _showSnack('تأكدي من تعبئة بيانات جميع الأطفال والمخولين بالاستلام');
        return;
      }
    }

    if (!emailVerificationSent) {
      _showSnack('يجب إرسال رابط التحقق إلى البريد الإلكتروني أولًا');
      return;
    }

    if (!emailVerified) {
      _showSnack('يجب التحقق من البريد الإلكتروني قبل إرسال الطلب');
      return;
    }

    if (authUid.trim().isEmpty) {
      _showSnack('تعذر تحديد حساب التحقق. أعيدي إرسال رابط التحقق');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      usernameCtrl.text = normalizeUsername(usernameCtrl.text);
      emailCtrl.text = emailCtrl.text.trim().toLowerCase();
      phoneCtrl.text = phoneCtrl.text.trim();
      alternatePhoneCtrl.text = alternatePhoneCtrl.text.trim();
      nationalIdCtrl.text = nationalIdCtrl.text.trim();

      final cleanUsername = usernameCtrl.text;
      final cleanEmail = emailCtrl.text;

      final usernameTaken = await _usernameExistsAnywhere(cleanUsername);
      if (usernameTaken) {
        throw Exception('اسم المستخدم مستخدم مسبقًا أو يوجد طلب معلق بنفس الاسم');
      }

      final emailTaken = await _emailExistsAnywhere(cleanEmail);
      if (emailTaken) {
        throw Exception('البريد الإلكتروني مستخدم مسبقًا أو يوجد طلب معلق بنفس البريد');
      }

      for (final child in children) {
        final sectionResult =
            ChildSectionUtils.resolveSectionAndGroup(child.birthDate);

        if (sectionResult.section == 'OutOfRange') {
          throw Exception(
            'يوجد طفل عمره أكبر من نطاق الحضانة/الروضة في النظام الحالي',
          );
        }
      }

      final requestData = <String, dynamic>{
        'requestType': 'parent_registration',
        'status': 'pending',
        'authAccountCreated': true,
        'authPreCreated': true,
        'authUid': authUid.trim(),
        'emailVerified': true,
        'verificationMethod': verificationMethod,
        'approvalMode': '',
        'activationMethod': '',
        'linkedParentUid': '',
        'linkedParentUsername': '',
        'linkedParentName': '',
        'processedToUserDoc': false,
        'processedChildrenCount': 0,
        'parentInfo': {
          'fullName': fullNameCtrl.text.trim(),
          'username': cleanUsername,
          'email': cleanEmail,
          'phone': phoneCtrl.text.trim(),
          'alternatePhone': alternatePhoneCtrl.text.trim(),
          'identityNumber': nationalIdCtrl.text.trim(),
          'gender': selectedGender,
          'birthDate': birthDateCtrl.text.trim().isEmpty
              ? null
              : birthDateCtrl.text.trim(),
          'relationship': selectedRelationship,
          'maritalStatus': selectedMaritalStatus,
          'city': cityCtrl.text.trim(),
          'address': addressCtrl.text.trim(),
          'jobTitle': jobTitleCtrl.text.trim(),
          'workplace': workPlaceCtrl.text.trim(),
          'workPhone': workPhoneCtrl.text.trim(),
          'employmentStatus': selectedEmploymentStatus,
          'bestContactTime': preferredContactTimeCtrl.text.trim(),
          'emergencyContactName': emergencyNameCtrl.text.trim(),
          'emergencyContactRelation': emergencyRelationCtrl.text.trim(),
          'emergencyContactPhone': emergencyPhoneCtrl.text.trim(),
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

      await _auth.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال طلب التسجيل بنجاح، وسيتم مراجعته من الإدارة',
          ),
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

  Widget buildVerificationCard() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (emailVerified) {
      statusColor = Colors.green;
      statusText = 'تم التحقق من البريد الإلكتروني';
      statusIcon = Icons.verified_rounded;
    } else if (emailVerificationSent) {
      statusColor = Colors.orange;
      statusText = 'تم إرسال رابط التحقق، بانتظار التأكيد';
      statusIcon = Icons.mark_email_read_outlined;
    } else {
      statusColor = AppColors.textLight;
      statusText = 'لم يتم التحقق من البريد بعد';
      statusIcon = Icons.email_outlined;
    }

    return buildMainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle(
            'التحقق من البريد الإلكتروني',
            'يجب التحقق من البريد قبل إرسال الطلب للإدارة.',
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.22)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    emailVerificationSent
                        ? '$statusText\n${verificationEmail.isEmpty ? '' : verificationEmail}'
                        : statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isSendingVerification ? null : sendEmailVerificationLink,
                  icon: isSendingVerification
    ? const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      )
    : const Icon(Icons.mark_email_unread_outlined),
                  label: Text(
                    isSendingVerification
                        ? 'جارٍ الإرسال...'
                        : (emailVerificationSent
                            ? 'إعادة إرسال رابط التحقق'
                            : 'إرسال رابط التحقق'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isCheckingVerification ? null : checkEmailVerificationStatus,
              icon: isCheckingVerification
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: Text(
                isCheckingVerification
                    ? 'جارٍ التحقق...'
                    : 'تحققت من بريدي الإلكتروني',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAccountSection() {
    return buildMainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle(
            'بيانات الحساب',
            'هذه البيانات ستُستخدم عند اعتماد الحساب من الإدارة.',
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
            validator: (value) => _validateUsername(value ?? ''),
            onChanged: (_) {
              if (emailVerificationSent || emailVerified) {
                setState(() {
                  emailVerificationSent = false;
                  emailVerified = false;
                  verificationMethod = '';
                  verificationEmail = '';
                  authUid = '';
                });
              }
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
              final clean = (value ?? '').trim().toLowerCase();

              if (clean.isEmpty) {
                return 'البريد الإلكتروني مطلوب';
              }

              if (!_isValidEmail(clean)) {
                return 'أدخلي بريدًا إلكترونيًا صحيحًا';
              }

              return null;
            },
            onChanged: (_) {
              if (emailVerificationSent || emailVerified) {
                setState(() {
                  emailVerificationSent = false;
                  emailVerified = false;
                  verificationMethod = '';
                  verificationEmail = '';
                  authUid = '';
                });
              }
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
            decoration: customDecoration(
              label: 'رقم الهوية',
              icon: Icons.credit_card_rounded,
            ),
            validator: (value) => _validatePalestinianId(value ?? ''),
            keyboardType: TextInputType.number,
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
            validator: (value) => _validateAdultBirthDate(value ?? ''),
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
            onChanged: (_) {
              _formKey.currentState?.validate();
            },
            decoration: customDecoration(
              label: 'رقم الجوال الأساسي',
              icon: Icons.phone_rounded,
            ),
            validator: (value) =>
                _validatePalestinianMobile(value ?? '', label: 'رقم الجوال'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: alternatePhoneCtrl,
            keyboardType: TextInputType.phone,
            onChanged: (_) {
              _formKey.currentState?.validate();
            },
            decoration: customDecoration(
              label: 'رقم جوال بديل',
              icon: Icons.phone_callback_rounded,
              hint: 'اختياري',
            ),
            validator: (value) => _validateAlternatePhone(value ?? ''),
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
              DropdownMenuItem(
                value: 'not_working',
                child: Text('لا يعمل/لا تعمل'),
              ),
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
            validator: (value) {
              final clean = (value ?? '').trim();

              if (clean.isEmpty) return null;

              if (!RegExp(r'^\d{10}$').hasMatch(clean)) {
                return 'هاتف العمل يجب أن يتكون من 10 أرقام';
              }

              if (!_isValidPalestinianMobile(clean)) {
                return 'هاتف العمل يجب أن يكون رقم جوال فلسطيني صحيحًا (059 أو 056)';
              }

              return null;
            },
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
              final clean = (value ?? '').trim();
              if (clean.isEmpty) {
                return 'أدخلي رقم هاتف الطوارئ';
              }
              return _validatePalestinianMobile(
                clean,
                label: 'رقم هاتف الطوارئ',
              );
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
            controller: child.childNationalIdCtrl,
            keyboardType: TextInputType.number,
            decoration: customDecoration(
              label: 'رقم هوية الطفل',
              icon: Icons.badge_outlined,
            ),
            validator: (value) => _validatePalestinianId(value ?? ''),
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
          if (child.section == 'OutOfRange') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: const Text(
                'عمر الطفل أكبر من نطاق الحضانة/الروضة في النظام الحالي.',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.apartment_rounded,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'القسم',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ChildSectionUtils.sectionArabicLabel(child.section),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_shouldShowGroupField(child)) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: child.groupCtrl,
              decoration: customDecoration(
                label: 'المجموعة / الصف',
                icon: Icons.groups_rounded,
                hint: 'مثال: KG1',
              ),
              validator: (value) {
                if (_shouldShowGroupField(child) &&
                    (value?.trim() ?? '').isEmpty) {
                  return 'أدخلي المجموعة / الصف';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'البيانات الصحية',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: child.hasChronicDiseases,
            onChanged: (value) {
              setState(() {
                child.hasChronicDiseases = value;
                if (!value) child.chronicDiseasesCtrl.clear();
              });
            },
            title: const Text('هل لدى الطفل أمراض مزمنة؟'),
            contentPadding: EdgeInsets.zero,
          ),
          if (child.hasChronicDiseases) ...[
            TextFormField(
              controller: child.chronicDiseasesCtrl,
              maxLines: 2,
              decoration: customDecoration(
                label: 'تفاصيل الأمراض المزمنة',
                icon: Icons.monitor_heart_outlined,
              ),
              validator: (value) {
                if (child.hasChronicDiseases &&
                    (value?.trim() ?? '').isEmpty) {
                  return 'أدخلي تفاصيل الأمراض المزمنة';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          SwitchListTile(
            value: child.hasAllergies,
            onChanged: (value) {
              setState(() {
                child.hasAllergies = value;
                if (!value) child.allergiesCtrl.clear();
              });
            },
            title: const Text('هل لدى الطفل حساسية؟'),
            contentPadding: EdgeInsets.zero,
          ),
          if (child.hasAllergies) ...[
            TextFormField(
              controller: child.allergiesCtrl,
              maxLines: 2,
              decoration: customDecoration(
                label: 'تفاصيل الحساسية',
                icon: Icons.warning_amber_rounded,
              ),
              validator: (value) {
                if (child.hasAllergies && (value?.trim() ?? '').isEmpty) {
                  return 'أدخلي تفاصيل الحساسية';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          SwitchListTile(
            value: child.takesMedications,
            onChanged: (value) {
              setState(() {
                child.takesMedications = value;
                if (!value) child.medicationsCtrl.clear();
              });
            },
            title: const Text('هل يتناول الطفل أدوية بشكل مستمر؟'),
            contentPadding: EdgeInsets.zero,
          ),
          if (child.takesMedications) ...[
            TextFormField(
              controller: child.medicationsCtrl,
              maxLines: 2,
              decoration: customDecoration(
                label: 'تفاصيل الأدوية',
                icon: Icons.medication_outlined,
              ),
              validator: (value) {
                if (child.takesMedications && (value?.trim() ?? '').isEmpty) {
                  return 'أدخلي تفاصيل الأدوية';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          SwitchListTile(
            value: child.hasDietaryRestrictions,
            onChanged: (value) {
              setState(() {
                child.hasDietaryRestrictions = value;
                if (!value) child.dietaryRestrictionsCtrl.clear();
              });
            },
            title: const Text('هل لدى الطفل قيود غذائية؟'),
            contentPadding: EdgeInsets.zero,
          ),
          if (child.hasDietaryRestrictions) ...[
            TextFormField(
              controller: child.dietaryRestrictionsCtrl,
              maxLines: 2,
              decoration: customDecoration(
                label: 'تفاصيل القيود الغذائية',
                icon: Icons.restaurant_menu_rounded,
              ),
              validator: (value) {
                if (child.hasDietaryRestrictions &&
                    (value?.trim() ?? '').isEmpty) {
                  return 'أدخلي تفاصيل القيود الغذائية';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          SwitchListTile(
            value: child.hasSpecialNeeds,
            onChanged: (value) {
              setState(() {
                child.hasSpecialNeeds = value;
                if (!value) child.specialNeedsCtrl.clear();
              });
            },
            title: const Text('هل لدى الطفل احتياجات خاصة؟'),
            contentPadding: EdgeInsets.zero,
          ),
          if (child.hasSpecialNeeds) ...[
            TextFormField(
              controller: child.specialNeedsCtrl,
              maxLines: 2,
              decoration: customDecoration(
                label: 'تفاصيل الاحتياجات الخاصة',
                icon: Icons.accessible_rounded,
              ),
              validator: (value) {
                if (child.hasSpecialNeeds && (value?.trim() ?? '').isEmpty) {
                  return 'أدخلي تفاصيل الاحتياجات الخاصة';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: child.healthNotesCtrl,
            maxLines: 3,
            decoration: customDecoration(
              label: 'ملاحظات صحية عامة',
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
                          onPressed: () =>
                              removePickupContact(child, pickupIndex),
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
                      final clean = (value ?? '').trim();
                      if (clean.isEmpty) {
                        return 'أدخلي رقم الجوال';
                      }
                      return _validatePalestinianMobile(
                        clean,
                        label: 'رقم الجوال',
                      );
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
                  'بعد إرسال الطلب ستقوم الإدارة بمراجعته. عند الموافقة سيتم إرسال رابط تعيين كلمة المرور إلى بريدك الإلكتروني.',
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
            width: double.infinity,
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
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          children: [
            buildHeaderCard(),
            const SizedBox(height: 16),
            buildInfoCard(),
            const SizedBox(height: 18),
            buildAccountSection(),
            const SizedBox(height: 14),
            buildVerificationCard(),
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
  final childNationalIdCtrl = TextEditingController();
  final birthDateCtrl = TextEditingController();
  final groupCtrl = TextEditingController();

  final chronicDiseasesCtrl = TextEditingController();
  final allergiesCtrl = TextEditingController();
  final medicationsCtrl = TextEditingController();
  final dietaryRestrictionsCtrl = TextEditingController();
  final specialNeedsCtrl = TextEditingController();
  final healthNotesCtrl = TextEditingController();

  DateTime? birthDate;
  String gender = 'female';
  String section = 'Nursery';

  bool hasChronicDiseases = false;
  bool hasAllergies = false;
  bool takesMedications = false;
  bool hasDietaryRestrictions = false;
  bool hasSpecialNeeds = false;

  final List<_PickupContactDraft> pickupContacts = [_PickupContactDraft()];

  bool isValid() {
    if (fullNameCtrl.text.trim().isEmpty) return false;
    if (childNationalIdCtrl.text.trim().isEmpty) return false;
    if (birthDateCtrl.text.trim().isEmpty) return false;

    if (ChildSectionUtils.shouldShowGroupField(section) &&
        groupCtrl.text.trim().isEmpty) {
      return false;
    }

    if (hasChronicDiseases && chronicDiseasesCtrl.text.trim().isEmpty) {
      return false;
    }
    if (hasAllergies && allergiesCtrl.text.trim().isEmpty) {
      return false;
    }
    if (takesMedications && medicationsCtrl.text.trim().isEmpty) {
      return false;
    }
    if (hasDietaryRestrictions &&
        dietaryRestrictionsCtrl.text.trim().isEmpty) {
      return false;
    }
    if (hasSpecialNeeds && specialNeedsCtrl.text.trim().isEmpty) {
      return false;
    }

    if (pickupContacts.isEmpty) return false;

    for (final pickup in pickupContacts) {
      if (!pickup.isValid()) return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() {
    String resolvedSection = section;

    if (birthDate != null) {
      final sectionResult =
          ChildSectionUtils.resolveSectionAndGroup(birthDate!);
      resolvedSection = sectionResult.section;
    }

    final resolvedGroup =
        ChildSectionUtils.shouldShowGroupField(resolvedSection)
            ? groupCtrl.text.trim()
            : '';

    return {
      'fullName': fullNameCtrl.text.trim(),
      'identityNumber': childNationalIdCtrl.text.trim(),
      'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),
      'gender': gender,
      'section': resolvedSection,
      'group': resolvedGroup,
      'status': 'active',
      'hasChronicDiseases': hasChronicDiseases,
      'chronicDiseases':
          hasChronicDiseases ? chronicDiseasesCtrl.text.trim() : '',
      'hasAllergies': hasAllergies,
      'allergies': hasAllergies ? allergiesCtrl.text.trim() : '',
      'takesMedications': takesMedications,
      'medications': takesMedications ? medicationsCtrl.text.trim() : '',
      'hasDietaryRestrictions': hasDietaryRestrictions,
      'dietaryRestrictions':
          hasDietaryRestrictions ? dietaryRestrictionsCtrl.text.trim() : '',
      'hasSpecialNeeds': hasSpecialNeeds,
      'specialNeeds': hasSpecialNeeds ? specialNeedsCtrl.text.trim() : '',
      'healthNotes': healthNotesCtrl.text.trim(),
      'bloodType': '',
      'dietInstructions':
          hasDietaryRestrictions ? dietaryRestrictionsCtrl.text.trim() : '',
      'specialInstructions':
          hasSpecialNeeds ? specialNeedsCtrl.text.trim() : '',
      'authorizedPickupContacts':
          pickupContacts.map((e) => e.toMap()).toList(),
    };
  }

  void dispose() {
    fullNameCtrl.dispose();
    childNationalIdCtrl.dispose();
    birthDateCtrl.dispose();
    groupCtrl.dispose();
    chronicDiseasesCtrl.dispose();
    allergiesCtrl.dispose();
    medicationsCtrl.dispose();
    dietaryRestrictionsCtrl.dispose();
    specialNeedsCtrl.dispose();
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
    final phone = phoneCtrl.text.trim();
    final isValidPhone = RegExp(r'^(059|056)\d{7}$').hasMatch(phone);

    return nameCtrl.text.trim().isNotEmpty &&
        relationCtrl.text.trim().isNotEmpty &&
        phone.isNotEmpty &&
        isValidPhone;
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