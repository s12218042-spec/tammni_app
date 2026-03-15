import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> register({
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  Future<User?> login({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();

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

    final data = snapshot.docs.first.data();
    final email = (data['email'] ?? '').toString().trim();

    if (email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'لا يوجد بريد إلكتروني مرتبط بهذا المستخدم',
      );
    }

    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return result.user;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
