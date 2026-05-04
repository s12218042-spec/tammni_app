import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/child_section_utils.dart';
import '../widgets/app_page_scaffold.dart';

class AdminAddChildRequestsPage extends StatefulWidget {
  const AdminAddChildRequestsPage({super.key});

  @override
  State<AdminAddChildRequestsPage> createState() =>
      _AdminAddChildRequestsPageState();
}

class _AdminAddChildRequestsPageState extends State<AdminAddChildRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Set<String> selectedStatuses = {'pending'};
  String searchText = '';
  bool isProcessing = false;

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
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
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return 'تمت الموافقة';
      case 'rejected':
        return 'مرفوض';
      case 'pending':
      default:
        return 'قيد المراجعة';
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

  DateTime? _parseBirthDate(dynamic value) {
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
          .toString()
          .trim();

      return {
        'uid': currentUser.uid,
        'name': displayName.isEmpty ? 'admin' : displayName,
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
        .collection('add_child_requests')
        .orderBy('createdAt', descending: true)
        .get();

    List<Map<String, dynamic>> items = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
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
        final parentName = (item['parentName'] ?? '').toString();
        final parentUsername = (item['parentUsername'] ?? '').toString();
        final parentEmail = (item['parentEmail'] ?? '').toString();

        final childInfo =
            (item['childInfo'] as Map<String, dynamic>?) ?? <String, dynamic>{};

        final childName =
            (childInfo['fullName'] ?? childInfo['name'] ?? '').toString();
        final childIdentity = (childInfo['identityNumber'] ?? '').toString();

        final combined =
            '$parentName $parentUsername $parentEmail $childName $childIdentity'
                .toLowerCase();

        return combined.contains(q);
      }).toList();
    }

    return items;
  }

  Future<void> _markRelatedAdminNotificationsAsHandled({
    required String requestId,
    required String status,
    required String adminUid,
    required String adminName,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('requestId', isEqualTo: requestId)
          .where('targetRole', isEqualTo: 'admin')
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.set(
          doc.reference,
          {
            'status': status,
            'isHandled': true,
            'handledAt': FieldValue.serverTimestamp(),
            'handledByUid': adminUid,
            'handledByName': adminName,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } catch (_) {
      // لا نوقف الموافقة/الرفض لو فشل تحديث إشعار الأدمن
    }
  }

  Future<void> _createParentNotification({
    required String parentUid,
    required String parentUsername,
    required String parentName,
    required String title,
    required String body,
    required String requestId,
    required String childName,
    required String status,
    required String adminUid,
    required String adminName,
    String reviewNote = '',
    String createdChildId = '',
  }) async {
    final cleanParentUsername = parentUsername.trim().toLowerCase();

    await _firestore.collection('notifications').add({
      'uid': parentUid,
      'targetUid': parentUid,
      'targetRole': 'parent',
      'receiverUid': parentUid,
      'receiverRole': 'parent',
      'parentUid': parentUid,
      'parentUsername': cleanParentUsername,
      'parentName': parentName.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'message': body.trim(),
      'type': 'add_child_request',
      'notificationType': 'add_child_request',
      'category': 'requests',
      'requestType': 'add_child',
      'requestId': requestId,
      'childId': createdChildId,
      'childName': childName.trim(),
      'section': 'Nursery',
      'group': '',
      'status': status,
      'reviewNote': reviewNote.trim(),
      'priority': status == 'approved' ? 'normal' : 'important',
      'importance': status == 'approved' ? 'normal' : 'important',
      'isRead': false,
      'read': false,
      'seen': false,
      'createdAt': FieldValue.serverTimestamp(),
      'time': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdByUid': adminUid,
      'createdByName': adminName,
      'createdByRole': 'admin',
      'senderUid': adminUid,
      'senderName': adminName,
      'senderRole': 'admin',
    });
  }

  Future<void> _updateRequestStatus({
    required String requestId,
    required String newStatus,
    String reviewNote = '',
    Map<String, dynamic>? extraData,
  }) async {
    final adminInfo = await _getCurrentAdminInfo();

    await _firestore.collection('add_child_requests').doc(requestId).update({
      'status': newStatus,
      'reviewNote': reviewNote.trim(),
      'reviewedByUid': adminInfo['uid'],
      'reviewedByName': adminInfo['name'],
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      ...?extraData,
    });
  }

  Future<bool> _childAlreadyExistsForParent({
    required String parentUid,
    required String childName,
    required DateTime birthDate,
  }) async {
    final snapshot = await _firestore
        .collection('children')
        .where('parentUid', isEqualTo: parentUid)
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final existingName =
          (data['fullName'] ?? data['name'] ?? '').toString().trim();
      final existingBirthDate = data['birthDate'];

      DateTime? existingDate;

      if (existingBirthDate is Timestamp) {
        existingDate = existingBirthDate.toDate();
      }

      if (existingName == childName.trim() &&
          existingDate != null &&
          existingDate.year == birthDate.year &&
          existingDate.month == birthDate.month &&
          existingDate.day == birthDate.day) {
        return true;
      }
    }

    return false;
  }

  Future<void> _approveRequest(Map<String, dynamic> item) async {
    if (isProcessing) return;

    final requestId = item['id'].toString();
    final currentStatus = (item['status'] ?? 'pending').toString();

    if (currentStatus == 'approved') {
      _showSnack('هذا الطلب تمت الموافقة عليه مسبقًا');
      return;
    }

    final parentUid = (item['parentUid'] ?? '').toString().trim();
    final parentName = (item['parentName'] ?? '').toString().trim();
    final parentUsername = (item['parentUsername'] ?? '').toString().trim();

    final childInfo =
        (item['childInfo'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final childName =
        (childInfo['fullName'] ?? childInfo['name'] ?? '').toString().trim();
    final childBirthDate = _parseBirthDate(childInfo['birthDate']);

    if (parentUid.isEmpty || parentUsername.isEmpty || childName.isEmpty) {
      _showSnack('الطلب ناقص: بيانات ولي الأمر أو الطفل غير مكتملة');
      return;
    }

    if (childBirthDate == null) {
      _showSnack('تاريخ ميلاد الطفل غير موجود أو غير صالح');
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
          title: const Text('الموافقة على طلب إضافة الطفل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'سيتم إنشاء سجل طفل جديد وربطه مباشرة بحساب ولي الأمر داخل Firestore.',
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

    if (confirmed != true) {
      noteController.dispose();
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      final sectionResult =
          ChildSectionUtils.resolveSectionAndGroup(childBirthDate);
      final resolvedSection = sectionResult.section;

      if (resolvedSection != 'Nursery') {
        _showSnack('عمر الطفل خارج نطاق الحضانة في النظام الحالي');
        return;
      }

      final alreadyExists = await _childAlreadyExistsForParent(
        parentUid: parentUid,
        childName: childName,
        birthDate: childBirthDate,
      );

      if (alreadyExists) {
        _showSnack('هذا الطفل مرتبط بالفعل بحساب ولي الأمر');
        return;
      }

      final adminInfo = await _getCurrentAdminInfo();
      final adminUid = adminInfo['uid'] ?? '';
      final adminName = adminInfo['name'] ?? 'admin';

      final childDocRef = _firestore.collection('children').doc();
      final requestRef =
          _firestore.collection('add_child_requests').doc(requestId);

      await _firestore.runTransaction((transaction) async {
        transaction.set(childDocRef, {
          'name': childName,
          'fullName': childName,
          'identityNumber':
              (childInfo['identityNumber'] ?? '').toString().trim(),
          'gender': (childInfo['gender'] ?? '').toString().trim(),
          'birthDate': Timestamp.fromDate(childBirthDate),
          'section': 'Nursery',
          'group': '',
          'status': 'active',
          'isActive': true,
          'hasChronicDiseases':
              (childInfo['hasChronicDiseases'] ?? false) == true,
          'chronicDiseases': (childInfo['chronicDiseases'] ?? '').toString(),
          'hasAllergies': (childInfo['hasAllergies'] ?? false) == true,
          'allergies': (childInfo['allergies'] ?? '').toString(),
          'takesMedications': (childInfo['takesMedications'] ?? false) == true,
          'medications': (childInfo['medications'] ?? '').toString(),
          'hasDietaryRestrictions':
              (childInfo['hasDietaryRestrictions'] ?? false) == true,
          'dietaryRestrictions':
              (childInfo['dietaryRestrictions'] ?? '').toString(),
          'hasSpecialNeeds': (childInfo['hasSpecialNeeds'] ?? false) == true,
          'specialNeeds': (childInfo['specialNeeds'] ?? '').toString(),
          'healthNotes': (childInfo['healthNotes'] ?? '').toString(),
          'bloodType': (childInfo['bloodType'] ?? '').toString(),
          'dietInstructions': (childInfo['dietInstructions'] ?? '').toString(),
          'specialInstructions':
              (childInfo['specialInstructions'] ?? '').toString(),
          'authorizedPickupContacts':
              childInfo['authorizedPickupContacts'] ?? [],
          'parentUid': parentUid,
          'parentUsername': parentUsername.trim().toLowerCase(),
          'parentName': parentName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdByUid': adminUid,
          'createdByName': adminName,
          'createdByRole': 'admin',
          'createdFromRequestId': requestId,
          'history': [],
        });

        transaction.update(requestRef, {
          'status': 'approved',
          'reviewNote': noteController.text.trim(),
          'reviewedByUid': adminUid,
          'reviewedByName': adminName,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdChildId': childDocRef.id,
          'approvalSection': 'Nursery',
          'processedToChildDoc': true,
          'linkedChildId': childDocRef.id,
        });
      });

      await _createParentNotification(
        parentUid: parentUid,
        parentUsername: parentUsername,
        parentName: parentName,
        title: 'تمت الموافقة على طلب إضافة الطفل',
        body: 'تمت إضافة الطفل $childName إلى حسابك بنجاح.',
        requestId: requestId,
        childName: childName,
        status: 'approved',
        adminUid: adminUid,
        adminName: adminName,
        reviewNote: noteController.text.trim(),
        createdChildId: childDocRef.id,
      );

      await _markRelatedAdminNotificationsAsHandled(
        requestId: requestId,
        status: 'approved',
        adminUid: adminUid,
        adminName: adminName,
      );

      if (!mounted) return;

      _showSnack('تمت الموافقة على الطلب وإضافة الطفل بنجاح');
      setState(() {});
    } catch (e) {
      _showSnack('حدث خطأ أثناء تنفيذ الموافقة: $e');
    } finally {
      noteController.dispose();

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

    final childInfo =
        (item['childInfo'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final parentUid = (item['parentUid'] ?? '').toString().trim();
    final parentName = (item['parentName'] ?? '').toString().trim();
    final parentUsername = (item['parentUsername'] ?? '').toString().trim();

    final childName =
        (childInfo['fullName'] ?? childInfo['name'] ?? '').toString().trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('رفض طلب إضافة الطفل'),
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

    if (confirmed != true) {
      noteController.dispose();
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      final adminInfo = await _getCurrentAdminInfo();
      final adminUid = adminInfo['uid'] ?? '';
      final adminName = adminInfo['name'] ?? 'admin';

      await _updateRequestStatus(
        requestId: requestId,
        newStatus: 'rejected',
        reviewNote: noteController.text,
        extraData: {
          'processedToChildDoc': false,
          'createdChildId': '',
          'linkedChildId': '',
        },
      );

      await _createParentNotification(
        parentUid: parentUid,
        parentUsername: parentUsername,
        parentName: parentName,
        title: 'تم رفض طلب إضافة الطفل',
        body: noteController.text.trim().isEmpty
            ? 'تم رفض طلب إضافة الطفل $childName.'
            : 'تم رفض طلب إضافة الطفل $childName. السبب: ${noteController.text.trim()}',
        requestId: requestId,
        childName: childName,
        status: 'rejected',
        adminUid: adminUid,
        adminName: adminName,
        reviewNote: noteController.text.trim(),
      );

      await _markRelatedAdminNotificationsAsHandled(
        requestId: requestId,
        status: 'rejected',
        adminUid: adminUid,
        adminName: adminName,
      );

      if (!mounted) return;

      _showSnack('تم رفض الطلب وتحديث حالته');
      setState(() {});
    } catch (e) {
      _showSnack('حدث خطأ أثناء رفض الطلب: $e');
    } finally {
      noteController.dispose();

      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  void _showRequestDetails(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'pending').toString();
    final reviewNote = (item['reviewNote'] ?? '').toString();
    final reviewedByName = (item['reviewedByName'] ?? '').toString();
    final createdChildId = (item['createdChildId'] ??
            item['linkedChildId'] ??
            '')
        .toString()
        .trim();

    final childInfo =
        (item['childInfo'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final birthDate = _parseBirthDate(childInfo['birthDate']);
    final sectionResult = ChildSectionUtils.resolveSectionAndGroup(birthDate);
    final resolvedSection = sectionResult.section;

    final sectionText =
        resolvedSection == 'Nursery' ? 'حضانة' : 'خارج نطاق الحضانة';

    final hasChronicDiseases =
        (childInfo['hasChronicDiseases'] ?? false) == true;
    final hasAllergies = (childInfo['hasAllergies'] ?? false) == true;
    final takesMedications = (childInfo['takesMedications'] ?? false) == true;
    final hasDietaryRestrictions =
        (childInfo['hasDietaryRestrictions'] ?? false) == true;
    final hasSpecialNeeds = (childInfo['hasSpecialNeeds'] ?? false) == true;

    final pickupContacts =
        (childInfo['authorizedPickupContacts'] as List<dynamic>?) ??
            <dynamic>[];

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
                      _InfoRow('الاسم', '${item['parentName'] ?? '-'}'),
                      _InfoRow(
                        'اسم المستخدم',
                        '${item['parentUsername'] ?? '-'}',
                      ),
                      _InfoRow(
                        'البريد الإلكتروني',
                        '${item['parentEmail'] ?? '-'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoBox(
                    title: 'بيانات الطفل',
                    children: [
                      _InfoRow(
                        'الاسم',
                        '${childInfo['fullName'] ?? childInfo['name'] ?? '-'}',
                      ),
                      _InfoRow(
                        'رقم الهوية',
                        '${childInfo['identityNumber'] ?? '-'}',
                      ),
                      _InfoRow('القسم', sectionText),
                      _InfoRow(
                        'الأمراض المزمنة',
                        hasChronicDiseases
                            ? '${childInfo['chronicDiseases'] ?? '-'}'
                            : 'لا',
                      ),
                      _InfoRow(
                        'الحساسية',
                        hasAllergies
                            ? '${childInfo['allergies'] ?? '-'}'
                            : 'لا',
                      ),
                      _InfoRow(
                        'الأدوية',
                        takesMedications
                            ? '${childInfo['medications'] ?? '-'}'
                            : 'لا',
                      ),
                      _InfoRow(
                        'القيود الغذائية',
                        hasDietaryRestrictions
                            ? '${childInfo['dietaryRestrictions'] ?? '-'}'
                            : 'لا',
                      ),
                      _InfoRow(
                        'الاحتياجات الخاصة',
                        hasSpecialNeeds
                            ? '${childInfo['specialNeeds'] ?? '-'}'
                            : 'لا',
                      ),
                      _InfoRow(
                        'ملاحظات صحية',
                        '${childInfo['healthNotes'] ?? '-'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoBox(
                    title: 'المخولون بالاستلام',
                    children: pickupContacts.isEmpty
                        ? [const _InfoRow('لا يوجد', '-')]
                        : pickupContacts.asMap().entries.expand((entry) {
                            final rawPickup = entry.value;
                            final pickup = rawPickup is Map<String, dynamic>
                                ? rawPickup
                                : Map<String, dynamic>.from(rawPickup as Map);

                            return [
                              _InfoRow(
                                'الشخص ${entry.key + 1}',
                                '${pickup['name'] ?? '-'}',
                              ),
                              _InfoRow(
                                'صلة القرابة',
                                '${pickup['relation'] ?? '-'}',
                              ),
                              _InfoRow(
                                'رقم الجوال',
                                '${pickup['phone'] ?? '-'}',
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
                      if (status == 'pending')
                        const _InfoRow(
                          'متابعة الطلب',
                          'الطلب بانتظار مراجعة الإدارة',
                        ),
                      if (status == 'approved') ...[
                        _InfoRow(
                          'تمت المراجعة بواسطة',
                          reviewedByName.isEmpty ? '-' : reviewedByName,
                        ),
                        _InfoRow(
                          'رقم الطفل المنشأ',
                          createdChildId.isEmpty ? '-' : createdChildId,
                        ),
                        _InfoRow(
                          'ملاحظة المراجعة',
                          reviewNote.trim().isEmpty ? '-' : reviewNote,
                        ),
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

  Widget _buildSectionBadge(String section) {
    final color =
        section == 'Nursery' ? const Color(0xFFEFA7C8) : Colors.redAccent;

    final text = section == 'Nursery' ? 'حضانة' : 'خارج نطاق الحضانة';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'pending').toString();
    final createdAt = item['createdAt'] as Timestamp?;

    final childInfo =
        (item['childInfo'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final childName =
        (childInfo['fullName'] ?? childInfo['name'] ?? '-').toString();
    final parentName = (item['parentName'] ?? '-').toString();
    final parentUsername = (item['parentUsername'] ?? '-').toString();

    final birthDate = _parseBirthDate(childInfo['birthDate']);
    final sectionResult = ChildSectionUtils.resolveSectionAndGroup(birthDate);
    final resolvedSection = sectionResult.section;

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
                      Icons.person_add_alt_1_outlined,
                      color: _statusColor(status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          childName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ولي الأمر: $parentName',
                          style: const TextStyle(
                            color: AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@$parentUsername',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
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
                      const SizedBox(height: 8),
                      _buildSectionBadge(resolvedSection),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هوية الطفل: ${childInfo['identityNumber'] ?? '-'}',
                      style: const TextStyle(color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تاريخ الطلب: ${_formatDate(createdAt)}',
                      style: const TextStyle(color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRequestDetails(item),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('عرض التفاصيل'),
                    ),
                  ),
                ],
              ),
              if (status == 'pending') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            isProcessing ? null : () => _approveRequest(item),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('موافقة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            isProcessing ? null : () => _rejectRequest(item),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('رفض'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomFilters = searchText.trim().isNotEmpty ||
        selectedStatuses.length != 1 ||
        !selectedStatuses.contains('pending');

    return AppPageScaffold(
      title: 'طلبات إضافة الأطفال',
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
                          'ابحثي باسم الطفل أو ولي الأمر أو اسم المستخدم أو البريد',
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(label: 'قيد المراجعة', value: 'pending'),
                      _buildFilterChip(label: 'تمت الموافقة', value: 'approved'),
                      _buildFilterChip(label: 'مرفوض', value: 'rejected'),
                    ],
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