import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<User?> login({
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

    final snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: cleanUsername)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'اسم المستخدم غير موجود',
      );
    }

    final userDoc = snapshot.docs.first;
    final data = userDoc.data();

    final email = (data['email'] ?? '').toString().trim().toLowerCase();
    final role = (data['role'] ?? '').toString().trim();
    final isActive = (data['isActive'] ?? true) == true;
    final authAccountCreated = (data['authAccountCreated'] ?? true) == true;
    final accountStatus = (data['accountStatus'] ?? '').toString().trim();

    if (email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'لا يوجد بريد إلكتروني مرتبط بهذا المستخدم',
      );
    }

    if (!isActive) {
      throw FirebaseAuthException(
        code: 'user-disabled',
        message: 'هذا الحساب غير مفعّل حاليًا',
      );
    }

    // مهم جدًا مع التدفق الجديد:
    // بعض حسابات أولياء الأمور تُنشأ في Firestore فقط بدون Firebase Auth فعلي.
    if (role == 'parent' && !authAccountCreated) {
      throw FirebaseAuthException(
        code: 'auth-account-not-created',
        message: accountStatus == 'pending_auth_setup'
            ? 'تمت الموافقة على الطلب إداريًا، لكن حساب تسجيل الدخول لم يُفعّل بعد. راجعي الإدارة لإكمال تفعيل الدخول.'
            : 'هذا الحساب غير جاهز لتسجيل الدخول بعد. راجعي الإدارة.',
      );
    }

    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(userDoc.id).set({
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return result.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'كلمة المرور غير صحيحة',
        );
      }

      if (e.code == 'invalid-credential') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'بيانات تسجيل الدخول غير صحيحة',
        );
      }

      if (e.code == 'user-disabled') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'هذا الحساب موقوف',
        );
      }

      if (e.code == 'user-not-found') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'لم يتم العثور على الحساب',
        );
      }

      throw FirebaseAuthException(
        code: e.code,
        message: e.message ?? 'حدث خطأ أثناء تسجيل الدخول',
      );
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<bool> usernameExists(String username) async {
    final cleanUsername = username.trim().toLowerCase();

    if (cleanUsername.isEmpty) return false;

    final snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: cleanUsername)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<bool> emailExists(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty) return false;

    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}