import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum EmailRefreshStatus {
  success,
  notCompletedYet,
  noCurrentUser,
}

class AccountSettingsData {
  final String uid;
  final String name;
  final String username;
  final String email;
  final String role;
  final bool isActive;
  final String pendingEmail;
  final DateTime? emailChangeRequestedAt;

  const AccountSettingsData({
    required this.uid,
    required this.name,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.pendingEmail,
    required this.emailChangeRequestedAt,
  });

  factory AccountSettingsData.fromMap({
    required String uid,
    required Map<String, dynamic> map,
  }) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return AccountSettingsData(
      uid: uid,
      name: (map['name'] ?? map['displayName'] ?? '').toString().trim(),
      username: (map['username'] ?? '').toString().trim(),
      email: (map['email'] ?? '').toString().trim(),
      role: _normalizeRole((map['role'] ?? '').toString()),
      isActive: (map['isActive'] ?? true) == true,
      pendingEmail: (map['pendingEmail'] ?? '').toString().trim(),
      emailChangeRequestedAt: parseDate(map['emailChangeRequestedAt']),
    );
  }

  static String _normalizeRole(String rawRole) {
    final role = rawRole.trim().toLowerCase();

    if (role == 'nursery' || role == 'nursery staff') {
      return 'nursery_staff';
    }

    return role;
  }

  String get roleLabel {
    switch (role) {
      case 'parent':
        return 'وليّ أمر';
      case 'nursery_staff':
        return 'موظفة الحضانة';
      case 'teacher':
        return 'المعلمة';
      case 'admin':
        return 'الأدمن';
      default:
        return 'مستخدم';
    }
  }

  bool get hasPendingEmailChange => pendingEmail.isNotEmpty;
}

class AccountDeletionRequestData {
  final String status;
  final String reviewNote;
  final DateTime? requestedAt;
  final DateTime? processedAt;

  const AccountDeletionRequestData({
    required this.status,
    required this.reviewNote,
    required this.requestedAt,
    required this.processedAt,
  });

  factory AccountDeletionRequestData.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return AccountDeletionRequestData(
      status: (map['status'] ?? '').toString().trim().toLowerCase(),
      reviewNote: (map['reviewNote'] ?? '').toString().trim(),
      requestedAt: parseDate(map['requestedAt']),
      processedAt: parseDate(map['processedAt']),
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
}

class AccountSettingsService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserDoc() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'لا يوجد مستخدم مسجّل دخول حاليًا',
      );
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      throw FirebaseAuthException(
        code: 'user-doc-not-found',
        message: 'تعذر العثور على بيانات الحساب',
      );
    }

    return doc;
  }

  Future<DocumentReference<Map<String, dynamic>>> _getUserDocRef() async {
    final doc = await _getUserDoc();
    return doc.reference;
  }

  Future<AccountSettingsData> getCurrentUserData() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'لا يوجد مستخدم مسجّل دخول حاليًا',
      );
    }

    final doc = await _getUserDoc();

    return AccountSettingsData.fromMap(
      uid: user.uid,
      map: doc.data() ?? <String, dynamic>{},
    );
  }

  String? validateFullName(String? value) {
    final name = (value ?? '').trim();

    if (name.isEmpty) return 'الاسم مطلوب';
    if (name.length < 2) return 'الاسم قصير جدًا';

    final normalizedSpaces = name.replaceAll(RegExp(r'\s+'), ' ');
    final regex = RegExp(r'^[A-Za-z\u0600-\u06FF\s]+$');
    if (!regex.hasMatch(normalizedSpaces)) {
      return 'الاسم يجب أن يحتوي على حروف فقط بدون أرقام أو رموز';
    }

    return null;
  }

  String? validateEmail(String? value) {
    final email = (value ?? '').trim().toLowerCase();

    if (email.isEmpty) return 'البريد الإلكتروني الجديد مطلوب';

    final regex = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    if (!regex.hasMatch(email)) {
      return 'البريد الإلكتروني غير صالح';
    }

    return null;
  }

  String formatFullName(String rawName) {
    String cleaned = rawName.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (cleaned.isEmpty) return cleaned;

    final words = cleaned.split(' ');

    final formattedWords = words.map((word) {
      if (word.isEmpty) return word;

      final isEnglishWord = RegExp(r'^[A-Za-z]+$').hasMatch(word);

      if (isEnglishWord) {
        final lower = word.toLowerCase();
        return lower[0].toUpperCase() + lower.substring(1);
      }

      return word;
    }).toList();

    return formattedWords.join(' ');
  }

  Future<void> logAccountAction({
    required String targetUid,
    required String action,
    required String title,
    required String message,
    String status = 'info',
    String? actorUid,
    String? actorName,
    String? actorRole,
    Map<String, dynamic>? extraData,
  }) async {
    await _firestore.collection('account_activity_logs').add({
      'targetUid': targetUid,
      'action': action,
      'title': title,
      'message': message,
      'status': status,
      'actorUid': actorUid ?? currentUser?.uid ?? '',
      'actorName': actorName ?? (currentUser?.displayName ?? ''),
      'actorRole': actorRole ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      ...?extraData,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> currentUserHistoryStream() {
    final user = _auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('account_activity_logs')
        .where('targetUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateCurrentUserName(String newName) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'لا يوجد مستخدم مسجّل دخول حاليًا',
      );
    }

    final validationError = validateFullName(newName);
    if (validationError != null) {
      throw FirebaseAuthException(
        code: 'invalid-name',
        message: validationError,
      );
    }

    final formattedName = formatFullName(newName);
    final docRef = await _getUserDocRef();

    await docRef.set({
      'name': formattedName,
      'displayName': formattedName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await user.updateDisplayName(formattedName);
    await user.reload();

    await logAccountAction(
      targetUid: user.uid,
      action: 'name_updated',
      title: 'تم تعديل الاسم',
      message: 'تم تحديث الاسم الكامل إلى: $formattedName',
      status: 'success',
    );
  }

  bool _hasPasswordProvider(User user) {
    return user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'لا يوجد مستخدم مسجّل دخول حاليًا',
      );
    }

    if (!_hasPasswordProvider(user)) {
      throw FirebaseAuthException(
        code: 'password-provider-not-enabled',
        message:
            'هذا الحساب لا يستخدم كلمة مرور مباشرة. يمكنك استخدام استعادة كلمة المرور أو طريقة تسجيل الدخول المرتبطة بالحساب.',
      );
    }

    final email = (user.email ?? '').trim();
    if (email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'لا يوجد بريد إلكتروني مرتبط بهذا الحساب',
      );
    }

    if (currentPassword.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'empty-current-password',
        message: 'كلمة المرور الحالية مطلوبة',
      );
    }

    if (newPassword.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'empty-new-password',
        message: 'كلمة المرور الجديدة مطلوبة',
      );
    }

    if (newPassword.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل',
      );
    }

    if (newPassword != confirmPassword) {
      throw FirebaseAuthException(
        code: 'password-mismatch',
        message: 'تأكيد كلمة المرور غير مطابق',
      );
    }

    if (currentPassword == newPassword) {
      throw FirebaseAuthException(
        code: 'same-password',
        message: 'كلمة المرور الجديدة يجب أن تكون مختلفة عن الحالية',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    try {
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      final docRef = await _getUserDocRef();

      await docRef.set({
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await logAccountAction(
        targetUid: user.uid,
        action: 'password_changed',
        title: 'تم تغيير كلمة المرور',
        message: 'تم تغيير كلمة المرور بنجاح',
        status: 'success',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'كلمة المرور الحالية غير صحيحة',
        );
      }

      if (e.code == 'weak-password') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'كلمة المرور الجديدة ضعيفة جدًا',
        );
      }

      if (e.code == 'requires-recent-login') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'يرجى تسجيل الدخول مرة أخرى ثم إعادة المحاولة',
        );
      }

      throw FirebaseAuthException(
        code: e.code,
        message: e.message ?? 'حدث خطأ أثناء تغيير كلمة المرور',
      );
    }
  }

  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'لا يوجد مستخدم مسجّل دخول حاليًا',
      );
    }

    if (!_hasPasswordProvider(user)) {
      throw FirebaseAuthException(
        code: 'password-provider-not-enabled',
        message:
            'هذا الحساب لا يستخدم كلمة مرور مباشرة حاليًا. تغيير البريد لهذا النوع من الحسابات سنعالجه لاحقًا ضمن ربط Google.',
      );
    }

    final currentEmail = (user.email ?? '').trim().toLowerCase();
    final cleanNewEmail = newEmail.trim().toLowerCase();
    final cleanPassword = currentPassword.trim();

    final emailError = validateEmail(cleanNewEmail);
    if (emailError != null) {
      throw FirebaseAuthException(
        code: 'invalid-new-email',
        message: emailError,
      );
    }

    if (cleanPassword.isEmpty) {
      throw FirebaseAuthException(
        code: 'empty-current-password',
        message: 'كلمة المرور الحالية مطلوبة لتأكيد العملية',
      );
    }

    if (currentEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'لا يوجد بريد إلكتروني حالي مرتبط بالحساب',
      );
    }

    if (cleanNewEmail == currentEmail) {
      throw FirebaseAuthException(
        code: 'same-email',
        message: 'البريد الجديد مطابق للبريد الحالي',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: currentEmail,
      password: cleanPassword,
    );

    try {
      await user.reauthenticateWithCredential(credential);

      final actionCodeSettings = ActionCodeSettings(
        url: 'https://daycare-app-220c0.web.app/auth_action.html',
        handleCodeInApp: false,
      );

      await user.verifyBeforeUpdateEmail(
        cleanNewEmail,
        actionCodeSettings,
      );

      final userDocRef = await _getUserDocRef();
      final userDoc = await _getUserDoc();
      final userData = userDoc.data() ?? <String, dynamic>{};
      final username =
          (userData['username'] ?? '').toString().trim().toLowerCase();

      final batch = _firestore.batch();

      batch.set(userDocRef, {
        'pendingEmail': cleanNewEmail,
        'emailChangeRequestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (username.isNotEmpty) {
        final loginRef = _firestore.collection('login_usernames').doc(username);
        batch.set(loginRef, {
          'pendingEmail': cleanNewEmail,
          'emailChangeRequestedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      await logAccountAction(
        targetUid: user.uid,
        action: 'email_change_requested',
        title: 'تم طلب تغيير البريد الإلكتروني',
        message:
            'تم إرسال رابط تحقق إلى البريد الجديد: $cleanNewEmail. لن يتم اعتماد البريد قبل تأكيده.',
        status: 'warning',
        extraData: {
          'oldEmail': currentEmail,
          'pendingEmail': cleanNewEmail,
        },
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'كلمة المرور الحالية غير صحيحة',
        );
      }

      if (e.code == 'requires-recent-login') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'يرجى تسجيل الدخول مرة أخرى ثم إعادة المحاولة',
        );
      }

      if (e.code == 'email-already-in-use') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'هذا البريد مستخدم بحساب آخر',
        );
      }

      if (e.code == 'invalid-email') {
        throw FirebaseAuthException(
          code: e.code,
          message: 'البريد الإلكتروني الجديد غير صالح',
        );
      }

      throw FirebaseAuthException(
        code: e.code,
        message: e.message ?? 'تعذر إرسال طلب تغيير البريد الإلكتروني',
      );
    }
  }

  Future<EmailRefreshStatus> refreshEmailAfterVerificationIfNeeded() async {
    final user = _auth.currentUser;

    if (user == null) {
      return EmailRefreshStatus.noCurrentUser;
    }

    final userDoc = await _getUserDoc();
    final data = userDoc.data() ?? <String, dynamic>{};

    final pendingEmail =
        (data['pendingEmail'] ?? '').toString().trim().toLowerCase();
    final username =
        (data['username'] ?? '').toString().trim().toLowerCase();

    if (pendingEmail.isEmpty) {
      return EmailRefreshStatus.notCompletedYet;
    }

    await user.reload();
    final refreshedUser = _auth.currentUser;
    final actualEmail = (refreshedUser?.email ?? '').trim().toLowerCase();

    if (actualEmail.isEmpty || actualEmail != pendingEmail) {
      return EmailRefreshStatus.notCompletedYet;
    }

    final batch = _firestore.batch();

    batch.set(userDoc.reference, {
      'email': actualEmail,
      'pendingEmail': FieldValue.delete(),
      'emailChangeRequestedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (username.isNotEmpty) {
      final loginUsernameRef =
          _firestore.collection('login_usernames').doc(username);

      batch.set(loginUsernameRef, {
        'email': actualEmail,
        'pendingEmail': FieldValue.delete(),
        'emailChangeRequestedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();

    await logAccountAction(
      targetUid: user.uid,
      action: 'email_changed',
      title: 'تم تغيير البريد الإلكتروني',
      message: 'تم اعتماد البريد الإلكتروني الجديد بنجاح: $actualEmail',
      status: 'success',
      extraData: {
        'newEmail': actualEmail,
      },
    );

    return EmailRefreshStatus.success;
  }

  Future<void> clearPendingEmailChange() async {
    final userDoc = await _getUserDoc();
    final data = userDoc.data() ?? <String, dynamic>{};
    final username = (data['username'] ?? '').toString().trim().toLowerCase();

    final batch = _firestore.batch();

    batch.set(userDoc.reference, {
      'pendingEmail': FieldValue.delete(),
      'emailChangeRequestedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (username.isNotEmpty) {
      final loginRef = _firestore.collection('login_usernames').doc(username);
      batch.set(loginRef, {
        'pendingEmail': FieldValue.delete(),
        'emailChangeRequestedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> deactivateCurrentAccount({
    required String reason,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'لا يوجد مستخدم مسجّل دخول حاليًا',
      );
    }

    final doc = await _getUserDoc();
    final data = doc.data() ?? <String, dynamic>{};
    final role = ((data['role'] ?? '').toString()).trim().toLowerCase();

    if (role == 'admin') {
      throw FirebaseAuthException(
        code: 'admin-self-deactivate-not-allowed',
        message: 'لا يمكن للأدمن تعطيل حسابه بنفسه',
      );
    }

    final cleanReason = reason.trim();
    final docRef = doc.reference;

    await docRef.set({
      'isActive': false,
      'accountStatus': 'deactivated',
      'deactivatedAt': FieldValue.serverTimestamp(),
      'deactivationReason': cleanReason,
      'deactivatedBy': 'self',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await logAccountAction(
      targetUid: user.uid,
      action: 'account_deactivated',
      title: 'تم تعطيل الحساب مؤقتًا',
      message: cleanReason.isNotEmpty
          ? 'تم تعطيل الحساب مؤقتًا. السبب: $cleanReason'
          : 'تم تعطيل الحساب مؤقتًا',
      status: 'warning',
      extraData: {
        'reason': cleanReason,
        'deactivatedBy': 'self',
      },
    );

    await _auth.signOut();
  }

  Future<void> requestPermanentDeletion() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'لا يوجد مستخدم مسجّل دخول حاليًا',
      );
    }

    final doc = await _getUserDoc();
    final data = doc.data() ?? <String, dynamic>{};

    final rawRole = (data['role'] ?? '').toString().trim().toLowerCase();
    final role = rawRole == 'nursery' || rawRole == 'nursery staff'
        ? 'nursery_staff'
        : rawRole;

    if (role == 'admin') {
      throw FirebaseAuthException(
        code: 'admin-self-delete-not-allowed',
        message: 'لا يمكن للأدمن طلب حذف حسابه بنفسه',
      );
    }

    final existingRequest = await _firestore
        .collection('account_deletion_requests')
        .where('uid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw FirebaseAuthException(
        code: 'deletion-request-already-exists',
        message: 'يوجد بالفعل طلب حذف دائم قيد المراجعة',
      );
    }

    final formattedName = formatFullName(
      (data['name'] ?? data['displayName'] ?? '').toString(),
    );

    await _firestore.collection('account_deletion_requests').add({
      'uid': user.uid,
      'name': formattedName,
      'displayName': formattedName,
      'username': (data['username'] ?? '').toString().trim(),
      'email': (data['email'] ?? '').toString().trim(),
      'role': role,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
      'processedAt': null,
      'processedByUid': '',
      'processedByName': '',
      'reviewNote': '',
      'requestType': 'permanent_delete',
      'cancelledAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final docRef = doc.reference;

    await docRef.set({
      'deletionRequested': true,
      'deletionRequestType': 'permanent',
      'deletionRequestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await logAccountAction(
      targetUid: user.uid,
      action: 'deletion_requested',
      title: 'تم إرسال طلب حذف دائم',
      message: 'تم إرسال طلب حذف الحساب إلى الإدارة للمراجعة',
      status: 'warning',
    );
  }

  Future<void> cancelPendingDeletionRequest() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'لا يوجد مستخدم مسجّل دخول حاليًا',
      );
    }

    final doc = await _getUserDoc();
    final data = doc.data() ?? <String, dynamic>{};
    final rawRole = (data['role'] ?? '').toString().trim().toLowerCase();

    if (rawRole == 'admin') {
      throw FirebaseAuthException(
        code: 'admin-cancel-delete-not-allowed',
        message: 'لا يمكن للأدمن تنفيذ هذه العملية',
      );
    }

    final snapshot = await _firestore
        .collection('account_deletion_requests')
        .where('uid', isEqualTo: user.uid)
        .get();

    final pendingDocs = snapshot.docs.where((doc) {
      final map = doc.data();
      final status = (map['status'] ?? '').toString().trim().toLowerCase();
      return status == 'pending';
    }).toList();

    if (pendingDocs.isEmpty) {
      throw FirebaseAuthException(
        code: 'no-pending-deletion-request',
        message: 'لا يوجد طلب حذف قيد المراجعة',
      );
    }

    pendingDocs.sort((a, b) {
      final aTime = (a.data()['requestedAt'] as Timestamp?)?.toDate();
      final bTime = (b.data()['requestedAt'] as Timestamp?)?.toDate();

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    final requestRef = pendingDocs.first.reference;
    final userRef = doc.reference;

    final batch = _firestore.batch();

    batch.set(requestRef, {
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'reviewNote': 'تم سحب طلب الحذف من المستخدم',
    }, SetOptions(merge: true));

    batch.set(userRef, {
      'deletionRequested': false,
      'deletionRequestType': FieldValue.delete(),
      'deletionRequestedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    await logAccountAction(
      targetUid: user.uid,
      action: 'deletion_request_cancelled',
      title: 'تم سحب طلب الحذف',
      message: 'قام المستخدم بسحب طلب حذف الحساب قبل مراجعته من الإدارة',
      status: 'info',
    );
  }

  Future<AccountDeletionRequestData?> getLatestDeletionRequest() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'لا يوجد مستخدم مسجّل دخول حاليًا',
      );
    }

    final snapshot = await _firestore
        .collection('account_deletion_requests')
        .where('uid', isEqualTo: user.uid)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final docs = [...snapshot.docs];

    docs.sort((a, b) {
      final aTime = (a.data()['requestedAt'] as Timestamp?)?.toDate();
      final bTime = (b.data()['requestedAt'] as Timestamp?)?.toDate();

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return AccountDeletionRequestData.fromMap(docs.first.data());
  }
}