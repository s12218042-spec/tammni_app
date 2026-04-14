import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AdminAccountDeletionRequestsPage extends StatefulWidget {
  const AdminAccountDeletionRequestsPage({super.key});

  @override
  State<AdminAccountDeletionRequestsPage> createState() =>
      _AdminAccountDeletionRequestsPageState();
}

class _AdminAccountDeletionRequestsPageState
    extends State<AdminAccountDeletionRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Set<String> selectedStatusFilters = {};
  String searchText = '';

  String normalizeRole(String value) {
    final role = value.trim().toLowerCase();
    if (role == 'nursery' || role == 'nursery staff') return 'nursery_staff';
    return role;
  }

  String roleLabel(String r) {
    switch (normalizeRole(r)) {
      case 'parent':
        return 'ولي أمر';
      case 'nursery_staff':
        return 'موظف/ة حضانة';
      case 'teacher':
        return 'معلمة روضة';
      case 'admin':
        return 'مدير النظام';
      default:
        return r;
    }
  }

  Color roleColor(String r) {
    switch (normalizeRole(r)) {
      case 'parent':
        return Colors.teal;
      case 'nursery_staff':
        return Colors.orange;
      case 'teacher':
        return Colors.indigo;
      case 'admin':
        return Colors.redAccent;
      default:
        return AppColors.primary;
    }
  }

  String statusLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'pending':
        return 'قيد المراجعة';
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'cancelled':
        return 'تم سحب الطلب';
      default:
        return value.isEmpty ? 'غير محدد' : value;
    }
  }

  Color statusColor(String value) {
    switch (value.trim().toLowerCase()) {
      case 'pending':
        return Colors.amber.shade700;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      case 'cancelled':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  String formatDate(dynamic raw) {
    if (raw is Timestamp) {
      final date = raw.toDate();
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'غير محدد';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> requestsStream() {
    return _firestore
        .collection('account_deletion_requests')
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  void toggleStatusFilter(String value) {
    setState(() {
      if (selectedStatusFilters.contains(value)) {
        selectedStatusFilters.remove(value);
      } else {
        selectedStatusFilters.add(value);
      }
    });
  }

  void clearAllFilters() {
    setState(() {
      selectedStatusFilters.clear();
      searchText = '';
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();

      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      final name =
          (data['displayName'] ?? data['name'] ?? '').toString().toLowerCase();
      final username = (data['username'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final role = normalizeRole((data['role'] ?? '').toString());

      final query = searchText.trim().toLowerCase();

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          username.contains(query) ||
          email.contains(query) ||
          role.contains(query);

      final matchesStatus = selectedStatusFilters.isEmpty ||
          selectedStatusFilters.contains(status);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Widget buildFilterChip({
    required String label,
    required String value,
    required Color color,
  }) {
    final isSelected = selectedStatusFilters.contains(value);

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => toggleStatusFilter(value),
      selectedColor: color,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? color : AppColors.primary.withOpacity(0.14),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Future<Map<String, String>> _getCurrentAdminInfo() async {
    return {
      'uid': '',
      'name': 'الإدارة',
      'role': 'admin',
    };
  }

  Future<void> _logAccountAction({
    required String targetUid,
    required String action,
    required String title,
    required String message,
    String status = 'info',
    String actorUid = '',
    String actorName = 'الإدارة',
    String actorRole = 'admin',
  }) async {
    await _firestore.collection('account_activity_logs').add({
      'targetUid': targetUid,
      'action': action,
      'title': title,
      'message': message,
      'status': status,
      'actorUid': actorUid,
      'actorName': actorName,
      'actorRole': actorRole,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveRequest({
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    final uid = (requestData['uid'] ?? '').toString().trim();

    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('معرّف المستخدم غير موجود في الطلب')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('قبول طلب الحذف'),
          content: const Text(
            'عند قبول الطلب سيتم تعطيل الحساب ووضعه كطلب حذف مقبول بانتظار المعالجة النهائية. هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              child: const Text('قبول الطلب'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final adminInfo = await _getCurrentAdminInfo();

    try {
      final batch = _firestore.batch();

      final userRef = _firestore.collection('users').doc(uid);
      final requestRef =
          _firestore.collection('account_deletion_requests').doc(requestId);
      final notificationRef = _firestore.collection('notifications').doc();
      final queueRef = _firestore.collection('final_deletion_queue').doc();

      batch.set(userRef, {
        'isActive': false,
        'accountStatus': 'pending_deletion',
        'deletionRequested': true,
        'deletionRequestType': 'permanent',
        'deletionApproved': true,
        'deletionApprovedAt': FieldValue.serverTimestamp(),
        'readyForFinalDelete': true,
        'finalDeletionStatus': 'queued',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(requestRef, {
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
        'processedByUid': adminInfo['uid'],
        'processedByName': adminInfo['name'],
        'reviewNote': 'تمت الموافقة على طلب الحذف من الإدارة',
      }, SetOptions(merge: true));

      batch.set(queueRef, {
        'targetUid': uid,
        'requestId': requestId,
        'status': 'queued',
        'queuedAt': FieldValue.serverTimestamp(),
        'queuedByUid': adminInfo['uid'],
        'queuedByName': adminInfo['name'],
        'deleteFromFirestore': true,
        'deleteFromAuth': true,
      });

      batch.set(notificationRef, {
        'uid': uid,
        'targetUid': uid,
        'title': 'تم قبول طلب حذف الحساب',
        'body':
            'تمت الموافقة على طلب حذف الحساب من الإدارة، وتم إيقاف الحساب بانتظار المعالجة النهائية.',
        'message':
            'تمت الموافقة على طلب حذف الحساب من الإدارة، وتم إيقاف الحساب بانتظار المعالجة النهائية.',
        'type': 'account_deletion_request',
        'status': 'approved',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      await _logAccountAction(
        targetUid: uid,
        action: 'deletion_request_approved',
        title: 'تم قبول طلب حذف الحساب',
        message:
            'قامت الإدارة بالموافقة على طلب الحذف وإرسال الحساب إلى قائمة الحذف النهائي',
        status: 'danger',
        actorUid: adminInfo['uid'] ?? '',
        actorName: adminInfo['name'] ?? 'الإدارة',
        actorRole: adminInfo['role'] ?? 'admin',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قبول طلب الحذف بنجاح ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء قبول الطلب: $e')),
      );
    }
  }

  Future<void> rejectRequest({
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    final uid = (requestData['uid'] ?? '').toString().trim();
    final noteController = TextEditingController();

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text('رفض طلب الحذف'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'يمكنك إضافة ملاحظة توضح سبب الرفض:',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'مثال: يرجى مراجعة الإدارة أولاً',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, noteController.text.trim()),
                child: const Text('رفض الطلب'),
              ),
            ],
          ),
        ),
      );

      if (result == null) return;

      final adminInfo = await _getCurrentAdminInfo();

      final batch = _firestore.batch();

      final requestRef =
          _firestore.collection('account_deletion_requests').doc(requestId);

      batch.set(requestRef, {
        'status': 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        'processedByUid': adminInfo['uid'],
        'processedByName': adminInfo['name'],
        'reviewNote': result,
      }, SetOptions(merge: true));

      if (uid.isNotEmpty) {
        final userRef = _firestore.collection('users').doc(uid);
        final notificationRef = _firestore.collection('notifications').doc();

        batch.set(userRef, {
          'deletionRequested': false,
          'deletionRequestType': '',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        batch.set(notificationRef, {
          'uid': uid,
          'targetUid': uid,
          'title': 'تم رفض طلب حذف الحساب',
          'body': result.isNotEmpty
              ? 'تم رفض طلب حذف الحساب. ملاحظة الإدارة: $result'
              : 'تم رفض طلب حذف الحساب من الإدارة.',
          'message': result.isNotEmpty
              ? 'تم رفض طلب حذف الحساب. ملاحظة الإدارة: $result'
              : 'تم رفض طلب حذف الحساب من الإدارة.',
          'type': 'account_deletion_request',
          'status': 'rejected',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await _logAccountAction(
        targetUid: uid,
        action: 'deletion_request_rejected',
        title: 'تم رفض طلب حذف الحساب',
        message: result.isNotEmpty
            ? 'قامت الإدارة برفض طلب الحذف. الملاحظة: $result'
            : 'قامت الإدارة برفض طلب حذف الحساب',
        status: 'warning',
        actorUid: adminInfo['uid'] ?? '',
        actorName: adminInfo['name'] ?? 'الإدارة',
        actorRole: adminInfo['role'] ?? 'admin',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض طلب الحذف ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء رفض الطلب: $e')),
      );
    } finally {
      noteController.dispose();
    }
  }

  Future<void> openRequestDetailsDialog(
    Map<String, dynamic> data,
  ) async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('تفاصيل طلب الحذف'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RequestDetailsSection(
                    title: 'بيانات الحساب',
                    children: [
                      _RequestDetailItem(
                        label: 'الاسم',
                        value:
                            (data['displayName'] ?? data['name'] ?? '')
                                .toString(),
                      ),
                      _RequestDetailItem(
                        label: 'اسم المستخدم',
                        value: (data['username'] ?? '').toString(),
                      ),
                      _RequestDetailItem(
                        label: 'البريد الإلكتروني',
                        value: (data['email'] ?? '').toString(),
                      ),
                      _RequestDetailItem(
                        label: 'الدور',
                        value: roleLabel((data['role'] ?? '').toString()),
                      ),
                    ],
                  ),
                  _RequestDetailsSection(
                    title: 'بيانات الطلب',
                    children: [
                      _RequestDetailItem(
                        label: 'نوع الطلب',
                        value:
                            (data['requestType'] ?? 'permanent_delete')
                                        .toString() ==
                                    'permanent_delete'
                                ? 'حذف دائم'
                                : (data['requestType'] ?? '').toString(),
                      ),
                      _RequestDetailItem(
                        label: 'الحالة',
                        value: statusLabel((data['status'] ?? '').toString()),
                      ),
                      _RequestDetailItem(
                        label: 'تاريخ الطلب',
                        value: formatDate(data['requestedAt']),
                      ),
                      _RequestDetailItem(
                        label: 'تاريخ المعالجة',
                        value: formatDate(data['processedAt']),
                      ),
                      _RequestDetailItem(
                        label: 'تاريخ سحب الطلب',
                        value: formatDate(data['cancelledAt']),
                      ),
                      _RequestDetailItem(
                        label: 'عولج بواسطة',
                        value: (data['processedByName'] ?? '').toString(),
                      ),
                      _RequestDetailItem(
                        label: 'ملاحظة الإدارة',
                        value: (data['reviewNote'] ?? '').toString(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomFilters =
        selectedStatusFilters.isNotEmpty || searchText.trim().isNotEmpty;

    return AppPageScaffold(
      title: 'طلبات حذف الحسابات',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: requestsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('حدث خطأ: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = applyFilters(docs);

          return ListView(
            children: [
              Text(
                'طلبات الحذف الدائم',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'مراجعة طلبات حذف الحسابات المقدمة من المستخدمين وقبولها أو رفضها.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: 'ابحثي بالاسم أو اسم المستخدم أو الإيميل',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: searchText.trim().isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    setState(() {
                                      searchText = '';
                                    });
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchText = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'حالة الطلب',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildFilterChip(
                            label: 'قيد المراجعة',
                            value: 'pending',
                            color: Colors.amber.shade700,
                          ),
                          buildFilterChip(
                            label: 'مقبول',
                            value: 'approved',
                            color: Colors.green,
                          ),
                          buildFilterChip(
                            label: 'مرفوض',
                            value: 'rejected',
                            color: Colors.redAccent,
                          ),
                          buildFilterChip(
                            label: 'تم سحب الطلب',
                            value: 'cancelled',
                            color: Colors.blueGrey,
                          ),
                        ],
                      ),
                      if (hasCustomFilters) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: clearAllFilters,
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('إعادة تعيين الفلاتر'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (filteredDocs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'لا توجد طلبات مطابقة حاليًا.',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              else
                ...filteredDocs.map((doc) {
                  final data = doc.data();
                  final status = (data['status'] ?? '').toString();
                  final isPending = status.trim().toLowerCase() == 'pending';

                  return _DeletionRequestCard(
                    name:
                        (data['displayName'] ?? data['name'] ?? 'بدون اسم')
                            .toString(),
                    username: (data['username'] ?? '').toString(),
                    email: (data['email'] ?? '').toString(),
                    roleText: roleLabel((data['role'] ?? '').toString()),
                    roleColor: roleColor((data['role'] ?? '').toString()),
                    statusText: statusLabel(status),
                    statusColor: statusColor(status),
                    requestedAt: formatDate(data['requestedAt']),
                    reviewNote: (data['reviewNote'] ?? '').toString(),
                    isPending: isPending,
                    onViewDetails: () => openRequestDetailsDialog(data),
                    onApprove: () => approveRequest(
                      requestId: doc.id,
                      requestData: data,
                    ),
                    onReject: () => rejectRequest(
                      requestId: doc.id,
                      requestData: data,
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

class _DeletionRequestCard extends StatelessWidget {
  final String name;
  final String username;
  final String email;
  final String roleText;
  final Color roleColor;
  final String statusText;
  final Color statusColor;
  final String requestedAt;
  final String reviewNote;
  final bool isPending;
  final VoidCallback onViewDetails;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _DeletionRequestCard({
    required this.name,
    required this.username,
    required this.email,
    required this.roleText,
    required this.roleColor,
    required this.statusText,
    required this.statusColor,
    required this.requestedAt,
    required this.reviewNote,
    required this.isPending,
    required this.onViewDetails,
    required this.onApprove,
    required this.onReject,
  });

  Widget buildChip({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: roleColor.withOpacity(0.15),
                  child: Text(
                    name.trim().isNotEmpty ? name.trim()[0] : '؟',
                    style: TextStyle(
                      color: roleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'اسم المستخدم: $username',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildChip(label: roleText, color: roleColor),
                buildChip(label: statusText, color: statusColor),
                buildChip(
                  label: 'تاريخ الطلب: $requestedAt',
                  color: AppColors.primary,
                ),
              ],
            ),
            if (reviewNote.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'ملاحظة الإدارة: $reviewNote',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('تفاصيل'),
                  ),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('رفض'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(
                          color: AppColors.danger,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      label: const Text('قبول'),
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
}

class _RequestDetailsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _RequestDetailsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final visibleChildren = children.where((widget) {
      if (widget is _RequestDetailItem) {
        return widget.value.trim().isNotEmpty &&
            widget.value.trim() != 'غير محدد';
      }
      return true;
    }).toList();

    if (visibleChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 10),
          ...visibleChildren,
        ],
      ),
    );
  }
}

class _RequestDetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _RequestDetailItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}