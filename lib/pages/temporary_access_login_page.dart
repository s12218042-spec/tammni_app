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

  List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];

    return value
        .map(_cleanText)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
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
    return !date.isAfter(DateTime.now());
  }

  bool _isBlockedStatus(String status) {
    final cleanStatus = status.trim().toLowerCase();

    return cleanStatus == 'cancelled' ||
        cleanStatus == 'disabled' ||
        cleanStatus == 'expired' ||
        cleanStatus == 'archived' ||
        cleanStatus == 'rejected_after_trial' ||
        cleanStatus == 'withdrawn' ||
        cleanStatus == 'inactive' ||
        cleanStatus == 'logged_out';
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

  bool _isChildAvailable(Map<String, dynamic> childData) {
    final childStatus = _cleanText(
      childData['childStatus'] ?? childData['status'],
    ).toLowerCase();

    final accountStatus =
        _cleanText(childData['accountStatus']).toLowerCase();

    final childIsActive = childData['isActive'] != false;

    if (!childIsActive ||
        _isBlockedStatus(childStatus) ||
        _isBlockedStatus(accountStatus)) {
      return false;
    }

    if (!_isAllowedChildType(childData)) {
      return false;
    }

    return !_isExpired(
      childData['temporaryAccessEndAt'] ??
          childData['temporaryEndAt'] ??
          childData['temporaryEndDate'] ??
          childData['trialEndAt'],
    );
  }

  String _childDisplayName(Map<String, dynamic> childData) {
    final name = _cleanText(childData['childName'] ?? childData['name']);
    return name.isEmpty ? 'طفل بدون اسم' : name;
  }

  String _childTypeLabel(Map<String, dynamic> childData) {
    final childType = _cleanText(childData['childType']).toLowerCase();
    final enrollmentType =
        _cleanText(childData['enrollmentType']).toLowerCase();
    final childStatus = _cleanText(childData['childStatus']).toLowerCase();

    if (childData['isTrialChild'] == true ||
        childType == 'trial' ||
        enrollmentType == 'trial' ||
        childStatus == 'trial') {
      return 'طفل تجربة';
    }

    return 'طفل زائر';
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
      throw Exception('تعذر إنشاء جلسة الزائر');
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

  Future<String> _getFcmTokenOrEmpty() async {
    if (kIsWeb) {
      debugPrint('TEMP FCM skipped on Web');
      return '';
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
      final cleanToken = token?.trim() ?? '';

      if (cleanToken.isEmpty) {
        debugPrint('TEMP FCM token is empty');
      }

      return cleanToken;
    } catch (e) {
      debugPrint('TEMP FCM getToken failed: $e');
      return '';
    }
  }

  Future<void> _saveTemporaryDeviceSession({
    required User authUser,
    required String token,
    required String accessCodeId,
    required String code,
    required String childId,
    required Map<String, dynamic> accessData,
    required Map<String, dynamic> childData,
  }) async {
    try {
      final childName = _cleanText(
        childData['childName'] ?? childData['name'] ?? accessData['childName'],
      );

      final parentName = _cleanText(
        childData['parentName'] ??
            childData['temporaryParentName'] ??
            accessData['parentName'] ??
            accessData['temporaryParentName'],
      );

      final parentPhone = _cleanText(
        childData['parentPhone'] ??
            childData['temporaryParentPhone'] ??
            accessData['parentPhone'] ??
            accessData['temporaryParentPhone'],
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

      final accessEndAt = childData['temporaryAccessEndAt'] ??
          childData['temporaryEndAt'] ??
          childData['temporaryEndDate'] ??
          childData['trialEndAt'] ??
          accessData['accessEndAt'] ??
          accessData['temporaryAccessEndAt'] ??
          accessData['temporaryEndAt'] ??
          accessData['temporaryEndDate'] ??
          accessData['trialEndAt'];

      final resolvedAccessCodeId = accessCodeId.isNotEmpty
          ? accessCodeId
          : _cleanText(childData['temporaryAccessCodeId']);

      final deviceDocId = _safeDocId('${authUser.uid}_$childId');

      final deviceRef =
          _firestore.collection('temporary_parent_devices').doc(deviceDocId);

      final oldDeviceDoc = await deviceRef.get();
      final alreadyExists = oldDeviceDoc.exists;

      final deviceData = <String, dynamic>{
        'id': deviceDocId,
        'deviceId': deviceDocId,
        'authUid': authUser.uid,
        'isAnonymousAuth': authUser.isAnonymous,
        'fcmToken': token,
        'supportsPush': token.isNotEmpty,
        'platform': kIsWeb ? 'web' : 'mobile',
        'accessCodeId': resolvedAccessCodeId,
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
        'temporaryParentName': parentName,
        'temporaryParentPhone': parentPhone,
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

      debugPrint(
        'TEMP DEVICE SESSION SAVED childId=$childId '
        'deviceDocId=$deviceDocId supportsPush=${token.isNotEmpty}',
      );
    } catch (e, st) {
      debugPrint('TEMP DEVICE SESSION SAVE FAILED BUT LOGIN WILL CONTINUE: $e');
      debugPrint('$st');
    }
  }

  Future<void> _saveAccessLoginMetadata({
    required User authUser,
    required String token,
    required String accessCodeId,
    required List<String> deviceDocIds,
  }) async {
    if (accessCodeId.isEmpty) return;

    try {
      await _firestore.collection('temporary_access_codes').doc(accessCodeId).set({
        'lastAnonymousAuthUid': authUser.uid,
        'lastFcmToken': token,
        'lastDeviceDocIds': deviceDocIds,
        if (deviceDocIds.isNotEmpty) 'lastDeviceDocId': deviceDocIds.first,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('TEMP ACCESS METADATA UPDATE FAILED BUT LOGIN WILL CONTINUE: $e');
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
        .get();

    final allowedChildren = childSnapshot.docs.where((doc) {
      return _isAllowedChildType(doc.data());
    }).toList();

    if (allowedChildren.isEmpty) return null;

    final firstChild = allowedChildren.first;
    final childData = firstChild.data();

    return {
      'accessCodeId': _cleanText(childData['temporaryAccessCodeId']),
      'accessData': {
        'code': normalized,
        'childId': firstChild.id,
        'childIds': allowedChildren.map((doc) => doc.id).toList(),
        'childName': childData['childName'] ?? childData['name'],
        'childNames': allowedChildren
            .map((doc) => _childDisplayName(doc.data()))
            .toList(),
        'parentName':
            childData['parentName'] ?? childData['temporaryParentName'],
        'parentPhone':
            childData['parentPhone'] ?? childData['temporaryParentPhone'],
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
        'isActive': true,
      },
    };
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _loadChildDocs({
    required String accessCodeId,
    required String code,
    required Map<String, dynamic> accessData,
  }) async {
    final docsById = <String, DocumentSnapshot<Map<String, dynamic>>>{};

    final childIds = <String>{
      ..._stringList(accessData['childIds']),
      if (_cleanText(accessData['childId']).isNotEmpty)
        _cleanText(accessData['childId']),
    };

    for (final childId in childIds) {
      final doc = await _firestore.collection('children').doc(childId).get();
      if (doc.exists) docsById[doc.id] = doc;
    }

    if (docsById.isEmpty && accessCodeId.isNotEmpty) {
      final snapshot = await _firestore
          .collection('children')
          .where('temporaryAccessCodeId', isEqualTo: accessCodeId)
          .get();

      for (final doc in snapshot.docs) {
        docsById[doc.id] = doc;
      }
    }

    if (docsById.isEmpty && code.isNotEmpty) {
      final snapshot = await _firestore
          .collection('children')
          .where('temporaryAccessCode', isEqualTo: code)
          .get();

      for (final doc in snapshot.docs) {
        docsById[doc.id] = doc;
      }
    }

    return docsById.values.toList();
  }

  Map<String, dynamic> _accessDataForChild({
    required Map<String, dynamic> accessData,
    required DocumentSnapshot<Map<String, dynamic>> childDoc,
  }) {
    final childData = childDoc.data() ?? <String, dynamic>{};

    return {
      ...accessData,
      'childId': childDoc.id,
      'childName': childData['childName'] ?? childData['name'],
      'childType': childData['childType'],
      'enrollmentType': childData['enrollmentType'],
      'childStatus': childData['childStatus'],
      'isTemporaryChild': childData['isTemporaryChild'],
      'isTrialChild': childData['isTrialChild'],
      'groupId': childData['groupId'] ?? accessData['groupId'],
      'groupName': childData['groupName'] ??
          childData['group'] ??
          accessData['groupName'],
      'accessStartAt': childData['temporaryAccessStartAt'] ??
          childData['temporaryStartAt'] ??
          childData['temporaryStartDate'] ??
          childData['trialStartAt'] ??
          accessData['accessStartAt'],
      'accessEndAt': childData['temporaryAccessEndAt'] ??
          childData['temporaryEndAt'] ??
          childData['temporaryEndDate'] ??
          childData['trialEndAt'] ??
          accessData['accessEndAt'],
    };
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _chooseChild(
    List<DocumentSnapshot<Map<String, dynamic>>> childDocs,
  ) async {
    if (childDocs.isEmpty) return null;
    if (childDocs.length == 1) return childDocs.first;

    return showDialog<DocumentSnapshot<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('اختر الطفل'),
            content: SizedBox(
              width: 420,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: childDocs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final childDoc = childDocs[index];
                  final childData = childDoc.data() ?? <String, dynamic>{};

                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withOpacity(0.10),
                        child: const Icon(
                          Icons.child_care_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        _childDisplayName(childData),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(_childTypeLabel(childData)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded),
                      onTap: () => Navigator.pop(dialogContext, childDoc),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _login() async {
    final code = _normalizeCode(codeCtrl.text);

    if (code.isEmpty || isLoading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    try {
      final authUser = await _ensureAnonymousSession();
      final accessResult = await _findAccessByCode(code);

      if (accessResult == null) {
        _showMessage('كود الدخول غير صحيح');
        return;
      }

      final accessCodeId = _cleanText(accessResult['accessCodeId']);
      final accessData =
          Map<String, dynamic>.from(accessResult['accessData'] as Map);

      await _saveAccessLoginMetadata(
        authUser: authUser,
        token: '',
        accessCodeId: accessCodeId,
        deviceDocIds: const <String>[],
      );

      final accessStatus = _cleanText(
        accessData['status'] ?? accessData['accountStatus'],
      ).toLowerCase();

      final accessIsActive = accessData['isActive'] != false;

      if (!accessIsActive || _isBlockedStatus(accessStatus)) {
        _showMessage('كود الدخول غير فعّال');
        return;
      }

      final allChildDocs = await _loadChildDocs(
        accessCodeId: accessCodeId,
        code: code,
        accessData: accessData,
      );

      if (allChildDocs.isEmpty) {
        _showMessage('بيانات الأطفال غير موجودة');
        return;
      }

      final availableChildDocs = allChildDocs.where((doc) {
        return _isChildAvailable(doc.data() ?? <String, dynamic>{});
      }).toList();

      if (availableChildDocs.isEmpty) {
        _showMessage('لا يوجد طفل فعّال مرتبط بهذا الكود');
        return;
      }

      final token = await _getFcmTokenOrEmpty();
      final deviceDocIds = <String>[];

      for (final childDoc in availableChildDocs) {
        final childData = childDoc.data() ?? <String, dynamic>{};

        await _saveTemporaryDeviceSession(
          authUser: authUser,
          token: token,
          accessCodeId: accessCodeId,
          code: code,
          childId: childDoc.id,
          accessData: accessData,
          childData: childData,
        );

        deviceDocIds.add(_safeDocId('${authUser.uid}_${childDoc.id}'));
      }

      await _saveAccessLoginMetadata(
        authUser: authUser,
        token: token,
        accessCodeId: accessCodeId,
        deviceDocIds: deviceDocIds,
      );

      if (!mounted) return;

      final selectedChildDoc = await _chooseChild(availableChildDocs);

      if (!mounted || selectedChildDoc == null) return;

      final selectedChildData =
          selectedChildDoc.data() ?? <String, dynamic>{};

      final selectedAccessData = _accessDataForChild(
        accessData: accessData,
        childDoc: selectedChildDoc,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TemporaryChildViewPage(
            accessCodeId: accessCodeId,
            accessData: selectedAccessData,
            childId: selectedChildDoc.id,
            childData: selectedChildData,
          ),
        ),
      );
    } on FirebaseAuthException catch (e, st) {
      debugPrint('TEMP ACCESS LOGIN AUTH ERROR: ${e.code}');
      debugPrint('${e.message}');
      debugPrint('$st');

      if (e.code == 'admin-restricted-operation') {
        _showMessage('دخول ولي الأمر الزائر غير مفعّل حاليًا من إعدادات Firebase');
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

      _showMessage('تعذر الدخول، حاول مرة أخرى');
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
              'دخول ولي الأمر الزائر',
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
      title: 'دخول ولي الأمر الزائر',
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
