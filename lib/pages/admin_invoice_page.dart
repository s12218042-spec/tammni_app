import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'add_extra_hours_page.dart';
import 'create_nursery_invoice_page.dart';

class AdminInvoicesPage extends StatefulWidget {
  const AdminInvoicesPage({super.key});

  @override
  State<AdminInvoicesPage> createState() => _AdminInvoicesPageState();
}

class _AdminInvoicesPageState extends State<AdminInvoicesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String selectedStatus = 'all';

  bool isUpdatingStatus = false;
  bool isSyncingConsultations = false;
  bool didRunInitialConsultationsSync = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || didRunInitialConsultationsSync) return;

      didRunInitialConsultationsSync = true;

      syncTemporaryInvoiceConsultations(
        showMessage: false,
      );
    });
  }

  Future<void> openCreateInvoice() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateNurseryInvoicePage(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await syncTemporaryInvoiceConsultations(
        showMessage: false,
      );

      if (!mounted) return;

      setState(() {});
    }
  }

  double numValue(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String normalizeStatus(dynamic value) {
    final status = (value ?? '').toString().trim().toLowerCase();

    if (status.isEmpty) return 'unpaid';

    if (status == 'pending' ||
        status == 'not_paid' ||
        status == 'notpaid' ||
        status == 'غير مدفوعة') {
      return 'unpaid';
    }

    if (status == 'partially_paid' ||
        status == 'مدفوعة جزئياً' ||
        status == 'مدفوعة جزئيًا') {
      return 'partial';
    }

    if (status == 'مدفوعة') {
      return 'paid';
    }

    if (status == 'متأخرة') {
      return 'overdue';
    }

    if (status == 'ملغاة' || status == 'canceled') {
      return 'cancelled';
    }

    return status;
  }

  String invoiceChildId(Map<String, dynamic> data) {
    final directChildId =
        (data['childId'] ?? '').toString().trim();

    if (directChildId.isNotEmpty) {
      return directChildId;
    }

    final childrenIds = data['childrenIds'];

    if (childrenIds is List && childrenIds.isNotEmpty) {
      return childrenIds.first.toString().trim();
    }

    final children = data['children'];

    if (children is List && children.isNotEmpty) {
      final firstChild = children.first;

      if (firstChild is Map) {
        return (firstChild['childId'] ?? firstChild['id'] ?? '')
            .toString()
            .trim();
      }
    }

    return '';
  }

  bool isTemporaryInvoice(Map<String, dynamic> data) {
    final childType = (data['childType'] ??
            data['enrollmentType'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final billingType =
        (data['billingType'] ?? '').toString().trim().toLowerCase();

    final invoiceCategory =
        (data['invoiceCategory'] ?? '').toString().trim().toLowerCase();

    final temporaryAccessCodeId =
        (data['temporaryAccessCodeId'] ?? '').toString().trim();

    final children = data['children'];

    final hasTemporaryChildItem = children is List &&
        children.any((item) {
          if (item is! Map) return false;

          final itemType =
              (item['childType'] ?? item['enrollmentType'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();

          return item['isTemporaryChild'] == true ||
              itemType == 'temporary';
        });

    return data['isTemporaryChild'] == true ||
        childType == 'temporary' ||
        invoiceCategory == 'temporary_child' ||
        invoiceCategory == 'temporary_fee' ||
        hasTemporaryChildItem ||
        (billingType == 'hourly' && temporaryAccessCodeId.isNotEmpty);
  }

  bool isTrialConsultation(Map<String, dynamic> data) {
    final childType = (data['childType'] ??
            data['enrollmentType'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final childStatus =
        (data['childStatus'] ?? '').toString().trim().toLowerCase();

    return data['isTrialChild'] == true ||
        childType == 'trial' ||
        childStatus == 'trial' ||
        childStatus == 'trial_pending_decision';
  }

  bool shouldIncludeConsultation(
    Map<String, dynamic> data, {
    required String invoiceId,
  }) {
    final approvalStatus =
        (data['parentApprovalStatus'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    final consultationStatus =
        (data['consultationStatus'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    final invoiceStatus =
        (data['invoiceStatus'] ?? '').toString().trim().toLowerCase();

    final billingStatus =
        (data['billingStatus'] ?? '').toString().trim().toLowerCase();

    final linkedInvoiceId =
        (data['invoiceId'] ?? '').toString().trim();

    final linkedToSameInvoice =
        linkedInvoiceId.isNotEmpty && linkedInvoiceId == invoiceId;

    final linkedToAnotherInvoice =
        linkedInvoiceId.isNotEmpty && linkedInvoiceId != invoiceId;

    final readyForInvoice = invoiceStatus == 'ready_for_invoice' ||
        billingStatus == 'ready_for_invoice' ||
        invoiceStatus == 'pending_invoice' ||
        billingStatus == 'pending_invoice';

    return approvalStatus == 'approved' &&
        consultationStatus == 'completed' &&
        data['billable'] == true &&
        !isTrialConsultation(data) &&
        !linkedToAnotherInvoice &&
        (readyForInvoice || linkedToSameInvoice);
  }

  double consultationAmount(Map<String, dynamic> data) {
    final savedTotal = numValue(data['totalAmount']);

    if (savedTotal > 0) {
      return savedTotal;
    }

    final hours = numValue(data['hours']);
    final hourlyPrice = numValue(data['hourlyPrice']);

    return hours * hourlyPrice;
  }

  DateTime invoiceSortDate(Map<String, dynamic> data) {
    final candidates = [
      data['createdAt'],
      data['invoiceDate'],
      data['updatedAt'],
      data['accessStartAt'],
    ];

    for (final value in candidates) {
      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String) {
        final parsed = DateTime.tryParse(value);

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String paymentStatusFromAmounts({
    required double totalAmount,
    required double paidAmount,
  }) {
    if (paidAmount <= 0) return 'unpaid';
    if (paidAmount >= totalAmount) return 'paid';

    return 'partial';
  }

  Future<void> syncTemporaryInvoiceConsultations({
    bool showMessage = true,
  }) async {
    if (isSyncingConsultations) return;

    if (mounted) {
      setState(() {
        isSyncingConsultations = true;
      });
    }

    try {
      final invoicesSnapshot =
          await _firestore.collection('invoices').get();

      final latestInvoiceByChildId =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

      for (final invoiceDoc in invoicesSnapshot.docs) {
        final invoiceData = invoiceDoc.data();

        if (!isTemporaryInvoice(invoiceData)) {
          continue;
        }

        if (isHiddenInvoiceStatus(invoiceData)) {
          continue;
        }

        final savedStatus = normalizeStatus(
          invoiceData['status'] ??
              invoiceData['paymentStatus'] ??
              invoiceData['invoiceStatus'],
        );

        if (savedStatus == 'cancelled') {
          continue;
        }

        final childId = invoiceChildId(invoiceData);

        if (childId.isEmpty) {
          continue;
        }

        final currentInvoice = latestInvoiceByChildId[childId];

        if (currentInvoice == null) {
          latestInvoiceByChildId[childId] = invoiceDoc;
          continue;
        }

        final currentDate = invoiceSortDate(
          currentInvoice.data(),
        );

        final candidateDate = invoiceSortDate(
          invoiceData,
        );

        if (candidateDate.isAfter(currentDate)) {
          latestInvoiceByChildId[childId] = invoiceDoc;
        }
      }

      int updatedInvoicesCount = 0;

      for (final invoiceDoc in latestInvoiceByChildId.values) {
        final invoiceData = invoiceDoc.data();
        final childId = invoiceChildId(invoiceData);

        if (childId.isEmpty) continue;

        final consultationsSnapshot = await _firestore
            .collection('child_consultations')
            .where('childId', isEqualTo: childId)
            .get();

        final consultationDocsById =
            <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

        for (final consultationDoc in consultationsSnapshot.docs) {
          consultationDocsById[consultationDoc.id] = consultationDoc;
        }

        final includedConsultations =
            consultationsSnapshot.docs.where((doc) {
          return shouldIncludeConsultation(
            doc.data(),
            invoiceId: invoiceDoc.id,
          );
        }).toList();

        final consultationIds =
            includedConsultations.map((doc) => doc.id).toList();

        double consultationsAmount = 0;

        for (final consultationDoc in includedConsultations) {
          consultationsAmount +=
              consultationAmount(consultationDoc.data());
        }

        final previousConsultationsAmount =
            numValue(invoiceData['consultationsAmount']);

        final extraHoursAmount = numValue(
          invoiceData['extraHoursAmount'] ??
              invoiceData['extraHoursTotal'],
        );

        final totalDiscount = numValue(
          invoiceData['totalDiscount'] ??
              invoiceData['discountAmount'] ??
              invoiceData['discount'],
        );

        double nurseryCostAmount = numValue(
          invoiceData['subtotalAmount'] ??
              invoiceData['baseAmount'],
        );

        if (nurseryCostAmount <= 0) {
          final previousTotal = numValue(
            invoiceData['totalAmount'] ??
                invoiceData['finalAmount'],
          );

          nurseryCostAmount = previousTotal -
              previousConsultationsAmount -
              extraHoursAmount +
              totalDiscount;

          if (nurseryCostAmount < 0) {
            nurseryCostAmount = 0;
          }
        }

        double totalAmount =
            nurseryCostAmount +
            extraHoursAmount +
            consultationsAmount -
            totalDiscount;

        if (totalAmount < 0) {
          totalAmount = 0;
        }

        final paidAmount =
            numValue(invoiceData['paidAmount']);

        double remainingAmount =
            totalAmount - paidAmount;

        if (remainingAmount < 0) {
          remainingAmount = 0;
        }

        final calculatedPaymentStatus =
            paymentStatusFromAmounts(
          totalAmount: totalAmount,
          paidAmount: paidAmount,
        );

        final previousStatus = normalizeStatus(
          invoiceData['status'] ??
              invoiceData['paymentStatus'] ??
              invoiceData['invoiceStatus'],
        );

        final nextStatus = previousStatus == 'overdue'
            ? 'overdue'
            : calculatedPaymentStatus;

        final oldConsultationIdsRaw =
            invoiceData['consultationIds'];

        final oldConsultationIds =
            oldConsultationIdsRaw is List
                ? oldConsultationIdsRaw
                    .map((item) => item.toString())
                    .toSet()
                : <String>{};

        final newConsultationIds =
            consultationIds.toSet();

        final removedConsultationIds =
            oldConsultationIds.difference(
          newConsultationIds,
        );

        final hasChanged =
            previousConsultationsAmount != consultationsAmount ||
                numValue(invoiceData['totalAmount']) != totalAmount ||
                numValue(invoiceData['finalAmount']) != totalAmount ||
                numValue(invoiceData['remainingAmount']) !=
                    remainingAmount ||
                oldConsultationIds.length !=
                    newConsultationIds.length ||
                !oldConsultationIds.containsAll(
                  newConsultationIds,
                );

        if (!hasChanged) {
          continue;
        }

        final batch = _firestore.batch();

        final consultationItems = includedConsultations.map((doc) {
          final data = doc.data();

          return {
            'consultationId': doc.id,
            'title': data['title'] ?? '',
            'childId': data['childId'] ?? '',
            'childName': data['childName'] ?? '',
            'hours': data['hours'] ?? 0,
            'hourlyPrice': data['hourlyPrice'] ?? 0,
            'totalAmount': consultationAmount(data),
            'childType': data['childType'] ?? '',
            'isTemporaryChild': data['isTemporaryChild'] == true,
            'isTrialChild': data['isTrialChild'] == true,
          };
        }).toList();

        batch.set(
          invoiceDoc.reference,
          {
            'subtotalAmount': nurseryCostAmount,
            'consultationIds': consultationIds,
            'consultations': consultationItems,
            'consultationsAmount': consultationsAmount,
            'consultationsCount': consultationIds.length,
            'totalAmount': totalAmount,
            'finalAmount': totalAmount,
            'remainingAmount': remainingAmount,
            'status': nextStatus,
            'paymentStatus': nextStatus,
            'invoiceStatus': nextStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        for (final consultationDoc in includedConsultations) {
          batch.set(
            consultationDoc.reference,
            {
              'addedToInvoice': true,
              'invoiceId': invoiceDoc.id,
              'invoiceStatus': 'invoiced',
              'billingStatus': 'invoiced',
              'invoicedAt':
                  FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        for (final removedConsultationId
            in removedConsultationIds) {
          final removedDoc =
              consultationDocsById[removedConsultationId];

          if (removedDoc == null) continue;

          final removedData = removedDoc.data();

          final approvalStatus =
              (removedData['parentApprovalStatus'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();

          final nextConsultationInvoiceStatus =
              approvalStatus == 'approved'
                  ? 'pending_invoice'
                  : 'not_billed';

          batch.set(
            removedDoc.reference,
            {
              'addedToInvoice': false,
              'invoiceId': '',
              'invoiceMonth': '',
              'invoiceStatus':
                  nextConsultationInvoiceStatus,
              'billingStatus':
                  nextConsultationInvoiceStatus,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit();

        updatedInvoicesCount++;
      }

      if (!mounted || !showMessage) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedInvoicesCount > 0
                ? 'تم تحديث الاستشارات داخل الفواتير'
                : 'الفواتير محدثة بالفعل',
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'AdminInvoicesPage: فشل تحديث استشارات الفواتير للطفل الزائر ',
      );

      if (!mounted || !showMessage) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تحديث الاستشارات داخل الفواتير: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSyncingConsultations = false;
        });
      }
    }
  }

  bool isHiddenInvoiceStatus(Map<String, dynamic> data) {
    final status = normalizeStatus(data['status']);
    final paymentStatus = normalizeStatus(data['paymentStatus']);
    final invoiceStatus = normalizeStatus(data['invoiceStatus']);

    const hiddenStatuses = {
      'draft',
      'superseded',
      'deleted',
      'void',
      'archived',
    };

    return hiddenStatuses.contains(status) ||
        hiddenStatuses.contains(paymentStatus) ||
        hiddenStatuses.contains(invoiceStatus);
  }

  String statusLabel(String status) {
    switch (normalizeStatus(status)) {
      case 'unpaid':
        return 'غير مدفوعة';

      case 'partial':
        return 'مدفوعة جزئيًا';

      case 'paid':
        return 'مدفوعة';

      case 'overdue':
        return 'متأخرة';

      case 'cancelled':
        return 'ملغاة';

      case 'superseded':
        return 'مستبدلة';

      default:
        return status.trim().isEmpty
            ? 'غير محددة'
            : status;
    }
  }

  Color statusColor(String status) {
    switch (normalizeStatus(status)) {
      case 'unpaid':
        return Colors.orange;

      case 'partial':
        return Colors.blueGrey;

      case 'paid':
        return Colors.green;

      case 'overdue':
        return Colors.redAccent;

      case 'cancelled':
        return Colors.grey;

      case 'superseded':
        return Colors.grey;

      default:
        return AppColors.primary;
    }
  }

  IconData statusIcon(String status) {
    switch (normalizeStatus(status)) {
      case 'unpaid':
        return Icons.schedule_rounded;

      case 'partial':
        return Icons.payments_outlined;

      case 'paid':
        return Icons.verified_rounded;

      case 'overdue':
        return Icons.warning_amber_rounded;

      case 'cancelled':
        return Icons.cancel_rounded;

      case 'superseded':
        return Icons.swap_horiz_rounded;

      default:
        return Icons.receipt_long_rounded;
    }
  }

  String paymentMethodLabel() {
    return 'كاش';
  }

  Timestamp? resolveTimestamp(dynamic value) {
    if (value is Timestamp) return value;

    return null;
  }

  String formatDate(dynamic value) {
    final ts = resolveTimestamp(value);

    if (ts == null) return 'غير محدد';

    final d = ts.toDate();

    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  String formatAmount(dynamic value) {
    final parsed = numValue(value);

    if (parsed == parsed.roundToDouble()) {
      return parsed.toStringAsFixed(0);
    }

    return parsed.toStringAsFixed(2);
  }

  double resolvedPaidAmount(Map<String, dynamic> data) {
    return numValue(data['paidAmount']);
  }

  double resolvedRemainingAmount(Map<String, dynamic> data) {
    final stored = data['remainingAmount'];

    if (stored != null) {
      return numValue(stored);
    }

    final total = numValue(
      data['totalAmount'] ??
          data['finalAmount'],
    );

    final paid = numValue(data['paidAmount']);

    final remaining = total - paid;

    return remaining < 0 ? 0 : remaining;
  }

  String resolvedStatus(Map<String, dynamic> data) {
    final stored = normalizeStatus(
      data['status'] ??
          data['paymentStatus'] ??
          data['invoiceStatus'],
    );

    if (stored == 'paid' ||
        stored == 'partial' ||
        stored == 'unpaid' ||
        stored == 'overdue' ||
        stored == 'cancelled') {
      return stored;
    }

    final total = numValue(
      data['totalAmount'] ??
          data['finalAmount'],
    );

    final paid = resolvedPaidAmount(data);

    return paymentStatusFromAmounts(
      totalAmount: total,
      paidAmount: paid,
    );
  }

  String invoiceChildrenNames(Map<String, dynamic> data) {
    final childrenNames = data['childrenNames'];

    if (childrenNames is List && childrenNames.isNotEmpty) {
      final names = childrenNames
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();

      if (names.isNotEmpty) {
        return names.join('، ');
      }
    }

    final children = data['children'];

    if (children is List && children.isNotEmpty) {
      final names = children.map((item) {
        if (item is Map) {
          return (item['childName'] ??
                  item['name'] ??
                  '')
              .toString()
              .trim();
        }

        return '';
      }).where((item) => item.isNotEmpty).toList();

      if (names.isNotEmpty) {
        return names.join('، ');
      }
    }

    return (data['childName'] ?? '').toString().trim();
  }

  int invoiceChildrenCount(Map<String, dynamic> data) {
    final count = data['childrenCount'];

    if (count is num && count > 0) {
      return count.toInt();
    }

    final childrenNames = data['childrenNames'];

    if (childrenNames is List && childrenNames.isNotEmpty) {
      return childrenNames.length;
    }

    final children = data['children'];

    if (children is List && children.isNotEmpty) {
      return children.length;
    }

    final childName =
        (data['childName'] ?? '').toString().trim();

    return childName.isEmpty ? 0 : 1;
  }

  String invoiceDisplayTitle(Map<String, dynamic> data) {
    final title =
        (data['title'] ?? '').toString().trim();

    final offerTitle =
        (data['offerTitle'] ?? '').toString().trim();

    final isTwoChildrenOffer =
        data['isTwoChildrenOffer'] == true;

    if (title.isNotEmpty) return title;
    if (isTwoChildrenOffer) return 'فاتورة عرض طفلين';
    if (offerTitle.isNotEmpty) return 'فاتورة $offerTitle';

    return 'فاتورة حضانة';
  }

  dynamic invoiceCreatedDate(Map<String, dynamic> data) {
    return data['createdAt'] ??
        data['invoiceDate'] ??
        data['updatedAt'] ??
        data['dueDate'];
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> invoicesStream() {
    return _firestore
        .collection('invoices')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> visibleDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      return !isHiddenInvoiceStatus(
        doc.data(),
      );
    }).toList();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> applyFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final cleanDocs = visibleDocs(docs);

    if (selectedStatus == 'all') {
      return cleanDocs;
    }

    return cleanDocs.where((doc) {
      return resolvedStatus(doc.data()) == selectedStatus;
    }).toList();
  }

  Map<String, int> buildStats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int unpaid = 0;
    int partial = 0;
    int paid = 0;
    int overdue = 0;
    int cancelled = 0;

    final cleanDocs = visibleDocs(docs);

    for (final doc in cleanDocs) {
      final status = resolvedStatus(
        doc.data(),
      );

      if (status == 'paid') {
        paid++;
      } else if (status == 'partial') {
        partial++;
      } else if (status == 'overdue') {
        overdue++;
      } else if (status == 'cancelled') {
        cancelled++;
      } else {
        unpaid++;
      }
    }

    return {
      'all': cleanDocs.length,
      'unpaid': unpaid,
      'partial': partial,
      'paid': paid,
      'overdue': overdue,
      'cancelled': cancelled,
    };
  }

  String buildNotificationTitle(String status) {
    switch (normalizeStatus(status)) {
      case 'paid':
        return 'تم تحديث الفاتورة كمدفوعة';

      case 'partial':
        return 'تم تسجيل دفعة جزئية للفاتورة';

      case 'overdue':
        return 'تنبيه: فاتورة متأخرة';

      case 'cancelled':
        return 'تم إلغاء فاتورة';

      case 'unpaid':
      default:
        return 'تحديث على حالة الفاتورة';
    }
  }

  String buildNotificationBody({
    required String status,
    required String invoiceTitle,
    required String childrenNames,
    required String totalAmount,
    required String paidAmount,
    required String remainingAmount,
  }) {
    final title =
        invoiceTitle.trim().isEmpty ? 'فاتورة' : invoiceTitle;

    final childPart = childrenNames.trim().isEmpty
        ? ''
        : ' للأطفال: $childrenNames';

    switch (normalizeStatus(status)) {
      case 'paid':
        return 'تم تسجيل الفاتورة "$title"$childPart كمدفوعة. الإجمالي: $totalAmount شيكل.';

      case 'partial':
        return 'تم تحديث الفاتورة "$title"$childPart كمدفوعة جزئيًا. المدفوع: $paidAmount شيكل، المتبقي: $remainingAmount شيكل.';

      case 'overdue':
        return 'الفاتورة "$title"$childPart أصبحت متأخرة. المتبقي: $remainingAmount شيكل.';

      case 'cancelled':
        return 'تم إلغاء الفاتورة "$title"$childPart.';

      case 'unpaid':
      default:
        return 'تم تحديث حالة الفاتورة "$title"$childPart إلى غير مدفوعة. الإجمالي: $totalAmount شيكل.';
    }
  }

  Future<void> createParentInvoiceNotification({
    required String invoiceId,
    required Map<String, dynamic> invoiceData,
    required String newStatus,
  }) async {
    final parentUid = (invoiceData['parentUid'] ??
            invoiceData['uid'] ??
            invoiceData['targetUid'] ??
            '')
        .toString()
        .trim();

    final parentUsername =
        (invoiceData['parentUsername'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    String childId =
        (invoiceData['childId'] ?? '').toString().trim();

    if (childId.isEmpty) {
      final childrenIds = invoiceData['childrenIds'];

      if (childrenIds is List && childrenIds.isNotEmpty) {
        childId = childrenIds.first.toString().trim();
      }
    }

    if (childId.isEmpty) {
      final children = invoiceData['children'];

      if (children is List && children.isNotEmpty) {
        final firstChild = children.first;

        if (firstChild is Map) {
          childId =
              (firstChild['childId'] ?? firstChild['id'] ?? '')
                  .toString()
                  .trim();
        }
      }
    }

    if (parentUid.isEmpty &&
        parentUsername.isEmpty &&
        childId.isEmpty) {
      return;
    }

    final parentName =
        (invoiceData['parentName'] ?? '').toString().trim();

    final childrenNames =
        invoiceChildrenNames(invoiceData);

    final invoiceTitle =
        invoiceDisplayTitle(invoiceData);

    final total =
        formatAmount(invoiceData['totalAmount']);

    final paid =
        formatAmount(invoiceData['paidAmount']);

    final remaining = formatAmount(
      invoiceData['remainingAmount'] ??
          resolvedRemainingAmount(invoiceData),
    );

    final title =
        buildNotificationTitle(newStatus);

    final body = buildNotificationBody(
      status: newStatus,
      invoiceTitle: invoiceTitle,
      childrenNames: childrenNames,
      totalAmount: total,
      paidAmount: paid,
      remainingAmount: remaining,
    );

    final currentUser = _auth.currentUser;

    String adminName = 'الإدارة';
    String adminRole = 'admin';

    if (currentUser != null) {
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();

        final userData =
            userDoc.data() ?? <String, dynamic>{};

        adminName = (userData['displayName'] ??
                userData['name'] ??
                userData['fullName'] ??
                userData['username'] ??
                'الإدارة')
            .toString();

        adminRole =
            (userData['role'] ?? 'admin').toString();
      } catch (_) {
        adminName = 'الإدارة';
        adminRole = 'admin';
      }
    }

    await AppNotificationService.instance.notifyChildParent(
      parentUid: parentUid,
      parentUsername: parentUsername,
      parentName: parentName,
      title: title,
      body: body,
      type: 'invoice_updated',
      childId: childId,
      childName: childrenNames,
      priority:
          normalizeStatus(newStatus) == 'overdue'
              ? 'important'
              : 'normal',
      createdByUid: currentUser?.uid ?? '',
      createdByName: adminName,
      createdByRole: adminRole,
      extraData: {
        'invoiceId': invoiceId,
        'invoiceStatus': normalizeStatus(newStatus),
        'paymentStatus': normalizeStatus(newStatus),
        'totalAmount': numValue(
          invoiceData['totalAmount'],
        ),
        'paidAmount': numValue(
          invoiceData['paidAmount'],
        ),
        'remainingAmount':
            resolvedRemainingAmount(invoiceData),
        'paymentMethod': 'cash',
        'category': 'invoice',
        'notificationType': 'invoice_updated',
        'screen': 'invoices',
        'route': 'parent_invoices',
        'relatedCollection': 'invoices',
      },
    );
  }

  Future<void> updateInvoiceStatus({
    required String docId,
    required String status,
    double? paidAmountOverride,
  }) async {
    if (isUpdatingStatus) return;

    setState(() {
      isUpdatingStatus = true;
    });

    try {
      final invoiceRef =
          _firestore.collection('invoices').doc(docId);

      final invoiceDoc =
          await invoiceRef.get();

      if (!invoiceDoc.exists) {
        throw Exception('الفاتورة غير موجودة');
      }

      final invoiceData =
          invoiceDoc.data() ?? <String, dynamic>{};

      final normalized =
          normalizeStatus(status);

      final total = numValue(
        invoiceData['totalAmount'] ??
            invoiceData['finalAmount'],
      );

      final currentPaid =
          numValue(invoiceData['paidAmount']);

      double newPaid = currentPaid;

      if (normalized == 'paid') {
        newPaid = total;
      } else if (normalized == 'unpaid') {
        newPaid = 0;
      } else if (normalized == 'partial') {
        final partialPaidAmount =
            paidAmountOverride ?? currentPaid;

        if (partialPaidAmount <= 0 ||
            partialPaidAmount >= total) {
          throw Exception(
            'قيمة الدفعة الجزئية يجب أن تكون أكبر من صفر وأقل من الإجمالي',
          );
        }

        newPaid = partialPaidAmount;
      }

      final remaining =
          total - newPaid;

      final updateData =
          <String, dynamic>{
        'status': normalized,
        'paymentStatus': normalized,
        'invoiceStatus': normalized,
        'paymentMethod': 'cash',
        'paidAmount': newPaid < 0 ? 0 : newPaid,
        'remainingAmount':
            remaining < 0 ? 0 : remaining,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (normalized == 'paid') {
        updateData['paidAt'] =
            FieldValue.serverTimestamp();
      } else if (normalized == 'unpaid') {
        updateData['paidAt'] = null;
      }

      await invoiceRef.update(updateData);

      try {
        await createParentInvoiceNotification(
          invoiceId: docId,
          invoiceData: {
            ...invoiceData,
            ...updateData,
            'status': normalized,
            'paymentStatus': normalized,
            'invoiceStatus': normalized,
            'paidAmount': updateData['paidAmount'],
            'remainingAmount':
                updateData['remainingAmount'],
          },
          newStatus: normalized,
        );
      } catch (e) {
        debugPrint(
          'AdminInvoicesPage: فشل إرسال إشعار تحديث الفاتورة: $e',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديث حالة الفاتورة إلى ${statusLabel(normalized)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء تحديث الفاتورة: $e',
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        isUpdatingStatus = false;
      });
    }
  }

  Future<void> openPartialPaymentDialog({
    required String docId,
  }) async {
    final invoiceDoc =
        await _firestore.collection('invoices').doc(docId).get();

    if (!invoiceDoc.exists || !mounted) return;

    final invoiceData =
        invoiceDoc.data() ?? <String, dynamic>{};

    final totalAmount = numValue(
      invoiceData['totalAmount'] ??
          invoiceData['finalAmount'],
    );

    final currentPaidAmount =
        numValue(invoiceData['paidAmount']);

    final paidAmountCtrl = TextEditingController(
      text: currentPaidAmount > 0
          ? formatAmount(currentPaidAmount)
          : '',
    );

    try {
      final amount = await showDialog<double>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تسجيل دفعة جزئية'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الإجمالي: ${formatAmount(totalAmount)} شيكل',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: paidAmountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المدفوع',
                    prefixIcon: Icon(Icons.price_check_rounded),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final parsed =
                      double.tryParse(paidAmountCtrl.text.trim());

                  if (parsed == null ||
                      parsed <= 0 ||
                      parsed >= totalAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'أدخل مبلغًا أكبر من صفر وأقل من الإجمالي',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, parsed);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      );

      if (amount == null) return;

      await updateInvoiceStatus(
        docId: docId,
        status: 'partial',
        paidAmountOverride: amount,
      );
    } finally {
      paidAmountCtrl.dispose();
    }
  }

  void openStatusDialog({
    required String docId,
    required String currentStatus,
  }) {
    final normalizedStatus =
        normalizeStatus(currentStatus);

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تحديث حالة الفاتورة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusOptionTile(
                label: 'غير مدفوعة',
                color: Colors.orange,
                selected: normalizedStatus == 'unpaid',
                onTap: () async {
                  Navigator.pop(context);

                  await updateInvoiceStatus(
                    docId: docId,
                    status: 'unpaid',
                  );
                },
              ),
              _StatusOptionTile(
                label: 'مدفوعة جزئيًا',
                color: Colors.blueGrey,
                selected: normalizedStatus == 'partial',
                onTap: () async {
                  Navigator.pop(context);

                  await openPartialPaymentDialog(
                    docId: docId,
                  );
                },
              ),
              _StatusOptionTile(
                label: 'مدفوعة',
                color: Colors.green,
                selected: normalizedStatus == 'paid',
                onTap: () async {
                  Navigator.pop(context);

                  await updateInvoiceStatus(
                    docId: docId,
                    status: 'paid',
                  );
                },
              ),
              _StatusOptionTile(
                label: 'متأخرة',
                color: Colors.redAccent,
                selected: normalizedStatus == 'overdue',
                onTap: () async {
                  Navigator.pop(context);

                  await updateInvoiceStatus(
                    docId: docId,
                    status: 'overdue',
                  );
                },
              ),
              _StatusOptionTile(
                label: 'ملغاة',
                color: Colors.grey,
                selected: normalizedStatus == 'cancelled',
                onTap: () async {
                  Navigator.pop(context);

                  await updateInvoiceStatus(
                    docId: docId,
                    status: 'cancelled',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildFilterChip({
    required String label,
    required String value,
    required int count,
  }) {
    final selected =
        selectedStatus == value;

    final color = value == 'all'
        ? AppColors.primary
        : statusColor(value);

    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) {
        setState(() {
          selectedStatus = value;
        });
      },
      selectedColor: color.withOpacity(0.16),
      labelStyle: TextStyle(
        color: selected
            ? color
            : AppColors.textDark,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected
            ? color
            : AppColors.border,
      ),
      backgroundColor: Colors.white,
    );
  }

  Widget buildFiltersCard(Map<String, int> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            buildFilterChip(
              label: 'الكل',
              value: 'all',
              count: stats['all'] ?? 0,
            ),
            buildFilterChip(
              label: 'غير مدفوعة',
              value: 'unpaid',
              count: stats['unpaid'] ?? 0,
            ),
            buildFilterChip(
              label: 'جزئيًا',
              value: 'partial',
              count: stats['partial'] ?? 0,
            ),
            buildFilterChip(
              label: 'مدفوعة',
              value: 'paid',
              count: stats['paid'] ?? 0,
            ),
            buildFilterChip(
              label: 'متأخرة',
              value: 'overdue',
              count: stats['overdue'] ?? 0,
            ),
            buildFilterChip(
              label: 'ملغاة',
              value: 'cancelled',
              count: stats['cancelled'] ?? 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: const [
            Icon(
              Icons.receipt_long_outlined,
              size: 46,
              color: AppColors.textLight,
            ),
            SizedBox(height: 12),
            Text(
              'لا توجد فواتير ضمن هذا التصنيف حاليًا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInvoiceCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final status =
        resolvedStatus(data);

    final createdAt =
        invoiceCreatedDate(data);

    final title =
        invoiceDisplayTitle(data);

    final childrenNames =
        invoiceChildrenNames(data);

    final childrenCount =
        invoiceChildrenCount(data);

    final parentName =
        (data['parentName'] ?? '').toString();

    final parentUsername =
        (data['parentUsername'] ?? '').toString();

    final temporaryInvoice =
        isTemporaryInvoice(data);

    final hoursCount =
        numValue(data['hoursCount'] ?? data['temporaryHoursCount']);

    final hourlyRate =
        numValue(data['hourlyRate'] ?? data['temporaryHourlyRate']);

    final totalAmount =
        formatAmount(
      data['totalAmount'] ??
          data['finalAmount'],
    );

    final paidAmount =
        formatAmount(data['paidAmount']);

    final remainingAmount =
        formatAmount(
      data['remainingAmount'] ??
          resolvedRemainingAmount(data),
    );

    final subtotalAmount =
        formatAmount(
      data['subtotalAmount'] ??
          data['baseAmount'] ??
          0,
    );

    final offerDiscount =
        formatAmount(
      data['offerDiscount'] ?? 0,
    );

    final manualDiscount =
        formatAmount(
      data['manualDiscount'] ??
          data['discountAmount'] ??
          0,
    );

    final totalDiscount =
        formatAmount(
      data['totalDiscount'] ??
          data['discountAmount'] ??
          data['discount'] ??
          0,
    );

    final discountNotes =
        (data['discountNotes'] ?? '')
            .toString()
            .trim();

    final offerTitle =
        (data['offerTitle'] ?? '')
            .toString()
            .trim();

    final extraHoursAmount =
        formatAmount(
      data['extraHoursAmount'] ??
          data['extraHoursTotal'] ??
          0,
    );

    final consultationsAmount =
        formatAmount(
      data['consultationsAmount'] ?? 0,
    );

    final consultationIds =
        data['consultationIds'];

    final extraHoursIds =
        data['extraHoursIds'];

    final consultationsCount =
        consultationIds is List
            ? consultationIds.length
            : 0;

    final extraHoursCount =
        extraHoursIds is List
            ? extraHoursIds.length
            : 0;

    final billingMonthKey =
        (data['billingMonthKey'] ?? '')
            .toString()
            .trim();

    final paymentMethod = paymentMethodLabel();

    final color =
        statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      color.withOpacity(0.15),
                  child: Icon(
                    statusIcon(status),
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.w800,
                          fontSize: 16,
                          color:
                              AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (childrenNames
                          .trim()
                          .isNotEmpty)
                        Text(
                          childrenCount > 1
                              ? 'الأطفال: $childrenNames'
                              : 'الطفل: $childrenNames',
                          style: const TextStyle(
                            color:
                                AppColors.textLight,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      if (parentName
                          .trim()
                          .isNotEmpty)
                        Text(
                          parentUsername
                                  .trim()
                                  .isNotEmpty
                              ? 'ولي الأمر: $parentName • @$parentUsername'
                              : 'ولي الأمر: $parentName',
                          style: const TextStyle(
                            color:
                                AppColors.textLight,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        color.withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(30),
                  ),
                  child: Text(
                    statusLabel(status),
                    style: TextStyle(
                      color: color,
                      fontWeight:
                          FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (temporaryInvoice && hoursCount > 0) ...[
              const SizedBox(height: 8),
              _InvoiceInfoTile(
                icon: Icons.schedule_outlined,
                title: 'عدد الساعات',
                value: formatAmount(hoursCount),
              ),
            ],
            if (temporaryInvoice && hourlyRate > 0) ...[
              const SizedBox(height: 8),
              _InvoiceInfoTile(
                icon: Icons.price_change_outlined,
                title: 'سعر الساعة',
                value: '${formatAmount(hourlyRate)} شيكل',
              ),
            ],
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon: Icons.groups_2_outlined,
              title: 'عدد الأطفال',
              value: childrenCount <= 0
                  ? '-'
                  : '$childrenCount',
            ),
            const SizedBox(height: 8),
            if (billingMonthKey.isNotEmpty) ...[
              _InvoiceInfoTile(
                icon:
                    Icons.calendar_month_outlined,
                title: 'شهر الفاتورة',
                value: billingMonthKey,
              ),
              const SizedBox(height: 8),
            ],
            if (offerTitle.isNotEmpty) ...[
              _InvoiceInfoTile(
                icon:
                    Icons.local_offer_outlined,
                title: 'العرض',
                value: offerTitle,
              ),
              const SizedBox(height: 8),
            ],
            _InvoiceInfoTile(
              icon: Icons.receipt_outlined,
              title: 'تكلفة الحضانة',
              value: '$subtotalAmount شيكل',
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon:
                  Icons.access_time_filled_rounded,
              title: extraHoursCount > 0
                  ? 'الساعات الإضافية ($extraHoursCount)'
                  : 'الساعات الإضافية',
              value: '$extraHoursAmount شيكل',
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon:
                  Icons.psychology_alt_outlined,
              title: consultationsCount > 0
                  ? 'الاستشارات ($consultationsCount)'
                  : 'الاستشارات',
              value:
                  '$consultationsAmount شيكل',
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon:
                  Icons.local_offer_outlined,
              title: 'خصم العرض',
              value: '$offerDiscount شيكل',
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon:
                  Icons.discount_outlined,
              title: 'خصم إضافي',
              value: '$manualDiscount شيكل',
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon:
                  Icons.price_change_outlined,
              title: 'مجموع الخصم',
              value: '$totalDiscount شيكل',
            ),
            if (discountNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InvoiceInfoTile(
                icon: Icons.notes_outlined,
                title: 'ملاحظات الخصم',
                value: discountNotes,
              ),
            ],
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon: Icons.payments_outlined,
              title: 'الإجمالي',
              value: '$totalAmount شيكل',
              strong: true,
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon:
                  Icons.price_check_rounded,
              title: 'المدفوع',
              value: '$paidAmount شيكل',
              strong: true,
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon: Icons
                  .account_balance_wallet_outlined,
              title: 'المتبقي',
              value: '$remainingAmount شيكل',
              strong: true,
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon:
                  Icons.credit_card_rounded,
              title: 'طريقة الدفع',
              value: paymentMethod,
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon:
                  Icons.access_time_rounded,
              title: 'تاريخ الإنشاء',
              value: formatDate(createdAt),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isUpdatingStatus
                    ? null
                    : () => openStatusDialog(
                          docId: doc.id,
                          currentStatus:
                              status,
                        ),
                icon: const Icon(
                  Icons.edit_note_rounded,
                ),
                label: const Text(
                  'تحديث الحالة',
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
      title: 'فواتير الحضانة',
      actions: [
        IconButton(
          tooltip: 'تحديث الاستشارات',
          onPressed: isSyncingConsultations
              ? null
              : () =>
                  syncTemporaryInvoiceConsultations(),
          icon: isSyncingConsultations
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.sync_rounded,
                ),
        ),
      ],
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'extra_hours_btn',
            onPressed: () async {
              final result =
                  await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AddExtraHoursPage(),
                ),
              );

              if (!mounted) return;

              if (result == true) {
                await syncTemporaryInvoiceConsultations(
                  showMessage: false,
                );

                if (!mounted) return;

                setState(() {});
              }
            },
            backgroundColor: Colors.orange,
            icon: const Icon(
              Icons.access_time_filled_rounded,
            ),
            label: const Text(
              'الساعات الإضافية',
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create_invoice_btn',
            onPressed: openCreateInvoice,
            icon: const Icon(Icons.add),
            label: const Text(
              'إنشاء فاتورة',
            ),
          ),
        ],
      ),
      child: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: invoicesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(18),
                child: Text(
                  'حدث خطأ أثناء تحميل الفواتير:\n${snapshot.error}',
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          final filteredDocs =
              applyFilter(docs);

          final stats =
              buildStats(docs);

          return RefreshIndicator(
            onRefresh: () async {
              await syncTemporaryInvoiceConsultations(
                showMessage: false,
              );

              if (!mounted) return;

              setState(() {});
            },
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.only(
                bottom: 100,
              ),
              children: [
                buildFiltersCard(stats),
                const SizedBox(height: 18),
                if (filteredDocs.isEmpty)
                  buildEmptyState()
                else
                  ...filteredDocs.map(
                    buildInvoiceCard,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InvoiceInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool strong;

  const _InvoiceInfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = strong
        ? AppColors.primary
        : AppColors.textDark;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: strong
                ? AppColors.primary
                : AppColors.textLight,
          ),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: TextStyle(
              color: strong
                  ? AppColors.primary
                  : AppColors.textLight,
              fontWeight:
                  FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty
                  ? '-'
                  : value,
              style: TextStyle(
                color: color,
                fontWeight: strong
                    ? FontWeight.w900
                    : FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusOptionTile extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOptionTile({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 13,
        backgroundColor:
            color.withOpacity(0.15),
        child: Icon(
          selected
              ? Icons.check
              : Icons.circle,
          size: selected ? 16 : 10,
          color: color,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected
              ? FontWeight.w800
              : FontWeight.w600,
          color: selected
              ? color
              : AppColors.textDark,
        ),
      ),
    );
  }
}