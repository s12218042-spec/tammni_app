import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/account_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'account_history_page.dart';
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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSavingName = false;
  bool _isChangingPassword = false;
  bool _isDeactivating = false;
  bool _isRequestingDeletion = false;

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  AccountSettingsData? _userData;
  AccountDeletionRequestData? _deletionRequestData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _service.getCurrentUserData();
      final deletionRequest = await _service.getLatestDeletionRequest();

      _nameController.text = data.name;

      if (!mounted) return;
      setState(() {
        _userData = data;
        _deletionRequestData = deletionRequest;
      });
    } on FirebaseAuthException catch (e) {
  _showSnack(e.message ?? 'حدث خطأ أثناء تحميل بيانات الحساب');
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

  Future<void> _deactivateAccount() async {
    final isAdmin = _userData?.role == 'admin';

    if (isAdmin) {
      _showSnack('لا يمكن للأدمن تعطيل حسابه بنفسه');
      return;
    }

    final reasonController = TextEditingController();

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تعطيل الحساب مؤقتًا'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'لن تتمكني من تسجيل الدخول بعد ذلك حتى تقوم الإدارة بإعادة تفعيل الحساب.',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'سبب التعطيل المؤقت (اختياري)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, reasonController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: const Text('تعطيل الحساب'),
              ),
            ],
          ),
        ),
      );

      if (result == null) return;

      setState(() {
        _isDeactivating = true;
      });

      await _service.deactivateCurrentAccount(reason: result);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'تعذر تعطيل الحساب');
    } catch (_) {
      _showSnack('تعذر تعطيل الحساب');
    } finally {
      reasonController.dispose();
      if (!mounted) return;
      setState(() {
        _isDeactivating = false;
      });
    }
  }

  Future<void> _requestPermanentDeletion() async {
    final isAdmin = _userData?.role == 'admin';

    if (isAdmin) {
      _showSnack('لا يمكن للأدمن طلب حذف حسابه بنفسه');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('طلب حذف دائم'),
          content: const Text(
            'هل أنتِ متأكدة أنكِ تريدين إرسال طلب حذف دائم للحساب؟ سيتم إرسال الطلب للإدارة للمراجعة، ولن يتم حذف الحساب مباشرة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              child: const Text('إرسال الطلب'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isRequestingDeletion = true;
    });

    try {
      await _service.requestPermanentDeletion();
      _showSnack('تم إرسال طلب الحذف الدائم للإدارة بنجاح');
      await _loadUserData();
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'تعذر إرسال طلب الحذف الدائم');
    } catch (_) {
      _showSnack('تعذر إرسال طلب الحذف الدائم');
    } finally {
      if (!mounted) return;
      setState(() {
        _isRequestingDeletion = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
                    children: [
                      _AccountHeaderCard(userData: _userData!),
                      const SizedBox(height: 18),

                      const _SectionLabel(title: 'معلومات الحساب'),
                      const SizedBox(height: 8),
                      _buildAccountInfoCard(),

                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'سجل الحساب'),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withOpacity(0.12),
                            child: const Icon(
                              Icons.history_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          title: const Text('سجل تغييرات الحساب'),
                          subtitle: const Text(
                            'عرض كل التعديلات والحركات المرتبطة بالحساب',
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AccountHistoryPage(),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'تعديل الاسم'),
                      const SizedBox(height: 8),
                      _buildNameEditCard(),

                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'تغيير كلمة المرور'),
                      const SizedBox(height: 8),
                      _buildPasswordCard(),

                      const SizedBox(height: 18),
                      const _SectionLabel(title: 'إدارة الحساب'),
                      const SizedBox(height: 8),
                      _buildAccountStatusCard(),
                      const SizedBox(height: 10),
                      _buildAccountActionsCard(),

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
                  hintText: 'مثال: Majd Masri',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'مسموح فقط بالحروف العربية أو الإنجليزية والمسافات. اسم المستخدم ثابت ولا يمكن تعديله.',
                  style: TextStyle(
                    color: AppColors.textLight,
                    height: 1.45,
                  ),
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
    final request = _deletionRequestData;

    Color bgColor = AppColors.background;
    Color textColor = AppColors.textDark;
    IconData icon = Icons.info_outline_rounded;
    String title = 'حالة الحساب';
    String message = '';

    if (data == null) {
      return const SizedBox.shrink();
    }

    final isActive = data.isActive;

    if (!isActive) {
      bgColor = AppColors.danger.withOpacity(0.08);
      textColor = AppColors.danger;
      icon = Icons.person_off_outlined;
      title = 'الحساب غير نشط';
      message =
          'هذا الحساب غير مفعل حاليًا. إذا كان التعطيل مؤقتًا فيمكن للإدارة إعادة تفعيله.';
    } else if (request?.isPending == true) {
      bgColor = Colors.amber.withOpacity(0.10);
      textColor = Colors.amber.shade800;
      icon = Icons.hourglass_top_rounded;
      title = 'طلب حذف قيد المراجعة';
      message =
          'تم إرسال طلب حذف دائم للحساب وهو الآن بانتظار مراجعة الإدارة.';
    } else if (request?.isApproved == true) {
      bgColor = AppColors.danger.withOpacity(0.08);
      textColor = AppColors.danger;
      icon = Icons.delete_forever_outlined;
      title = 'تم قبول طلب الحذف';
      message =
          'تمت الموافقة على طلب حذف الحساب من الإدارة، والحساب الآن بانتظار المعالجة النهائية.';
    } else if (request?.isRejected == true) {
      bgColor = Colors.orange.withOpacity(0.10);
      textColor = Colors.orange.shade800;
      icon = Icons.cancel_outlined;
      title = 'تم رفض طلب الحذف';
      message = request!.reviewNote.isNotEmpty
          ? 'تم رفض طلب الحذف. ملاحظة الإدارة: ${request.reviewNote}'
          : 'تم رفض طلب الحذف من الإدارة.';
    } else {
      bgColor = AppColors.success.withOpacity(0.08);
      textColor = AppColors.success;
      icon = Icons.verified_user_outlined;
      title = 'الحساب نشط';
      message = 'الحساب يعمل بشكل طبيعي ولا توجد طلبات حذف حالية.';
    }

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (request?.requestedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'تاريخ الطلب: ${_formatDate(request!.requestedAt!)}',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (request?.processedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'تاريخ المعالجة: ${_formatDate(request!.processedAt!)}',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountActionsCard() {
    final isAdmin = _userData?.role == 'admin';
    final hasPendingDeletion = _deletionRequestData?.isPending == true;
    final hasApprovedDeletion = _deletionRequestData?.isApproved == true;
    final isInactive = _userData?.isActive == false;

    final disableDeactivate = isAdmin || _isDeactivating || isInactive;
    final disableDeletionRequest = isAdmin ||
        _isRequestingDeletion ||
        hasPendingDeletion ||
        hasApprovedDeletion;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAdmin
                    ? Colors.orange.withOpacity(0.10)
                    : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                isAdmin
                    ? 'حساب الأدمن لا يمكن تعطيله أو طلب حذفه ذاتيًا من داخل التطبيق.'
                    : 'يمكنك تعطيل الحساب مؤقتًا أو إرسال طلب حذف دائم للإدارة. الحذف الدائم لا يتم مباشرة من داخل التطبيق.',
                style: TextStyle(
                  color: isAdmin ? Colors.orange.shade800 : AppColors.danger,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: disableDeactivate ? null : _deactivateAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                icon: _isDeactivating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_off_outlined),
                label: Text(
                  isInactive
                      ? 'الحساب معطل حاليًا'
                      : _isDeactivating
                          ? 'جاري تعطيل الحساب...'
                          : 'تعطيل الحساب مؤقتًا',
                ),
              ),
            ),
            if (!isAdmin) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      disableDeletionRequest ? null : _requestPermanentDeletion,
                  icon: _isRequestingDeletion
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                          ),
                        )
                      : const Icon(Icons.delete_forever_outlined),
                  label: Text(
                    hasPendingDeletion
                        ? 'يوجد طلب حذف قيد المراجعة'
                        : hasApprovedDeletion
                            ? 'تم قبول طلب الحذف'
                            : _isRequestingDeletion
                                ? 'جاري إرسال الطلب...'
                                : 'طلب حذف دائم',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(
                      color: AppColors.danger,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ],
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
    final firstLetter = trimmedName.isNotEmpty ? trimmedName.substring(0, 1) : '؟';

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
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: userData.isActive
                          ? AppColors.success.withOpacity(0.10)
                          : AppColors.danger.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      userData.isActive ? 'الحساب نشط' : 'الحساب غير نشط',
                      style: TextStyle(
                        color: userData.isActive
                            ? AppColors.success
                            : AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
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