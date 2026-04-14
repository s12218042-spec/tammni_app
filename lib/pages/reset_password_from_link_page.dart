import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/password_validation_utils.dart';
import '../widgets/app_page_scaffold.dart';

class ResetPasswordFromLinkPage extends StatefulWidget {
  final String oobCode;
  final String username;

  const ResetPasswordFromLinkPage({
    super.key,
    required this.oobCode,
    this.username = '',
  });

  @override
  State<ResetPasswordFromLinkPage> createState() =>
      _ResetPasswordFromLinkPageState();
}

class _ResetPasswordFromLinkPageState
    extends State<ResetPasswordFromLinkPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isCheckingCode = true;
  bool _isCodeValid = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _verifyResetCode();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyResetCode() async {
    setState(() {
      _isCheckingCode = true;
      _isCodeValid = false;
      _statusMessage = '';
    });

    try {
      await FirebaseAuth.instance.verifyPasswordResetCode(widget.oobCode);

      if (!mounted) return;
      setState(() {
        _isCodeValid = true;
        _statusMessage = '';
      });
    } on FirebaseAuthException catch (e) {
      String message = 'رابط إعادة تعيين كلمة المرور غير صالح';

      if (e.code == 'expired-action-code') {
        message = 'انتهت صلاحية رابط إعادة تعيين كلمة المرور';
      } else if (e.code == 'invalid-action-code') {
        message = 'رابط إعادة تعيين كلمة المرور غير صالح أو تم استخدامه';
      } else if (e.message != null && e.message!.trim().isNotEmpty) {
        message = e.message!;
      }

      if (!mounted) return;
      setState(() {
        _isCodeValid = false;
        _statusMessage = message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCodeValid = false;
        _statusMessage = 'تعذر التحقق من رابط إعادة تعيين كلمة المرور';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isCheckingCode = false;
      });
    }
  }

  Future<void> _saveNewPassword() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final newPassword = _passwordCtrl.text.trim();

      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: newPassword,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تعيين كلمة المرور بنجاح، يمكنك الآن تسجيل الدخول',
            textAlign: TextAlign.center,
          ),
        ),
      );

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      String message = 'حدث خطأ أثناء تعيين كلمة المرور';

      if (e.code == 'expired-action-code') {
        message = 'انتهت صلاحية الرابط، اطلب رابطًا جديدًا';
      } else if (e.code == 'invalid-action-code') {
        message = 'الرابط غير صالح أو تم استخدامه مسبقًا';
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
    return AppPageScaffold(
      title: 'تعيين كلمة المرور',
      child: _isCheckingCode
          ? const Center(child: CircularProgressIndicator())
          : !_isCodeValid
              ? Center(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 52,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'تعذر فتح رابط إعادة التعيين',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _statusMessage.isEmpty
                              ? 'الرابط غير صالح'
                              : _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            height: 1.6,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
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
                                widget.username.trim().isEmpty
                                    ? 'تعيين كلمة مرور جديدة'
                                    : 'مرحبًا ${widget.username}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'أدخلي كلمة مرور جديدة ثم أكديها لإكمال تفعيل الحساب أو استعادة الوصول إليه.',
                                style: TextStyle(
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
                                validator: (value) =>
                                    PasswordValidationUtils.validateNewPassword(
                                  value: value,
                                  username: widget.username,
                                  temporaryPassword: '',
                                ),
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
                                validator: (value) => PasswordValidationUtils
                                    .validateConfirmPassword(
                                  confirmPassword: value,
                                  password: _passwordCtrl.text,
                                ),
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
                              _isLoading
                                  ? 'جارٍ الحفظ...'
                                  : 'حفظ كلمة المرور',
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