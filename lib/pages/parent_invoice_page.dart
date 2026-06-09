import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentInvoicesPage extends StatefulWidget {
  final String parentUsername;

  const ParentInvoicesPage({
    super.key,
    required this.parentUsername,
  });

  @override
  State<ParentInvoicesPage> createState() => _ParentInvoicesPageState();
}

class _ParentInvoicesPageState extends State<ParentInvoicesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedStatus = 'all';

  String _cleanUsername() => widget.parentUsername.trim().toLowerCase();

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  double _numValue(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String normalizeStatus(dynamic value) {
    final status = (value ?? '').toString().trim().toLowerCase();

    if (status.isEmpty) return 'unpaid';
    if (status == 'pending') return 'unpaid';
    if (status == 'not_paid') return 'unpaid';
    if (status == 'notpaid') return 'unpaid';
    if (status == 'partially_paid') return 'partial';

    return status;
  }

  String statusLabel(String status) {
    switch (normalizeStatus(status)) {
      case 'unpaid':
        return 'غير مدفوعة';
      case 'paid':
        return 'مدفوعة';
      case 'partial':
        return 'مدفوعة جزئيًا';
      case 'overdue':
        return 'متأخرة';
      case 'cancelled':
      case 'canceled':
        return 'ملغاة';
      default:
        return status.trim().isEmpty ? 'غير محددة' : status;
    }
  }

  Color statusColor(String status) {
    switch (normalizeStatus(status)) {
      case 'unpaid':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.blue;
      case 'overdue':
        return Colors.redAccent;
      case 'cancelled':
      case 'canceled':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  IconData statusIcon(String status) {
    switch (normalizeStatus(status)) {
      case 'paid':
        return Icons.verified_rounded;
      case 'partial':
        return Icons.payments_rounded;
      case 'overdue':
        return Icons.warning_amber_rounded;
      case 'cancelled':
      case 'canceled':
        return Icons.cancel_rounded;
      case 'unpaid':
      default:
        return Icons.schedule_rounded;
    }
  }

  String paymentMethodLabel() {
    return 'كاش';
  }

  String formatDate(dynamic raw) {
    if (raw is Timestamp) {
      final d = raw.toDate();
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    }

    if (raw is DateTime) {
      return '${raw.year}/${raw.month.toString().padLeft(2, '0')}/${raw.day.toString().padLeft(2, '0')}';
    }

    return 'غير محدد';
  }

  String formatMoney(dynamic raw) {
    final value = _numValue(raw);

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String resolveTitle(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['title'],
      data['invoiceTitle'],
      data['name'],
      'فاتورة',
    ]);
  }

  String resolveChildName(Map<String, dynamic> data) {
    final childrenNames = data['childrenNames'];

    if (childrenNames is List && childrenNames.isNotEmpty) {
      final names = childrenNames
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (names.isNotEmpty) return names.join('، ');
    }

    final children = data['children'];

    if (children is List && children.isNotEmpty) {
      final names = children.map((item) {
        if (item is Map) {
          return (item['childName'] ?? item['name'] ?? '').toString().trim();
        }
        return '';
      }).where((e) => e.isNotEmpty).toList();

      if (names.isNotEmpty) return names.join('، ');
    }

    return _firstNonEmpty([
      data['childName'],
      data['studentName'],
    ]);
  }

  String resolveBillingType(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['billingType'],
      data['type'],
      data['invoiceType'],
    ]);
  }

  String resolveDescription(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['description'],
      data['note'],
      data['details'],
      data['message'],
    ]);
  }

  double resolveTotalAmount(Map<String, dynamic> data) {
    return _numValue(
      data['totalAmount'] ??
          data['finalAmount'] ??
          data['amount'] ??
          data['invoiceAmount'] ??
          data['total'] ??
          0,
    );
  }

  double resolveSubtotalAmount(Map<String, dynamic> data) {
    return _numValue(
      data['subtotalAmount'] ??
          data['childrenBaseAmount'] ??
          data['baseAmount'] ??
          0,
    );
  }

  double resolvePaidAmount(Map<String, dynamic> data) {
    return _numValue(
      data['paidAmount'] ?? data['paid'] ?? data['collectedAmount'] ?? 0,
    );
  }

  double resolveRemainingAmount(Map<String, dynamic> data) {
    final stored = data['remainingAmount'];
    if (stored != null) return _numValue(stored);

    final total = resolveTotalAmount(data);
    final paid = resolvePaidAmount(data);
    final remaining = total - paid;

    return remaining < 0 ? 0 : remaining;
  }

  dynamic resolveCreatedAt(Map<String, dynamic> data) {
    return data['createdAt'] ?? data['time'] ?? data['updatedAt'];
  }

  String resolveStatus(Map<String, dynamic> data) {
    final stored = normalizeStatus(
      _firstNonEmpty([
        data['paymentStatus'],
        data['status'],
        data['invoiceStatus'],
      ]),
    );

    if (stored == 'paid' ||
        stored == 'partial' ||
        stored == 'unpaid' ||
        stored == 'overdue' ||
        stored == 'cancelled' ||
        stored == 'canceled') {
      return stored;
    }

    final total = resolveTotalAmount(data);
    final paid = resolvePaidAmount(data);

    if (total <= 0 || paid <= 0) return 'unpaid';
    if (paid >= total) return 'paid';
    return 'partial';
  }

  String resolveOfferTitle(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['offerTitle'],
      data['offerName'],
    ]);
  }

  double resolveOfferDiscount(Map<String, dynamic> data) {
    return _numValue(data['offerDiscount'] ?? 0);
  }

  double resolveManualDiscount(Map<String, dynamic> data) {
    return _numValue(
      data['manualDiscount'] ?? data['discountAmount'] ?? 0,
    );
  }

  double resolveTotalDiscount(Map<String, dynamic> data) {
    final stored = data['totalDiscount'];
    if (stored != null) return _numValue(stored);

    return resolveOfferDiscount(data) + resolveManualDiscount(data);
  }

  String resolveDiscountNotes(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['discountNotes'],
      data['discountNote'],
    ]);
  }

  double resolveExtraHoursAmount(Map<String, dynamic> data) {
    return _numValue(
      data['extraHoursAmount'] ??
          data['extraHoursTotal'] ??
          data['extraHoursFee'] ??
          0,
    );
  }

  double resolveConsultationsAmount(Map<String, dynamic> data) {
    return _numValue(
      data['consultationsAmount'] ??
          data['consultationAmount'] ??
          data['consultationsTotal'] ??
          0,
    );
  }

  double resolveHoursCount(Map<String, dynamic> data) {
    return _numValue(
      data['hoursCount'] ??
          data['temporaryHoursCount'] ??
          data['serviceUnits'] ??
          0,
    );
  }

  double resolveHourlyRate(Map<String, dynamic> data) {
    return _numValue(
      data['hourlyRate'] ??
          data['temporaryHourlyRate'] ??
          data['unitPrice'] ??
          0,
    );
  }


  bool isHourlyInvoice(Map<String, dynamic> data) {
    return resolveBillingType(data).trim().toLowerCase() == 'hourly';
  }

  int resolveListCount(dynamic value) {
    if (value is List) return value.length;
    return 0;
  }

  bool hasExtraHours(Map<String, dynamic> data) {
    final amount = resolveExtraHoursAmount(data);
    final ids = data['extraHoursIds'];

    return amount > 0 || (ids is List && ids.isNotEmpty);
  }

  bool hasConsultations(Map<String, dynamic> data) {
    final amount = resolveConsultationsAmount(data);
    final ids = data['consultationIds'];

    return amount > 0 || (ids is List && ids.isNotEmpty);
  }

  bool isHiddenInvoice(Map<String, dynamic> data) {
  final status = resolveStatus(data);

  final invoiceStatus =
      (data['invoiceStatus'] ?? '').toString().trim().toLowerCase();
  final paymentStatus =
      (data['paymentStatus'] ?? '').toString().trim().toLowerCase();

    const hiddenStatuses = {
      'draft',
      'superseded',
      'deleted',
      'void',
      'archived',
    };

  return hiddenStatuses.contains(status) ||
      hiddenStatuses.contains(invoiceStatus) ||
      hiddenStatuses.contains(paymentStatus);
}

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _fetchInvoices() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final cleanUsername = _cleanUsername();

    final docsById =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    if (currentUid.trim().isNotEmpty) {
      final byUid = await _firestore
          .collection('invoices')
          .where('parentUid', isEqualTo: currentUid.trim())
          .get();

      for (final doc in byUid.docs) {
        if (!isHiddenInvoice(doc.data())) {
          docsById[doc.id] = doc;
        }
      }
    }

    if (cleanUsername.isNotEmpty) {
      final byUsername = await _firestore
          .collection('invoices')
          .where('parentUsername', isEqualTo: cleanUsername)
          .get();

      for (final doc in byUsername.docs) {
        if (!isHiddenInvoice(doc.data())) {
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
      final status = resolveStatus(doc.data());

      if (selectedStatus == 'unpaid') {
        return status == 'unpaid';
      }

      if (selectedStatus == 'partial') {
        return status == 'partial';
      }

      return status == selectedStatus;
    }).toList();
  }

  Widget _summaryCard(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    double totalAmount = 0;
    double paidAmount = 0;
    double remainingAmount = 0;
    double extraHoursTotal = 0;
    double consultationsTotal = 0;

    for (final doc in docs) {
      final data = doc.data();
      final status = resolveStatus(data);

      if (status == 'cancelled' || status == 'canceled') continue;

      totalAmount += resolveTotalAmount(data);
      paidAmount += resolvePaidAmount(data);
      remainingAmount += resolveRemainingAmount(data);
      extraHoursTotal += resolveExtraHoursAmount(data);
      consultationsTotal += resolveConsultationsAmount(data);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    title: 'الإجمالي',
                    value: '${formatMoney(totalAmount)} شيكل',
                    icon: Icons.receipt_long_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryItem(
                    title: 'المدفوع',
                    value: '${formatMoney(paidAmount)} شيكل',
                    icon: Icons.price_check_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryItem(
                    title: 'المتبقي',
                    value: '${formatMoney(remainingAmount)} شيكل',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),
            if (extraHoursTotal > 0 || consultationsTotal > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      title: 'ساعات إضافية',
                      value: '${formatMoney(extraHoursTotal)} شيكل',
                      icon: Icons.access_time_filled_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryItem(
                      title: 'استشارات',
                      value: '${formatMoney(consultationsTotal)} شيكل',
                      icon: Icons.psychology_alt_outlined,
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

  Widget _buildStatusFilter() {
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
              child: Text('كل الفواتير'),
            ),
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
            DropdownMenuItem(
              value: 'overdue',
              child: Text('متأخرة'),
            ),
            DropdownMenuItem(
              value: 'cancelled',
              child: Text('ملغاة'),
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

  Widget _emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.10),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد فواتير حاليًا',
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

  Widget _invoiceCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final status = resolveStatus(data);
    final title = resolveTitle(data);
    final childName = resolveChildName(data);
    final description = resolveDescription(data);

    final subtotalAmount = resolveSubtotalAmount(data);
    final totalAmount = resolveTotalAmount(data);
    final paidAmount = resolvePaidAmount(data);
    final remainingAmount = resolveRemainingAmount(data);

    final createdAt = resolveCreatedAt(data);

    final offerTitle = resolveOfferTitle(data);
    final offerDiscount = resolveOfferDiscount(data);
    final manualDiscount = resolveManualDiscount(data);
    final totalDiscount = resolveTotalDiscount(data);
    final discountNotes = resolveDiscountNotes(data);

    final extraHoursAmount = resolveExtraHoursAmount(data);
    final consultationsAmount = resolveConsultationsAmount(data);

    final showExtraHours = hasExtraHours(data);
    final showConsultations = hasConsultations(data);

    final extraHoursCount = resolveListCount(data['extraHoursIds']);
    final consultationsCount = resolveListCount(data['consultationIds']);

    final paymentMethod = paymentMethodLabel();

    final hourlyInvoice = isHourlyInvoice(data);
    final hoursCount = resolveHoursCount(data);
    final hourlyRate = resolveHourlyRate(data);

    final color = statusColor(status);

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
                    statusIcon(status),
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.trim().isEmpty ? 'فاتورة' : title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (childName.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          childName.contains('،')
                              ? 'الأطفال: $childName'
                              : 'الطفل: $childName',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
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
                    statusLabel(status),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InvoiceInfoRow(
              icon: Icons.payments_outlined,
              label: 'تكلفة الحضانة',
              value: '${formatMoney(subtotalAmount)} شيكل',
            ),
            if (hourlyInvoice && hoursCount > 0) ...[
              const SizedBox(height: 6),
              _InvoiceInfoRow(
                icon: Icons.schedule_outlined,
                label: 'عدد الساعات',
                value: formatMoney(hoursCount),
              ),
            ],
            if (hourlyInvoice && hourlyRate > 0) ...[
              const SizedBox(height: 6),
              _InvoiceInfoRow(
                icon: Icons.price_change_outlined,
                label: 'سعر الساعة',
                value: '${formatMoney(hourlyRate)} شيكل',
              ),
            ],
            if (offerTitle.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              _InvoiceInfoRow(
                icon: Icons.local_offer_outlined,
                label: 'العرض',
                value: offerTitle,
              ),
            ],
            if (offerDiscount > 0) ...[
              const SizedBox(height: 6),
              _InvoiceInfoRow(
                icon: Icons.local_offer_outlined,
                label: 'خصم العرض',
                value: '${formatMoney(offerDiscount)} شيكل',
              ),
            ],
            if (manualDiscount > 0) ...[
              const SizedBox(height: 6),
              _InvoiceInfoRow(
                icon: Icons.discount_outlined,
                label: 'خصم إضافي',
                value: '${formatMoney(manualDiscount)} شيكل',
              ),
            ],
            if (totalDiscount > 0) ...[
              const SizedBox(height: 6),
              _InvoiceInfoRow(
                icon: Icons.price_change_outlined,
                label: 'مجموع الخصم',
                value: '${formatMoney(totalDiscount)} شيكل',
              ),
            ],
            if (discountNotes.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              _InvoiceInfoRow(
                icon: Icons.notes_outlined,
                label: 'ملاحظات الخصم',
                value: discountNotes,
              ),
            ],
            if (showExtraHours) ...[
              const SizedBox(height: 6),
              _InvoiceInfoRow(
                icon: Icons.access_time_filled_rounded,
                label: extraHoursCount > 0
                    ? 'الساعات الإضافية ($extraHoursCount)'
                    : 'الساعات الإضافية',
                value: '${formatMoney(extraHoursAmount)} شيكل',
              ),
            ],
            if (showConsultations) ...[
              const SizedBox(height: 6),
              _InvoiceInfoRow(
                icon: Icons.psychology_alt_outlined,
                label: consultationsCount > 0
                    ? 'الاستشارات ($consultationsCount)'
                    : 'الاستشارات',
                value: '${formatMoney(consultationsAmount)} شيكل',
              ),
            ],
            const SizedBox(height: 6),
            _InvoiceInfoRow(
              icon: Icons.receipt_long_rounded,
              label: 'الإجمالي',
              value: '${formatMoney(totalAmount)} شيكل',
              isStrong: true,
            ),
            const SizedBox(height: 6),
            _InvoiceInfoRow(
              icon: Icons.price_check_rounded,
              label: 'المدفوع',
              value: '${formatMoney(paidAmount)} شيكل',
              isStrong: true,
            ),
            const SizedBox(height: 6),
            _InvoiceInfoRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'المتبقي',
              value: '${formatMoney(remainingAmount)} شيكل',
              isStrong: true,
            ),
            const SizedBox(height: 6),
            _InvoiceInfoRow(
              icon: Icons.credit_card_rounded,
              label: 'طريقة الدفع',
              value: paymentMethod,
            ),
            const SizedBox(height: 6),
            _InvoiceInfoRow(
              icon: Icons.access_time_rounded,
              label: 'تاريخ الإنشاء',
              value: formatDate(createdAt),
            ),
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'فواتيري',
      child: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: _fetchInvoices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
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
            final aDate = resolveCreatedAt(a.data());
            final bDate = resolveCreatedAt(b.data());

            final aResolved = aDate is Timestamp
                ? aDate.toDate()
                : aDate is DateTime
                    ? aDate
                    : null;

            final bResolved = bDate is Timestamp
                ? bDate.toDate()
                : bDate is DateTime
                    ? bDate
                    : null;

            if (aResolved == null && bResolved == null) return 0;
            if (aResolved == null) return 1;
            if (bResolved == null) return -1;

            return bResolved.compareTo(aResolved);
          });

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _summaryCard(docs),
                const SizedBox(height: 14),
                _buildStatusFilter(),
                const SizedBox(height: 18),
                if (filteredDocs.isEmpty)
                  _emptyState()
                else
                  ...filteredDocs.map(_invoiceCard),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isStrong;

  const _InvoiceInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isStrong = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isStrong ? AppColors.primary : AppColors.textDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isStrong ? AppColors.primary : AppColors.textLight,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: textColor,
              fontSize: 12.5,
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: TextStyle(
                color: textColor,
                fontWeight: isStrong ? FontWeight.w900 : FontWeight.w700,
                fontSize: 13.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}