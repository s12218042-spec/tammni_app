import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentInvoicesPage extends StatefulWidget {
  final String parentUsername;

  const ParentInvoicesPage({super.key, required this.parentUsername});

  @override
  State<ParentInvoicesPage> createState() => _ParentInvoicesPageState();
}

class _ParentInvoicesPageState extends State<ParentInvoicesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedStatus = 'all';

  String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'paid':
        return 'مدفوعة';
      case 'overdue':
        return 'متأخرة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.redAccent;
      case 'cancelled':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  String billingTypeLabel(String type) {
    switch (type) {
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
      default:
        return type;
    }
  }

  String formatDate(Timestamp? ts) {
    if (ts == null) return 'غير محدد';
    final d = ts.toDate();
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> invoicesStream() {
    return _firestore
        .collection('invoices')
        .where('parentUsername', isEqualTo: widget.parentUsername)
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> applyFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (selectedStatus == 'all') return docs;

    return docs.where((doc) {
      final data = doc.data();
      return (data['status'] ?? '').toString() == selectedStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'فواتيري',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: invoicesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = applyFilter(docs);

          filteredDocs.sort((a, b) {
            final aDate = a.data()['createdAt'] as Timestamp?;
            final bDate = b.data()['createdAt'] as Timestamp?;

            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;

            return bDate.compareTo(aDate);
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
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textLight),
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
                      DropdownMenuItem(value: 'paid', child: Text('مدفوعة')),
                      DropdownMenuItem(value: 'overdue', child: Text('متأخرة')),
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
              ),

              const SizedBox(height: 18),

              if (filteredDocs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'لا توجد فواتير متاحة حاليًا.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                )
              else
                ...filteredDocs.map((doc) {
                  final data = doc.data();
                  final status = (data['status'] ?? 'pending').toString();

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
                                backgroundColor: statusColor(
                                  status,
                                ).withOpacity(0.15),
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
                                      (data['title'] ?? 'فاتورة').toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'الطفل: ${(data['childName'] ?? '').toString()}',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
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
                          Text(
                            'نوع الفاتورة: ${billingTypeLabel((data['billingType'] ?? '').toString())}',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'المبلغ الإجمالي: ${(data['totalAmount'] ?? 0).toString()}',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'تاريخ الاستحقاق: ${formatDate(data['dueDate'] as Timestamp?)}',
                          ),
                          const SizedBox(height: 6),
                          if ((data['description'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            Text(
                              'الوصف: ${(data['description'] ?? '').toString()}',
                            ),
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
