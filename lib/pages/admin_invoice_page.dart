import 'package:cloud_firestore/cloud_firestore.dart';
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

  String selectedStatus = 'all';
  bool isUpdatingStatus = false;

  Future<void> openCreateInvoice() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateNurseryInvoicePage(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {});
    }
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
      default:
        return AppColors.primary;
    }
  }

  IconData statusIcon(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'paid':
        return Icons.verified_rounded;
      case 'overdue':
        return Icons.warning_amber_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.receipt_long_rounded;
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
      default:
        return type.trim().isEmpty ? 'غير محدد' : type;
    }
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
    if (value == null) return '0';

    if (value is num) {
      if (value == value.roundToDouble()) {
        return value.toStringAsFixed(0);
      }
      return value.toStringAsFixed(2);
    }

    final parsed = num.tryParse(value.toString());
    if (parsed == null) return value.toString();

    if (parsed == parsed.roundToDouble()) {
      return parsed.toStringAsFixed(0);
    }

    return parsed.toStringAsFixed(2);
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
      return (data['status'] ?? '').toString().trim().toLowerCase() ==
          selectedStatus;
    }).toList();
  }

  Map<String, int> buildStats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int pending = 0;
    int paid = 0;
    int overdue = 0;
    int cancelled = 0;

    for (final doc in docs) {
      final status = (doc.data()['status'] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();

      if (status == 'paid') {
        paid++;
      } else if (status == 'overdue') {
        overdue++;
      } else if (status == 'cancelled') {
        cancelled++;
      } else {
        pending++;
      }
    }

    return {
      'all': docs.length,
      'pending': pending,
      'paid': paid,
      'overdue': overdue,
      'cancelled': cancelled,
    };
  }

  String buildNotificationTitle(String status) {
    switch (status.trim().toLowerCase()) {
      case 'paid':
        return 'تم تحديث الفاتورة كمدفوعة';
      case 'overdue':
        return 'تنبيه: فاتورة متأخرة';
      case 'cancelled':
        return 'تم إلغاء فاتورة';
      case 'pending':
      default:
        return 'تحديث على حالة الفاتورة';
    }
  }

  String buildNotificationBody({
    required String status,
    required String invoiceTitle,
    required String childName,
    required String amount,
    required String dueDate,
  }) {
    final title = invoiceTitle.trim().isEmpty ? 'فاتورة' : invoiceTitle;
    final childPart = childName.trim().isEmpty ? '' : ' للطفل $childName';

    switch (status.trim().toLowerCase()) {
      case 'paid':
        return 'تم تسجيل الفاتورة "$title"$childPart كمدفوعة. المبلغ: $amount.';
      case 'overdue':
        return 'الفاتورة "$title"$childPart أصبحت متأخرة. المبلغ: $amount، تاريخ الاستحقاق: $dueDate.';
      case 'cancelled':
        return 'تم إلغاء الفاتورة "$title"$childPart.';
      case 'pending':
      default:
        return 'تم تحديث حالة الفاتورة "$title"$childPart إلى قيد الانتظار. المبلغ: $amount.';
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
        (invoiceData['parentUsername'] ?? '').toString().trim().toLowerCase();

    if (parentUid.isEmpty && parentUsername.isEmpty) return;

    final parentName = (invoiceData['parentName'] ?? '').toString().trim();
    final childId = (invoiceData['childId'] ?? '').toString().trim();
    final childName = (invoiceData['childName'] ?? '').toString().trim();
    final invoiceTitle = (invoiceData['title'] ?? 'فاتورة').toString().trim();
    final amount = formatAmount(invoiceData['totalAmount']);
    final dueDate = formatDate(invoiceData['dueDate']);

    final title = buildNotificationTitle(newStatus);
    final body = buildNotificationBody(
      status: newStatus,
      invoiceTitle: invoiceTitle,
      childName: childName,
      amount: amount,
      dueDate: dueDate,
    );

    await _firestore.collection('notifications').add({
      'uid': parentUid,
      'targetUid': parentUid,
      'targetRole': 'parent',
      'receiverUid': parentUid,
      'receiverRole': 'parent',
      'parentUid': parentUid,
      'parentUsername': parentUsername,
      'parentName': parentName,
      'childId': childId,
      'childName': childName,
      'title': title,
      'body': body,
      'message': body,
      'description': body,
      'type': 'invoice',
      'notificationType': 'invoice',
      'category': 'invoice',
      'invoiceId': invoiceId,
      'invoiceStatus': newStatus,
      'status': newStatus,
      'priority': newStatus == 'overdue' ? 'important' : 'normal',
      'importance': newStatus == 'overdue' ? 'important' : 'normal',
      'isRead': false,
      'read': false,
      'seen': false,
      'createdAt': FieldValue.serverTimestamp(),
      'time': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdByRole': 'admin',
      'byRole': 'admin',
      'senderRole': 'admin',
    });
  }

  Future<void> updateInvoiceStatus({
    required String docId,
    required String status,
  }) async {
    if (isUpdatingStatus) return;

    setState(() {
      isUpdatingStatus = true;
    });

    try {
      final invoiceRef = _firestore.collection('invoices').doc(docId);
      final invoiceDoc = await invoiceRef.get();

      if (!invoiceDoc.exists) {
        throw Exception('الفاتورة غير موجودة');
      }

      final invoiceData = invoiceDoc.data() ?? <String, dynamic>{};

      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'paid') {
        updateData['paidAt'] = FieldValue.serverTimestamp();
      } else {
        updateData['paidAt'] = null;
      }

      await invoiceRef.update(updateData);

      await createParentInvoiceNotification(
        invoiceId: docId,
        invoiceData: invoiceData,
        newStatus: status,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث حالة الفاتورة إلى ${statusLabel(status)}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحديث الفاتورة: $e'),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        isUpdatingStatus = false;
      });
    }
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

  Widget buildFilterChip({
    required String label,
    required String value,
    required int count,
  }) {
    final selected = selectedStatus == value;
    final color = value == 'all' ? AppColors.primary : statusColor(value);

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
        color: selected ? color : AppColors.textDark,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected ? color : AppColors.border,
      ),
      backgroundColor: Colors.white,
    );
  }

  Widget buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.14),
            AppColors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.80),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة الفواتير',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'عرض ومتابعة فواتير الحضانة وتحديث حالات الدفع وإشعار ولي الأمر عند تغيير الحالة.',
                  style: TextStyle(
                    color: AppColors.textLight,
                    height: 1.5,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFiltersCard(Map<String, int> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'فلترة الفواتير',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildFilterChip(
                  label: 'الكل',
                  value: 'all',
                  count: stats['all'] ?? 0,
                ),
                buildFilterChip(
                  label: 'قيد الانتظار',
                  value: 'pending',
                  count: stats['pending'] ?? 0,
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
            SizedBox(height: 6),
            Text(
              'يمكنك إنشاء فاتورة جديدة من زر إنشاء فاتورة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInvoiceCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final status = (data['status'] ?? 'pending').toString().trim();
    final dueDate = data['dueDate'];
    final createdAt = data['createdAt'];

    final title = (data['title'] ?? 'فاتورة').toString();
    final childName = (data['childName'] ?? '').toString();
    final parentName = (data['parentName'] ?? '').toString();
    final parentUsername = (data['parentUsername'] ?? '').toString();
    final billingType = (data['billingType'] ?? '').toString();
    final totalAmount = formatAmount(data['totalAmount']);

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
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (childName.trim().isNotEmpty)
                        Text(
                          'الطفل: $childName',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (parentName.trim().isNotEmpty)
                        Text(
                          parentUsername.trim().isNotEmpty
                              ? 'ولي الأمر: $parentName • @$parentUsername'
                              : 'ولي الأمر: $parentName',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
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
            _InvoiceInfoTile(
              icon: Icons.category_outlined,
              title: 'نوع الفاتورة',
              value: billingTypeLabel(billingType),
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon: Icons.payments_outlined,
              title: 'المبلغ الإجمالي',
              value: totalAmount,
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon: Icons.event_available_outlined,
              title: 'تاريخ الاستحقاق',
              value: formatDate(dueDate),
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon: Icons.access_time_rounded,
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
                          currentStatus: status,
                        ),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('تحديث الحالة'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openCreateInvoice,
        icon: const Icon(Icons.add),
        label: const Text('إنشاء فاتورة'),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: invoicesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'حدث خطأ أثناء تحميل الفواتير:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = applyFilter(docs);
          final stats = buildStats(docs);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                buildHeaderCard(),
                const SizedBox(height: 16),
                buildFiltersCard(stats),
                const SizedBox(height: 18),
                if (filteredDocs.isEmpty)
                  buildEmptyState()
                else
                  ...filteredDocs.map(buildInvoiceCard),
                const SizedBox(height: 90),
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

  const _InvoiceInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.textLight,
          ),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: const TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
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
        backgroundColor: color.withOpacity(0.15),
        child: Icon(
          selected ? Icons.check : Icons.circle,
          size: selected ? 16 : 10,
          color: color,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? color : AppColors.textDark,
        ),
      ),
    );
  }
}