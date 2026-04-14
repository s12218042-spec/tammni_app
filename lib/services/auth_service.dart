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

  Future<UserCredential> _signInWithPossibleEmails({
    required String username,
    required String primaryEmail,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanPrimaryEmail = primaryEmail.trim().toLowerCase();

    String? pendingEmail;

    try {
      final lookupDoc =
          await _firestore.collection('login_usernames').doc(cleanUsername).get();

      final lookupData = lookupDoc.data() ?? <String, dynamic>{};
      pendingEmail =
          (lookupData['pendingEmail'] ?? '').toString().trim().toLowerCase();
    } catch (_) {
      pendingEmail = null;
    }

    final emailsToTry = <String>[];

    if (cleanPrimaryEmail.isNotEmpty) {
      emailsToTry.add(cleanPrimaryEmail);
    }

    if (pendingEmail != null &&
        pendingEmail.isNotEmpty &&
        pendingEmail != cleanPrimaryEmail) {
      emailsToTry.add(pendingEmail);
    }

    FirebaseAuthException? lastAuthError;

    for (final email in emailsToTry) {
      try {
        print('LOGIN AUTH TRY: email = $email');

        return await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        print('LOGIN AUTH FAILED for $email: ${e.code}');

        lastAuthError = e;

        final canTryNext =
            e.code == 'wrong-password' ||
            e.code == 'invalid-credential' ||
            e.code == 'user-not-found' ||
            e.code == 'invalid-email';

        if (!canTryNext) {
          rethrow;
        }
      }
    }

    throw lastAuthError ??
        FirebaseAuthException(
          code: 'login-failed',
          message: 'تعذر تسجيل الدخول',
        );
  }

  Future<void> _syncPendingEmailIfNeeded({
  required User authUser,
  required String username,
  required Map<String, dynamic> userData,
  required Map<String, dynamic> lookupData,
}) async {
  final cleanUsername = username.trim().toLowerCase();

  final userPendingEmail =
      (userData['pendingEmail'] ?? '').toString().trim().toLowerCase();

  final lookupPendingEmail =
      (lookupData['pendingEmail'] ?? '').toString().trim().toLowerCase();

  final authEmail = (authUser.email ?? '').trim().toLowerCase();

  print('EMAIL SYNC: authEmail = $authEmail');
  print('EMAIL SYNC: userPendingEmail = $userPendingEmail');
  print('EMAIL SYNC: lookupPendingEmail = $lookupPendingEmail');

  if (authEmail.isEmpty) {
    print('EMAIL SYNC: auth email is empty');
    return;
  }

  final shouldSync =
      (userPendingEmail.isNotEmpty && authEmail == userPendingEmail) ||
      (lookupPendingEmail.isNotEmpty && authEmail == lookupPendingEmail);

  if (!shouldSync) {
    print('EMAIL SYNC: no sync needed');
    return;
  }

  try {
    final userRef = _firestore.collection('users').doc(authUser.uid);
    final loginRef = _firestore.collection('login_usernames').doc(cleanUsername);

    print('EMAIL SYNC: preparing batch');

    final batch = _firestore.batch();

    batch.set(userRef, {
      'email': authEmail,
      'pendingEmail': FieldValue.delete(),
      'emailChangeRequestedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('EMAIL SYNC: user doc added to batch');

    if (cleanUsername.isNotEmpty) {
      batch.set(loginRef, {
        'email': authEmail,
        'pendingEmail': FieldValue.delete(),
        'emailChangeRequestedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    print('EMAIL SYNC: login_usernames doc added to batch');
    print('EMAIL SYNC: committing batch...');

    await batch.commit();

    print('EMAIL SYNC: batch committed');

    await _firestore.collection('account_activity_logs').add({
      'targetUid': authUser.uid,
      'action': 'email_changed',
      'title': 'تم تغيير البريد الإلكتروني',
      'message': 'تم اعتماد البريد الإلكتروني الجديد بنجاح: $authEmail',
      'status': 'success',
      'actorUid': authUser.uid,
      'actorName': (userData['displayName'] ??
              userData['name'] ??
              userData['username'] ??
              '')
          .toString(),
      'actorRole': (userData['role'] ?? '').toString(),
      'createdAt': FieldValue.serverTimestamp(),
      'newEmail': authEmail,
    });

    print('EMAIL SYNC: success');
  } catch (e, st) {
    print('EMAIL SYNC ERROR: $e');
    print(st);
    rethrow;
  }
}

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

      final lookupData = lookupDoc.data() ?? <String, dynamic>{};
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

      print('LOGIN STEP 6: sign in with possible emails');

      final result = await _signInWithPossibleEmails(
        username: cleanUsername,
        primaryEmail: email,
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

      var userData = userDoc.data() ?? <String, dynamic>{};
      final storedUsername =
          (userData['username'] ?? '').toString().trim().toLowerCase();
      final userIsActive = (userData['isActive'] ?? true) == true;

      print('LOGIN STEP 10: storedUsername = $storedUsername');
      print('LOGIN STEP 11: userIsActive = $userIsActive');

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

      print('LOGIN STEP 12: syncing pending email if needed');

      try {
  await _syncPendingEmailIfNeeded(
    authUser: authUser,
    username: cleanUsername,
    userData: userData,
    lookupData: lookupData,
  );
} catch (e, st) {
  print('EMAIL SYNC FAILED BUT LOGIN WILL CONTINUE: $e');
  print(st);
}

      final refreshedUserDoc =
          await _firestore.collection('users').doc(authUid).get();
      userData = refreshedUserDoc.data() ?? <String, dynamic>{};

      final mustChangePassword = userData['mustChangePassword'] == true;
      final isFirstLogin = userData['isFirstLogin'] == true;

      print('LOGIN STEP 13: mustChangePassword = $mustChangePassword');
      print('LOGIN STEP 14: isFirstLogin = $isFirstLogin');

      print('LOGIN STEP 15: updating lastLoginAt');

      await _firestore.collection('users').doc(authUid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      print('LOGIN STEP 16: success');

      return LoginResult(
        user: authUser,
        userData: userData,
        mustChangePassword: mustChangePassword,
        isFirstLogin: isFirstLogin,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'كلمة المرور غير صحيحة',
        );
      }

      if (e.code == 'user-not-found') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'اسم المستخدم أو البريد المرتبط بالحساب غير موجود',
        );
      }

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