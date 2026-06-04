import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'temporary_child_view_page.dart';

class TemporaryAccessLoginPage extends StatefulWidget {
  const TemporaryAccessLoginPage({super.key});

  @override
  State<TemporaryAccessLoginPage> createState() =>
      _TemporaryAccessLoginPageState();
}

class _TemporaryAccessLoginPageState extends State<TemporaryAccessLoginPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final TextEditingController codeCtrl = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    codeCtrl.dispose();
    super.dispose();
  }

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _cleanUsername(dynamic value) {
    return _cleanText(value).toLowerCase();
  }

  String _normalizeCode(String value) {
    return value.trim().toUpperCase();
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _isExpired(dynamic value) {
    final date = _dateFromDynamic(value);
    if (date == null) return false;
    return DateTime.now().isAfter(date);
  }

  bool _isBlockedStatus(String status) {
    final cleanStatus = status.trim().toLowerCase();

    return cleanStatus == 'cancelled' ||
        cleanStatus == 'disabled' ||
        cleanStatus == 'expired' ||
        cleanStatus == 'archived' ||
        cleanStatus == 'rejected_after_trial' ||
        cleanStatus == 'withdrawn' ||
        cleanStatus == 'inactive';
  }

  bool _isAllowedChildType(Map<String, dynamic> childData) {
    final childType = _cleanText(childData['childType']).toLowerCase();
    final enrollmentType =
        _cleanText(childData['enrollmentType']).toLowerCase();
    final childStatus = _cleanText(childData['childStatus']).toLowerCase();
    final isTemporaryChild = childData['isTemporaryChild'] == true;
    final isTrialChild = childData['isTrialChild'] == true;

    if (isTemporaryChild || isTrialChild) return true;

    return childType == 'temporary' ||
        childType == 'trial' ||
        enrollmentType == 'temporary' ||
        enrollmentType == 'trial' ||
        childStatus == 'temporary' ||
        childStatus == 'trial';
  }

  Future<User> _ensureAnonymousSession() async {
    final currentUser = _auth.currentUser;

    if (currentUser != null && currentUser.isAnonymous) {
      return currentUser;
    }

    if (currentUser != null && !currentUser.isAnonymous) {
      await _auth.signOut();
    }

    final credential = await _auth.signInAnonymously();
    final user = credential.user;

    if (user == null) {
      throw Exception('تعذر إنشاء جلسة مؤقتة');
    }

    return user;
  }

  String _safeDocId(String value) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }

    return clean.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  Future<String?> _getFcmToken() async {
    if (kIsWeb) {
      debugPrint('TEMP FCM skipped on Web');
      return null;
    }

    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('TEMP FCM permission request failed: $e');
    }

    try {
      final token = await _messaging.getToken();
      final cleanToken = token?.trim();

      if (cleanToken == null || cleanToken.isEmpty) {
        debugPrint('TEMP FCM token is empty');
        return null;
      }

      return cleanToken;
    } catch (e) {
      debugPrint('TEMP FCM getToken failed: $e');
      return null;
    }
  }

  Future<void> _saveTemporaryDeviceToken({
    required String accessCodeId,
    required String code,
    required String childId,
    required Map<String, dynamic> accessData,
    required Map<String, dynamic> childData,
  }) async {
    try {
      final authUser = await _ensureAnonymousSession();
      final token = await _getFcmToken();

      if (token == null || token.isEmpty) {
        debugPrint('TEMP FCM token is empty, login will continue');
        return;
      }

      final childName = _cleanText(
        childData['childName'] ?? childData['name'] ?? accessData['childName'],
      );

      final parentName = _cleanText(
        childData['parentName'] ?? accessData['parentName'],
      );

      final parentPhone = _cleanText(
        childData['parentPhone'] ?? accessData['parentPhone'],
      );

      final parentUid = _cleanText(
        childData['parentUid'] ?? accessData['parentUid'],
      );

      final parentUsername = _cleanUsername(
        childData['parentUsername'] ?? accessData['parentUsername'],
      );

      final groupId = _cleanText(
        childData['groupId'] ?? accessData['groupId'],
      );

      final groupName = _cleanText(
        childData['groupName'] ?? childData['group'] ?? accessData['groupName'],
      );

      final childType = _cleanText(
        childData['childType'] ?? accessData['childType'],
      );

      final enrollmentType = _cleanText(
        childData['enrollmentType'] ?? accessData['enrollmentType'],
      );

      final childStatus = _cleanText(
        childData['childStatus'] ?? accessData['childStatus'],
      );

      final isTemporaryChild =
          childData['isTemporaryChild'] == true ||
          accessData['isTemporaryChild'] == true;

      final isTrialChild =
          childData['isTrialChild'] == true ||
          accessData['isTrialChild'] == true;

      final accessEndAt = accessData['accessEndAt'] ??
          accessData['temporaryAccessEndAt'] ??
          accessData['temporaryEndAt'] ??
          accessData['temporaryEndDate'] ??
          accessData['trialEndAt'] ??
          childData['temporaryAccessEndAt'] ??
          childData['temporaryEndAt'] ??
          childData['temporaryEndDate'] ??
          childData['trialEndAt'];

      final deviceDocId = _safeDocId(
        '${authUser.uid}_${accessCodeId.isNotEmpty ? accessCodeId : childId}',
      );

      final deviceRef =
          _firestore.collection('temporary_parent_devices').doc(deviceDocId);

      final oldDeviceDoc = await deviceRef.get();
      final alreadyExists = oldDeviceDoc.exists;

      final deviceData = <String, dynamic>{
        'id': deviceDocId,
        'authUid': authUser.uid,
        'isAnonymousAuth': authUser.isAnonymous,
        'fcmToken': token,
        'platform': kIsWeb ? 'web' : 'mobile',
        'accessCodeId': accessCodeId,
        'code': code,
        'childId': childId,
        'childName': childName,
        'childType': childType,
        'enrollmentType': enrollmentType,
        'childStatus': childStatus,
        'isTemporaryChild': isTemporaryChild,
        'isTrialChild': isTrialChild,
        'parentUid': parentUid,
        'parentUsername': parentUsername,
        'parentName': parentName,
        'parentPhone': parentPhone,
        'groupId': groupId,
        'groupName': groupName,
        'isActive': true,
        'accountStatus': 'active',
        'accessEndAt': accessEndAt,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!alreadyExists) {
        deviceData['createdAt'] = FieldValue.serverTimestamp();
      }

      await deviceRef.set(deviceData, SetOptions(merge: true));

      if (accessCodeId.isNotEmpty) {
        await _firestore
            .collection('temporary_access_codes')
            .doc(accessCodeId)
            .set({
          'lastAnonymousAuthUid': authUser.uid,
          'lastFcmToken': token,
          'lastDeviceDocId': deviceDocId,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      debugPrint(
        'TEMP FCM token saved successfully childId=$childId deviceDocId=$deviceDocId',
      );
    } catch (e, st) {
      debugPrint('TEMP FCM save failed but login will continue: $e');
      debugPrint('$st');
    }
  }

  Future<Map<String, dynamic>?> _findAccessByCode(String code) async {
    final normalized = _normalizeCode(code);

    final accessSnapshot = await _firestore
        .collection('temporary_access_codes')
        .where('code', isEqualTo: normalized)
        .limit(1)
        .get();

    if (accessSnapshot.docs.isNotEmpty) {
      final doc = accessSnapshot.docs.first;

      return {
        'accessCodeId': doc.id,
        'accessData': doc.data(),
      };
    }

    final childSnapshot = await _firestore
        .collection('children')
        .where('temporaryAccessCode', isEqualTo: normalized)
        .limit(1)
        .get();

    if (childSnapshot.docs.isNotEmpty) {
      final childDoc = childSnapshot.docs.first;
      final childData = childDoc.data();

      if (!_isAllowedChildType(childData)) {
        return null;
      }

      return {
        'accessCodeId': '',
        'accessData': {
          'code': normalized,
          'childId': childDoc.id,
          'childName': childData['childName'] ?? childData['name'],
          'parentName': childData['parentName'],
          'parentPhone': childData['parentPhone'],
          'parentUid': childData['parentUid'],
          'parentUsername': childData['parentUsername'],
          'groupId': childData['groupId'],
          'groupName': childData['groupName'] ?? childData['group'],
          'childType': childData['childType'],
          'enrollmentType': childData['enrollmentType'],
          'childStatus': childData['childStatus'],
          'isTemporaryChild': childData['isTemporaryChild'],
          'isTrialChild': childData['isTrialChild'],
          'accessStartAt': childData['temporaryAccessStartAt'] ??
              childData['temporaryStartAt'] ??
              childData['temporaryStartDate'] ??
              childData['trialStartAt'],
          'accessEndAt': childData['temporaryAccessEndAt'] ??
              childData['temporaryEndAt'] ??
              childData['temporaryEndDate'] ??
              childData['trialEndAt'],
          'status': childData['temporaryAccessStatus'] ??
              childData['childStatus'] ??
              'active',
        },
      };
    }

    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadChildDoc(
    Map<String, dynamic> accessData,
  ) async {
    final childId = _cleanText(accessData['childId']);

    if (childId.isNotEmpty) {
      final doc = await _firestore.collection('children').doc(childId).get();
      if (doc.exists) return doc;
    }

    final code = _cleanText(accessData['code']);
    if (code.isEmpty) return null;

    final snapshot = await _firestore
        .collection('children')
        .where('temporaryAccessCode', isEqualTo: code)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first;
  }

  Future<void> _login() async {
    final code = _normalizeCode(codeCtrl.text);

    if (code.isEmpty || isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      await _ensureAnonymousSession();

      final accessResult = await _findAccessByCode(code);

      if (accessResult == null) {
        _showMessage('كود الدخول غير صحيح');
        return;
      }

      final accessCodeId = _cleanText(accessResult['accessCodeId']);
      final accessData =
          Map<String, dynamic>.from(accessResult['accessData'] as Map);

      final status = _cleanText(accessData['status']).toLowerCase();
      final isActive = accessData['isActive'] != false;

      if (!isActive || _isBlockedStatus(status)) {
        _showMessage('كود الدخول غير فعّال');
        return;
      }

      if (_isExpired(
        accessData['accessEndAt'] ??
            accessData['temporaryAccessEndAt'] ??
            accessData['temporaryEndAt'] ??
            accessData['temporaryEndDate'] ??
            accessData['trialEndAt'] ??
            accessData['expiresAt'],
      )) {
        _showMessage('انتهت صلاحية كود الدخول');
        return;
      }

      final childDoc = await _loadChildDoc(accessData);

      if (childDoc == null || !childDoc.exists) {
        _showMessage('بيانات الطفل غير موجودة');
        return;
      }

      final childData = childDoc.data() ?? <String, dynamic>{};

      final childStatus = _cleanText(childData['childStatus']).toLowerCase();
      final childIsActive = childData['isActive'] != false;

      if (!childIsActive || _isBlockedStatus(childStatus)) {
        _showMessage('حساب الطفل غير فعّال');
        return;
      }

      if (!_isAllowedChildType(childData)) {
        _showMessage('هذا الكود مخصص للأطفال المؤقتين أو أطفال التجربة فقط');
        return;
      }

      if (_isExpired(
        childData['temporaryAccessEndAt'] ??
            childData['temporaryEndAt'] ??
            childData['temporaryEndDate'] ??
            childData['trialEndAt'],
      )) {
        _showMessage('انتهت صلاحية الدخول لهذا الطفل');
        return;
      }

      await _saveTemporaryDeviceToken(
        accessCodeId: accessCodeId,
        code: code,
        childId: childDoc.id,
        accessData: accessData,
        childData: childData,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TemporaryChildViewPage(
            accessCodeId: accessCodeId,
            accessData: accessData,
            childId: childDoc.id,
            childData: childData,
          ),
        ),
      );
    } on FirebaseAuthException catch (e, st) {
      debugPrint('TEMP ACCESS LOGIN AUTH ERROR: ${e.code}');
      debugPrint('${e.message}');
      debugPrint('$st');

      if (e.code == 'admin-restricted-operation') {
        _showMessage('الدخول المؤقت غير مفعّل حاليًا من إعدادات Firebase');
      } else {
        _showMessage('تعذر الدخول: ${e.code}');
      }
    } on FirebaseException catch (e, st) {
      debugPrint('TEMP ACCESS LOGIN FIREBASE ERROR: ${e.code}');
      debugPrint('${e.message}');
      debugPrint('$st');

      _showMessage('تعذر الدخول: ${e.code}');
    } catch (e, st) {
      debugPrint('TEMP ACCESS LOGIN ERROR: $e');
      debugPrint('$st');
      _showMessage('تعذر الدخول، حاولي مرة أخرى');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildLoginCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.primary.withOpacity(0.10),
              child: const Icon(
                Icons.key_rounded,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'الدخول المؤقت',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: codeCtrl,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'كود الدخول',
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _login,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(isLoading ? 'جاري الدخول...' : 'دخول'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الدخول المؤقت',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 35),
          _buildLoginCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}