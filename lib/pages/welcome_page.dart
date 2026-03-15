import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'admin_home_page.dart';
import 'nursery_staff_home_page.dart';
import 'parent_home_page.dart';
import 'register_role_page.dart';
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
    _showSnack(
      'إعادة تعيين كلمة المرور ما زالت مرتبطة بالبريد الإلكتروني، ويمكن تطويرها لاحقًا بصفحة مستقلة.',
    );
  }

  Future<void> onGoogleLogin() async {
    setState(() {
      isGoogleLoading = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;

      if (user == null) {
        _showSnack('فشل تسجيل الدخول عبر Google');
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        await googleSignIn.signOut();

        _showSnack(
          'تم تسجيل الدخول عبر Google لكن لا يوجد حساب مكتمل لهذا المستخدم داخل التطبيق. أنشئ حسابًا أولًا.',
        );
        return;
      }

      await NotificationService.instance.saveCurrentUserToken();
      await _goToUserHome(user);
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
      if (!mounted) return;
      setState(() {
        isCheckingUser = false;
      });
      _showSnack('بيانات المستخدم غير موجودة في قاعدة البيانات');
      return;
    }

    final data = doc.data()!;
    final role = data['role'] ?? '';
    final username = data['username'] ?? '';

    Widget nextPage;

    if (role == 'parent') {
      nextPage = ParentHomePage(parentUsername: username);
    } else if (role == 'nursery') {
      nextPage = const NurseryStaffHomePage();
    } else if (role == 'teacher') {
      nextPage = const TeacherHomePage();
    } else {
      nextPage = const AdminHomePage();
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextPage),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, textAlign: TextAlign.center)),
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
                          const SizedBox(height: 14),
                          GlassOutlineButton(
                            text: 'إنشاء حساب جديد',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterRolePage(),
                                ),
                              );
                            },
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
                                child: SizedBox(
                                  height: 58,
                                  child: Center(
                                    child: isGoogleLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: AppColors.primary,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'المتابعة باستخدام Google',
                                                style: TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textDark,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.45),
                                                  borderRadius:
                                                      BorderRadius.circular(11),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.65),
                                                  ),
                                                ),
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'G',
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _miniChip('ثقة', Icons.favorite_border_rounded),
                              const SizedBox(width: 10),
                              _miniChip('أمان', Icons.shield_outlined),
                              const SizedBox(width: 10),
                              _miniChip(
                                'متابعة',
                                Icons.remove_red_eye_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'طمّني • Nursery & Kindergarten Management',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 10),
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
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? prefix,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscure,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: prefix,
          suffixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(end: 10, start: 6),
            child: Icon(icon, color: AppColors.textLight),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 46,
            minHeight: 46,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.72),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.90),
              width: 1.25,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.45,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: AppColors.danger,
              width: 1.2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: AppColors.danger,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String text, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.24),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.52),
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
              Text(
                text,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                icon,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
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

class GlassOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const GlassOutlineButton({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withOpacity(0.14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.58),
                  width: 1.45,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 17.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
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
              size: index % 2 == 0 ? 18 : 15,
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
      child: Icon(
        Icons.auto_awesome,
        size: 28,
        color: Colors.white,
      ),
    );
  }
}
