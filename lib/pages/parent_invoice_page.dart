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

  String statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'unpaid':
      case 'pending':
        return 'غير مدفوعة';
      case 'paid':
        return 'مدفوعة';
      case 'partial':
      case 'partially_paid':
        return 'مدفوعة جزئيًا';
      case 'overdue':
        return 'متأخرة';
      case 'cancelled':
        return 'ملغاة';
      case 'draft':
        return 'مسودة';
      default:
        return status.trim().isEmpty ? 'غير محددة' : status;
    }
  }

  Color statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'unpaid':
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'partial':
      case 'partially_paid':
        return Colors.blue;
      case 'overdue':
        return Colors.redAccent;
      case 'cancelled':
        return Colors.grey;
      case 'draft':
        return Colors.blueGrey;
      default:
        return AppColors.primary;
    }
  }

  IconData statusIcon(String status) {
    switch (status.trim().toLowerCase()) {
      case 'paid':
        return Icons.verified_rounded;
      case 'partial':
      case 'partially_paid':
        return Icons.payments_rounded;
      case 'overdue':
        return Icons.warning_amber_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'draft':
        return Icons.edit_document;
      case 'unpaid':
      case 'pending':
      default:
        return Icons.schedule_rounded;
    }
  }

  String billingTypeLabel(String type) {
    switch (type.trim().toLowerCase()) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      case 'registration':
        return 'رسوم تسجيل';
      case 'late_fee':
        return 'رسوم تأخير';
      case 'transport':
        return 'رسوم مواصلات';
      case 'activity':
        return 'رسوم نشاط';
      case 'other':
        return 'رسوم أخرى';
      default:
        return type.trim().isEmpty ? 'غير محدد' : type;
    }
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
    if (raw == null) return '0';

    if (raw is int) return raw.toString();

    if (raw is double) {
      if (raw == raw.roundToDouble()) {
        return raw.toInt().toString();
      }
      return raw.toStringAsFixed(2);
    }

    if (raw is num) {
      final value = raw.toDouble();
      if (value == value.roundToDouble()) {
        return value.toInt().toString();
      }
      return value.toStringAsFixed(2);
    }

    final parsed = double.tryParse(raw.toString());
    if (parsed == null) return raw.toString();

    if (parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString();
    }

    return parsed.toStringAsFixed(2);
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

  dynamic resolveTotalAmount(Map<String, dynamic> data) {
    return data['totalAmount'] ??
        data['finalAmount'] ??
        data['amount'] ??
        data['invoiceAmount'] ??
        data['total'] ??
        0;
  }

  dynamic resolveSubtotalAmount(Map<String, dynamic> data) {
    return data['subtotalAmount'] ??
        data['childrenBaseAmount'] ??
        data['baseAmount'] ??
        0;
  }

  dynamic resolvePaidAmount(Map<String, dynamic> data) {
    return data['paidAmount'] ?? data['paid'] ?? data['collectedAmount'];
  }

  dynamic resolveDueDate(Map<String, dynamic> data) {
    return data['dueDate'] ?? data['paymentDueDate'];
  }

  dynamic resolveCreatedAt(Map<String, dynamic> data) {
    return data['createdAt'] ?? data['time'] ?? data['updatedAt'];
  }

  String resolveStatus(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['paymentStatus'],
      data['status'],
      'pending',
    ]).toLowerCase();
  }

  String resolveOfferTitle(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['offerTitle'],
      data['offerName'],
    ]);
  }

  double resolveOfferDiscount(Map<String, dynamic> data) {
    return _numValue(
      data['offerDiscount'] ??
          data['discountAmount'] ??
          data['discount'] ??
          0,
    );
  }

  double resolveExtraHoursAmount(Map<String, dynamic> data) {
    return _numValue(
      data['extraHoursAmount'] ??
          data['extraHoursTotal'] ??
          data['extraHoursFee'] ??
          0,
    );
  }

  bool hasExtraHours(Map<String, dynamic> data) {
    final amount = resolveExtraHoursAmount(data);
    final ids = data['extraHoursIds'];

    return amount > 0 || (ids is List && ids.isNotEmpty);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _fetchInvoices() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final cleanUsername = _cleanUsername();

    if (currentUid != null && currentUid.trim().isNotEmpty) {
      final byUid = await _firestore
          .collection('invoices')
          .where('parentUid', isEqualTo: currentUid)
          .get();

      if (byUid.docs.isNotEmpty) {
        return byUid.docs;
      }
    }

    if (cleanUsername.isEmpty) return [];

    final byUsername = await _firestore
        .collection('invoices')
        .where('parentUsername', isEqualTo: cleanUsername)
        .get();

    return byUsername.docs;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> applyFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (selectedStatus == 'all') return docs;

    return docs.where((doc) {
      final status = resolveStatus(doc.data());

      if (selectedStatus == 'unpaid') {
        return status == 'unpaid' || status == 'pending';
      }

      if (selectedStatus == 'partial') {
        return status == 'partial' || status == 'partially_paid';
      }

      return status == selectedStatus;
    }).toList();
  }

  Widget _summaryCard(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    double totalDue = 0;
    double unpaidDue = 0;
    double extraHoursTotal = 0;

    for (final doc in docs) {
      final data = doc.data();
      final status = resolveStatus(data);
      final amount = _numValue(resolveTotalAmount(data));

      totalDue += amount;
      extraHoursTotal += resolveExtraHoursAmount(data);

      if (status != 'paid' && status != 'cancelled') {
        unpaidDue += amount;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                title: 'إجمالي الفواتير',
                value: '${formatMoney(totalDue)} شيكل',
                icon: Icons.receipt_long_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryItem(
                title: 'غير المسدد',
                value: '${formatMoney(unpaidDue)} شيكل',
                icon: Icons.payments_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryItem(
                title: 'ساعات إضافية',
                value: '${formatMoney(extraHoursTotal)} شيكل',
                icon: Icons.access_time_filled_rounded,
              ),
            ),
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
            labelText: 'فلترة حسب الحالة',
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
              value: 'paid',
              child: Text('مدفوعة'),
            ),
            DropdownMenuItem(
              value: 'partial',
              child: Text('مدفوعة جزئيًا'),
            ),
            DropdownMenuItem(
              value: 'overdue',
              child: Text('متأخرة'),
            ),
            DropdownMenuItem(
              value: 'cancelled',
              child: Text('ملغاة'),
            ),
            DropdownMenuItem(
              value: 'draft',
              child: Text('مسودة'),
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
              'لا توجد فواتير متاحة حاليًا.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
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
    final billingType = resolveBillingType(data);
    final description = resolveDescription(data);

    final subtotalAmount = resolveSubtotalAmount(data);
    final totalAmount = resolveTotalAmount(data);
    final paidAmount = resolvePaidAmount(data);
    final dueDate = resolveDueDate(data);
    final createdAt = resolveCreatedAt(data);

    final offerTitle = resolveOfferTitle(data);
    final offerDiscount = resolveOfferDiscount(data);
    final extraHoursAmount = resolveExtraHoursAmount(data);
    final showExtraHours = hasExtraHours(data);

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
                          'الطفل: $childName',
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
              icon: Icons.category_outlined,
              label: 'نوع الفاتورة',
              value: billingTypeLabel(billingType),
            ),
            const SizedBox(height: 6),
            _InvoiceInfoRow(
              icon: Icons.payments_outlined,
              label: 'المبلغ قبل الخصم',
              value: '${formatMoney(subtotalAmount)} شيكل',
            ),
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
                icon: Icons.discount_outlined,
                label: 'الخصم',
                value: '${formatMoney(offerDiscount)} شيكل',
              ),
            ],
            if (showExtraHours) ...[
              const SizedBox(height: 6),
              _InvoiceInfoRow(
                icon: Icons.access_time_filled_rounded,
                label: 'الساعات الإضافية',
                value: '${formatMoney(extraHoursAmount)} شيكل',
              ),
            ],
            const SizedBox(height: 6),
            _InvoiceInfoRow(
              icon: Icons.receipt_long_rounded,
              label: 'الإجمالي النهائي',
              value: '${formatMoney(totalAmount)} شيكل',
              isStrong: true,
            ),
            if (paidAmount != null) ...[
              const SizedBox(height: 6),
              _InvoiceInfoRow(
                icon: Icons.verified_rounded,
                label: 'المبلغ المدفوع',
                value: '${formatMoney(paidAmount)} شيكل',
              ),
            ],
            const SizedBox(height: 6),
            _InvoiceInfoRow(
              icon: Icons.event_available_outlined,
              label: 'تاريخ الاستحقاق',
              value: formatDate(dueDate),
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

            final aTs = aDate is Timestamp ? aDate : null;
            final bTs = bDate is Timestamp ? bDate : null;

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
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  'الفواتير والرسوم',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'هنا يمكنك الاطلاع على فواتير أطفالك وحالة الدفع والتفاصيل المالية.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLight,
                      ),
                ),
                const SizedBox(height: 16),
                _summaryCard(docs),
                const SizedBox(height: 14),
                _buildStatusFilter(),
                const SizedBox(height: 18),
                if (filteredDocs.isEmpty)
                  _emptyState()
                else
                  ...filteredDocs.map(_invoiceCard),
                const SizedBox(height: 24),
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
