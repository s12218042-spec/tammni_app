import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentConsultationsPage extends StatefulWidget {
  final String parentUsername;
  final String childId;
  final bool isTemporaryParent;

  const ParentConsultationsPage({
    super.key,
    this.parentUsername = '',
    this.childId = '',
    this.isTemporaryParent = false,
  });

  @override
  State<ParentConsultationsPage> createState() =>
      _ParentConsultationsPageState();
}

class _ParentConsultationsPageState extends State<ParentConsultationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedStatus = 'all';
  bool isUpdating = false;

  String get cleanUsername => widget.parentUsername.trim().toLowerCase();

  String get cleanChildId => widget.childId.trim();

  String formatMoney(dynamic value) {
    if (value == null) return '0';

    if (value is int) return value.toString();

    if (value is double) {
      if (value == value.roundToDouble()) return value.toInt().toString();
      return value.toStringAsFixed(2);
    }

    if (value is num) {
      final val = value.toDouble();
      if (val == val.roundToDouble()) return val.toInt().toString();
      return val.toStringAsFixed(2);
    }

    final parsed = double.tryParse(value.toString());

    if (parsed == null) return value.toString();
    if (parsed == parsed.roundToDouble()) return parsed.toInt().toString();

    return parsed.toStringAsFixed(2);
  }

  double numberFromDynamic(
    dynamic value, {
    double defaultValue = 0,
  }) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();

    final parsed = double.tryParse(value.toString());

    return parsed ?? defaultValue;
  }

  String formatDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();

      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    }

    if (value is DateTime) {
      return '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return '${parsed.year}/${parsed.month.toString().padLeft(2, '0')}/${parsed.day.toString().padLeft(2, '0')}';
      }
    }

    return 'غير محدد';
  }

  String approvalLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return 'تمت الموافقة';
      case 'rejected':
        return 'مرفوضة';
      case 'pending':
      default:
        return 'بانتظار الرد';
    }
  }

  Color approvalColor(String status) {
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

  String consultationStatusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'completed':
        return 'مكتملة';
      case 'scheduled':
        return 'تمت الموافقة';
      case 'cancelled':
        return 'ملغاة';
      case 'proposed':
      default:
          return 'غير محددة';
    }
  }

  bool isTrialConsultation(Map<String, dynamic> data) {
    final childType = (data['childType'] ??
            data['enrollmentType'] ??
            data['childStatus'] ??
            data['type'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final childStatus = (data['childStatus'] ?? data['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    return data['isTrialChild'] == true ||
        childType == 'trial' ||
        childType == 'تجربة' ||
        childStatus == 'trial';
  }

  bool isTemporaryConsultation(Map<String, dynamic> data) {
    final childType = (data['childType'] ??
            data['enrollmentType'] ??
            data['childStatus'] ??
            data['type'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final childStatus = (data['childStatus'] ?? data['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    return data['isTemporaryChild'] == true ||
        childType == 'temporary' ||
        childType == 'temp' ||
        childType == 'temporary_child' ||
        childType == 'مؤقت' ||
        childStatus == 'temporary';
  }

  String childTypeLabel(Map<String, dynamic> data) {
    if (isTrialConsultation(data)) {
      return 'طفل تجربة';
    }

    if (isTemporaryConsultation(data)) {
      return 'طفل مؤقت';
    }

    return 'طفل دائم';
  }

  String invoiceLabel(Map<String, dynamic> data) {
    final invoiceStatus =
        (data['invoiceStatus'] ?? data['billingStatus'] ?? '').toString();

    switch (invoiceStatus.trim().toLowerCase()) {
      case 'added_to_invoice':
      case 'invoiced':
        return 'مضافة للفاتورة';

      case 'paid':
        return 'مدفوعة';

      case 'pending_approval':
        return 'بانتظار الموافقة';

      case 'pending_invoice':
        return 'بانتظار الإضافة للفاتورة';

      case 'ready_for_invoice':
        return 'جاهزة للإضافة للفاتورة';

      case 'not_billed':
        return 'غير مفوترة';

      default:
        return '';
    }
  }

  bool isTemporaryDeviceSessionActive(Map<String, dynamic> data) {
    if (data.isEmpty) return false;

    if (data['isActive'] != true) return false;

    final accountStatus =
        (data['accountStatus'] ?? 'active').toString().trim().toLowerCase();

    if (accountStatus == 'archived' ||
        accountStatus == 'inactive' ||
        accountStatus == 'expired' ||
        accountStatus == 'disabled') {
      return false;
    }

    final accessEndAt = data['accessEndAt'];

    if (accessEndAt is Timestamp) {
      if (accessEndAt.toDate().isBefore(DateTime.now())) {
        return false;
      }
    }

    return true;
  }

  Future<Map<String, dynamic>?> fetchTemporaryDeviceSession() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || cleanChildId.isEmpty) return null;

    try {
      final deviceId = '${user.uid}_$cleanChildId';

      final doc = await _firestore
          .collection('temporary_parent_devices')
          .doc(deviceId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data() ?? <String, dynamic>{};

      if (!isTemporaryDeviceSessionActive(data)) {
        return null;
      }

      return data;
    } catch (_) {
      return null;
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      fetchConsultations() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    if (widget.isTemporaryParent) {
      if (cleanChildId.isEmpty) return [];

      final deviceSession = await fetchTemporaryDeviceSession();

      if (deviceSession == null) return [];

      final byChild = await _firestore
          .collection('child_consultations')
          .where('childId', isEqualTo: cleanChildId)
          .get();

      return byChild.docs.where((doc) {
        return !isTrialConsultation(doc.data());
      }).toList();
    }

    final docsById =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    if (currentUid.isNotEmpty) {
      final byUid = await _firestore
          .collection('child_consultations')
          .where('parentUid', isEqualTo: currentUid)
          .get();

      for (final doc in byUid.docs) {
        if (!isTrialConsultation(doc.data())) {
          docsById[doc.id] = doc;
        }
      }
    }

    if (cleanUsername.isNotEmpty) {
      final byUsername = await _firestore
          .collection('child_consultations')
          .where('parentUsername', isEqualTo: cleanUsername)
          .get();

      for (final doc in byUsername.docs) {
        if (!isTrialConsultation(doc.data())) {
          docsById[doc.id] = doc;
        }
      }
    }

    return docsById.values.toList();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> applyFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (selectedStatus == 'all') return docs;

    return docs.where((doc) {
      final status =
          (doc.data()['parentApprovalStatus'] ?? 'pending').toString();

      return status.trim().toLowerCase() == selectedStatus;
    }).toList();
  }

  Future<Map<String, String>> fetchCurrentParentInfo() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return {
        'uid': '',
        'name': widget.isTemporaryParent ? 'ولي الأمر المؤقت' : 'ولي الأمر',
        'username': cleanUsername,
      };
    }

    if (widget.isTemporaryParent) {
      final deviceData = await fetchTemporaryDeviceSession();

      return {
        'uid': user.uid,
        'name': (deviceData?['parentName'] ?? 'ولي الأمر المؤقت')
            .toString()
            .trim(),
        'username': (deviceData?['parentUsername'] ?? '')
            .toString()
            .trim()
            .toLowerCase(),
      };
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      final data = doc.data() ?? {};

      return {
        'uid': user.uid,
        'name': (data['displayName'] ??
                data['name'] ??
                data['fullName'] ??
                data['username'] ??
                'ولي الأمر')
            .toString()
            .trim(),
        'username': (data['username'] ?? cleanUsername)
            .toString()
            .trim()
            .toLowerCase(),
      };
    } catch (_) {
      return {
        'uid': user.uid,
        'name': 'ولي الأمر',
        'username': cleanUsername,
      };
    }
  }

  Future<void> notifyAdminConsultationResponse({
    required String consultationId,
    required bool approved,
    required Map<String, dynamic> consultationData,
    required double totalAmount,
    required double hourlyPrice,
    required double hours,
  }) async {
    final parentInfo = await fetchCurrentParentInfo();

    final parentUid = (parentInfo['uid'] ?? '').trim();

    final parentUsername =
        (parentInfo['username'] ?? '').trim().toLowerCase();

    final parentName = (parentInfo['name'] ?? 'ولي الأمر').trim();

    final childName =
        (consultationData['childName'] ?? '').toString().trim();

    final title =
        (consultationData['title'] ?? 'استشارة').toString().trim();

    final responseText = approved ? 'وافق' : 'رفض';

    final childType = (consultationData['childType'] ??
            consultationData['enrollmentType'] ??
            consultationData['childStatus'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final childStatus =
        (consultationData['childStatus'] ?? consultationData['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    final isTrialChild = isTrialConsultation(consultationData);

    final isTemporaryChild = isTemporaryConsultation(consultationData);

    final excludeFromMonthlyInvoice =
        consultationData['excludeFromMonthlyInvoice'] == true || isTrialChild;

    final createdByRole =
        widget.isTemporaryParent ? 'temporary_parent' : 'parent';

    await AppNotificationService.instance.notifyAdmin(
      title: approved ? 'تمت الموافقة على استشارة' : 'تم رفض استشارة',
      body:
          '$responseText ولي الأمر $parentName على الاستشارة "$title"${childName.isNotEmpty ? ' للطفل $childName' : ''}. المبلغ: ${formatMoney(totalAmount)} شيكل.',
      type: approved ? 'consultation_approved' : 'consultation_rejected',
      priority: approved ? 'normal' : 'important',
      parentUid: parentUid,
      parentUsername: parentUsername,
      parentName: parentName,
      childId: (consultationData['childId'] ?? '').toString(),
      childName: childName,
      section: (consultationData['section'] ?? 'Nursery').toString(),
      group: (consultationData['group'] ?? '').toString(),
      createdByUid: parentUid,
      createdByName: parentName,
      createdByRole: createdByRole,
      extraData: {
        'consultationId': consultationId,
        'consultationStatus': approved ? 'scheduled' : 'cancelled',
        'parentApprovalStatus': approved ? 'approved' : 'rejected',
        'notificationType':
            approved ? 'consultation_approved' : 'consultation_rejected',
        'category': 'consultations',
        'screen': 'consultations',
        'route': 'admin_consultations',
        'relatedCollection': 'child_consultations',
        'relatedDocId': consultationId,
        'totalAmount': totalAmount,
        'hourlyPrice': hourlyPrice,
        'hours': hours,
        'billable': approved && !isTrialChild,
        'invoiceStatus':
            approved && !isTrialChild ? 'pending_invoice' : 'not_billed',
        'childType': childType,
        'childStatus': childStatus,
        'isTemporaryChild': isTemporaryChild,
        'isTrialChild': isTrialChild,
        'isTemporaryParent': widget.isTemporaryParent,
        'excludeFromMonthlyInvoice': excludeFromMonthlyInvoice,
      },
    );
  }

  Future<void> respondToConsultation({
    required String consultationId,
    required bool approved,
  }) async {
    if (isUpdating) return;

    setState(() {
      isUpdating = true;
    });

    try {
      final now = DateTime.now();

      final consultationRef =
          _firestore.collection('child_consultations').doc(consultationId);

      final consultationDoc = await consultationRef.get();

      if (!consultationDoc.exists) {
        throw Exception('الاستشارة غير موجودة');
      }

      final consultationData =
          consultationDoc.data() ?? <String, dynamic>{};

      if (isTrialConsultation(consultationData)) {
        throw Exception('لا يمكن تنفيذ استشارة لطفل التجربة');
      }

      if (widget.isTemporaryParent) {
        final consultationChildId =
            (consultationData['childId'] ?? '').toString().trim();

        if (cleanChildId.isEmpty || consultationChildId != cleanChildId) {
          throw Exception('لا يمكنك تعديل هذه الاستشارة');
        }

        final deviceSession = await fetchTemporaryDeviceSession();

        if (deviceSession == null) {
          throw Exception('انتهت جلسة الدخول، يرجى تسجيل الدخول من جديد');
        }
      }

      final hours = numberFromDynamic(
        consultationData['hours'],
        defaultValue: 0,
      );

      final hourlyPrice = numberFromDynamic(
        consultationData['hourlyPrice'],
        defaultValue: 50,
      );

      final currentTotal = numberFromDynamic(
        consultationData['totalAmount'],
        defaultValue: 0,
      );

      final calculatedTotal =
          currentTotal > 0 ? currentTotal : (hours * hourlyPrice);

      final parentInfo = await fetchCurrentParentInfo();

      final respondingAuthUid = (parentInfo['uid'] ?? '').trim();

      final parentUsername =
          (parentInfo['username'] ?? cleanUsername).trim().toLowerCase();

      final parentName = (parentInfo['name'] ?? 'ولي الأمر').trim();

      final childType = (consultationData['childType'] ??
              consultationData['enrollmentType'] ??
              consultationData['childStatus'] ??
              '')
          .toString()
          .trim()
          .toLowerCase();

      final childStatus =
          (consultationData['childStatus'] ?? consultationData['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      final isTemporaryChild = isTemporaryConsultation(consultationData);

      final shouldBillConsultation = approved;

      final nextInvoiceStatus =
          shouldBillConsultation ? 'pending_invoice' : 'not_billed';

      final updatedData = <String, dynamic>{
        'parentApprovalStatus': approved ? 'approved' : 'rejected',
        'parentRespondedAt': Timestamp.fromDate(now),
        'consultationStatus': approved ? 'scheduled' : 'cancelled',
        'updatedAt': Timestamp.fromDate(now),
        'parentName': parentName,
        'hours': hours,
        'hourlyPrice': hourlyPrice,
        'totalAmount': calculatedTotal,
        'billable': shouldBillConsultation,
        'invoiceStatus': nextInvoiceStatus,
        'billingStatus': nextInvoiceStatus,
        'addedToInvoice': false,
        'invoiceId': consultationData['invoiceId'] ?? '',
        'invoiceMonth': consultationData['invoiceMonth'] ?? '',
        'childType': childType,
        'childStatus': childStatus,
        'isTemporaryChild': isTemporaryChild,
        'isTrialChild': false,
        'excludeFromMonthlyInvoice':
            consultationData['excludeFromMonthlyInvoice'] == true,
        'respondedByAuthUid': respondingAuthUid,
        'respondedByRole':
            widget.isTemporaryParent ? 'temporary_parent' : 'parent',
      };

      if (widget.isTemporaryParent) {
        updatedData['temporaryParentAuthUid'] = respondingAuthUid;
      } else {
        updatedData['parentUid'] = respondingAuthUid.isNotEmpty
            ? respondingAuthUid
            : (consultationData['parentUid'] ?? '').toString();

        updatedData['parentUsername'] = parentUsername.isNotEmpty
            ? parentUsername
            : (consultationData['parentUsername'] ?? '').toString();
      }

      await consultationRef.update(updatedData);

      try {
        await notifyAdminConsultationResponse(
          consultationId: consultationId,
          approved: approved,
          consultationData: consultationData,
          totalAmount: calculatedTotal,
          hourlyPrice: hourlyPrice,
          hours: hours,
        );
      } catch (e) {
        debugPrint(
          'ParentConsultationsPage: فشل إرسال إشعار رد الاستشارة للإدارة: $e',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved ? 'تمت الموافقة على الاستشارة' : 'تم رفض الاستشارة',
          ),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحديث الاستشارة: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Future<void> confirmResponse({
    required String consultationId,
    required bool approved,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            approved ? 'الموافقة على الاستشارة' : 'رفض الاستشارة',
          ),
          content: Text(
            approved
                ? 'هل تريد الموافقة على هذه الاستشارة؟'
                : 'هل تريد رفض هذه الاستشارة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(approved ? 'موافقة' : 'رفض'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    await respondToConsultation(
      consultationId: consultationId,
      approved: approved,
    );
  }

  Widget statusFilterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DropdownButtonFormField<String>(
          value: selectedStatus,
          decoration: InputDecoration(
            labelText: 'الحالة',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: 'all',
              child: Text('كل الاستشارات'),
            ),
            DropdownMenuItem(
              value: 'pending',
              child: Text('بانتظار الرد'),
            ),
            DropdownMenuItem(
              value: 'approved',
              child: Text('تمت الموافقة'),
            ),
            DropdownMenuItem(
              value: 'rejected',
              child: Text('مرفوضة'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              selectedStatus = value ?? 'all';
            });
          },
        ),
      ),
    );
  }

  Widget emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.primary.withOpacity(0.10),
              child: const Icon(
                Icons.psychology_alt_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد استشارات حاليًا',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget consultationCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final title = (data['title'] ?? 'استشارة').toString();

    final childName = (data['childName'] ?? '').toString();

    final description = (data['description'] ?? '').toString();

    final typeLabel = (data['consultationTypeLabel'] ??
            data['consultationType'] ??
            'استشارة')
        .toString();

    final approval =
        (data['parentApprovalStatus'] ?? 'pending').toString();

    final consultationStatus =
        (data['consultationStatus'] ?? 'proposed').toString();

    final hours = numberFromDynamic(data['hours']);

    final hourlyPrice = numberFromDynamic(
      data['hourlyPrice'],
      defaultValue: 50,
    );

    final totalAmountFromData =
        numberFromDynamic(data['totalAmount']);

    final totalAmount = totalAmountFromData > 0
        ? totalAmountFromData
        : (hours * hourlyPrice);

    final suggestedDate = data['suggestedDate'];

    final color = approvalColor(approval);

    final isPending =
        approval.trim().toLowerCase() == 'pending';

    final childType = childTypeLabel(data);

    final invoiceStatus = invoiceLabel(data);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(
                    Icons.psychology_alt_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.trim().isEmpty ? 'استشارة' : title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (childName.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'الطفل: $childName',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    approvalLabel(approval),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ConsultationInfoRow(
              icon: Icons.category_outlined,
              label: 'النوع',
              value: typeLabel,
            ),
            if (childType.isNotEmpty) ...[
              const SizedBox(height: 6),
              _ConsultationInfoRow(
                icon: Icons.child_care_rounded,
                label: 'نوع الطفل',
                value: childType,
              ),
            ],
            const SizedBox(height: 6),
            _ConsultationInfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'التاريخ',
              value: formatDate(suggestedDate),
            ),
            const SizedBox(height: 6),
            _ConsultationInfoRow(
              icon: Icons.access_time_rounded,
              label: 'الساعات',
              value: formatMoney(hours),
            ),
            const SizedBox(height: 6),
            _ConsultationInfoRow(
              icon: Icons.payments_outlined,
              label: 'سعر الساعة',
              value: '${formatMoney(hourlyPrice)} شيكل',
            ),
            const SizedBox(height: 6),
            _ConsultationInfoRow(
              icon: Icons.receipt_long_rounded,
              label: 'الإجمالي',
              value: '${formatMoney(totalAmount)} شيكل',
              strong: true,
            ),
            const SizedBox(height: 6),
            _ConsultationInfoRow(
              icon: Icons.info_outline_rounded,
              label: 'حالة الاستشارة',
              value: consultationStatusLabel(consultationStatus),
            ),
            if (invoiceStatus.isNotEmpty) ...[
              const SizedBox(height: 6),
              _ConsultationInfoRow(
                icon: Icons.request_quote_outlined,
                label: 'الفاتورة',
                value: invoiceStatus,
              ),
            ],
            if (description.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isUpdating
                          ? null
                          : () => confirmResponse(
                                consultationId: doc.id,
                                approved: false,
                              ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('رفض'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isUpdating
                          ? null
                          : () => confirmResponse(
                                consultationId: doc.id,
                                approved: true,
                              ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('موافقة'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الاستشارات',
      child: FutureBuilder<
          List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: fetchConsultations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data ?? [];

          final filteredDocs = applyFilter(docs);

          filteredDocs.sort((a, b) {
            final aCreated = a.data()['createdAt'];

            final bCreated = b.data()['createdAt'];

            final aTs =
                aCreated is Timestamp ? aCreated : null;

            final bTs =
                bCreated is Timestamp ? bCreated : null;

            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;

            return bTs.compareTo(aTs);
          });

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Text(
                  'استشارات الأطفال',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 14),
                statusFilterCard(),
                const SizedBox(height: 18),
                if (filteredDocs.isEmpty)
                  emptyState()
                else
                  ...filteredDocs.map(consultationCard),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConsultationInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool strong;

  const _ConsultationInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        strong ? AppColors.primary : AppColors.textDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color:
                strong ? AppColors.primary : AppColors.textLight,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 12.5,
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: TextStyle(
                color: color,
                fontWeight:
                    strong ? FontWeight.w900 : FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}