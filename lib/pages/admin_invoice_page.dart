import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'create_nursery_invoice_page.dart';

class AdminInvoicesPage extends StatefulWidget {
  const AdminInvoicesPage({super.key});

  @override
  State<AdminInvoicesPage> createState() => _AdminInvoicesPageState();
}

class _AdminInvoicesPageState extends State<AdminInvoicesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> openCreateInvoic() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateNurseryInvoicePage()),
    );
    if (!mounted) return;
    if (Result == true) {
      setState(() {});
    }
  }

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
        .orderBy('createdAt', descending: true)
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

  Future<void> updateInvoiceStatus({
    required String docId,
    required String status,
  }) async {
    await _firestore.collection('invoices').doc(docId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'paidAt': status == 'paid' ? FieldValue.serverTimestamp() : null,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تحديث حالة الفاتورة إلى ${statusLabel(status)}'),
      ),
    );
  }

  void openStatusDialog({
    required String docId,
    required String currentStatus,
  }) {
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
                label: 'قيد الانتظار',
                color: Colors.orange,
                selected: currentStatus == 'pending',
                onTap: () async {
                  Navigator.pop(context);
                  await updateInvoiceStatus(docId: docId, status: 'pending');
                },
              ),
              _StatusOptionTile(
                label: 'مدفوعة',
                color: Colors.green,
                selected: currentStatus == 'paid',
                onTap: () async {
                  Navigator.pop(context);
                  await updateInvoiceStatus(docId: docId, status: 'paid');
                },
              ),
              _StatusOptionTile(
                label: 'متأخرة',
                color: Colors.redAccent,
                selected: currentStatus == 'overdue',
                onTap: () async {
                  Navigator.pop(context);
                  await updateInvoiceStatus(docId: docId, status: 'overdue');
                },
              ),
              _StatusOptionTile(
                label: 'ملغاة',
                color: Colors.grey,
                selected: currentStatus == 'cancelled',
                onTap: () async {
                  Navigator.pop(context);
                  await updateInvoiceStatus(docId: docId, status: 'cancelled');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'فواتير الحضانة',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateNurseryInvoicePage()),
          );
          if (result == true) {
            setState(() {});
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('إنشاء فاتورة'),
      ),
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

          return ListView(
            children: [
              Text(
                'إدارة الفواتير',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'عرض ومتابعة فواتير الحضانة وتحديث حالات الدفع.',
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
                      'لا توجد فواتير ضمن هذا التصنيف حاليًا.',
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
                  final dueDate = data['dueDate'];

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
                                    const SizedBox(height: 2),
                                    Text(
                                      'ولي الأمر: ${(data['parentName'] ?? '').toString()}',
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
                            'تاريخ الاستحقاق: ${formatDate(dueDate is Timestamp ? dueDate : null)}',
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => openStatusDialog(
                                    docId: doc.id,
                                    currentStatus: status,
                                  ),
                                  icon: const Icon(Icons.edit_note_rounded),
                                  label: const Text('تحديث الحالة'),
                                ),
                              ),
                            ],
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
        radius: 12,
        backgroundColor: color.withOpacity(0.15),
        child: Icon(
          selected ? Icons.check : Icons.circle,
          size: 14,
          color: color,
        ),
      ),
      title: Text(label),
    );
  }
}
