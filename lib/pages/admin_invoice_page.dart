import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  String normalizeStatus(dynamic value) {
    final status = (value ?? '').toString().trim().toLowerCase();

    if (status.isEmpty) return 'unpaid';
    if (status == 'pending') return 'unpaid';
    if (status == 'not_paid') return 'unpaid';
    if (status == 'notpaid') return 'unpaid';
    if (status == 'partially_paid') return 'partial';

    return status;
  }

  bool isHiddenInvoiceStatus(Map<String, dynamic> data) {
    final status = normalizeStatus(data['status']);
    final paymentStatus = normalizeStatus(data['paymentStatus']);
    final invoiceStatus = normalizeStatus(data['invoiceStatus']);

    const hiddenStatuses = {
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
      case 'canceled':
        return 'ملغاة';
      case 'superseded':
        return 'مستبدلة';
      default:
        return status.trim().isEmpty ? 'غير محددة' : status;
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
      case 'canceled':
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
      case 'canceled':
        return Icons.cancel_rounded;
      case 'superseded':
        return Icons.swap_horiz_rounded;
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

  String invoiceChildrenNames(Map<String, dynamic> data) {
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

    return (data['childName'] ?? '').toString().trim();
  }

  int invoiceChildrenCount(Map<String, dynamic> data) {
    final count = data['childrenCount'];
    if (count is num && count > 0) return count.toInt();

    final childrenNames = data['childrenNames'];
    if (childrenNames is List && childrenNames.isNotEmpty) {
      return childrenNames.length;
    }

    final children = data['children'];
    if (children is List && children.isNotEmpty) {
      return children.length;
    }

    final childName = (data['childName'] ?? '').toString().trim();
    return childName.isEmpty ? 0 : 1;
  }

  String invoiceDisplayTitle(Map<String, dynamic> data) {
    final title = (data['title'] ?? '').toString().trim();
    final offerTitle = (data['offerTitle'] ?? '').toString().trim();
    final isTwoChildrenOffer = data['isTwoChildrenOffer'] == true;

    if (title.isNotEmpty) return title;
    if (isTwoChildrenOffer) return 'فاتورة عرض طفلين';
    if (offerTitle.isNotEmpty) return 'فاتورة $offerTitle';

    return 'فاتورة حضانة';
  }

  dynamic invoiceCreatedDate(Map<String, dynamic> data) {
    return data['createdAt'] ?? data['updatedAt'] ?? data['dueDate'];
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
      final data = doc.data();
      return !isHiddenInvoiceStatus(data);
    }).toList();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> applyFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final cleanDocs = visibleDocs(docs);

    if (selectedStatus == 'all') return cleanDocs;

    return cleanDocs.where((doc) {
      final data = doc.data();
      final status = normalizeStatus(data['status'] ?? data['paymentStatus']);
      return status == selectedStatus;
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
      final status = normalizeStatus(
        doc.data()['status'] ?? doc.data()['paymentStatus'],
      );

      if (status == 'paid') {
        paid++;
      } else if (status == 'partial') {
        partial++;
      } else if (status == 'overdue') {
        overdue++;
      } else if (status == 'cancelled' || status == 'canceled') {
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
      case 'canceled':
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
    required String amount,
    required String dueDate,
  }) {
    final title = invoiceTitle.trim().isEmpty ? 'فاتورة' : invoiceTitle;
    final childPart =
        childrenNames.trim().isEmpty ? '' : ' للأطفال: $childrenNames';

    switch (normalizeStatus(status)) {
      case 'paid':
        return 'تم تسجيل الفاتورة "$title"$childPart كمدفوعة. المبلغ: $amount شيكل.';
      case 'partial':
        return 'تم تحديث الفاتورة "$title"$childPart كمدفوعة جزئيًا. المبلغ الإجمالي: $amount شيكل.';
      case 'overdue':
        return 'الفاتورة "$title"$childPart أصبحت متأخرة. المبلغ: $amount شيكل، تاريخ الاستحقاق: $dueDate.';
      case 'cancelled':
      case 'canceled':
        return 'تم إلغاء الفاتورة "$title"$childPart.';
      case 'unpaid':
      default:
        return 'تم تحديث حالة الفاتورة "$title"$childPart إلى غير مدفوعة. المبلغ: $amount شيكل.';
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
  final childrenNames = invoiceChildrenNames(invoiceData);
  final invoiceTitle = invoiceDisplayTitle(invoiceData);
  final amount = formatAmount(invoiceData['totalAmount']);
  final dueDate = formatDate(invoiceData['dueDate']);

  final title = buildNotificationTitle(newStatus);
  final body = buildNotificationBody(
    status: newStatus,
    invoiceTitle: invoiceTitle,
    childrenNames: childrenNames,
    amount: amount,
    dueDate: dueDate,
  );

  final currentUser = _auth.currentUser;

  String adminName = 'الإدارة';
  String adminRole = 'admin';

  if (currentUser != null) {
    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      final userData = userDoc.data() ?? <String, dynamic>{};

      adminName = (userData['displayName'] ??
              userData['name'] ??
              userData['fullName'] ??
              userData['username'] ??
              'الإدارة')
          .toString();

      adminRole = (userData['role'] ?? 'admin').toString();
    } catch (_) {
      adminName = 'الإدارة';
      adminRole = 'admin';
    }
  }

  await AppNotificationService.instance.notifyParent(
    parentUid: parentUid,
    parentUsername: parentUsername,
    parentName: parentName,
    title: title,
    body: body,
    type: 'invoice_updated',
    childId: childId,
    childName: childrenNames,
    priority: normalizeStatus(newStatus) == 'overdue' ? 'important' : 'normal',
    createdByUid: currentUser?.uid ?? '',
    createdByName: adminName,
    createdByRole: adminRole,
    extraData: {
      'invoiceId': invoiceId,
      'invoiceStatus': normalizeStatus(newStatus),
      'paymentStatus': normalizeStatus(newStatus),
      'category': 'invoice',
      'notificationType': 'invoice',
      'screen': 'invoices',
    },
  );
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

      final normalized = normalizeStatus(status);

      final updateData = <String, dynamic>{
        'status': normalized,
        'paymentStatus': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (normalized == 'paid') {
        updateData['paidAt'] = FieldValue.serverTimestamp();
      } else {
        updateData['paidAt'] = null;
      }

      await invoiceRef.update(updateData);

      await createParentInvoiceNotification(
        invoiceId: docId,
        invoiceData: {
          ...invoiceData,
          ...updateData,
          'status': normalized,
          'paymentStatus': normalized,
        },
        newStatus: normalized,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث حالة الفاتورة إلى ${statusLabel(normalized)}'),
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
    final normalizedStatus = normalizeStatus(currentStatus);

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
                  await updateInvoiceStatus(docId: docId, status: 'unpaid');
                },
              ),
              _StatusOptionTile(
                label: 'مدفوعة جزئيًا',
                color: Colors.blueGrey,
                selected: normalizedStatus == 'partial',
                onTap: () async {
                  Navigator.pop(context);
                  await updateInvoiceStatus(docId: docId, status: 'partial');
                },
              ),
              _StatusOptionTile(
                label: 'مدفوعة',
                color: Colors.green,
                selected: normalizedStatus == 'paid',
                onTap: () async {
                  Navigator.pop(context);
                  await updateInvoiceStatus(docId: docId, status: 'paid');
                },
              ),
              _StatusOptionTile(
                label: 'متأخرة',
                color: Colors.redAccent,
                selected: normalizedStatus == 'overdue',
                onTap: () async {
                  Navigator.pop(context);
                  await updateInvoiceStatus(docId: docId, status: 'overdue');
                },
              ),
              _StatusOptionTile(
                label: 'ملغاة',
                color: Colors.grey,
                selected: normalizedStatus == 'cancelled',
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

    final status = normalizeStatus(data['status'] ?? data['paymentStatus']);
    final dueDate = data['dueDate'];
    final createdAt = invoiceCreatedDate(data);

    final title = invoiceDisplayTitle(data);
    final childrenNames = invoiceChildrenNames(data);
    final childrenCount = invoiceChildrenCount(data);

    final parentName = (data['parentName'] ?? '').toString();
    final parentUsername = (data['parentUsername'] ?? '').toString();
    final billingType = (data['billingType'] ?? '').toString();
    final totalAmount = formatAmount(data['totalAmount']);
    final subtotalAmount = formatAmount(data['subtotalAmount']);
    final offerDiscount = formatAmount(data['offerDiscount'] ?? 0);
    final offerTitle = (data['offerTitle'] ?? '').toString().trim();

    final extraHoursAmount = formatAmount(
      data['extraHoursAmount'] ?? data['extraHoursTotal'] ?? 0,
    );

    final consultationsAmount = formatAmount(
      data['consultationsAmount'] ?? 0,
    );

    final billingMonthKey = (data['billingMonthKey'] ?? '').toString().trim();

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
                      if (childrenNames.trim().isNotEmpty)
                        Text(
                          childrenCount > 1
                              ? 'الأطفال: $childrenNames'
                              : 'الطفل: $childrenNames',
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
              icon: Icons.groups_2_outlined,
              title: 'عدد الأطفال',
              value: childrenCount <= 0 ? '-' : '$childrenCount',
            ),
            const SizedBox(height: 8),
            if (billingMonthKey.isNotEmpty) ...[
              _InvoiceInfoTile(
                icon: Icons.calendar_month_outlined,
                title: 'شهر الفاتورة',
                value: billingMonthKey,
              ),
              const SizedBox(height: 8),
            ],
            if (offerTitle.isNotEmpty) ...[
              _InvoiceInfoTile(
                icon: Icons.local_offer_outlined,
                title: 'العرض',
                value: offerTitle,
              ),
              const SizedBox(height: 8),
            ],
            _InvoiceInfoTile(
              icon: Icons.receipt_outlined,
              title: 'الإجمالي قبل الخصم',
              value: '$subtotalAmount شيكل',
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon: Icons.discount_outlined,
              title: 'الخصم',
              value: '$offerDiscount شيكل',
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon: Icons.payments_outlined,
              title: 'المبلغ الإجمالي',
              value: '$totalAmount شيكل',
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon: Icons.access_time_filled_rounded,
              title: 'الساعات الإضافية',
              value: '$extraHoursAmount شيكل',
            ),
            const SizedBox(height: 8),
            _InvoiceInfoTile(
              icon: Icons.psychology_alt_outlined,
              title: 'الاستشارات',
              value: '$consultationsAmount شيكل',
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'extra_hours_btn',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddExtraHoursPage(),
                ),
              );

              if (!mounted) return;

              if (result == true) {
                setState(() {});
              }
            },
            backgroundColor: Colors.orange,
            icon: const Icon(Icons.access_time_filled_rounded),
            label: const Text('الساعات الإضافية'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create_invoice_btn',
            onPressed: openCreateInvoice,
            icon: const Icon(Icons.add),
            label: const Text('إنشاء فاتورة'),
          ),
        ],
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