import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/account_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'welcome_page.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final AccountSettingsService _service = AccountSettingsService();

  final _nameFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _emailPasswordController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSavingName = false;
  bool _isChangingPassword = false;
  bool _isChangingEmail = false;
  bool _isCancellingPendingEmailChange = false;

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureEmailPassword = true;

  bool _isAutoCheckingEmail = false;
  bool _emailVerificationTimedOut = false;
  bool _isCheckingEmailNow = false;
  bool _isRedirectingAfterEmailLoss = false;

  Timer? _emailVerificationTimer;
  int _remainingEmailVerificationSeconds = 0;

  AccountSettingsData? _userData;

  static const int _emailCheckIntervalSeconds = 3;
  static const int _emailCheckTotalSeconds = 120;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    _stopEmailVerificationWatcher();
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newEmailController.dispose();
    _emailPasswordController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    await _loadUserData();

    try {
      final result = await _service.refreshEmailAfterVerificationIfNeeded();

      if (result == EmailRefreshStatus.success) {
        await _loadUserData();
        _showSnack('تمت مزامنة البريد الإلكتروني بنجاح');
      } else if (result == EmailRefreshStatus.noCurrentUser) {
        await _handleSessionEndedAfterEmailVerification();
        return;
      }
    } catch (_) {}

    await _restoreEmailWatcherIfNeeded();
  }

  String _formatCountdown(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _stopEmailVerificationWatcher({bool keepTimeoutState = false}) {
    _emailVerificationTimer?.cancel();
    _emailVerificationTimer = null;
    _isCheckingEmailNow = false;

    if (mounted) {
      setState(() {
        _isAutoCheckingEmail = false;
        _remainingEmailVerificationSeconds = 0;
        if (!keepTimeoutState) {
          _emailVerificationTimedOut = false;
        }
      });
    }
  }

  Future<void> _handleSessionEndedAfterEmailVerification() async {
    if (_isRedirectingAfterEmailLoss) return;
    _isRedirectingAfterEmailLoss = true;

    _stopEmailVerificationWatcher();

    _showSnack(
      'تم تحديث البريد، يرجى تسجيل الدخول من جديد.',
    );

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  Future<void> _restoreEmailWatcherIfNeeded() async {
    if (!mounted) return;

    final data = _userData;
    if (data == null) return;
    if (!data.hasPendingEmailChange) return;

    final requestedAt = data.emailChangeRequestedAt;
    if (requestedAt == null) return;

    final elapsed = DateTime.now().difference(requestedAt).inSeconds;
    final remaining = _emailCheckTotalSeconds - elapsed;

    if (remaining <= 0) {
      setState(() {
        _emailVerificationTimedOut = true;
        _isAutoCheckingEmail = false;
        _remainingEmailVerificationSeconds = 0;
      });
      return;
    }

    if (_isAutoCheckingEmail) return;

    await _startEmailVerificationWatcher(
      initialRemainingSeconds: remaining,
    );
  }

  Future<void> _startEmailVerificationWatcher({
    int initialRemainingSeconds = _emailCheckTotalSeconds,
  }) async {
    _emailVerificationTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _isAutoCheckingEmail = true;
      _emailVerificationTimedOut = false;
      _remainingEmailVerificationSeconds = initialRemainingSeconds;
      _isCheckingEmailNow = false;
    });

    _emailVerificationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (!mounted) {
          _stopEmailVerificationWatcher();
          return;
        }

        if (_remainingEmailVerificationSeconds <= 0) {
          _stopEmailVerificationWatcher(keepTimeoutState: true);
          if (mounted) {
            setState(() {
              _emailVerificationTimedOut = true;
            });
          }
          return;
        }

        setState(() {
          _remainingEmailVerificationSeconds--;
        });

        if (_remainingEmailVerificationSeconds % _emailCheckIntervalSeconds !=
            0) {
          return;
        }

        if (_isCheckingEmailNow) return;
        _isCheckingEmailNow = true;

        try {
          final result = await _service.refreshEmailAfterVerificationIfNeeded();

          if (!mounted) return;

          if (result == EmailRefreshStatus.success) {
            _stopEmailVerificationWatcher();
            await _loadUserData();
            _showSnack('تم تحديث البريد الإلكتروني بنجاح');
            return;
          }

          if (result == EmailRefreshStatus.noCurrentUser) {
            await _handleSessionEndedAfterEmailVerification();
            return;
          }

          if (_remainingEmailVerificationSeconds <= 0) {
            _stopEmailVerificationWatcher(keepTimeoutState: true);
            if (mounted) {
              setState(() {
                _emailVerificationTimedOut = true;
              });
            }
          }
        } on FirebaseAuthException catch (e) {
          if (!mounted) return;

          if (e.code == 'no-current-user') {
            await _handleSessionEndedAfterEmailVerification();
            return;
          }

          if (_remainingEmailVerificationSeconds <= 0) {
            _stopEmailVerificationWatcher(keepTimeoutState: true);
            setState(() {
              _emailVerificationTimedOut = true;
            });
          }
        } catch (_) {
          if (!mounted) return;

          if (_remainingEmailVerificationSeconds <= 0) {
            _stopEmailVerificationWatcher(keepTimeoutState: true);
            setState(() {
              _emailVerificationTimedOut = true;
            });
          }
        } finally {
          _isCheckingEmailNow = false;
        }
      },
    );
  }

  Future<void> _loadUserData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final data = await _service.getCurrentUserData();

      _nameController.text = data.name;

      if (!mounted) return;
      setState(() {
        _userData = data;
      });
    } on FirebaseAuthException catch (e) {
      if (e.code != 'no-current-user') {
        _showSnack(e.message ?? 'حدث خطأ أثناء تحميل بيانات الحساب');
      }
    } on FirebaseException catch (e) {
      _showSnack(e.message ?? 'حدث خطأ في قراءة بيانات Firestore');
    } catch (e) {
      _showSnack('حدث خطأ أثناء تحميل بيانات الحساب: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveName() async {
    if (!_nameFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSavingName = true;
    });

    try {
      await _service.updateCurrentUserName(_nameController.text);
      await _loadUserData();
      _showSnack('تم تحديث الاسم بنجاح');
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'تعذر تحديث الاسم');
    } catch (_) {
      _showSnack('تعذر تحديث الاسم');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingName = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isChangingPassword = true;
    });

    try {
      await _service.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      _showSnack('تم تغيير كلمة المرور بنجاح');
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'تعذر تغيير كلمة المرور');
    } catch (_) {
      _showSnack('تعذر تغيير كلمة المرور');
    } finally {
      if (!mounted) return;
      setState(() {
        _isChangingPassword = false;
      });
    }
  }

  Future<void> _requestEmailChange() async {
    if (!_emailFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isChangingEmail = true;
    });

    try {
      await _service.requestEmailChange(
        newEmail: _newEmailController.text,
        currentPassword: _emailPasswordController.text,
      );

      _newEmailController.clear();
      _emailPasswordController.clear();

      await _loadUserData();
      await _startEmailVerificationWatcher();

      _showSnack('تم إرسال رابط التحقق إلى البريد الجديد');
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'تعذر بدء تغيير البريد الإلكتروني');
    } catch (_) {
      _showSnack('تعذر بدء تغيير البريد الإلكتروني');
    } finally {
      if (!mounted) return;
      setState(() {
        _isChangingEmail = false;
      });
    }
  }

  Future<void> _clearPendingEmailChange() async {
    if (_isCancellingPendingEmailChange) return;

    setState(() {
      _isCancellingPendingEmailChange = true;
    });

    try {
      _stopEmailVerificationWatcher();
      await _service.clearPendingEmailChange();
      _newEmailController.clear();
      _emailPasswordController.clear();
      await _loadUserData();
      _showSnack('تم إلغاء طلب تغيير البريد الإلكتروني');
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'تعذر إلغاء الطلب');
    } catch (_) {
      _showSnack('تعذر إلغاء الطلب');
    } finally {
      if (!mounted) return;
      setState(() {
        _isCancellingPendingEmailChange = false;
      });
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, textAlign: TextAlign.center)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إعدادات الحساب',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('تعذر تحميل بيانات الحساب'))
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _AccountHeaderCard(userData: _userData!),
                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'حالة الحساب'),
                      const SizedBox(height: 8),
                      _buildAccountStatusCard(),
                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'معلومات الحساب'),
                      const SizedBox(height: 8),
                      _buildAccountInfoCard(),
                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'تعديل الاسم'),
                      const SizedBox(height: 8),
                      _buildNameEditCard(),
                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'تغيير البريد الإلكتروني'),
                      const SizedBox(height: 8),
                      _buildEmailCard(),
                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'تغيير كلمة المرور'),
                      const SizedBox(height: 8),
                      _buildPasswordCard(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAccountInfoCard() {
    final data = _userData!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'الاسم الكامل',
              value: data.name.isEmpty ? 'غير محدد' : data.name,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.alternate_email_rounded,
              label: 'اسم المستخدم',
              value: data.username.isEmpty ? 'غير محدد' : data.username,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'البريد الإلكتروني',
              value: data.email.isEmpty ? 'غير محدد' : data.email,
            ),
            if (data.hasPendingEmailChange) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.mark_email_unread_outlined,
                label: 'بريد جديد بانتظار التحقق',
                value: data.pendingEmail,
              ),
            ],
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'الدور',
              value: data.roleLabel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameEditCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _nameFormKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                validator: _service.validateFullName,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSavingName ? null : _saveName,
                  icon: _isSavingName
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSavingName ? 'جاري الحفظ...' : 'حفظ الاسم'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailCard() {
    final data = _userData!;
    final hasPending = data.hasPendingEmailChange;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (hasPending) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'طلب تغيير البريد معلق إلى: ${data.pendingEmail}',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Form(
              key: _emailFormKey,
              child: Column(
                children: [
                  TextFormField(
                    initialValue: data.email,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'البريد الحالي',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newEmailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: _service.validateEmail,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني الجديد',
                      prefixIcon: Icon(Icons.mark_email_read_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailPasswordController,
                    obscureText: _obscureEmailPassword,
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'كلمة المرور الحالية مطلوبة';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الحالية',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscureEmailPassword = !_obscureEmailPassword;
                          });
                        },
                        icon: Icon(
                          _obscureEmailPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isChangingEmail ||
                              _isAutoCheckingEmail ||
                              _isCancellingPendingEmailChange)
                          ? null
                          : _requestEmailChange,
                      icon: _isChangingEmail
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : _isAutoCheckingEmail
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.mark_email_read_outlined),
                      label: Text(
                        _isChangingEmail
                            ? 'جاري إرسال الرابط...'
                            : _isAutoCheckingEmail
                                ? 'جاري التحقق...'
                                : 'إرسال رابط التحقق',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (hasPending) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _emailVerificationTimedOut
                        ? AppColors.danger.withOpacity(0.5)
                        : AppColors.primary.withOpacity(0.25),
                  ),
                ),
                child: Column(
                  children: [
                    if (_isAutoCheckingEmail) ...[
                      const Text(
                        'التحقق التلقائي',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatCountdown(_remainingEmailVerificationSeconds),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else if (_emailVerificationTimedOut) ...[
                      const Text(
                        'انتهت مهلة التحقق. يمكنك إعادة المحاولة أو تسجيل الدخول من جديد.',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      const Text(
                        'الطلب بانتظار التحقق من البريد الجديد.',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCancellingPendingEmailChange
                      ? null
                      : _clearPendingEmailChange,
                  icon: _isCancellingPendingEmailChange
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.3),
                        )
                      : const Icon(Icons.close_rounded),
                  label: Text(
                    _isCancellingPendingEmailChange
                        ? 'جاري الإلغاء...'
                        : 'إلغاء الطلب المعلق',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _passwordFormKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'كلمة المرور الحالية مطلوبة';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الحالية',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                    icon: Icon(
                      _obscureCurrentPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                validator: (value) {
                  final password = value ?? '';
                  if (password.trim().isEmpty) {
                    return 'كلمة المرور الجديدة مطلوبة';
                  }
                  if (password.length < 6) {
                    return 'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'تأكيد كلمة المرور مطلوب';
                  }
                  if (value != _newPasswordController.text) {
                    return 'تأكيد كلمة المرور غير مطابق';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور الجديدة',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isChangingPassword ? null : _changePassword,
                  icon: _isChangingPassword
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.password_rounded),
                  label: Text(
                    _isChangingPassword
                        ? 'جاري التحديث...'
                        : 'تغيير كلمة المرور',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountStatusCard() {
    final data = _userData;

    if (data == null) {
      return const SizedBox.shrink();
    }

    final isActive = data.isActive;

    final bgColor = isActive
        ? AppColors.success.withOpacity(0.08)
        : AppColors.danger.withOpacity(0.08);

    final textColor = isActive ? AppColors.success : AppColors.danger;

    final icon = isActive
        ? Icons.verified_user_outlined
        : Icons.person_off_outlined;

    final title = isActive ? 'الحساب نشط' : 'الحساب غير نشط';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: textColor.withOpacity(0.12),
                child: Icon(icon, color: textColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
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

class _AccountHeaderCard extends StatelessWidget {
  final AccountSettingsData userData;

  const _AccountHeaderCard({required this.userData});

  @override
  Widget build(BuildContext context) {
    final trimmedName = userData.name.trim();
    final firstLetter =
        trimmedName.isNotEmpty ? trimmedName.substring(0, 1) : '؟';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Text(
                firstLetter,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userData.name.isEmpty ? 'مستخدم' : userData.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userData.roleLabel,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textLight,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}