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

  final titleCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();

  // هذا المبلغ هو سعر الطفل الواحد بالشهر.
  final baseAmountCtrl = TextEditingController(text: '700');
  final transportFeeCtrl = TextEditingController();
  final mealsFeeCtrl = TextEditingController();
  final registrationFeeCtrl = TextEditingController();
  final lateFeeCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  String selectedBillingType = 'monthly';
  String selectedPaymentStatus = 'unpaid';
  Map<String, dynamic>? selectedChild;
  Map<String, dynamic>? selectedSecondChild;
  Map<String, dynamic>? selectedOffer;

  double extraHoursAmount = 0;
  List<String> linkedExtraHoursIds = [];

  double consultationsAmount = 0;
  List<String> linkedConsultationIds = [];
  List<Map<String, dynamic>> selectedConsultations = [];

  DateTime? startDate;
  DateTime? endDate;
  DateTime? dueDate;

  bool isLoading = false;

  @override
  void dispose() {
    titleCtrl.dispose();
    descriptionCtrl.dispose();
    baseAmountCtrl.dispose();
    transportFeeCtrl.dispose();
    mealsFeeCtrl.dispose();
    registrationFeeCtrl.dispose();
    lateFeeCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  bool get isRegistrationInvoice => selectedBillingType == 'registration';
  bool get isLateFeeInvoice => selectedBillingType == 'late_fee';

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

  String get invoiceCategory {
    switch (selectedBillingType) {
      case 'registration':
        return 'registration_fee';
      case 'late_fee':
        return 'late_fee';
      default:
        return 'nursery_fee';
    }
  }

  double _parseAmount(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  double _numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double get baseAmount => _parseAmount(baseAmountCtrl);
  double get transportFee => _parseAmount(transportFeeCtrl);
  double get mealsFee => _parseAmount(mealsFeeCtrl);
  double get registrationFee => _parseAmount(registrationFeeCtrl);
  double get lateFee => _parseAmount(lateFeeCtrl);

  double get childrenBaseAmount {
    if (isRegistrationInvoice || isLateFeeInvoice) return baseAmount;
    return baseAmount * invoiceChildrenCount;
  }

  double get offerDiscount {
    if (selectedOffer == null || isRegistrationInvoice || isLateFeeInvoice) {
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

  double get subtotalAmount {
    if (isRegistrationInvoice) return registrationFee;
    if (isLateFeeInvoice) return lateFee;

    return childrenBaseAmount + transportFee + mealsFee;
  }

  double get totalAmount {
    final total =
        subtotalAmount - offerDiscount + extraHoursAmount + consultationsAmount;

    return total < 0 ? 0 : total;
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
          .where('parentUsername',
              isEqualTo: parentUsername.trim().toLowerCase())
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
              status != 'rejected_after_trial'
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
        'isActive': isActive,
      };
    }).where((item) {
      final section = (item['section'] ?? '').toString().trim().toLowerCase();
      final isNurseryLike = section.isEmpty ||
          section == 'nursery' ||
          section == 'حضانة' ||
          section == 'nursery_section';

      return item['isActive'] == true && isNurseryLike;
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

      final isActive = isActiveValue == null
          ? status != 'inactive' &&
              status != 'withdrawn' &&
              status != 'rejected_after_trial'
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

      return name.isNotEmpty && isActive && isNurseryLike;
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
          .where('parentApprovalStatus', isEqualTo: 'approved')
          .where(
            'invoiceStatus',
            whereIn: ['pending_invoice', 'ready_for_invoice'],
          )
          .get();

      for (final doc in snapshot.docs) {
        if (seenIds.add(doc.id)) {
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

  Future<void> pickDate({
    required DateTime? initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked == null) return;
    onPicked(picked);
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
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

  final invoiceTitle = titleCtrl.text.trim().isEmpty
      ? 'فاتورة حضانة'
      : titleCtrl.text.trim();

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
        '$actionText "$invoiceTitle" للأطفال: $childrenText. المبلغ: ${totalAmount.toStringAsFixed(0)} شيكل، تاريخ الاستحقاق: ${formatDate(dueDate)}.',
    type: isUpdatingExistingInvoice ? 'invoice_updated' : 'invoice_created',
    childId: (selectedChild?['id'] ?? '').toString(),
    childName: childrenText,
    section: (selectedChild?['section'] ?? 'Nursery').toString(),
    group: (selectedChild?['group'] ?? '').toString(),
    priority: selectedPaymentStatus == 'unpaid' ? 'important' : 'normal',
    createdByUid: currentUser['uid'] ?? '',
    createdByName: currentUser['name'] ?? 'الإدارة',
    createdByRole: currentUser['role'] ?? 'admin',
    extraData: {
      'invoiceId': invoiceId,
      'invoiceStatus': selectedPaymentStatus,
      'paymentStatus': selectedPaymentStatus,
      'billingType': selectedBillingType,
      'invoiceCategory': invoiceCategory,
      'totalAmount': totalAmount,
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
      _showSnack('اختاري الطفل أولًا');
      return;
    }

    if (isTwoChildrenOffer) {
      if (selectedSecondChild == null) {
        _showSnack('اختاري الطفل الثاني لعرض طفلين');
        return;
      }

      if (selectedSecondChild!['id'] == selectedChild!['id']) {
        _showSnack('لا يمكن اختيار نفس الطفل مرتين');
        return;
      }
    }

    if (dueDate == null) {
      _showSnack('حددي تاريخ الاستحقاق');
      return;
    }

    if (!isRegistrationInvoice && !isLateFeeInvoice) {
      if (startDate == null || endDate == null) {
        _showSnack('حددي تاريخ البداية والنهاية');
        return;
      }

      if (endDate!.isBefore(startDate!)) {
        _showSnack('تاريخ النهاية يجب أن يكون بعد تاريخ البداية');
        return;
      }
    }

    if (totalAmount <= 0) {
      _showSnack('المبلغ الإجمالي يجب أن يكون أكبر من صفر');
      return;
    }

    if (selectedBillingType == 'monthly' && !isTwoChildrenOffer) {
      final parentChildren =
          await fetchActiveChildrenForSameParent(selectedChild!);

      if (parentChildren.length >= 2) {
        _showSnack(
          'هذا ولي الأمر لديه طفلين أو أكثر. اختاري عرض طفلين بدل إنشاء فاتورة 700 لطفل واحد.',
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

      final invoiceMonthKey = selectedBillingType == 'monthly'
          ? _monthKey(startDate ?? dueDate ?? now)
          : '';

      final parentUid = (selectedChild!['parentUid'] ?? '').toString();
      final parentUsername =
          (selectedChild!['parentUsername'] ?? '').toString().toLowerCase();

      final sameParentInvoices = selectedBillingType == 'monthly'
          ? await fetchSameParentMonthlyInvoices(
              parentUid: parentUid,
              parentUsername: parentUsername,
              billingMonthKey: invoiceMonthKey,
            )
          : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      final docRef = sameParentInvoices.isNotEmpty
          ? sameParentInvoices.first.reference
          : _firestore.collection('invoices').doc();

      final isUpdatingExistingInvoice = sameParentInvoices.isNotEmpty;

      final invoiceChildren = selectedInvoiceChildren();
      final childrenIds = invoiceChildren
          .map((child) => (child['id'] ?? '').toString())
          .toList();
      final childrenNames = invoiceChildren
          .map((child) => (child['name'] ?? '').toString())
          .toList();

      final extraHoursDocs = await fetchPendingExtraHoursDocs(childrenIds);
      final pendingExtraHoursAmount = calculateExtraHoursTotal(extraHoursDocs);

      extraHoursAmount = pendingExtraHoursAmount;
      linkedExtraHoursIds = extraHoursDocs.map((doc) => doc.id).toList();

      final consultationDocs = await fetchPendingConsultationsDocs(childrenIds);

      consultationsAmount = calculateConsultationsTotal(consultationDocs);

      linkedConsultationIds = consultationDocs.map((doc) => doc.id).toList();

      selectedConsultations = consultationDocs.map((doc) {
        final data = doc.data();

        return {
          'consultationId': doc.id,
          'title': data['title'] ?? '',
          'childId': data['childId'] ?? '',
          'childName': data['childName'] ?? '',
          'hours': data['hours'] ?? 1,
          'totalAmount': data['totalAmount'] ?? 0,
        };
      }).toList();

      await docRef.set({
        'id': docRef.id,

        // حقول قديمة حتى لا تنكسر صفحات العرض الحالية.
        'childId': selectedChild!['id'] ?? '',
        'childName': selectedChild!['name'] ?? '',

        // حقول جديدة لدعم فاتورة طفلين/أكثر.
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
              },
            )
            .toList(),

        'parentName': selectedChild!['parentName'] ?? '',
        'parentUsername': parentUsername,
        'parentUid': parentUid,
        'section': selectedChild!['section'] ?? 'Nursery',
        'group': selectedChild!['group'] ?? '',
        'invoiceCategory': invoiceCategory,
        'billingType': selectedBillingType,
        'billingMonthKey': invoiceMonthKey,
        'billingYear': startDate?.year ?? dueDate?.year ?? now.year,
        'billingMonth': startDate?.month ?? dueDate?.month ?? now.month,
        'title': titleCtrl.text.trim(),
        'description': descriptionCtrl.text.trim(),
        'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
        'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
        'dueDate': Timestamp.fromDate(dueDate!),
        'paidAt': null,

        // baseAmount = سعر الطفل الواحد.
        'baseAmount': baseAmount,
        'baseAmountPerChild': baseAmount,
        'childrenBaseAmount': childrenBaseAmount,

        'transportFee': transportFee,
        'mealsFee': mealsFee,
        'registrationFee': registrationFee,
        'lateFee': lateFee,
        'subtotalAmount': subtotalAmount,
        'extraHoursAmount': extraHoursAmount,
        'extraHoursTotal': extraHoursAmount,
        'extraHoursIds': linkedExtraHoursIds,

        'consultationsAmount': consultationsAmount,
        'consultationIds': linkedConsultationIds,
        'consultations': selectedConsultations,

        'offerId': selectedOffer?['id'] ?? '',
        'offerTitle':
            (selectedOffer?['title'] ?? selectedOffer?['name'] ?? '')
                .toString(),
        'offerCollectionName': selectedOffer?['collectionName'] ?? '',
        'isDefaultOffer': selectedOffer?['isDefaultOffer'] == true,
        'isTwoChildrenOffer': isTwoChildrenOffer,
        'offerDiscount': offerDiscount,

        'totalAmount': totalAmount,
        'status': selectedPaymentStatus,
        'paymentStatus': selectedPaymentStatus,
        'paymentMethod': '',
        'notes': notesCtrl.text.trim(),

        'updatedExistingInvoice': isUpdatingExistingInvoice,
        'createdByUid': isUpdatingExistingInvoice
            ? FieldValue.delete()
            : (currentUser['uid'] ?? ''),
        'createdByName': isUpdatingExistingInvoice
            ? FieldValue.delete()
            : (currentUser['name'] ?? 'مستخدم'),
        'createdByRole': isUpdatingExistingInvoice
            ? FieldValue.delete()
            : (currentUser['role'] ?? ''),
        'updatedByUid': currentUser['uid'] ?? '',
        'updatedByName': currentUser['name'] ?? 'مستخدم',
        'updatedByRole': currentUser['role'] ?? '',
        'createdAt': isUpdatingExistingInvoice
            ? FieldValue.delete()
            : Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

await sendInvoiceCreatedNotification(
  invoiceId: docRef.id,
  isUpdatingExistingInvoice: isUpdatingExistingInvoice,
  currentUser: currentUser,
  childrenNames: childrenNames,
);
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
            'consultationStatus': 'completed',
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
            'invoiceTitle': titleCtrl.text.trim(),
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
                ? 'تم تحديث فاتورة الشهر بدل إنشاء فاتورة مكررة ✅'
                : 'تم إنشاء الفاتورة بنجاح ✅',
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
    );
  }

  Widget sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textLight),
        ),
      ],
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

    if (price > 0) return '$title • ${price.toStringAsFixed(0)} شيكل';
    if (discount > 0) return '$title • خصم ${discount.toStringAsFixed(0)}';
    return title;
  }

  String childLabel(Map<String, dynamic> child) {
    final group = (child['group'] ?? '').toString();
    final parent = (child['parentName'] ?? '').toString();

    final parts = [
      (child['name'] ?? 'طفل بدون اسم').toString(),
      group.isEmpty ? 'بدون مجموعة' : group,
      if (parent.isNotEmpty) parent,
    ];

    return parts.join(' • ');
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

            return ListView(
              children: [
                mainCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle(
                        'اختيار الطفل',
                        'اختاري الطفل الذي سيتم إنشاء الفاتورة له من طرف الأدمن.',
                      ),
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
                            'لا يوجد أطفال ظاهرين حاليًا. تأكدي أن الأطفال موجودون في children وأن حالتهم ليست inactive.',
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: selectedChild?['id'],
                          decoration: customDecoration(
                            label: 'الطفل الأول',
                            icon: Icons.child_care_rounded,
                          ),
                          items: children.map((child) {
                            return DropdownMenuItem<String>(
                              value: child['id'] as String,
                              child: Text(childLabel(child)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedChild = children.firstWhere(
                                (child) => child['id'] == value,
                              );
                              selectedSecondChild = null;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'اختاري الطفل';
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle(
                        'نوع الفاتورة',
                        'اختاري نوع الرسوم المناسبة.',
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedBillingType,
                        decoration: customDecoration(
                          label: 'نوع الفاتورة',
                          icon: Icons.receipt_long_rounded,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'daily', child: Text('يومي')),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('أسبوعي'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('شهري'),
                          ),
                          DropdownMenuItem(
                            value: 'registration',
                            child: Text('رسوم تسجيل'),
                          ),
                          DropdownMenuItem(
                            value: 'late_fee',
                            child: Text('رسوم تأخير'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedBillingType = value ?? 'monthly';

                            baseAmountCtrl.text =
                                selectedBillingType == 'monthly' ? '700' : '';
                            transportFeeCtrl.clear();
                            mealsFeeCtrl.clear();
                            registrationFeeCtrl.clear();
                            lateFeeCtrl.clear();
                            selectedOffer = null;
                            selectedSecondChild = null;

                            if (isRegistrationInvoice || isLateFeeInvoice) {
                              startDate = null;
                              endDate = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: customDecoration(
                          label: 'عنوان الفاتورة',
                          icon: Icons.title_rounded,
                          hint: 'مثال: رسوم حضانة شهرية',
                        ),
                        validator: (value) {
                          if ((value?.trim() ?? '').isEmpty) {
                            return 'أدخلي عنوان الفاتورة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: descriptionCtrl,
                        maxLines: 3,
                        decoration: customDecoration(
                          label: 'وصف الفاتورة',
                          icon: Icons.description_outlined,
                          hint: 'تفاصيل إضافية عن الفاتورة',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!isRegistrationInvoice && !isLateFeeInvoice)
                  mainCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionTitle(
                          'فترة الفاتورة',
                          'حددي تاريخ البداية والنهاية.',
                        ),
                        const SizedBox(height: 14),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_today_rounded),
                          title: const Text('تاريخ البداية'),
                          subtitle: Text(formatDate(startDate)),
                          onTap: () => pickDate(
                            initialDate: startDate,
                            onPicked: (date) {
                              setState(() {
                                startDate = date;
                              });
                            },
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_rounded),
                          title: const Text('تاريخ النهاية'),
                          subtitle: Text(formatDate(endDate)),
                          onTap: () => pickDate(
                            initialDate: endDate,
                            onPicked: (date) {
                              setState(() {
                                endDate = date;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                mainCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle(
                        'تفاصيل الرسوم',
                        isTwoChildrenOffer
                            ? 'سعر الطفل الواحد 700، وعرض الطفلين يحسب طفلين تلقائيًا.'
                            : 'أدخلي الرسوم المطلوبة حسب نوع الفاتورة.',
                      ),
                      const SizedBox(height: 14),
                      if (!isRegistrationInvoice && !isLateFeeInvoice) ...[
                        TextFormField(
                          controller: baseAmountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: customDecoration(
                            label: 'رسوم الطفل الواحد',
                            icon: Icons.payments_outlined,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (isTwoChildrenOffer) ...[
                          const SizedBox(height: 10),
                          Text(
                            'عدد الأطفال: 2 • مجموع رسوم الأطفال قبل الخصم: ${childrenBaseAmount.toStringAsFixed(2)} شيكل',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: transportFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: customDecoration(
                            label: 'رسوم المواصلات',
                            icon: Icons.directions_bus_outlined,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: mealsFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: customDecoration(
                            label: 'رسوم الوجبات',
                            icon: Icons.restaurant_outlined,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      if (isRegistrationInvoice)
                        TextFormField(
                          controller: registrationFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: customDecoration(
                            label: 'رسوم التسجيل',
                            icon: Icons.app_registration_rounded,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      if (isLateFeeInvoice)
                        TextFormField(
                          controller: lateFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: customDecoration(
                            label: 'رسوم التأخير',
                            icon: Icons.warning_amber_rounded,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!isRegistrationInvoice && !isLateFeeInvoice)
                  mainCard(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: fetchActiveOffers(),
                      builder: (context, offerSnapshot) {
                        final offers = offerSnapshot.data ?? [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionTitle(
                              'العروض والاشتراكات',
                              'اختاري عرضًا فعالًا ليتم احتساب الخصم داخل الفاتورة.',
                            ),
                            const SizedBox(height: 14),
                            if (offerSnapshot.connectionState ==
                                ConnectionState.waiting)
                              const Center(child: CircularProgressIndicator())
                            else if (offers.isEmpty)
                              const Text('لا توجد عروض فعالة حاليًا.')
                            else
                              DropdownButtonFormField<String>(
                                value: selectedOffer?['dropdownValue'],
                                decoration: customDecoration(
                                  label: 'اختيار عرض',
                                  icon: Icons.local_offer_outlined,
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text('بدون عرض'),
                                  ),
                                  ...offers.map((offer) {
                                    return DropdownMenuItem<String>(
                                      value: offer['dropdownValue'] as String,
                                      child: Text(offerLabel(offer)),
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
                                        (offer) =>
                                            offer['dropdownValue'] == value,
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
                                const Text(
                                  'اختاري الطفل الأول أولًا حتى يظهر اختيار الطفل الثاني.',
                                )
                              else if (secondOptions.isEmpty)
                                const Text(
                                  'لا يوجد طفل ثاني لنفس ولي الأمر. تأكدي من ربط الطفلين بنفس parentUid أو parentUsername.',
                                )
                              else
                                DropdownButtonFormField<String>(
                                  value: selectedSecondChild?['id'],
                                  decoration: customDecoration(
                                    label: 'الطفل الثاني للعرض',
                                    icon: Icons.child_friendly_rounded,
                                  ),
                                  items: secondOptions.map((child) {
                                    return DropdownMenuItem<String>(
                                      value: child['id'] as String,
                                      child: Text(childLabel(child)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedSecondChild =
                                          secondOptions.firstWhere(
                                        (child) => child['id'] == value,
                                      );
                                    });
                                  },
                                  validator: (value) {
                                    if (isTwoChildrenOffer &&
                                        (value == null || value.isEmpty)) {
                                      return 'اختاري الطفل الثاني لعرض طفلين';
                                    }
                                    return null;
                                  },
                                ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'قيمة الخصم: ${offerDiscount.toStringAsFixed(2)} شيكل',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
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
                      sectionTitle(
                        'الاستحقاق والملاحظات',
                        'حددي موعد الدفع وأضيفي أي ملاحظات.',
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedPaymentStatus,
                        decoration: customDecoration(
                          label: 'حالة الدفع',
                          icon: Icons.payments_rounded,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'unpaid',
                            child: Text('غير مدفوعة'),
                          ),
                          DropdownMenuItem(
                            value: 'partial',
                            child: Text('مدفوعة جزئيًا'),
                          ),
                          DropdownMenuItem(
                            value: 'paid',
                            child: Text('مدفوعة'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentStatus = value ?? 'unpaid';
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule_rounded),
                        title: const Text('تاريخ الاستحقاق'),
                        subtitle: Text(formatDate(dueDate)),
                        onTap: () => pickDate(
                          initialDate: dueDate,
                          onPicked: (date) {
                            setState(() {
                              dueDate = date;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 4,
                        decoration: customDecoration(
                          label: 'ملاحظات',
                          icon: Icons.notes_rounded,
                          hint: 'أي تفاصيل إضافية...',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                mainCard(
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
                              'رسوم الأطفال: ${childrenBaseAmount.toStringAsFixed(2)} شيكل\n'
                              'الإجمالي قبل الخصم: ${subtotalAmount.toStringAsFixed(2)} شيكل\n'
                              'الخصم: ${offerDiscount.toStringAsFixed(2)} شيكل\n'
                              'الساعات الإضافية غير المفوترة: ${extraHoursAmount.toStringAsFixed(2)} شيكل\n'
                              'الاستشارات: ${consultationsAmount.toStringAsFixed(2)} شيكل\n'
                              'الإجمالي النهائي: ${totalAmount.toStringAsFixed(2)} شيكل',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
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
                ),
                const SizedBox(height: 10),
              ],
            );
          },
        ),
      ),
    );
  }
}