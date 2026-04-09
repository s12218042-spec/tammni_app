import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class EmployeeAccountCreationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<FirebaseApp> createSecondaryApp(String appName) async {
    try {
      return Firebase.app(appName);
    } catch (_) {
      return Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  Future<void> validateCommonUniqueness({
    required String username,
    required String email,
    required String nationalId,
    required String phone,
    String? excludeUid,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanEmail = email.trim().toLowerCase();
    final cleanNationalId = nationalId.trim();
    final cleanPhone = phone.trim();

    final usernameDoc = await _firestore
        .collection('login_usernames')
        .doc(cleanUsername)
        .get();

    if (usernameDoc.exists) {
      throw Exception('اسم المستخدم مستخدم مسبقًا');
    }

    final emailQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (emailQuery.docs.isNotEmpty) {
      throw Exception('البريد الإلكتروني مستخدم مسبقًا');
    }

    final nationalIdQuery = await _firestore
        .collection('users')
        .where('personalInfo.nationalId', isEqualTo: cleanNationalId)
        .limit(1)
        .get();

    if (nationalIdQuery.docs.isNotEmpty) {
      throw Exception('رقم الهوية مستخدم مسبقًا');
    }

    final phoneQuery = await _firestore
        .collection('users')
        .where('personalInfo.phone', isEqualTo: cleanPhone)
        .limit(1)
        .get();

    if (phoneQuery.docs.isNotEmpty) {
      throw Exception('رقم الجوال مستخدم مسبقًا');
    }
  }

  Future<String> getCurrentAdminName() async {
    final currentAdmin = _auth.currentUser;
    if (currentAdmin == null) {
      throw Exception('يجب أن يكون الأدمن مسجل الدخول أولًا');
    }

    final adminDoc =
        await _firestore.collection('users').doc(currentAdmin.uid).get();

    if (!adminDoc.exists) return 'الإدارة';

    return (adminDoc.data()?['name'] ??
            adminDoc.data()?['displayName'] ??
            'الإدارة')
        .toString();
  }

  Future<void> createEmployeeAccount({
    required String secondaryAppName,
    required String name,
    required String username,
    required String email,
    required String password,
    required String role,
    required Map<String, dynamic> userData,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    final currentAdmin = _auth.currentUser;
    if (currentAdmin == null) {
      throw Exception('يجب أن يكون الأدمن مسجل الدخول أولًا');
    }

    FirebaseApp? tempApp;
    FirebaseAuth? tempAuth;
    User? createdAuthUser;

    try {
      tempApp = await createSecondaryApp(secondaryAppName);
      tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPassword,
      );

      createdAuthUser = credential.user;

      if (createdAuthUser == null) {
        throw Exception('فشل إنشاء حساب Authentication');
      }

      final newUid = createdAuthUser.uid;

      final finalUserData = <String, dynamic>{
        ...userData,
        'uid': newUid,
        'username': cleanUsername,
        'email': cleanEmail,
        'role': role,
        'isActive': userData['isActive'] ?? true,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(newUid).set(finalUserData);

      await _firestore.collection('login_usernames').doc(cleanUsername).set({
        'username': cleanUsername,
        'email': cleanEmail,
        'uid': newUid,
        'role': role,
        'isActive': finalUserData['isActive'] ?? true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await tempAuth.signOut();
    } catch (e) {
      if (createdAuthUser != null) {
        try {
          await createdAuthUser.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      if (tempApp != null) {
        try {
          await tempApp.delete();
        } catch (_) {}
      }
    }
  }
}