class EmailVerificationService {
  Future<void> sendVerificationCode({
    required String email,
    required String username,
  }) async {
    throw UnimplementedError(
      'Email verification is temporarily disabled until Firebase Functions is enabled on Blaze plan.',
    );
  }

  Future<bool> verifyCode({
    required String email,
    required String code,
  }) async {
    return false;
  }
}