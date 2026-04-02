import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'admin_home_page.dart';
import 'nursery_staff_home_page.dart';
import 'parent_home_page.dart';
import 'parent_registration_request_page.dart';
import 'teacher_home_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final AuthService _authService = AuthService();

  bool obscurePassword = true;
  bool isLoading = false;
  bool isCheckingUser = true;
  bool isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    checkLoggedInUser();
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> checkLoggedInUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        isCheckingUser = false;
      });
      return;
    }

    try {
      await _goToUserHome(user);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isCheckingUser = false;
      });
    }
  }

  String? validateUsername(String? value) {
    final username = value?.trim() ?? '';

    if (username.isEmpty) {
      return 'الرجاء إدخال اسم المستخدم';
    }

    if (username.length < 3) {
      return 'اسم المستخدم قصير جدًا';
    }

    return null;
  }

  String? validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'الرجاء إدخال كلمة المرور';
    }

    if (password.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }

    return null;
  }

  Future<void> onLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      final user = await _authService.login(
        username: usernameCtrl.text.trim(),
        password: passwordCtrl.text,
      );

      if (user == null) {
        _showSnack('فشل تسجيل الدخول');
        return;
      }

      await NotificationService.instance.saveCurrentUserToken();
      await _goToUserHome(user);
    } on FirebaseException catch (e) {
      String message = 'حدث خطأ أثناء تسجيل الدخول';

      if (e.code == 'user-not-found') {
        message = 'اسم المستخدم غير موجود';
      } else if (e.code == 'wrong-password') {
        message = 'كلمة المرور غير صحيحة';
      } else if (e.code == 'invalid-email') {
        message = 'لا يوجد بريد إلكتروني مرتبط بهذا المستخدم';
      } else if (e.code == 'invalid-credential') {
        message = 'بيانات الدخول غير صحيحة';
      }

      _showSnack(message);
    } catch (e) {
      _showSnack('حدث خطأ: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> onForgotPassword() async {
    final usernameController = TextEditingController();

    try {
      final enteredUsername = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          final dialogFormKey = GlobalKey<FormState>();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                'استعادة كلمة المرور',
                textAlign: TextAlign.center,
              ),
              content: Form(
                key: dialogFormKey,
                child: TextFormField(
                  controller: usernameController,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'أدخل اسم المستخدم',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  validator: (value) {
                    final username = value?.trim() ?? '';
                    if (username.isEmpty) {
                      return 'الرجاء إدخال اسم المستخدم';
                    }
                    if (username.length < 3) {
                      return 'اسم المستخدم غير صحيح';
                    }
                    return null;
                  },
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (dialogFormKey.currentState!.validate()) {
                      Navigator.pop(context, usernameController.text.trim());
                    }
                  },
                  child: const Text('متابعة'),
                ),
              ],
            ),
          );
        },
      );

      if (enteredUsername == null || enteredUsername.isEmpty) return;

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: enteredUsername)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showSnack('اسم المستخدم غير موجود');
        return;
      }

      final userData = userQuery.docs.first.data();
      final email = (userData['email'] ?? '').toString().trim();

      if (email.isEmpty) {
        _showSnack('لا يوجد بريد إلكتروني مرتبط بهذا الحساب');
        return;
      }

      final maskedEmail = _maskEmail(email);

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                'تأكيد الهوية',
                textAlign: TextAlign.center,
              ),
              content: Text(
                'سيتم إرسال رابط إعادة تعيين كلمة المرور إلى البريد التالي:\n$maskedEmail\n\nهل تريد المتابعة؟',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.6),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('إرسال الرابط'),
                ),
              ],
            ),
          );
        },
      );

      if (confirmed != true) return;

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      _showSnack('تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        _showSnack('البريد الإلكتروني المرتبط بالحساب غير صالح');
      } else {
        _showSnack('تعذر إرسال رابط إعادة التعيين');
      }
    } catch (_) {
      _showSnack('حدث خطأ أثناء استعادة كلمة المرور');
    } finally {
      usernameController.dispose();
    }
  }

  Future<void> onGoogleLogin() async {
    setState(() {
      isGoogleLoading = true;
    });

    GoogleSignIn? googleSignIn;

    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        userCredential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();

        final googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          return;
        }

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCredential.user;

      if (user == null) {
        _showSnack('فشل تسجيل الدخول باستخدام Google');
        return;
      }

      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (currentUserDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'loginProvider': 'google',
        }, SetOptions(merge: true));

        await NotificationService.instance.saveCurrentUserToken();
        await _goToUserHome(user);
        return;
      }

      final userEmail = (user.email ?? '').trim();

      if (userEmail.isNotEmpty) {
        final existingByEmail = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: userEmail)
            .limit(1)
            .get();

        if (existingByEmail.docs.isNotEmpty) {
          await FirebaseAuth.instance.signOut();
          if (!kIsWeb && googleSignIn != null) {
            await googleSignIn.signOut();
          }

          _showSnack(
            'هذا البريد مرتبط بحساب موجود مسبقًا. سجّلي الدخول بالطريقة المعتادة أولًا، ثم اربطي Google لاحقًا.',
          );
          return;
        }
      }

      await FirebaseAuth.instance.signOut();
      if (!kIsWeb && googleSignIn != null) {
        await googleSignIn.signOut();
      }

      _showSnack(
        'لا يمكن إنشاء حساب جديد مباشرة من داخل التطبيق. يمكنك تقديم طلب إنشاء حساب ولي أمر من هذه الشاشة.',
      );
    } on FirebaseAuthException catch (e) {
      String message = 'تعذر تسجيل الدخول باستخدام Google';

      if (e.code == 'account-exists-with-different-credential') {
        message =
            'هذا البريد مستخدم مسبقًا بطريقة تسجيل دخول مختلفة. استخدمي الطريقة الأصلية لهذا الحساب.';
      } else if (e.code == 'invalid-credential') {
        message = 'بيانات Google غير صالحة، حاولي مرة أخرى';
      } else if (e.code == 'popup-closed-by-user') {
        message = 'تم إغلاق نافذة تسجيل الدخول قبل إكمال العملية';
      } else if (e.code == 'popup-blocked') {
        message =
            'المتصفح منع نافذة Google. اسمحي بالنوافذ المنبثقة ثم حاولي مرة أخرى';
      } else if (e.code == 'user-disabled') {
        message = 'تم تعطيل هذا الحساب';
      }

      _showSnack(message);
    } catch (_) {
      _showSnack('تعذر تسجيل الدخول باستخدام Google');
    } finally {
      if (!mounted) return;
      setState(() {
        isGoogleLoading = false;
      });
    }
  }

  Future<void> _goToUserHome(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      setState(() {
        isCheckingUser = false;
      });

      _showSnack('لا يوجد حساب مفعّل لهذا المستخدم. يرجى مراجعة الإدارة.');
      return;
    }

    final data = doc.data()!;
    final role = (data['role'] ?? '').toString().trim().toLowerCase();
    final username = (data['username'] ?? '').toString().trim();
    final isProfileCompleted = data['isProfileCompleted'] ?? true;
    final isActive = data['isActive'] ?? true;

    if (isActive != true) {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      setState(() {
        isCheckingUser = false;
      });

      _showSnack('هذا الحساب غير مفعل حاليًا');
      return;
    }

    if (role.isEmpty || isProfileCompleted == false) {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      setState(() {
        isCheckingUser = false;
      });

      _showSnack('الحساب غير مكتمل أو غير مفعّل. يرجى مراجعة الإدارة.');
      return;
    }

    Widget nextPage;

     final normalizedRole = role == 'nursery' || role == 'nursery staff'
    ? 'nursery_staff'
    : role;

if (normalizedRole == 'parent') {
  nextPage = ParentHomePage(parentUsername: username);
} else if (normalizedRole == 'nursery_staff') {
  nextPage = const NurseryStaffHomePage();
} else if (normalizedRole == 'teacher') {
  nextPage = const TeacherHomePage();
} else if (normalizedRole == 'admin') {
  nextPage = const AdminHomePage();
} else {
  await FirebaseAuth.instance.signOut();

  if (!mounted) return;
  setState(() {
    isCheckingUser = false;
  });

  _showSnack('نوع الحساب غير معروف: $role');
  return;
}

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextPage),
    );
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final name = parts[0];
    final domain = parts[1];

    if (name.isEmpty) return email;

    String maskedName;
    if (name.length == 1) {
      maskedName = '*';
    } else if (name.length == 2) {
      maskedName = '${name[0]}*';
    } else {
      maskedName =
          '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}';
    }

    return '$maskedName@$domain';
  }

  void _openParentRegistrationRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ParentRegistrationRequestPage(),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isCheckingUser) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF8FBFF),
                Color(0xFFF3F8FF),
                Color(0xFFEEF8F7),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                const Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: _SoftBackgroundPattern(),
                  ),
                ),
                const Positioned(
                  bottom: 18,
                  right: 18,
                  child: IgnorePointer(
                    child: _BottomGlowStar(),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 78),
                          Center(
                            child: Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFA7AAFF).withOpacity(0.42),
                                    Colors.white.withOpacity(0.82),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.20),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.55),
                                  width: 1.4,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.child_friendly_rounded,
                                    size: 58,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'أهلاً بك في طمّني',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'متابعة طفلك بسهولة وأمان',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16.5,
                              height: 1.55,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 34),

                          GlassContainer(
                            padding: const EdgeInsets.all(18),
                            borderRadius: BorderRadius.circular(28),
                            opacity: 0.24,
                            blur: 16,
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  _buildTextField(
                                    controller: usernameCtrl,
                                    hint: 'اسم المستخدم',
                                    icon: Icons.person_outline_rounded,
                                    validator: validateUsername,
                                    keyboardType: TextInputType.text,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildTextField(
                                    controller: passwordCtrl,
                                    hint: 'كلمة المرور',
                                    icon: Icons.lock_outline_rounded,
                                    validator: validatePassword,
                                    obscure: obscurePassword,
                                    prefix: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          obscurePassword = !obscurePassword;
                                        });
                                      },
                                      icon: Icon(
                                        obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: onForgotPassword,
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: const Text(
                                        'هل نسيت كلمة المرور؟',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.24),
                                  blurRadius: 26,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : onLogin,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 60),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'تسجيل الدخول',
                                      style: TextStyle(
                                        fontSize: 17.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          GlassContainer(
                            padding: EdgeInsets.zero,
                            borderRadius: BorderRadius.circular(20),
                            opacity: 0.22,
                            blur: 13,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: isGoogleLoading ? null : onGoogleLogin,
                                child: Container(
                                  height: 58,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.login_rounded,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 10),
                                      isGoogleLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                              ),
                                            )
                                          : const Text(
                                              'المتابعة باستخدام Google',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          Center(
                            child: TextButton.icon(
                              onPressed: _openParentRegistrationRequest,
                              icon: const Icon(Icons.how_to_reg_rounded),
                              label: const Text(
                                'طلب إنشاء حساب ولي أمر',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          GlassContainer(
                            padding: const EdgeInsets.all(14),
                            borderRadius: BorderRadius.circular(20),
                            opacity: 0.18,
                            blur: 12,
                            child: const Column(
                              children: [
                                _MiniInfoChip(
                                  icon: Icons.admin_panel_settings_outlined,
                                  text: 'حسابات المعلمات والموظفات والأدمن تنشئها الإدارة فقط',
                                ),
                                SizedBox(height: 10),
                                _MiniInfoChip(
                                  icon: Icons.family_restroom_outlined,
                                  text: 'أولياء الأمور يقدّمون طلب تسجيل ثم تتم المراجعة والموافقة',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          const Text(
                            'طمّني • Nursery & Kindergarten Management',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? prefix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscure,
        keyboardType: keyboardType,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: prefix,
          suffixIcon: Icon(
            icon,
            color: AppColors.primary.withOpacity(0.90),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.58),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.45),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.45),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.4,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: Colors.redAccent,
              width: 1.2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: Colors.redAccent,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final String text;
  final IconData icon;

  const _MiniInfoChip({
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final double opacity;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.blur = 14,
    this.opacity = 0.20,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withOpacity(0.46),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SoftBackgroundPattern extends StatelessWidget {
  const _SoftBackgroundPattern();

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.eco_outlined,
      Icons.favorite_border_rounded,
      Icons.toys_outlined,
      Icons.nightlight_round,
    ];

    return Opacity(
      opacity: 0.05,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            10,
            (index) => Icon(
              icons[index % icons.length],
              size: index.isEven ? 18 : 15,
              color: AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomGlowStar extends StatelessWidget {
  const _BottomGlowStar();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.22,
      child: const Icon(
        Icons.auto_awesome,
        size: 28,
        color: Colors.white,
      ),
    );
  }
}