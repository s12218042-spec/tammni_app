import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class CreateNurseryInvoicePage extends StatefulWidget {
  const CreateNurseryInvoicePage({super.key});

  @override
  State<CreateNurseryInvoicePage> createState() =>
      _CreateNurseryInvoicePageState();
}

class _CreateNurseryInvoicePageState extends State<CreateNurseryInvoicePage> {
  final _formKey = GlobalKey<FormState>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;



  final paidAmountCtrl = TextEditingController(text: '0');
  final manualDiscountCtrl = TextEditingController(text: '0');
  final discountNotesCtrl = TextEditingController();
  final notesCtrl = TextEditingController();


  Map<String, dynamic>? selectedChild;
  Map<String, dynamic>? selectedSecondChild;
  Map<String, dynamic>? selectedOffer;

  double extraHoursAmount = 0;
  List<String> linkedExtraHoursIds = [];

  double consultationsAmount = 0;
  List<String> linkedConsultationIds = [];
  List<Map<String, dynamic>> selectedConsultations = [];


  bool isLoading = false;

  @override
  void dispose() {
    paidAmountCtrl.dispose();
    manualDiscountCtrl.dispose();
    discountNotesCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  bool get isTwoChildrenOffer {
    if (selectedOffer == null) return false;

    final id = (selectedOffer!['id'] ?? '').toString().toLowerCase();
    final title = (selectedOffer!['title'] ?? selectedOffer!['name'] ?? '')
        .toString()
        .toLowerCase();
    final description =
        (selectedOffer!['description'] ?? '').toString().toLowerCase();

    final childrenCount = _numValue(
      selectedOffer!['childrenCount'] ??
          selectedOffer!['maxChildren'] ??
          selectedOffer!['numberOfChildren'],
    );

    final finalPrice = _numValue(
      selectedOffer!['finalPrice'] ??
          selectedOffer!['price'] ??
          selectedOffer!['offerPrice'],
    );

    return childrenCount >= 2 ||
        id.contains('two') ||
        id.contains('2') ||
        title.contains('طفلين') ||
        title.contains('طفلان') ||
        title.contains('أخوين') ||
        title.contains('اخوين') ||
        title.contains('two') ||
        description.contains('طفلين') ||
        description.contains('طفلان') ||
        description.contains('أخوين') ||
        description.contains('اخوين') ||
        finalPrice == 1100;
  }

  int get invoiceChildrenCount => isTwoChildrenOffer ? 2 : 1;

  String get invoiceCategory => 'nursery_fee';

  double _parseAmount(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  double _numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<String> _readStringList(dynamic value) {
    if (value is! Iterable) return <String>[];

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  List<Map<String, dynamic>> _readMapList(dynamic value) {
    if (value is! Iterable) return <Map<String, dynamic>>[];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  bool _isBillableMonthlyChild(Map<String, dynamic> data) {
    final status = (data['status'] ?? data['childStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final childType = (data['childType'] ??
            data['enrollmentType'] ??
            data['type'] ??
            data['childStatus'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final isActiveValue = data['isActive'];
    final isActive = isActiveValue == null
        ? status != 'inactive' &&
            status != 'withdrawn' &&
            status != 'rejected_after_trial' &&
            status != 'archived'
        : isActiveValue == true;

    final isTrial = childType == 'trial' ||
        status == 'trial' ||
        data['isTrialChild'] == true;

    final isTemporary = childType == 'temporary' ||
        childType == 'temp' ||
        childType == 'temporary_child' ||
        childType == 'مؤقت' ||
        status == 'temporary' ||
        data['isTemporaryChild'] == true;

    final excludedFromMonthly =
        data['excludeFromMonthlyInvoice'] == true || data['isBillable'] == false;

    return isActive && !isTrial && !isTemporary && !excludedFromMonthly;
  }

  String formatMoney(dynamic value) {
    final val = _numValue(value);
    if (val == val.roundToDouble()) return val.toInt().toString();
    return val.toStringAsFixed(2);
  }

  double get baseAmount => 700;
  double get paidAmountRaw => _parseAmount(paidAmountCtrl);
  double get manualDiscountRaw => _parseAmount(manualDiscountCtrl);

  double get manualDiscount {
    if (manualDiscountRaw < 0) return 0;
    return manualDiscountRaw;
  }

  double get childrenBaseAmount => baseAmount * invoiceChildrenCount;

  double get offerDiscount {
    if (selectedOffer == null) {
      return 0;
    }

    final type = (selectedOffer!['discountType'] ??
            selectedOffer!['type'] ??
            selectedOffer!['offerType'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final discountValue = _numValue(
      selectedOffer!['discountValue'] ??
          selectedOffer!['discount'] ??
          selectedOffer!['amount'],
    );

    final offerPrice = _numValue(
      selectedOffer!['finalPrice'] ??
          selectedOffer!['price'] ??
          selectedOffer!['offerPrice'],
    );

    if (offerPrice > 0 && childrenBaseAmount > offerPrice) {
      return childrenBaseAmount - offerPrice;
    }

    if (type == 'percentage' || type == 'percent') {
      return childrenBaseAmount * (discountValue / 100);
    }

    return discountValue;
  }

  double get totalDiscount {
    return offerDiscount + manualDiscount;
  }

  double get subtotalAmount => childrenBaseAmount;

  double get totalAmount {
    final total =
        subtotalAmount - totalDiscount + extraHoursAmount + consultationsAmount;

    return total < 0 ? 0 : total;
  }

  double get paidAmount {
    if (paidAmountRaw < 0) return 0;
    if (paidAmountRaw > totalAmount) return totalAmount;
    return paidAmountRaw;
  }

  double get remainingAmount {
    final remaining = totalAmount - paidAmount;
    return remaining < 0 ? 0 : remaining;
  }

  String get calculatedPaymentStatus {
    if (totalAmount <= 0) return 'unpaid';
    if (paidAmount <= 0) return 'unpaid';
    if (paidAmount >= totalAmount) return 'paid';
    return 'partial';
  }

  String paymentStatusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'paid':
        return 'مدفوعة';
      case 'partial':
        return 'مدفوعة جزئيًا';
      case 'unpaid':
      default:
        return 'غير مدفوعة';
    }
  }

  String paymentMethodLabel() {
    return 'كاش';
  }

  String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  DateTime? _dateFromInvoiceValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _invoiceMonthKeyFromData(Map<String, dynamic> data) {
    final direct = (data['billingMonthKey'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final start = _dateFromInvoiceValue(data['startDate']);
    if (start != null) return _monthKey(start);

    final due = _dateFromInvoiceValue(data['dueDate']);
    if (due != null) return _monthKey(due);

    final created = _dateFromInvoiceValue(data['createdAt']);
    if (created != null) return _monthKey(created);

    return '';
  }

  bool _isActiveInvoiceForDuplicateCheck(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    final paymentStatus =
        (data['paymentStatus'] ?? '').toString().trim().toLowerCase();
    final invoiceStatus =
        (data['invoiceStatus'] ?? '').toString().trim().toLowerCase();

    const badStatuses = {
      'cancelled',
      'canceled',
      'deleted',
      'void',
      'superseded',
      'draft',
    };

    return !badStatuses.contains(status) &&
        !badStatuses.contains(paymentStatus) &&
        !badStatuses.contains(invoiceStatus);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      fetchSameParentMonthlyInvoices({
    required String parentUid,
    required String parentUsername,
    required String billingMonthKey,
  }) async {
    if (billingMonthKey.isEmpty) return [];

    QuerySnapshot<Map<String, dynamic>> snapshot;

    if (parentUid.trim().isNotEmpty) {
      snapshot = await _firestore
          .collection('invoices')
          .where('parentUid', isEqualTo: parentUid.trim())
          .get();
    } else if (parentUsername.trim().isNotEmpty) {
      snapshot = await _firestore
          .collection('invoices')
          .where(
            'parentUsername',
            isEqualTo: parentUsername.trim().toLowerCase(),
          )
          .get();
    } else {
      return [];
    }

    final docs = snapshot.docs.where((doc) {
      final data = doc.data();

      final category = (data['invoiceCategory'] ?? '').toString();
      final type = (data['billingType'] ?? '').toString();

      final isNurseryFee =
          category.isEmpty || category == 'nursery_fee' || category == 'monthly';

      final isMonthly = type.isEmpty || type == 'monthly';

      final docMonthKey = _invoiceMonthKeyFromData(data);

      return isNurseryFee &&
          isMonthly &&
          docMonthKey == billingMonthKey &&
          _isActiveInvoiceForDuplicateCheck(data);
    }).toList();

    docs.sort((a, b) {
      final aDate = _dateFromInvoiceValue(a.data()['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _dateFromInvoiceValue(b.data()['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });

    return docs;
  }

  Future<List<Map<String, dynamic>>> fetchActiveChildrenForSameParent(
    Map<String, dynamic> child,
  ) async {
    final parentUid = (child['parentUid'] ?? '').toString().trim();
    final parentUsername =
        (child['parentUsername'] ?? '').toString().trim().toLowerCase();

    QuerySnapshot<Map<String, dynamic>> snapshot;

    if (parentUid.isNotEmpty) {
      snapshot = await _firestore
          .collection('children')
          .where('parentUid', isEqualTo: parentUid)
          .get();
    } else if (parentUsername.isNotEmpty) {
      snapshot = await _firestore
          .collection('children')
          .where('parentUsername', isEqualTo: parentUsername)
          .get();
    } else {
      return [];
    }

    final children = snapshot.docs.map((doc) {
      final data = doc.data();

      final section = (data['section'] ??
              data['childSection'] ??
              data['nurserySection'] ??
              'Nursery')
          .toString();

      final status = (data['status'] ?? data['childStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final isActiveValue = data['isActive'];
      final isActive = isActiveValue == null
          ? status != 'inactive' &&
              status != 'withdrawn' &&
              status != 'rejected_after_trial' &&
              status != 'archived'
          : isActiveValue == true;

      return {
        'id': doc.id,
        'name': (data['name'] ??
                data['childName'] ??
                data['fullName'] ??
                'طفل بدون اسم')
            .toString(),
        'section': section,
        'group': (data['groupName'] ?? data['group'] ?? '').toString(),
        'parentName': (data['parentName'] ?? '').toString(),
        'parentUid': (data['parentUid'] ?? '').toString(),
        'parentUsername': (data['parentUsername'] ?? '').toString(),
        'childType': (data['childType'] ??
                data['enrollmentType'] ??
                data['type'] ??
                data['childStatus'] ??
                '')
            .toString()
            .trim()
            .toLowerCase(),
        'childStatus': status,
        'isTemporaryChild': data['isTemporaryChild'] == true,
        'isTrialChild': data['isTrialChild'] == true,
        'isBillable': data['isBillable'],
        'excludeFromMonthlyInvoice': data['excludeFromMonthlyInvoice'] == true,
        'isActive': isActive,
        '_rawData': data,
      };
    }).where((item) {
      final section = (item['section'] ?? '').toString().trim().toLowerCase();
      final isNurseryLike = section.isEmpty ||
          section == 'nursery' ||
          section == 'حضانة' ||
          section == 'nursery_section';

      final rawData = item['_rawData'];

      return item['isActive'] == true &&
          isNurseryLike &&
          rawData is Map<String, dynamic> &&
          _isBillableMonthlyChild(rawData);
    }).toList();

    return children;
  }

  List<Map<String, dynamic>> secondChildrenOptions(
    List<Map<String, dynamic>> children,
  ) {
    if (selectedChild == null) return [];

    final firstId = (selectedChild!['id'] ?? '').toString();
    final firstParentUid = (selectedChild!['parentUid'] ?? '').toString();
    final firstParentUsername =
        (selectedChild!['parentUsername'] ?? '').toString().toLowerCase();

    final filtered = children.where((child) {
      final childId = (child['id'] ?? '').toString();
      if (childId == firstId) return false;

      final parentUid = (child['parentUid'] ?? '').toString();
      final parentUsername =
          (child['parentUsername'] ?? '').toString().toLowerCase();

      if (firstParentUid.isNotEmpty || firstParentUsername.isNotEmpty) {
        return (firstParentUid.isNotEmpty && parentUid == firstParentUid) ||
            (firstParentUsername.isNotEmpty &&
                parentUsername == firstParentUsername);
      }

      return true;
    }).toList();

    return filtered;
  }

  List<Map<String, dynamic>> selectedInvoiceChildren() {
    final list = <Map<String, dynamic>>[];

    if (selectedChild != null) list.add(selectedChild!);
    if (isTwoChildrenOffer && selectedSecondChild != null) {
      list.add(selectedSecondChild!);
    }

    return list;
  }

  Future<List<Map<String, dynamic>>> fetchNurseryChildren() async {
    final snapshot = await _firestore.collection('children').get();

    final children = snapshot.docs.map((doc) {
      final data = doc.data();

      final section = (data['section'] ??
              data['childSection'] ??
              data['nurserySection'] ??
              'Nursery')
          .toString();

      final isActiveValue = data['isActive'];
      final status = (data['status'] ?? data['childStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final childType = (data['childType'] ??
              data['enrollmentType'] ??
              data['type'] ??
              data['childStatus'] ??
              '')
          .toString()
          .trim()
          .toLowerCase();

      final isTemporary = childType == 'temporary' ||
          childType == 'temp' ||
          childType == 'temporary_child' ||
          childType == 'مؤقت' ||
          status == 'temporary' ||
          data['isTemporaryChild'] == true;

      final isTrial = childType == 'trial' ||
          status == 'trial' ||
          data['isTrialChild'] == true;

      final excludedFromMonthly =
          data['excludeFromMonthlyInvoice'] == true ||
              data['isBillable'] == false;

      final isActive = isActiveValue == null
          ? status != 'inactive' &&
              status != 'withdrawn' &&
              status != 'rejected_after_trial' &&
              status != 'archived'
          : isActiveValue == true;

      return {
        'id': doc.id,
        'name': (data['name'] ??
                data['childName'] ??
                data['fullName'] ??
                'طفل بدون اسم')
            .toString(),
        'section': section.isEmpty ? 'Nursery' : section,
        'group': (data['groupName'] ?? data['group'] ?? '').toString(),
        'parentName': (data['parentName'] ?? '').toString(),
        'parentUsername': (data['parentUsername'] ?? '').toString(),
        'parentUid': (data['parentUid'] ?? '').toString(),
        'childType': childType,
        'childStatus': status,
        'isTemporaryChild': isTemporary,
        'isTrialChild': isTrial,
        'isBillable': data['isBillable'],
        'excludeFromMonthlyInvoice': excludedFromMonthly,
        'isActive': isActive,
      };
    }).where((child) {
      final name = (child['name'] ?? '').toString().trim();
      final section = (child['section'] ?? '').toString().trim().toLowerCase();
      final isActive = child['isActive'] == true;

      final isNurseryLike = section.isEmpty ||
          section == 'nursery' ||
          section == 'حضانة' ||
          section == 'nursery_section';

      final isTrial = child['isTrialChild'] == true;
      final isTemporary = child['isTemporaryChild'] == true;
      final excludedFromMonthly = child['excludeFromMonthlyInvoice'] == true;
      final notBillable = child['isBillable'] == false;

      return name.isNotEmpty &&
          isActive &&
          isNurseryLike &&
          !isTrial &&
          !isTemporary &&
          !excludedFromMonthly &&
          !notBillable;
    }).toList();

    children.sort(
      (a, b) => (a['name'] as String).toLowerCase().compareTo(
            (b['name'] as String).toLowerCase(),
          ),
    );

    return children;
  }

  Future<List<Map<String, dynamic>>> fetchActiveOffers() async {
    final collectionNames = [
      'offers',
      'nursery_offers',
      'subscriptions',
      'nursery_subscriptions',
    ];

    final List<Map<String, dynamic>> allOffers = [];

    for (final collectionName in collectionNames) {
      try {
        final snapshot = await _firestore.collection(collectionName).get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().trim().toLowerCase();

          final isActive = data['isActive'] != false &&
              data['active'] != false &&
              data['disabled'] != true &&
              data['isDisabled'] != true &&
              status != 'inactive' &&
              status != 'disabled' &&
              status != 'archived';

          if (!isActive) continue;

          allOffers.add({
            'id': doc.id,
            'dropdownValue': '$collectionName/${doc.id}',
            'collectionName': collectionName,
            ...data,
            'isActive': true,
          });
        }
      } catch (_) {}
    }

    if (allOffers.isEmpty) {
      allOffers.addAll([
        {
          'id': 'default_monthly_700',
          'dropdownValue': 'default/default_monthly_700',
          'collectionName': 'default',
          'title': 'الاشتراك الأساسي',
          'description': 'اشتراك شهري بقيمة 700 شيكل',
          'price': 700,
          'finalPrice': 700,
          'discountValue': 0,
          'discountType': 'fixed',
          'childrenCount': 1,
          'isActive': true,
          'isDefaultOffer': true,
        },
        {
          'id': 'default_offer_600',
          'dropdownValue': 'default/default_offer_600',
          'collectionName': 'default',
          'title': 'عرض 600 شيكل',
          'description': 'عرض خاص لطفل واحد بقيمة 600 شيكل',
          'price': 600,
          'finalPrice': 600,
          'discountValue': 100,
          'discountType': 'fixed',
          'childrenCount': 1,
          'isActive': true,
          'isDefaultOffer': true,
        },
        {
          'id': 'default_two_children_1100',
          'dropdownValue': 'default/default_two_children_1100',
          'collectionName': 'default',
          'title': 'عرض طفلين 1100 شيكل',
          'description': 'عرض خاص لتسجيل طفلين بقيمة 1100 شيكل',
          'price': 1100,
          'finalPrice': 1100,
          'discountValue': 300,
          'discountType': 'fixed',
          'childrenCount': 2,
          'isActive': true,
          'isDefaultOffer': true,
        },
      ]);
    }

    allOffers.sort((a, b) {
      final aName = (a['title'] ?? a['name'] ?? '').toString();
      final bName = (b['title'] ?? b['name'] ?? '').toString();
      return aName.compareTo(bName);
    });

    return allOffers;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      fetchPendingExtraHoursDocs(List<String> childIds) async {
    final cleanChildIds = childIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (cleanChildIds.isEmpty) return [];

    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final seenIds = <String>{};

    for (final childId in cleanChildIds) {
      final snapshot = await _firestore
          .collection('extra_child_hours')
          .where('childId', isEqualTo: childId)
          .where('status', isEqualTo: 'pending_invoice')
          .get();

      for (final doc in snapshot.docs) {
        if (seenIds.add(doc.id)) {
          docs.add(doc);
        }
      }
    }

    return docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      fetchPendingConsultationsDocs(List<String> childIds) async {
    final cleanChildIds = childIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (cleanChildIds.isEmpty) return [];

    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final seenIds = <String>{};

    for (final childId in cleanChildIds) {
      final snapshot = await _firestore
          .collection('child_consultations')
          .where('childId', isEqualTo: childId)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final approval =
            (data['parentApprovalStatus'] ?? '').toString().trim().toLowerCase();

        final invoiceStatus =
            (data['invoiceStatus'] ?? '').toString().trim().toLowerCase();

        final billingStatus =
            (data['billingStatus'] ?? '').toString().trim().toLowerCase();

        final consultationStatus = (data['consultationStatus'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final addedToInvoice = data['addedToInvoice'] == true;
        final billable = data['billable'] == true;
        final linkedInvoiceId = (data['invoiceId'] ?? '').toString().trim();
        final childType = (data['childType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final isTrialChild = data['isTrialChild'] == true ||
            childType == 'trial';

        final isReady = invoiceStatus == 'ready_for_invoice' ||
            billingStatus == 'ready_for_invoice';

        if (approval == 'approved' &&
            consultationStatus == 'completed' &&
            billable &&
            !isTrialChild &&
            isReady &&
            !addedToInvoice &&
            linkedInvoiceId.isEmpty &&
            seenIds.add(doc.id)) {
          docs.add(doc);
        }
      }
    }

    return docs;
  }

  double calculateExtraHoursTotal(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    double total = 0;

    for (final doc in docs) {
      total += _numValue(doc.data()['totalAmount']);
    }

    return total;
  }

  double calculateConsultationsTotal(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    double total = 0;

    for (final doc in docs) {
      final data = doc.data();
      total += _numValue(data['totalAmount']);
    }

    return total;
  }

  Future<Map<String, String>> getCurrentUserInfo() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'uid': '', 'name': 'مستخدم', 'role': ''};
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
                'مستخدم')
            .toString(),
        'role': (data['role'] ?? '').toString(),
      };
    } catch (_) {
      return {'uid': user.uid, 'name': 'مستخدم', 'role': ''};
    }
  }

  Future<void> sendInvoiceCreatedNotification({
    required String invoiceId,
    required bool isUpdatingExistingInvoice,
    required Map<String, String> currentUser,
    required List<String> childrenNames,
  }) async {
    final parentUid = (selectedChild?['parentUid'] ?? '').toString().trim();
    final parentUsername =
        (selectedChild?['parentUsername'] ?? '').toString().trim().toLowerCase();
    final parentName = (selectedChild?['parentName'] ?? '').toString().trim();

    if (parentUid.isEmpty && parentUsername.isEmpty) return;

    final cleanChildrenNames = childrenNames
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final childrenText = cleanChildrenNames.isEmpty
        ? (selectedChild?['name'] ?? 'الطفل').toString()
        : cleanChildrenNames.join('، ');

    const invoiceTitle = 'فاتورة حضانة';

    final actionText =
        isUpdatingExistingInvoice ? 'تم تحديث الفاتورة' : 'تم إنشاء فاتورة جديدة';

    await AppNotificationService.instance.notifyParent(
      parentUid: parentUid,
      parentUsername: parentUsername,
      parentName: parentName,
      title: isUpdatingExistingInvoice
          ? 'تم تحديث فاتورة الحضانة'
          : 'فاتورة حضانة جديدة',
      body:
          '$actionText "$invoiceTitle" للأطفال: $childrenText. الإجمالي: ${formatMoney(totalAmount)} شيكل، المدفوع: ${formatMoney(paidAmount)} شيكل، المتبقي: ${formatMoney(remainingAmount)} شيكل.',
      type: isUpdatingExistingInvoice ? 'invoice_updated' : 'invoice_created',
      childId: (selectedChild?['id'] ?? '').toString(),
      childName: childrenText,
      section: (selectedChild?['section'] ?? 'Nursery').toString(),
      group: (selectedChild?['group'] ?? '').toString(),
      priority: calculatedPaymentStatus == 'paid' ? 'normal' : 'important',
      createdByUid: currentUser['uid'] ?? '',
      createdByName: currentUser['name'] ?? 'الإدارة',
      createdByRole: currentUser['role'] ?? 'admin',
      extraData: {
        'invoiceId': invoiceId,
        'invoiceStatus': calculatedPaymentStatus,
        'paymentStatus': calculatedPaymentStatus,
        'paymentMethod': 'cash',
        'billingType': 'monthly',
        'invoiceCategory': invoiceCategory,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'remainingAmount': remainingAmount,
        'childrenNames': childrenText,
        'childrenCount': invoiceChildrenCount,
        'category': 'invoice',
        'notificationType':
            isUpdatingExistingInvoice ? 'invoice_updated' : 'invoice_created',
        'screen': 'invoices',
        'route': 'parent_invoices',
        'relatedCollection': 'invoices',
      },
    );
  }

  Future<void> saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedChild == null) {
      _showSnack('اختر الطفل أولًا');
      return;
    }

    if (isTwoChildrenOffer) {
      if (selectedSecondChild == null) {
        _showSnack('اختر الطفل الثاني لعرض طفلين');
        return;
      }

      if (selectedSecondChild!['id'] == selectedChild!['id']) {
        _showSnack('لا يمكن اختيار نفس الطفل مرتين');
        return;
      }
    }

    if (!isTwoChildrenOffer) {
      final parentChildren =
          await fetchActiveChildrenForSameParent(selectedChild!);

      if (parentChildren.length >= 2) {
        _showSnack(
          'هذا ولي الأمر لديه طفلين أو أكثر. اختر عرض طفلين بدل إنشاء فاتورة 700 لطفل واحد.',
        );
        return;
      }
    }

    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = await getCurrentUserInfo();

      if (currentUser['role'] != 'admin') {
        _showSnack('فقط الأدمن يستطيع إنشاء الفواتير');
        return;
      }

      final now = DateTime.now();

      final invoiceMonthKey = _monthKey(now);

      final parentUid = (selectedChild!['parentUid'] ?? '').toString();
      final parentUsername =
          (selectedChild!['parentUsername'] ?? '').toString().toLowerCase();

      final sameParentInvoices = await fetchSameParentMonthlyInvoices(
        parentUid: parentUid,
        parentUsername: parentUsername,
        billingMonthKey: invoiceMonthKey,
      );

      final docRef = sameParentInvoices.isNotEmpty
          ? sameParentInvoices.first.reference
          : _firestore.collection('invoices').doc();

      final isUpdatingExistingInvoice = sameParentInvoices.isNotEmpty;
      final existingInvoiceData = isUpdatingExistingInvoice
          ? sameParentInvoices.first.data()
          : <String, dynamic>{};

      final invoiceChildren = selectedInvoiceChildren();
      final childrenIds = invoiceChildren
          .map((child) => (child['id'] ?? '').toString())
          .toList();

      final childrenNames = invoiceChildren
          .map((child) => (child['name'] ?? '').toString())
          .toList();

      final existingExtraHoursIds =
          _readStringList(existingInvoiceData['extraHoursIds']);
      final existingConsultationIds =
          _readStringList(existingInvoiceData['consultationIds']);

      final extraHoursDocs =
          (await fetchPendingExtraHoursDocs(childrenIds))
              .where((doc) => !existingExtraHoursIds.contains(doc.id))
              .toList();

      final consultationDocs =
          (await fetchPendingConsultationsDocs(childrenIds))
              .where((doc) => !existingConsultationIds.contains(doc.id))
              .toList();

      extraHoursAmount =
          _numValue(existingInvoiceData['extraHoursAmount'] ??
                  existingInvoiceData['extraHoursTotal']) +
              calculateExtraHoursTotal(extraHoursDocs);

      consultationsAmount =
          _numValue(existingInvoiceData['consultationsAmount']) +
              calculateConsultationsTotal(consultationDocs);

      linkedExtraHoursIds = <String>{
        ...existingExtraHoursIds,
        ...extraHoursDocs.map((doc) => doc.id),
      }.toList();

      linkedConsultationIds = <String>{
        ...existingConsultationIds,
        ...consultationDocs.map((doc) => doc.id),
      }.toList();

      final previousConsultations =
          _readMapList(existingInvoiceData['consultations']);
      final previousConsultationIds = previousConsultations
          .map((item) => (item['consultationId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      selectedConsultations = [
        ...previousConsultations,
        ...consultationDocs.where((doc) {
          return !previousConsultationIds.contains(doc.id);
        }).map((doc) {
          final data = doc.data();

          return {
            'consultationId': doc.id,
            'title': data['title'] ?? '',
            'childId': data['childId'] ?? '',
            'childName': data['childName'] ?? '',
            'hours': data['hours'] ?? 1,
            'hourlyPrice': data['hourlyPrice'] ?? 50,
            'totalAmount': data['totalAmount'] ?? 0,
            'childType': data['childType'] ?? '',
            'isTemporaryChild': data['isTemporaryChild'] == true,
            'isTrialChild': data['isTrialChild'] == true,
          };
        }),
      ];

      if (totalAmount <= 0) {
        _showSnack('المبلغ الإجمالي يجب أن يكون أكبر من صفر');
        return;
      }

      if (paidAmountRaw < 0) {
        _showSnack('المبلغ المدفوع لا يمكن أن يكون أقل من صفر');
        return;
      }

      if (paidAmountRaw > totalAmount) {
        _showSnack('المبلغ المدفوع لا يمكن أن يكون أكبر من الإجمالي');
        return;
      }

      if (manualDiscountRaw < 0) {
        _showSnack('الخصم لا يمكن أن يكون أقل من صفر');
        return;
      }

      if (manualDiscount >
          subtotalAmount + extraHoursAmount + consultationsAmount) {
        _showSnack('قيمة الخصم كبيرة جدًا');
        return;
      }

      final finalPaymentStatus = calculatedPaymentStatus;
      final paidAt = paidAmount > 0 ? Timestamp.fromDate(now) : null;

      final invoiceData = <String, dynamic>{
        'id': docRef.id,
        'childId': selectedChild!['id'] ?? '',
        'childName': selectedChild!['name'] ?? '',
        'childrenCount': invoiceChildren.length,
        'childrenIds': childrenIds,
        'childrenNames': childrenNames,
        'children': invoiceChildren
            .map(
              (child) => {
                'childId': child['id'] ?? '',
                'childName': child['name'] ?? '',
                'group': child['group'] ?? '',
                'section': child['section'] ?? 'Nursery',
                'parentUid': child['parentUid'] ?? '',
                'parentUsername': child['parentUsername'] ?? '',
                'childType': child['childType'] ?? '',
                'childStatus': child['childStatus'] ?? '',
                'isTemporaryChild': child['isTemporaryChild'] == true,
                'isTrialChild': child['isTrialChild'] == true,
                'isBillable': child['isBillable'],
                'excludeFromMonthlyInvoice':
                    child['excludeFromMonthlyInvoice'] == true,
              },
            )
            .toList(),
        'parentName': selectedChild!['parentName'] ?? '',
        'parentUsername': parentUsername,
        'parentUid': parentUid,
        'section': selectedChild!['section'] ?? 'Nursery',
        'group': selectedChild!['group'] ?? '',
        'invoiceCategory': invoiceCategory,
        'billingType': 'monthly',
        'billingMonthKey': invoiceMonthKey,
        'billingYear': now.year,
        'billingMonth': now.month,
        'title': 'فاتورة حضانة',
        'baseAmount': baseAmount,
        'baseAmountPerChild': baseAmount,
        'childrenBaseAmount': childrenBaseAmount,
        'subtotalAmount': subtotalAmount,
        'extraHoursAmount': extraHoursAmount,
        'extraHoursTotal': extraHoursAmount,
        'extraHoursIds': linkedExtraHoursIds,
        'consultationsAmount': consultationsAmount,
        'consultationIds': linkedConsultationIds,
        'consultations': selectedConsultations,
        'offerId': selectedOffer?['id'] ?? '',
        'offerTitle':
            (selectedOffer?['title'] ?? selectedOffer?['name'] ?? '').toString(),
        'offerCollectionName': selectedOffer?['collectionName'] ?? '',
        'isDefaultOffer': selectedOffer?['isDefaultOffer'] == true,
        'isTwoChildrenOffer': isTwoChildrenOffer,
        'offerDiscount': offerDiscount,
        'manualDiscount': manualDiscount,
        'discountAmount': manualDiscount,
        'totalDiscount': totalDiscount,
        'discountNotes': discountNotesCtrl.text.trim(),
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'remainingAmount': remainingAmount,
        'status': finalPaymentStatus,
        'paymentStatus': finalPaymentStatus,
        'invoiceStatus': finalPaymentStatus,
        'paymentMethod': 'cash',
        'paymentMethodLabel': paymentMethodLabel(),
        'paidAt': paidAt,
        'notes': notesCtrl.text.trim(),
        'updatedExistingInvoice': isUpdatingExistingInvoice,
        'updatedByUid': currentUser['uid'] ?? '',
        'updatedByName': currentUser['name'] ?? 'مستخدم',
        'updatedByRole': currentUser['role'] ?? '',
        'updatedAt': Timestamp.fromDate(now),
      };

      if (!isUpdatingExistingInvoice) {
        invoiceData['createdByUid'] = currentUser['uid'] ?? '';
        invoiceData['createdByName'] = currentUser['name'] ?? 'مستخدم';
        invoiceData['createdByRole'] = currentUser['role'] ?? '';
        invoiceData['createdAt'] = Timestamp.fromDate(now);
      }

      await docRef.set(invoiceData, SetOptions(merge: true));

      try {
        await sendInvoiceCreatedNotification(
          invoiceId: docRef.id,
          isUpdatingExistingInvoice: isUpdatingExistingInvoice,
          currentUser: currentUser,
          childrenNames: childrenNames,
        );
      } catch (e) {
        debugPrint('CreateNurseryInvoicePage: فشل إرسال إشعار الفاتورة: $e');
      }

      if (sameParentInvoices.length > 1) {
        final batch = _firestore.batch();

        for (final oldDoc in sameParentInvoices.skip(1)) {
          if (oldDoc.id == docRef.id) continue;

          batch.update(oldDoc.reference, {
            'status': 'superseded',
            'paymentStatus': 'superseded',
            'invoiceStatus': 'superseded',
            'supersededByInvoiceId': docRef.id,
            'updatedAt': Timestamp.fromDate(now),
          });
        }

        await batch.commit();
      }

      if (consultationDocs.isNotEmpty) {
        final batch = _firestore.batch();

        for (final doc in consultationDocs) {
          batch.update(doc.reference, {
            'invoiceId': docRef.id,
            'invoiceStatus': 'invoiced',
            'billingStatus': 'invoiced',
            'consultationStatus': 'completed',
            'addedToInvoice': true,
            'invoicedAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
          });
        }

        await batch.commit();
      }

      if (extraHoursDocs.isNotEmpty) {
        final batch = _firestore.batch();

        for (final doc in extraHoursDocs) {
          batch.update(doc.reference, {
            'invoiceId': docRef.id,
            'invoiceTitle': 'فاتورة حضانة',
            'status': 'invoiced',
            'updatedAt': Timestamp.fromDate(now),
          });
        }

        await batch.commit();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUpdatingExistingInvoice
                ? 'تم تحديث فاتورة الشهر بدل إنشاء فاتورة مكررة'
                : 'تم إنشاء الفاتورة بنجاح',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('حدث خطأ أثناء حفظ الفاتورة: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration customDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textLight),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
    );
  }

  Widget mainCard({required Widget child}) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }

  String offerLabel(Map<String, dynamic> offer) {
    final title = (offer['title'] ?? offer['name'] ?? 'عرض بدون اسم').toString();
    final price = _numValue(
      offer['finalPrice'] ?? offer['price'] ?? offer['offerPrice'],
    );
    final discount = _numValue(
      offer['discountValue'] ?? offer['discount'] ?? offer['amount'],
    );

    if (price > 0) return '$title • ${formatMoney(price)} شيكل';
    if (discount > 0) return '$title • خصم ${formatMoney(discount)}';
    return title;
  }

  String childLabel(Map<String, dynamic> child) {
    final group = (child['group'] ?? '').toString();
    final parent = (child['parentName'] ?? '').toString();

    return [
      (child['name'] ?? 'طفل بدون اسم').toString(),
      group.isEmpty ? 'بدون مجموعة' : group,
      if (parent.isNotEmpty) parent,
    ].join(' • ');
  }

  Widget selectedChildInfo(Map<String, dynamic> child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ولي الأمر: ${(child['parentName'] ?? '').toString().isEmpty ? 'غير محدد' : child['parentName']}',
          ),
          const SizedBox(height: 6),
          Text(
            'اسم المستخدم: ${(child['parentUsername'] ?? '').toString().isEmpty ? 'غير محدد' : child['parentUsername']}',
          ),
          const SizedBox(height: 6),
          Text(
            'المجموعة: ${(child['group'] ?? '').toString().isEmpty ? 'غير محدد' : child['group']}',
          ),  
        ],
      ),
    );
  }

  Widget amountSummaryCard() {
    return mainCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.calculate_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'عدد الأطفال: $invoiceChildrenCount\n'
                  'رسوم الأطفال: ${formatMoney(childrenBaseAmount)} شيكل\n'
                  'الإجمالي قبل الخصم: ${formatMoney(subtotalAmount)} شيكل\n'
                  'خصم العرض: ${formatMoney(offerDiscount)} شيكل\n'
                  'خصم إضافي: ${formatMoney(manualDiscount)} شيكل\n'
                  'الساعات الإضافية: ${formatMoney(extraHoursAmount)} شيكل\n'
                  'الإجمالي النهائي: ${formatMoney(totalAmount)} شيكل\n'
                  'المدفوع: ${formatMoney(paidAmount)} شيكل\n'
                  'المتبقي: ${formatMoney(remainingAmount)} شيكل\n'
                  'حالة الدفع: ${paymentStatusLabel(calculatedPaymentStatus)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : saveInvoice,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                isLoading ? 'جارٍ حفظ الفاتورة...' : 'حفظ الفاتورة',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'إنشاء فاتورة حضانة',
      child: Form(
        key: _formKey,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchNurseryChildren(),
          builder: (context, snapshot) {
            final children = snapshot.data ?? [];
            final secondOptions = secondChildrenOptions(children);

            if (selectedSecondChild != null &&
                !secondOptions.any(
                  (child) => child['id'] == selectedSecondChild!['id'],
                )) {
              selectedSecondChild = null;
            }

            if (selectedChild != null &&
                !children.any((child) => child['id'] == selectedChild!['id'])) {
              selectedChild = null;
              selectedSecondChild = null;
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                mainCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle('اختيار الطفل'),
                      const SizedBox(height: 14),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator())
                      else if (children.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'لا يوجد أطفال قابلون للفوترة الشهرية حاليًا',
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: selectedChild?['id']?.toString(),
                          isExpanded: true,
                          menuMaxHeight: 360,
                          decoration: customDecoration(
                            label: 'الطفل',
                            icon: Icons.child_care_rounded,
                          ),
                          items: children.map((child) {
                            return DropdownMenuItem<String>(
                              value: child['id'].toString(),
                              child: Text(
                                childLabel(child),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            );
                          }).toList(),
                          selectedItemBuilder: (context) {
                            return children.map((child) {
                              return Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  (child['name'] ?? 'طفل بدون اسم').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              );
                            }).toList();
                          },
                          onChanged: (value) {
                            if (value == null) return;

                            setState(() {
                              selectedChild = children.firstWhere(
                                (child) => child['id'].toString() == value,
                              );
                              selectedSecondChild = null;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'اختر الطفل';
                            }
                            return null;
                          },
                        ),
                      if (selectedChild != null) ...[
                        const SizedBox(height: 14),
                        selectedChildInfo(selectedChild!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                mainCard(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: fetchActiveOffers(),
                      builder: (context, offerSnapshot) {
                        final offers = offerSnapshot.data ?? [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionTitle('العروض والاشتراكات'),
                            const SizedBox(height: 14),
                            if (offerSnapshot.connectionState ==
                                ConnectionState.waiting)
                              const Center(child: CircularProgressIndicator())
                            else if (offers.isEmpty)
                              const Text('لا توجد عروض فعالة حاليًا')
                            else
                              DropdownButtonFormField<String>(
                                value: selectedOffer?['dropdownValue']?.toString(),
                                isExpanded: true,
                                menuMaxHeight: 360,
                                decoration: customDecoration(
                                  label: 'اختيار عرض',
                                  icon: Icons.local_offer_outlined,
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text(
                                      'بدون عرض',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  ...offers.map((offer) {
                                    return DropdownMenuItem<String>(
                                      value: offer['dropdownValue'].toString(),
                                      child: Text(
                                        offerLabel(offer),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    if (value == null || value.isEmpty) {
                                      selectedOffer = null;
                                      selectedSecondChild = null;
                                    } else {
                                      selectedOffer = offers.firstWhere(
                                        (offer) => offer['dropdownValue'].toString() == value,
                                      );

                                      if (!isTwoChildrenOffer) {
                                        selectedSecondChild = null;
                                      }
                                    }
                                  });
                                },
                              ),
                            if (isTwoChildrenOffer) ...[
                              const SizedBox(height: 14),
                              if (selectedChild == null)
                                const Text('اختر الطفل الأول أولًا')
                              else if (secondOptions.isEmpty)
                                const Text('لا يوجد طفل ثاني لنفس ولي الأمر')
                              else
                                DropdownButtonFormField<String>(
                                  value: selectedSecondChild?['id']?.toString(),
                                  isExpanded: true,
                                  menuMaxHeight: 360,
                                  decoration: customDecoration(
                                    label: 'الطفل الثاني للعرض',
                                    icon: Icons.child_friendly_rounded,
                                  ),
                                  items: secondOptions.map((child) {
                                    return DropdownMenuItem<String>(
                                      value: child['id'].toString(),
                                      child: Text(
                                        childLabel(child),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                      ),
                                    );
                                  }).toList(),
                                  selectedItemBuilder: (context) {
                                    return secondOptions.map((child) {
                                      return Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          (child['name'] ?? 'طفل بدون اسم').toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                        ),
                                      );
                                    }).toList();
                                  },
                                  onChanged: (value) {
                                    if (value == null) return;

                                    setState(() {
                                      selectedSecondChild = secondOptions.firstWhere(
                                        (child) => child['id'].toString() == value,
                                      );
                                    });
                                  },
                                  validator: (value) {
                                    if (isTwoChildrenOffer &&
                                        (value == null || value.isEmpty)) {
                                      return 'اختر الطفل الثاني';
                                    }
                                    return null;
                                  },
                                ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 14),
                mainCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle('الخصم والدفع'),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: manualDiscountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: customDecoration(
                          label: 'خصم إضافي',
                          icon: Icons.discount_outlined,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: discountNotesCtrl,
                        maxLines: 2,
                        decoration: customDecoration(
                          label: 'ملاحظات الخصم',
                          icon: Icons.notes_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: paidAmountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: customDecoration(
                          label: 'المبلغ المدفوع',
                          icon: Icons.price_check_rounded,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                mainCard(
                  child: TextFormField(
                    controller: notesCtrl,
                    maxLines: 4,
                    decoration: customDecoration(
                      label: 'ملاحظات',
                      icon: Icons.notes_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                amountSummaryCard(),
              ],
            );
          },
        ),
      ),
    );
  }
}