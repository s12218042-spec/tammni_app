class PasswordValidationUtils {
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

  static bool _allCharactersSame(String text) {
    if (text.isEmpty) return false;
    return text.split('').every((char) => char == text[0]);
  }

  static bool _isOnlyNumbers(String text) {
    return RegExp(r'^\d+$').hasMatch(text);
  }

  static bool _isOnlyLetters(String text) {
    return RegExp(r'^[a-zA-Z]+$').hasMatch(text);
  }

  static String? validateNewPassword({
    required String? value,
    String username = '',
    String temporaryPassword = '',
  }) {
    final text = value?.trim() ?? '';
    final lowerText = text.toLowerCase();
    final lowerUsername = username.trim().toLowerCase();
    final tempPassword = temporaryPassword.trim();

    if (text.isEmpty) {
      return 'كلمة المرور الجديدة مطلوبة';
    }

    if (text.length < 6) {
      return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل';
    }

    if (tempPassword.isNotEmpty && text == tempPassword) {
      return 'يجب اختيار كلمة مرور جديدة مختلفة عن كلمة المرور المؤقتة';
    }

    if (lowerUsername.isNotEmpty && lowerText == lowerUsername) {
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

  static String? validateConfirmPassword({
    required String? confirmPassword,
    required String password,
  }) {
    final text = confirmPassword?.trim() ?? '';

    if (text.isEmpty) {
      return 'تأكيد كلمة المرور مطلوب';
    }

    if (text != password.trim()) {
      return 'كلمتا المرور غير متطابقتين';
    }

    return null;
  }
}