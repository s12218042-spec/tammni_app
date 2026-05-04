import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final fullNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();

  final nationalIdCtrl = TextEditingController();
  final birthDateCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  final phoneCtrl = TextEditingController();
  final alternatePhoneCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final jobTitleCtrl = TextEditingController();
  final workPlaceCtrl = TextEditingController();
  final workPhoneCtrl = TextEditingController();
  final preferredContactTimeCtrl = TextEditingController();

  final emergencyNameCtrl = TextEditingController();
  final emergencyRelationCtrl = TextEditingController();
  final emergencyPhoneCtrl = TextEditingController();

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

  @override
  void initState() {
    super.initState();

    usernameCtrl.addListener(() {
      final lower = usernameCtrl.text.toLowerCase();
      if (usernameCtrl.text != lower) {
        usernameCtrl.value = TextEditingValue(
          text: lower,
          selection: TextSelection.collapsed(offset: lower.length),
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
                  'املئي بيانات ولي الأمر فقط، ثم تحققي من البريد الإلكتروني قبل إرسال الطلب للإدارة.',
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
              'هذا النموذج مخصص لإنشاء حساب ولي أمر فقط. بعد موافقة الإدارة سيتم إرسال رابط تعيين كلمة المرور إلى البريد الإلكتروني. بعد تسجيل الدخول يمكن لولي الأمر إرسال طلب إضافة طفل من الصفحة الرئيسية.',
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

  bool _isValidPalestinianIdChecksum(String id) {
    if (!RegExp(r'^\d{9}$').hasMatch(id)) return false;

    int sum = 0;
    for (int i = 0; i < id.length; i++) {
      int digit = int.parse(id[i]);
      int factor = (i % 2 == 0) ? 1 : 2;
      int result = digit * factor;
      if (result > 9) result -= 9;
      sum += result;
    }

    return sum % 10 == 0;
  }

  String? _validatePalestinianId(String value) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return 'رقم الهوية مطلوب';
    }

    if (!RegExp(r'^\d{9}$').hasMatch(clean)) {
      return 'رقم الهوية يجب أن يتكون من 9 أرقام';
    }

    if (RegExp(r'^(\d)\1{8}$').hasMatch(clean)) {
      return 'رقم الهوية غير صالح';
    }

    if (!_isValidPalestinianIdChecksum(clean)) {
      return 'رقم الهوية غير صالح';
    }

    return null;
  }

  bool _isValidPalestinianMobile(String value) {
    final clean = value.trim();
    return RegExp(r'^(059|056|052)\d{7}$').hasMatch(clean);
  }

  String? _validatePalestinianMobile(
    String value, {
    required String label,
    bool requiredField = true,
  }) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return requiredField ? '$label مطلوب' : null;
    }

    if (!RegExp(r'^\d{10}$').hasMatch(clean)) {
      return '$label يجب أن يتكون من 10 أرقام';
    }

    if (RegExp(r'^(\d)\1{9}$').hasMatch(clean)) {
      return '$label غير صالح';
    }

    if (!_isValidPalestinianMobile(clean)) {
      return '$label يجب أن يكون رقم جوال صحيحًا يبدأ بـ 059 أو 056 أو 052';
    }

    return null;
  }

  String? _validateAlternatePhone(String value) {
    final clean = value.trim();
    final mainPhone = phoneCtrl.text.trim();

    if (clean.isEmpty) return null;

    final validation = _validatePalestinianMobile(
      clean,
      label: 'رقم الجوال البديل',
      requiredField: false,
    );

    if (validation != null) return validation;

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

    final now = DateTime.now();
    int age = now.year - birthDate.year;

    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

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

  bool _isValidEmail(String value) {
    return _isValidEmailFormat(value.trim().toLowerCase());
  }

  Future<bool> _usernameExistsAnywhere(String username) async {
    final clean = normalizeUsername(username);

    final lookupDoc =
        await _firestore.collection('login_usernames').doc(clean).get();

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

  void _resetVerificationState() {
    setState(() {
      emailVerificationSent = false;
      emailVerified = false;
      verificationMethod = '';
      verificationEmail = '';
      authUid = '';
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
        throw Exception('اسم المستخدم مستخدم مسبقًا');
      }

      final emailTaken = await _emailExistsAnywhere(cleanEmail);
      if (emailTaken) {
        throw Exception('البريد الإلكتروني مستخدم مسبقًا');
      }

      final currentUser = _auth.currentUser;
      if (currentUser != null &&
          (currentUser.email ?? '').trim().toLowerCase() != cleanEmail) {
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

      final actionCodeSettings = ActionCodeSettings(
        url: 'https://daycare-app-220c0.web.app/auth_action.html',
        handleCodeInApp: false,
      );

      await authUser.sendEmailVerification(actionCodeSettings);
      await authUser.reload();

      final refreshedUser = _auth.currentUser;

      setState(() {
        emailVerificationSent = true;
        emailVerified = refreshedUser?.emailVerified ?? false;
        verificationEmail = cleanEmail;
        authUid = refreshedUser?.uid ?? authUser?.uid ?? '';
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
        _showSnack(
          'لم يتم التحقق من البريد بعد. افتحي الرابط من البريد ثم أعيدي المحاولة',
        );
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

  Future<void> _createAdminRegistrationNotification({
    required String requestId,
    required String parentUid,
    required String parentName,
    required String parentUsername,
    required String parentEmail,
    required String parentPhone,
  }) async {
    final title = 'طلب تسجيل ولي أمر جديد';
    final body =
        'تم إرسال طلب تسجيل جديد من $parentName باسم المستخدم @$parentUsername، بانتظار مراجعة الإدارة.';

    final baseData = <String, dynamic>{
      'title': title,
      'body': body,
      'message': body,
      'type': 'parent_registration_request',
      'notificationType': 'parent_registration_request',
      'category': 'registration_requests',
      'priority': 'important',
      'importance': 'important',
      'isRead': false,
      'read': false,
      'seen': false,
      'requestId': requestId,
      'requestType': 'parent_registration',
      'status': 'pending',
      'parentUid': parentUid,
      'parentUsername': parentUsername,
      'parentName': parentName,
      'parentEmail': parentEmail,
      'parentPhone': parentPhone,
      'createdByUid': parentUid,
      'createdByName': parentName,
      'createdByRole': 'parent',
      'senderUid': parentUid,
      'senderName': parentName,
      'senderRole': 'parent',
      'targetRole': 'admin',
      'receiverRole': 'admin',
      'route': 'registration_requests',
      'createdAt': FieldValue.serverTimestamp(),
      'time': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final adminsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      final activeAdmins = adminsSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['isActive'] != false;
      }).toList();

      if (activeAdmins.isEmpty) {
        await _firestore.collection('notifications').add({
          ...baseData,
          'receiverUid': '',
          'adminUid': '',
          'userUid': '',
          'scope': 'admin',
        });
        return;
      }

      final batch = _firestore.batch();

      for (final adminDoc in activeAdmins) {
        final adminData = adminDoc.data();
        final adminName = (adminData['displayName'] ??
                adminData['name'] ??
                adminData['username'] ??
                'الإدارة')
            .toString();

        final notificationRef = _firestore.collection('notifications').doc();

        batch.set(notificationRef, {
          ...baseData,
          'receiverUid': adminDoc.id,
          'adminUid': adminDoc.id,
          'userUid': adminDoc.id,
          'receiverName': adminName,
          'scope': 'admin',
        });
      }

      await batch.commit();
    } catch (_) {
      await _firestore.collection('notifications').add({
        ...baseData,
        'receiverUid': '',
        'adminUid': '',
        'userUid': '',
        'scope': 'admin',
      });
    }
  }

  Future<void> submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (!emailVerificationSent) {
      _showSnack('يجب إرسال رابط التحقق إلى البريد الإلكتروني أولًا');
      return;
    }

    if (!emailVerified) {
      _showSnack('يجب التحقق من البريد الإلكتروني قبل إرسال الطلب');
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showSnack('لا يوجد حساب تحقق نشط. أعيدي إرسال رابط التحقق');
      return;
    }

    await currentUser.reload();
    final verifiedUser = _auth.currentUser;

    final cleanEmail = emailCtrl.text.trim().toLowerCase();
    final cleanUsername = normalizeUsername(usernameCtrl.text);

    if (verifiedUser == null) {
      _showSnack('تعذر التحقق من حساب البريد الحالي');
      return;
    }

    if (!verifiedUser.emailVerified) {
      _showSnack('البريد الحالي غير موثّق بعد');
      return;
    }

    if ((verifiedUser.email ?? '').trim().toLowerCase() != cleanEmail) {
      _showSnack('البريد المتحقق منه لا يطابق البريد المكتوب في النموذج');
      return;
    }

    if (verifiedUser.uid.trim().isEmpty) {
      _showSnack('تعذر تحديد uid للحساب الحالي');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      usernameCtrl.text = cleanUsername;
      emailCtrl.text = cleanEmail;
      phoneCtrl.text = phoneCtrl.text.trim();
      alternatePhoneCtrl.text = alternatePhoneCtrl.text.trim();
      nationalIdCtrl.text = nationalIdCtrl.text.trim();

      final usernameTaken = await _usernameExistsAnywhere(cleanUsername);
      if (usernameTaken) {
        throw Exception('اسم المستخدم مستخدم مسبقًا');
      }

      final emailTaken = await _emailExistsAnywhere(cleanEmail);
      if (emailTaken) {
        throw Exception('البريد الإلكتروني مستخدم مسبقًا');
      }

      final requestAuthUid = verifiedUser.uid.trim();
      final fullName = fullNameCtrl.text.trim();
      final mainPhone = phoneCtrl.text.trim();

      final requestData = <String, dynamic>{
        'requestType': 'parent_registration',
        'status': 'pending',

        'authUid': requestAuthUid,
        'authPreCreated': true,
        'authAccountCreated': true,
        'emailVerified': true,
        'verificationMethod': 'email_link',

        'email': cleanEmail,
        'username': cleanUsername,
        'fullName': fullName,
        'phone': mainPhone,

        'approvalMode': '',
        'activationMethod': '',
        'linkedParentUid': '',
        'linkedParentUsername': '',
        'linkedParentName': '',
        'processedToUserDoc': false,
        'processedChildrenCount': 0,

        'createdByUid': requestAuthUid,
        'createdByName': fullName.isEmpty ? 'ولي أمر' : fullName,
        'createdByRole': 'parent',

        'parentInfo': {
          'fullName': fullName,
          'username': cleanUsername,
          'email': cleanEmail,
          'phone': mainPhone,
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

        'childrenInfo': [],

        'reviewNote': '',
        'reviewedByUid': '',
        'reviewedByName': '',
        'reviewedAt': null,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final requestRef =
          await _firestore.collection('registration_requests').add(requestData);

      await _createAdminRegistrationNotification(
        requestId: requestRef.id,
        parentUid: requestAuthUid,
        parentName: fullName.isEmpty ? 'ولي أمر' : fullName,
        parentUsername: cleanUsername,
        parentEmail: cleanEmail,
        parentPhone: mainPhone,
      );

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
    } on FirebaseException catch (e) {
      _showSnack('خطأ Firestore: ${e.code} - ${e.message}');
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
            'هذه آخر خطوة قبل إرسال الطلب للإدارة.',
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  isSendingVerification ? null : sendEmailVerificationLink,
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  isCheckingVerification ? null : checkEmailVerificationStatus,
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
                _resetVerificationState();
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
                _resetVerificationState();
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
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            decoration: customDecoration(
              label: 'رقم الهوية',
              icon: Icons.credit_card_rounded,
            ),
            validator: (value) => _validatePalestinianId(value ?? ''),
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
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: (_) {
              _formKey.currentState?.validate();
            },
            decoration: customDecoration(
              label: 'رقم الجوال الأساسي',
              icon: Icons.phone_rounded,
            ),
            validator: (value) => _validatePalestinianMobile(
              value ?? '',
              label: 'رقم الجوال الأساسي',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: alternatePhoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
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
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: customDecoration(
              label: 'هاتف العمل',
              icon: Icons.call_rounded,
              hint: 'اختياري',
            ),
            validator: (value) => _validatePalestinianMobile(
              value ?? '',
              label: 'هاتف العمل',
              requiredField: false,
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
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
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
            buildPersonalSection(),
            const SizedBox(height: 14),
            buildContactSection(),
            const SizedBox(height: 14),
            buildEmergencySection(),
            const SizedBox(height: 18),
            buildVerificationCard(),
            const SizedBox(height: 14),
            buildSubmitSection(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}