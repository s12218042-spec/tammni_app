import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/child_section_utils.dart';
import '../widgets/app_page_scaffold.dart';

class AdminRegistrationRequestsPage extends StatefulWidget {
  const AdminRegistrationRequestsPage({super.key});

  @override
  State<AdminRegistrationRequestsPage> createState() =>
      _AdminRegistrationRequestsPageState();
}

class _AdminRegistrationRequestsPageState
    extends State<AdminRegistrationRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Set<String> selectedStatuses = {'pending'};
  String searchText = '';
  bool isProcessing = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'تمت الموافقة';
      case 'rejected':
        return 'مرفوض';
      case 'pending':
      default:
        return 'قيد المراجعة';
    }
  }

  String _activationMethodLabel(String value) {
    switch (value) {
      case 'temporary_password':
        return 'كلمة مرور مؤقتة';
      case 'email_reset':
        return 'رابط تعيين كلمة المرور عبر البريد';
      case 'manual_activation':
        return 'تفعيل يدوي';
      default:
        return '-';
    }
  }

  void _toggleStatusFilter(String value) {
    setState(() {
      if (selectedStatuses.contains(value)) {
        selectedStatuses.remove(value);
      } else {
        selectedStatuses.add(value);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      selectedStatuses
        ..clear()
        ..add('pending');
      searchText = '';
    });
  }

  DateTime? _parseRequestBirthDate(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  Future<Map<String, String>> _getCurrentAdminInfo() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return {
        'uid': '',
        'name': 'admin',
      };
    }

    try {
      final doc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      final data = doc.data() ?? {};
      final displayName = (data['name'] ??
              data['displayName'] ??
              data['fullName'] ??
              data['username'] ??
              'admin')
          .toString();

      return {
        'uid': currentUser.uid,
        'name': displayName,
      };
    } catch (_) {
      return {
        'uid': currentUser.uid,
        'name': 'admin',
      };
    }
  }

  Future<List<Map<String, dynamic>>> _loadRequests() async {
    final snapshot = await _firestore
        .collection('registration_requests')
        .orderBy('createdAt', descending: true)
        .get();

    final docs = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();

    List<Map<String, dynamic>> items = docs.where((item) {
      final requestType = (item['requestType'] ?? '').toString().trim();
      return requestType == 'parent_registration' ||
          requestType == 'parent' ||
          requestType.isEmpty;
    }).toList();

    if (selectedStatuses.isNotEmpty) {
      items = items.where((item) {
        final status = (item['status'] ?? 'pending').toString().trim();
        return selectedStatuses.contains(status);
      }).toList();
    }

    if (searchText.trim().isNotEmpty) {
      final q = searchText.trim().toLowerCase();

      items = items.where((item) {
        final parentInfo =
            (item['parentInfo'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final childrenInfo =
            (item['childrenInfo'] as List<dynamic>?) ?? <dynamic>[];

        final fullName =
            (parentInfo['fullName'] ?? parentInfo['name'] ?? '').toString();
        final username = (parentInfo['username'] ?? '').toString();
        final email = (parentInfo['email'] ?? '').toString();

        final childNames = childrenInfo
            .map(
              (e) => (e is Map ? (e['fullName'] ?? e['name'] ?? '') : '')
                  .toString(),
            )
            .join(' ');

        final combined =
            '$fullName $username $email $childNames'.toLowerCase();

        return combined.contains(q);
      }).toList();
    }

    return items;
  }

  Future<bool> _usernameExists(String username) async {
    final clean = username.trim().toLowerCase();

    final lookupDoc =
        await _firestore.collection('login_usernames').doc(clean).get();
    if (lookupDoc.exists) return true;

    final snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: clean)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<bool> _emailExists(String email) async {
    final clean = email.trim().toLowerCase();

    final loginLookup = await _firestore
        .collection('login_usernames')
        .where('email', isEqualTo: clean)
        .limit(1)
        .get();

    if (loginLookup.docs.isNotEmpty) return true;

    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: clean)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<void> _updateRequestStatus({
    required String requestId,
    required String newStatus,
    String reviewNote = '',
    Map<String, dynamic>? extraData,
  }) async {
    final adminInfo = await _getCurrentAdminInfo();

    await _firestore.collection('registration_requests').doc(requestId).update({
      'status': newStatus,
      'reviewNote': reviewNote.trim(),
      'reviewedByUid': adminInfo['uid'],
      'reviewedByName': adminInfo['name'],
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      ...?extraData,
    });
  }

  Future<void> _showApprovalDoneDialog({
    required String parentName,
    required String email,
    required String username,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('تم اعتماد الطلب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تم اعتماد طلب وليّ الأمر:\n$parentName',
                textAlign: TextAlign.right,
                style: const TextStyle(height: 1.6),
              ),
              const SizedBox(height: 14),
              _dialogInfoRow('البريد الإلكتروني', email),
              const SizedBox(height: 8),
              _dialogInfoRow('اسم المستخدم', username),
              const SizedBox(height: 8),
              _dialogInfoRow(
                'طريقة التفعيل',
                'تم إرسال رابط تعيين كلمة المرور إلى البريد الإلكتروني',
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withOpacity(0.22)),
                ),
                child: const Text(
                  'سيقوم وليّ الأمر بفتح الرابط من بريده الإلكتروني وتعيين كلمة المرور بنفسه، ثم تسجيل الدخول بالتطبيق.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تم'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(Map<String, dynamic> item) async {
    if (isProcessing) return;

    final requestId = item['id'].toString();
    final parentInfo =
        (item['parentInfo'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final childrenInfo =
        (item['childrenInfo'] as List<dynamic>?) ?? <dynamic>[];
    final currentStatus = (item['status'] ?? 'pending').toString();

    if (currentStatus == 'approved') {
      _showSnack('هذا الطلب تمت الموافقة عليه مسبقًا');
      return;
    }

    final parentName =
        (parentInfo['fullName'] ?? parentInfo['name'] ?? '').toString().trim();
    final rawUsername =
        (parentInfo['username'] ?? '').toString().trim().toLowerCase();
    final email = (parentInfo['email'] ?? '').toString().trim().toLowerCase();
    final authUid = (item['authUid'] ?? '').toString().trim();
    final emailVerified = (item['emailVerified'] ?? false) == true;
    final authPreCreated = (item['authPreCreated'] ?? false) == true;

    if (parentName.isEmpty ||
        rawUsername.isEmpty ||
        email.isEmpty ||
        authUid.isEmpty) {
      _showSnack('الطلب ناقص: الاسم أو اسم المستخدم أو البريد أو authUid');
      return;
    }

    if (!emailVerified) {
      _showSnack('لا يمكن الموافقة على الطلب قبل التحقق من البريد الإلكتروني');
      return;
    }

    if (!authPreCreated) {
      _showSnack('هذا الطلب لا يحتوي على حساب Auth مبدئي');
      return;
    }

    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('الموافقة على الطلب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'سيتم اعتماد الطلب وربط بيانات وليّ الأمر والأطفال داخل النظام، ثم إرسال رابط تعيين كلمة المرور إلى البريد الإلكتروني المعتمد.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                maxLines: 3,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'ملاحظة إدارية (اختياري)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('موافقة'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final usernameExists = await _usernameExists(rawUsername);
      if (usernameExists) {
        _showSnack('اسم المستخدم موجود مسبقًا داخل users أو login_usernames');
        return;
      }

      final emailExists = await _emailExists(email);
      if (emailExists) {
        _showSnack('البريد الإلكتروني موجود مسبقًا داخل users أو login_usernames');
        return;
      }

      for (final rawChild in childrenInfo) {
        final child = Map<String, dynamic>.from(rawChild as Map);
        final childBirthDate = _parseRequestBirthDate(child['birthDate']);
        final sectionResult =
            ChildSectionUtils.resolveSectionAndGroup(childBirthDate);
        final resolvedSection = sectionResult.section;

       if (resolvedSection != 'Nursery') {
  _showSnack('يوجد طفل عمره خارج نطاق الحضانة في النظام الحالي');
  return;
}
      }

      final adminInfo = await _getCurrentAdminInfo();
      final batch = _firestore.batch();

      final parentDocRef = _firestore.collection('users').doc(authUid);
      final loginLookupRef =
          _firestore.collection('login_usernames').doc(rawUsername);

      batch.set(parentDocRef, {
        'uid': authUid,
        'name': parentName,
        'displayName': parentName,
        'fullName': parentName,
        'username': rawUsername,
        'email': email,
        'role': 'parent',
        'isActive': true,
        'isProfileCompleted': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdByUid': adminInfo['uid'],
        'createdByName': adminInfo['name'],
        'createdFromRequestId': requestId,
        'phone': parentInfo['phone'] ?? parentInfo['mobile'] ?? '',
        'alternatePhone': parentInfo['alternatePhone'] ?? '',
        'city': parentInfo['city'] ?? '',
        'address': parentInfo['address'] ?? '',
        'gender': parentInfo['gender'] ?? '',
        'birthDate': parentInfo['birthDate'],
        'identityNumber': parentInfo['identityNumber'] ?? '',
        'relationship': parentInfo['relationship'] ?? '',
        'maritalStatus': parentInfo['maritalStatus'] ?? '',
        'jobTitle': parentInfo['jobTitle'] ?? parentInfo['profession'] ?? '',
        'workplace': parentInfo['workplace'] ?? '',
        'workPhone': parentInfo['workPhone'] ?? '',
        'bestContactTime': parentInfo['bestContactTime'] ?? '',
        'emergencyContactName': parentInfo['emergencyContactName'] ?? '',
        'emergencyContactRelation':
            parentInfo['emergencyContactRelation'] ?? '',
        'emergencyContactPhone': parentInfo['emergencyContactPhone'] ?? '',
        'notes': parentInfo['notes'] ?? '',
        'accountSource': 'registration_request',
        'authAccountCreated': true,
        'authPreCreated': true,
        'emailVerified': true,
        'accountStatus': 'active',
        'passwordStored': false,
        'temporaryPasswordSetByAdmin': false,
        'activationMethod': 'email_reset',
        'mustChangePassword': false,
        'isFirstLogin': false,
        'passwordChangedAt': null,
      });

      batch.set(loginLookupRef, {
        'username': rawUsername,
        'email': email,
        'uid': authUid,
        'role': 'parent',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdFromRequestId': requestId,
      });

      for (final rawChild in childrenInfo) {
        final child = Map<String, dynamic>.from(rawChild as Map);

        final childBirthDate = _parseRequestBirthDate(child['birthDate']);

       

        final childDocRef = _firestore.collection('children').doc();

        batch.set(childDocRef, {
          'name': (child['fullName'] ?? child['name'] ?? '').toString().trim(),
          'fullName':
              (child['fullName'] ?? child['name'] ?? '').toString().trim(),
          'identityNumber': (child['identityNumber'] ?? '').toString().trim(),
          'gender': (child['gender'] ?? '').toString().trim(),
          'birthDate': childBirthDate == null
              ? null
              : Timestamp.fromDate(childBirthDate),
          'section': 'Nursery',
          'status': 'active',
          'isActive': true,
          'hasChronicDiseases': (child['hasChronicDiseases'] ?? false) == true,
          'chronicDiseases': (child['chronicDiseases'] ?? '').toString(),
          'hasAllergies': (child['hasAllergies'] ?? false) == true,
          'allergies': (child['allergies'] ?? '').toString(),
          'takesMedications': (child['takesMedications'] ?? false) == true,
          'medications': (child['medications'] ?? '').toString(),
          'hasDietaryRestrictions':
              (child['hasDietaryRestrictions'] ?? false) == true,
          'dietaryRestrictions':
              (child['dietaryRestrictions'] ?? '').toString(),
          'hasSpecialNeeds': (child['hasSpecialNeeds'] ?? false) == true,
          'specialNeeds': (child['specialNeeds'] ?? '').toString(),
          'healthNotes': (child['healthNotes'] ?? '').toString(),
          'bloodType': (child['bloodType'] ?? '').toString(),
          'dietInstructions': (child['dietInstructions'] ?? '').toString(),
          'specialInstructions':
              (child['specialInstructions'] ?? '').toString(),
          'authorizedPickupContacts': child['authorizedPickupContacts'] ?? [],
          'parentUid': authUid,
          'parentUsername': rawUsername,
          'parentName': parentName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdByUid': adminInfo['uid'],
          'createdByName': adminInfo['name'],
          'createdFromRequestId': requestId,
          'history': [],
        });
      }

      final requestRef =
          _firestore.collection('registration_requests').doc(requestId);

      batch.update(requestRef, {
        'status': 'approved',
        'reviewNote': noteController.text.trim(),
        'reviewedByUid': adminInfo['uid'],
        'reviewedByName': adminInfo['name'],
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'processedToUserDoc': true,
        'processedChildrenCount': childrenInfo.length,
        'linkedParentUid': authUid,
        'linkedParentUsername': rawUsername,
        'linkedParentName': parentName,
        'authAccountCreated': true,
        'passwordStored': false,
        'approvalMode': 'auth_precreated_and_firestore',
        'activationMethod': 'email_reset',
        'temporaryPasswordGenerated': false,
        'mustChangePassword': false,
        'isFirstLogin': false,
      });

      final notificationRef = _firestore.collection('notifications').doc();
      batch.set(notificationRef, {
        'uid': authUid,
        'targetUid': authUid,
        'title': 'تمت الموافقة على طلب التسجيل',
        'body':
            'تمت الموافقة على طلب إنشاء حسابك. تم إرسال رابط تعيين كلمة المرور إلى بريدك الإلكتروني. بعد تعيين كلمة المرور يمكنك تسجيل الدخول باستخدام اسم المستخدم الخاص بك.',
        'message':
            'تمت الموافقة على طلب إنشاء حسابك. تم إرسال رابط تعيين كلمة المرور إلى بريدك الإلكتروني. بعد تعيين كلمة المرور يمكنك تسجيل الدخول باستخدام اسم المستخدم الخاص بك.',
        'type': 'registration_request',
        'status': 'approved',
        'requestId': requestId,
        'activationMethod': 'email_reset',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': adminInfo['uid'],
        'createdByName': adminInfo['name'],
      });

      await batch.commit();

      final actionCodeSettings = ActionCodeSettings(
  url: 'https://daycare-app-220c0.web.app/auth_action.html',
  handleCodeInApp: false,
);

await _auth.sendPasswordResetEmail(
  email: email,
  actionCodeSettings: actionCodeSettings,
);

      if (!mounted) return;

      _showSnack('تمت الموافقة على الطلب وإرسال رابط تعيين كلمة المرور');
      setState(() {});

      await _showApprovalDoneDialog(
        parentName: parentName,
        email: email,
        username: rawUsername,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'حدث خطأ أثناء إرسال رابط تعيين كلمة المرور';

      if (e.code == 'user-not-found') {
        message = 'حساب Firebase Auth المرتبط بهذا البريد غير موجود';
      } else if (e.code == 'invalid-email') {
        message = 'البريد الإلكتروني غير صالح';
      } else if (e.message != null && e.message!.trim().isNotEmpty) {
        message = e.message!;
      }

      _showSnack(message);
    } catch (e) {
      _showSnack('حدث خطأ أثناء تنفيذ الموافقة: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> item) async {
    if (isProcessing) return;

    final requestId = item['id'].toString();
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('رفض الطلب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'يمكنك كتابة سبب الرفض أو ملاحظة إدارية.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                maxLines: 3,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'سبب الرفض / ملاحظة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('رفض'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() {
      isProcessing = true;
    });

    try {
      await _updateRequestStatus(
        requestId: requestId,
        newStatus: 'rejected',
        reviewNote: noteController.text,
        extraData: {
          'authAccountCreated': false,
          'approvalMode': '',
          'activationMethod': '',
          'temporaryPasswordGenerated': false,
          'mustChangePassword': false,
          'isFirstLogin': false,
        },
      );

      if (!mounted) return;
      _showSnack('تم رفض الطلب وتحديث حالته');
      setState(() {});
    } catch (e) {
      _showSnack('حدث خطأ أثناء رفض الطلب: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  void _showRequestDetails(Map<String, dynamic> item) {
    final parentInfo =
        (item['parentInfo'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final childrenInfo =
        (item['childrenInfo'] as List<dynamic>?) ?? <dynamic>[];
    final status = (item['status'] ?? 'pending').toString();
    final reviewNote = (item['reviewNote'] ?? '').toString();
    final reviewedByName = (item['reviewedByName'] ?? '').toString();
    final linkedParentUsername =
        (item['linkedParentUsername'] ?? '').toString().trim();
    final activationMethod = (item['activationMethod'] ?? '').toString().trim();
    final authAccountCreated = (item['authAccountCreated'] ?? false) == true;
    final emailVerified = (item['emailVerified'] ?? false) == true;
    final authUid = (item['authUid'] ?? '').toString().trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              right: 20,
              left: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'تفاصيل الطلب',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _InfoBox(
                    title: 'بيانات ولي الأمر',
                    children: [
                      _InfoRow(
                        'الاسم',
                        '${parentInfo['fullName'] ?? parentInfo['name'] ?? '-'}',
                      ),
                      _InfoRow(
                        'اسم المستخدم',
                        '${parentInfo['username'] ?? '-'}',
                      ),
                      _InfoRow(
                        'البريد الإلكتروني',
                        '${parentInfo['email'] ?? '-'}',
                      ),
                      _InfoRow(
                        'رقم الجوال',
                        '${parentInfo['phone'] ?? parentInfo['mobile'] ?? '-'}',
                      ),
                      _InfoRow(
                        'الجوال البديل',
                        '${parentInfo['alternatePhone'] ?? '-'}',
                      ),
                      _InfoRow(
                        'رقم الهوية',
                        '${parentInfo['identityNumber'] ?? '-'}',
                      ),
                      _InfoRow('المدينة', '${parentInfo['city'] ?? '-'}'),
                      _InfoRow('العنوان', '${parentInfo['address'] ?? '-'}'),
                      _InfoRow(
                        'صلة القرابة',
                        '${parentInfo['relationship'] ?? '-'}',
                      ),
                      _InfoRow(
                        'الحالة الاجتماعية',
                        '${parentInfo['maritalStatus'] ?? '-'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoBox(
                    title: 'الأطفال',
                    children: childrenInfo.isEmpty
                        ? [const _InfoRow('لا يوجد أطفال', '-')]
                        : childrenInfo.asMap().entries.expand((entry) {
                            final rawChild = entry.value;
                            final child = rawChild is Map<String, dynamic>
                                ? rawChild
                                : Map<String, dynamic>.from(rawChild as Map);

                            final birthDate =
                                _parseRequestBirthDate(child['birthDate']);
                            final sectionResult =
                                ChildSectionUtils.resolveSectionAndGroup(
                              birthDate,
                            );
                            final resolvedSection = sectionResult.section;

                            final sectionText =
    resolvedSection == 'Nursery' ? 'حضانة' : 'خارج نطاق الحضانة';
                            
                            final ageWarning = resolvedSection != 'Nursery'
    ? ' • العمر خارج نطاق الحضانة'
    : '';

                            final hasChronicDiseases =
                                (child['hasChronicDiseases'] ?? false) == true;
                            final hasAllergies =
                                (child['hasAllergies'] ?? false) == true;
                            final takesMedications =
                                (child['takesMedications'] ?? false) == true;
                            final hasDietaryRestrictions =
                                (child['hasDietaryRestrictions'] ?? false) ==
                                    true;
                            final hasSpecialNeeds =
                                (child['hasSpecialNeeds'] ?? false) == true;

                            return [
                              _InfoRow(
                                'الطفل ${entry.key + 1}',
                               '${child['fullName'] ?? child['name'] ?? '-'}'
' • $sectionText$ageWarning',
                              ),
                              _InfoRow(
                                'هوية الطفل',
                                '${child['identityNumber'] ?? '-'}',
                              ),
                              _InfoRow(
                                'الأمراض المزمنة',
                                hasChronicDiseases
                                    ? '${child['chronicDiseases'] ?? '-'}'
                                    : 'لا',
                              ),
                              _InfoRow(
                                'الحساسية',
                                hasAllergies
                                    ? '${child['allergies'] ?? '-'}'
                                    : 'لا',
                              ),
                              _InfoRow(
                                'الأدوية',
                                takesMedications
                                    ? '${child['medications'] ?? '-'}'
                                    : 'لا',
                              ),
                              _InfoRow(
                                'القيود الغذائية',
                                hasDietaryRestrictions
                                    ? '${child['dietaryRestrictions'] ?? '-'}'
                                    : 'لا',
                              ),
                              _InfoRow(
                                'الاحتياجات الخاصة',
                                hasSpecialNeeds
                                    ? '${child['specialNeeds'] ?? '-'}'
                                    : 'لا',
                              ),
                              _InfoRow(
                                'ملاحظات صحية',
                                '${child['healthNotes'] ?? '-'}',
                              ),
                              const _InfoRow('—', '—'),
                            ];
                          }).toList(),
                  ),
                  const SizedBox(height: 14),
                  _InfoBox(
                    title: 'الحالة الحالية',
                    children: [
                      _InfoRow('الحالة', _statusLabel(status)),
                      _InfoRow(
                        'تم إنشاء حساب Auth',
                        authAccountCreated ? 'نعم' : 'لا',
                      ),
                      _InfoRow(
                        'تم التحقق من البريد',
                        emailVerified ? 'نعم' : 'لا',
                      ),
                      _InfoRow(
                        'Auth UID',
                        authUid.isEmpty ? '-' : authUid,
                      ),
                      if (status == 'pending') ...[
                        const _InfoRow(
                          'متابعة الطلب',
                          'الطلب بانتظار مراجعة الإدارة',
                        ),
                      ],
                      if (status == 'approved') ...[
                        _InfoRow(
                          'تمت المراجعة بواسطة',
                          reviewedByName.isEmpty ? '-' : reviewedByName,
                        ),
                        _InfoRow(
                          'اسم المستخدم المرتبط',
                          linkedParentUsername.isEmpty
                              ? '-'
                              : linkedParentUsername,
                        ),
                        _InfoRow(
                          'طريقة التفعيل',
                          _activationMethodLabel(activationMethod),
                        ),
                        if (reviewNote.trim().isNotEmpty)
                          _InfoRow('ملاحظة المراجعة', reviewNote),
                      ],
                      if (status == 'rejected') ...[
                        _InfoRow(
                          'تمت المراجعة بواسطة',
                          reviewedByName.isEmpty ? '-' : reviewedByName,
                        ),
                        _InfoRow(
                          'سبب الرفض / الملاحظة',
                          reviewNote.trim().isEmpty ? '-' : reviewNote,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (status == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isProcessing
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _approveRequest(item);
                                  },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('موافقة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isProcessing
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _rejectRequest(item);
                                  },
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('رفض'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'بدون تاريخ';
    final d = ts.toDate();
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
  }) {
    final isSelected = selectedStatuses.contains(value);

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => _toggleStatusFilter(value),
      selectedColor: _statusColor(value),
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? _statusColor(value)
            : AppColors.primary.withOpacity(0.14),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> item) {
    final parentInfo =
        (item['parentInfo'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final childrenInfo =
        (item['childrenInfo'] as List<dynamic>?) ?? <dynamic>[];
    final status = (item['status'] ?? 'pending').toString();
    final createdAt = item['createdAt'] as Timestamp?;
    final activationMethod = (item['activationMethod'] ?? '').toString().trim();
    final emailVerified = (item['emailVerified'] ?? false) == true;

    final parentName =
        (parentInfo['fullName'] ?? parentInfo['name'] ?? '-').toString();
    final username = (parentInfo['username'] ?? '-').toString();
    final phone =
        (parentInfo['phone'] ?? parentInfo['mobile'] ?? '-').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showRequestDetails(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _statusColor(status).withOpacity(0.12),
                    child: Icon(
                      Icons.assignment_ind_outlined,
                      color: _statusColor(status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parentName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@$username',
                          style: const TextStyle(
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 18, color: AppColors.textLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phone,
                      style: const TextStyle(color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.child_care_outlined,
                      size: 18, color: AppColors.textLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'عدد الأطفال: ${childrenInfo.length}',
                      style: const TextStyle(color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 18, color: AppColors.textLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تاريخ الطلب: ${_formatDate(createdAt)}',
                      style: const TextStyle(color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    emailVerified
                        ? Icons.verified_rounded
                        : Icons.mark_email_unread_outlined,
                    size: 18,
                    color: emailVerified ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      emailVerified
                          ? 'البريد الإلكتروني متحقق'
                          : 'البريد الإلكتروني غير متحقق',
                      style: TextStyle(
                        color: emailVerified ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (status == 'approved' && activationMethod.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.vpn_key_outlined,
                        size: 18, color: AppColors.textLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'طريقة التفعيل: ${_activationMethodLabel(activationMethod)}',
                        style: const TextStyle(color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showRequestDetails(item),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('عرض التفاصيل'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomFilters =
        searchText.trim().isNotEmpty ||
        selectedStatuses.length != 1 ||
        !selectedStatuses.contains('pending');

    return AppPageScaffold(
      title: 'طلبات تسجيل أولياء الأمور',
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText:
                          'ابحثي بالاسم أو اسم المستخدم أو البريد أو اسم الطفل',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchText.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                setState(() {
                                  searchText = '';
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchText = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'قيد المراجعة',
                          value: 'pending',
                        ),
                        _buildFilterChip(
                          label: 'تمت الموافقة',
                          value: 'approved',
                        ),
                        _buildFilterChip(
                          label: 'مرفوض',
                          value: 'rejected',
                        ),
                      ],
                    ),
                  ),
                  if (hasCustomFilters) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('إعادة تعيين الفلاتر'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل الطلبات',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'لا توجد طلبات مطابقة حاليًا',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textLight,
                          ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _buildRequestCard(items[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoBox({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (label == '—' && value == '—') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Divider(),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.textDark,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}