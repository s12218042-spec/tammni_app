import 'package:firebase_auth/firebase_auth.dart';

class EmailVerificationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> createUnapprovedParentAccount({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    await user?.sendEmailVerification();
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    await user.reload();
    final refreshedUser = _auth.currentUser;
    return refreshedUser?.emailVerified ?? false;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}