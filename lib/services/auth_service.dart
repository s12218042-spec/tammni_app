import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginResult {
  final User user;
  final Map<String, dynamic> userData;
  final bool mustChangePassword;
  final bool isFirstLogin;

  LoginResult({
    required this.user,
    required this.userData,
    required this.mustChangePassword,
    required this.isFirstLogin,
  });
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-username',
        message: 'اسم المستخدم مطلوب',
      );
    }

    if (cleanPassword.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-password',
        message: 'كلمة المرور مطلوبة',
      );
    }

    try {
      print('LOGIN STEP 1: reading login_usernames/$cleanUsername');

      final lookupDoc = await _firestore
          .collection('login_usernames')
          .doc(cleanUsername)
          .get();

      print('LOGIN STEP 2: lookupDoc.exists = ${lookupDoc.exists}');

      if (!lookupDoc.exists) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'اسم المستخدم غير موجود',
        );
      }

      final lookupData = lookupDoc.data() ?? {};
      final email = (lookupData['email'] ?? '').toString().trim().toLowerCase();
      final lookupUid = (lookupData['uid'] ?? '').toString().trim();
      final isActive = (lookupData['isActive'] ?? true) == true;

      print('LOGIN STEP 3: email = $email');
      print('LOGIN STEP 4: lookupUid = $lookupUid');
      print('LOGIN STEP 5: lookup isActive = $isActive');

      if (email.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-email',
          message: 'البريد الإلكتروني المرتبط بالحساب غير موجود',
        );
      }

      if (!isActive) {
        throw FirebaseAuthException(
          code: 'user-disabled',
          message: 'هذا الحساب غير نشط حاليًا',
        );
      }

      print('LOGIN STEP 6: signInWithEmailAndPassword');

      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: cleanPassword,
      );

      final authUser = result.user;
      print('LOGIN STEP 7: auth uid = ${authUser?.uid}');

      if (authUser == null) {
        throw FirebaseAuthException(
          code: 'auth-user-null',
          message: 'تعذر إكمال تسجيل الدخول',
        );
      }

      final authUid = authUser.uid;

      if (lookupUid.isNotEmpty && lookupUid != authUid) {
        throw FirebaseAuthException(
          code: 'uid-mismatch',
          message: 'حدث تعارض في بيانات تسجيل الدخول',
        );
      }

      print('LOGIN STEP 8: reading users/$authUid');

      final userDoc = await _firestore.collection('users').doc(authUid).get();

      print('LOGIN STEP 9: userDoc.exists = ${userDoc.exists}');

      if (!userDoc.exists) {
        throw FirebaseAuthException(
          code: 'user-doc-not-found',
          message: 'بيانات المستخدم غير موجودة في النظام',
        );
      }

      final userData = userDoc.data() ?? {};
      final storedUsername =
          (userData['username'] ?? '').toString().trim().toLowerCase();
      final userIsActive = (userData['isActive'] ?? true) == true;

      final mustChangePassword = userData['mustChangePassword'] == true;
      final isFirstLogin = userData['isFirstLogin'] == true;

      print('LOGIN STEP 10: storedUsername = $storedUsername');
      print('LOGIN STEP 11: userIsActive = $userIsActive');
      print('LOGIN STEP 12: mustChangePassword = $mustChangePassword');
      print('LOGIN STEP 13: isFirstLogin = $isFirstLogin');

      if (storedUsername.isNotEmpty && storedUsername != cleanUsername) {
        throw FirebaseAuthException(
          code: 'username-mismatch',
          message: 'حدث تعارض في اسم المستخدم',
        );
      }

      if (!userIsActive) {
        throw FirebaseAuthException(
          code: 'user-disabled',
          message: 'هذا الحساب غير نشط حاليًا',
        );
      }

      print('LOGIN STEP 14: updating lastLoginAt');

      await _firestore.collection('users').doc(authUid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      print('LOGIN STEP 15: success');

      return LoginResult(
        user: authUser,
        userData: userData,
        mustChangePassword: mustChangePassword,
        isFirstLogin: isFirstLogin,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e, st) {
      print('LOGIN UNKNOWN ERROR: $e');
      print(st);
      throw FirebaseAuthException(
        code: 'login-failed',
        message: 'حدث خطأ أثناء تسجيل الدخول: $e',
      );
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}