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

  String statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return 'قيد الانتظار';
      case 'paid':
        return 'مدفوعة';
      case 'overdue':
        return 'متأخرة';
      case 'cancelled':
        return 'ملغاة';
      case 'partial':
        return 'مدفوعة جزئيًا';
      case 'draft':
        return 'مسودة';
      default:
        return status.trim().isEmpty ? 'غير محددة' : status;
    }
  }

  Color statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.redAccent;
      case 'cancelled':
        return Colors.grey;
      case 'partial':
        return Colors.blue;
      case 'draft':
        return Colors.blueGrey;
      default:
        return AppColors.primary;
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
        data['amount'] ??
        data['invoiceAmount'] ??
        data['total'] ??
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
      data['status'],
      'pending',
    ]);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchInvoices() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final cleanUsername = _cleanUsername();

    if (currentUid != null) {
      final byUid = await _firestore
          .collection('invoices')
          .where('parentUid', isEqualTo: currentUid)
          .get();

      if (byUid.docs.isNotEmpty) {
        return byUid.docs;
      }
    }

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
      final data = doc.data();
      return resolveStatus(data).toLowerCase() == selectedStatus;
    }).toList();
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

          return ListView(
            children: [
              Text(
                'الفواتير والرسوم',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'هنا يمكنك الاطلاع على فواتير أطفالك وحالة الدفع الخاصة بكل فاتورة.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
              ),
              const SizedBox(height: 16),

              Card(
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
                        value: 'pending',
                        child: Text('قيد الانتظار'),
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
              ),

              const SizedBox(height: 18),

              if (filteredDocs.isEmpty)
                Card(
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textLight,
                                  ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredDocs.map((doc) {
                  final data = doc.data();
                  final status = resolveStatus(data);
                  final title = resolveTitle(data);
                  final childName = resolveChildName(data);
                  final billingType = resolveBillingType(data);
                  final description = resolveDescription(data);
                  final totalAmount = resolveTotalAmount(data);
                  final paidAmount = resolvePaidAmount(data);
                  final dueDate = resolveDueDate(data);

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
                                backgroundColor:
                                    statusColor(status).withOpacity(0.15),
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  color: statusColor(status),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (childName.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'الطفل: $childName',
                                        style: const TextStyle(
                                          color: Colors.black54,
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
                                  color: statusColor(status).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  statusLabel(status),
                                  style: TextStyle(
                                    color: statusColor(status),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          _InvoiceInfoRow(
                            label: 'نوع الفاتورة',
                            value: billingTypeLabel(billingType),
                          ),
                          const SizedBox(height: 6),
                          _InvoiceInfoRow(
                            label: 'المبلغ الإجمالي',
                            value: formatMoney(totalAmount),
                          ),
                          if (paidAmount != null) ...[
                            const SizedBox(height: 6),
                            _InvoiceInfoRow(
                              label: 'المبلغ المدفوع',
                              value: formatMoney(paidAmount),
                            ),
                          ],
                          const SizedBox(height: 6),
                          _InvoiceInfoRow(
                            label: 'تاريخ الاستحقاق',
                            value: formatDate(dueDate),
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
                }),
            ],
          );
        },
      ),
    );
  }
}

class _InvoiceInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InvoiceInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}