import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ForceChangePasswordPage extends StatefulWidget {
  final String userRole;
  final String username;
  final String temporaryPassword;

  const ForceChangePasswordPage({
    super.key,
    required this.userRole,
    required this.username,
    required this.temporaryPassword,
  });

  @override
  State<ForceChangePasswordPage> createState() =>
      _ForceChangePasswordPageState();
}

class _ForceChangePasswordPageState extends State<ForceChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  static const Set<String> _weakPasswords = {
    '123456',
    '1234567',
    '12345678',
    '123456789',
    '111111',
    '11111111',
    '000000',
    '00000000',
    'password',
    'password123',
    'qwerty',
    'qwerty123',
    'abcdef',
    'abc123',
  };

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  bool _allCharactersSame(String text) {
    if (text.isEmpty) return false;
    return text.split('').every((char) => char == text[0]);
  }

  bool _isOnlyNumbers(String text) {
    return RegExp(r'^\d+$').hasMatch(text);
  }

  bool _isOnlyLetters(String text) {
    return RegExp(r'^[a-zA-Z]+$').hasMatch(text);
  }

  String? _validatePassword(String? value) {
    final text = value?.trim() ?? '';
    final lowerText = text.toLowerCase();
    final lowerUsername = widget.username.trim().toLowerCase();
    final tempPassword = widget.temporaryPassword.trim();

    if (text.isEmpty) {
      return 'كلمة المرور الجديدة مطلوبة';
    }

    if (text.length < 6) {
      return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل';
    }

    if (tempPassword.isNotEmpty && text == tempPassword) {
      return 'يجب اختيار كلمة مرور جديدة مختلفة عن كلمة المرور المؤقتة';
    }

    if (lowerText == lowerUsername && lowerUsername.isNotEmpty) {
      return 'لا يمكن أن تكون كلمة المرور مطابقة لاسم المستخدم';
    }

    if (_weakPasswords.contains(lowerText)) {
      return 'كلمة المرور ضعيفة جدًا، اختاري كلمة أقوى';
    }

    if (_allCharactersSame(text)) {
      return 'كلمة المرور ضعيفة جدًا، لا تستخدمي نفس الحرف أو الرقم مكررًا';
    }

    if (_isOnlyNumbers(text) && text.length < 8) {
      return 'كلمة المرور الضعيفة جدًا لا تُقبل، استخدمي حروفًا وأرقامًا';
    }

    if (_isOnlyLetters(text) && text.length < 8) {
      return 'كلمة المرور الضعيفة جدًا لا تُقبل، استخدمي حروفًا وأرقامًا';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'تأكيد كلمة المرور مطلوب';
    }

    if (text != _passwordCtrl.text.trim()) {
      return 'كلمتا المرور غير متطابقتين';
    }

    return null;
  }

  String _roleLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'parent':
        return 'ولي الأمر';
      case 'teacher':
        return 'المعلمة';
      case 'nursery':
      case 'nursery staff':
      case 'nursery_staff':
        return 'موظفة الحضانة';
      case 'admin':
        return 'الإدارة';
      default:
        return 'المستخدم';
    }
  }

  Future<void> _saveNewPassword() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'لا يوجد مستخدم مسجل دخول حاليًا',
        );
      }

      final newPassword = _passwordCtrl.text.trim();

      await currentUser.updatePassword(newPassword);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'mustChangePassword': false,
        'isFirstLogin': false,
        'passwordChangedAt': FieldValue.serverTimestamp(),
        'temporaryPasswordPlain': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تغيير كلمة المرور بنجاح',
            textAlign: TextAlign.center,
          ),
        ),
      );

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      String message = 'حدث خطأ أثناء تغيير كلمة المرور';

      if (e.code == 'requires-recent-login') {
        message =
            'انتهت صلاحية الجلسة الحالية. سجّل الدخول مرة أخرى ثم أعد المحاولة.';
      } else if (e.code == 'weak-password') {
        message = 'كلمة المرور الجديدة ضعيفة جدًا';
      } else if (e.message != null && e.message!.trim().isNotEmpty) {
        message = e.message!;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ غير متوقع: $e',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = _roleLabel(widget.userRole);

    return AppPageScaffold(
      title: 'تغيير كلمة المرور',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحبًا ${widget.username}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'تم تسجيل دخولك كـ $roleLabel لأول مرة باستخدام كلمة مرور مؤقتة. لحماية حسابك، يجب تعيين كلمة مرور جديدة مختلفة عن الكلمة المؤقتة قبل المتابعة.',
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.7,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      validator: _validatePassword,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                        prefixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textLight,
                          ),
                        ),
                        suffixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      obscureText: _obscureConfirmPassword,
                      validator: _validateConfirmPassword,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور الجديدة',
                        prefixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textLight,
                          ),
                        ),
                        suffixIcon: const Icon(
                          Icons.lock_reset_outlined,
                          color: AppColors.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.18),
                        ),
                      ),
                      child: const Text(
                        'يفضل اختيار كلمة مرور تحتوي على حروف وأرقام، وألا تكون سهلة أو مكررة أو مطابقة لاسم المستخدم.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.6,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveNewPassword,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isLoading ? 'جارٍ الحفظ...' : 'حفظ كلمة المرور',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}