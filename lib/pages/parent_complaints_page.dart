import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class ParentComplaintsPage extends StatefulWidget {
  final String parentUsername;

  const ParentComplaintsPage({
    super.key,
    required this.parentUsername,
  });

  @override
  State<ParentComplaintsPage> createState() => _ParentComplaintsPageState();
}

class _ParentComplaintsPageState extends State<ParentComplaintsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isSubmitting = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _safeText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  Timestamp? _resolveTimestamp(Map<String, dynamic> data) {
    final candidates = [
      data['createdAt'],
      data['updatedAt'],
      data['reviewedAt'],
    ];

    for (final value in candidates) {
      if (value is Timestamp) return value;
    }

    return null;
  }

  Future<Map<String, dynamic>> _getParentInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cleanUsername = widget.parentUsername.trim().toLowerCase();

    if (uid != null) {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();

      if (data != null) {
        return {
          'uid': uid,
          'name': _safeText(
            data['name'] ?? data['displayName'],
            fallback: 'وليّ الأمر',
          ),
          'username': _safeText(
            data['username'],
            fallback: cleanUsername,
          ).toLowerCase(),
        };
      }
    }

    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: cleanUsername)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      return {
        'uid': _safeText(data['uid']),
        'name': _safeText(
          data['name'] ?? data['displayName'],
          fallback: 'وليّ الأمر',
        ),
        'username': _safeText(
          data['username'],
          fallback: cleanUsername,
        ).toLowerCase(),
      };
    }

    return {
      'uid': uid ?? '',
      'name': 'وليّ الأمر',
      'username': cleanUsername,
    };
  }

  Future<void> _submitComplaint() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال عنوان الشكوى'),
        ),
      );
      return;
    }

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة تفاصيل الشكوى'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final parentInfo = await _getParentInfo();

      await _firestore.collection('complaints').add({
        'title': title,
        'message': message,
        'status': 'pending',
        'parentUid': _safeText(parentInfo['uid']),
        'parentName': _safeText(parentInfo['name'], fallback: 'وليّ الأمر'),
        'parentUsername':
            _safeText(parentInfo['username']).trim().toLowerCase(),
        'adminReply': '',
        'reviewNote': '',
        'reviewedByName': '',
        'reviewedByUid': '',
        'reviewedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _titleController.clear();
      _messageController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الشكوى بنجاح'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال الشكوى: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return 'قيد الانتظار';
      case 'in_review':
        return 'قيد المراجعة';
      case 'resolved':
        return 'تم الحل';
      case 'rejected':
        return 'مرفوضة';
      default:
        return 'غير محددة';
    }
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in_review':
        return Colors.blue;
      case 'resolved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.textLight;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'in_review':
        return Icons.manage_search_rounded;
      case 'resolved':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'غير محدد';
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final q = _searchQuery.trim().toLowerCase();

    final filtered = docs.where((doc) {
      final data = doc.data();
      final title = _safeText(data['title']).toLowerCase();
      final message = _safeText(data['message']).toLowerCase();
      final status = _safeText(data['status']).toLowerCase();
      final adminReply = _safeText(data['adminReply']).toLowerCase();
      final reviewNote = _safeText(data['reviewNote']).toLowerCase();

      if (q.isEmpty) return true;

      return title.contains(q) ||
          message.contains(q) ||
          status.contains(q) ||
          adminReply.contains(q) ||
          reviewNote.contains(q);
    }).toList();

    filtered.sort((a, b) {
      final aTime = _resolveTimestamp(a.data());
      final bTime = _resolveTimestamp(b.data());

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return filtered;
  }

  Future<void> _showComplaintDetails(Map<String, dynamic> data) async {
    final status = _safeText(data['status'], fallback: 'pending');
    final adminReply = _safeText(data['adminReply']);
    final reviewNote = _safeText(data['reviewNote']);
    final reviewedByName = _safeText(data['reviewedByName']);

    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تفاصيل الشكوى'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailItem(
                  label: 'عنوان الشكوى',
                  value: _safeText(data['title'], fallback: 'بدون عنوان'),
                ),
                _detailItem(
                  label: 'الحالة',
                  value: _statusLabel(status),
                ),
                _detailItem(
                  label: 'تاريخ الإرسال',
                  value: _formatDate(data['createdAt']),
                ),
                _detailItem(
                  label: 'نص الشكوى',
                  value: _safeText(data['message'], fallback: 'لا يوجد نص'),
                  isMultiline: true,
                ),
                _detailItem(
                  label: 'رد الإدارة',
                  value: adminReply.isEmpty ? 'لا يوجد رد بعد' : adminReply,
                  isMultiline: true,
                ),
                if (reviewNote.isNotEmpty)
                  _detailItem(
                    label: 'ملاحظة الإدارة',
                    value: reviewNote,
                    isMultiline: true,
                  ),
                if (reviewedByName.isNotEmpty)
                  _detailItem(
                    label: 'تمت المراجعة بواسطة',
                    value: reviewedByName,
                  ),
                if (data['reviewedAt'] != null)
                  _detailItem(
                    label: 'تاريخ المراجعة',
                    value: _formatDate(data['reviewedAt']),
                  ),
              ],
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

  Widget _detailItem({
    required String label,
    required String value,
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: isMultiline ? FontWeight.w500 : FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _complaintsStream() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final cleanUsername = widget.parentUsername.trim().toLowerCase();

    if (currentUid != null && currentUid.trim().isNotEmpty) {
      return _firestore
          .collection('complaints')
          .where('parentUid', isEqualTo: currentUid)
          .snapshots();
    }

    return _firestore
        .collection('complaints')
        .where('parentUsername', isEqualTo: cleanUsername)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الشكاوى والملاحظات',
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.red.withOpacity(0.12),
                        child: const Icon(
                          Icons.report_problem_outlined,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'إرسال شكوى أو ملاحظة للإدارة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الشكوى',
                      hintText: 'مثال: ملاحظة على المتابعة أو الفواتير',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'تفاصيل الشكوى',
                      hintText: 'اكتبي هنا تفاصيل الشكوى أو الملاحظة بشكل واضح',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitComplaint,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _isSubmitting ? 'جاري الإرسال...' : 'إرسال الشكوى',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'ابحث في شكاواك السابقة',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _complaintsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('حدث خطأ أثناء تحميل الشكاوى: ${snapshot.error}'),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];
                final docs = _applyFilters(allDocs);

                if (docs.isEmpty) {
                  return ListView(
                    children: const [
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 44,
                                color: AppColors.textLight,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'لا توجد شكاوى مرسلة حتى الآن',
                                style: TextStyle(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'عند إرسال شكوى أو ملاحظة ستظهر هنا لمتابعة حالتها ورد الإدارة عليها.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final title =
                        _safeText(data['title'], fallback: 'شكوى بدون عنوان');
                    final message = _safeText(data['message']);
                    final status = _safeText(data['status'], fallback: 'pending');
                    final adminReply = _safeText(data['adminReply']);
                    final reviewNote = _safeText(data['reviewNote']);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        _statusColor(status).withOpacity(0.12),
                                    child: Icon(
                                      _statusIcon(status),
                                      color: _statusColor(status),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15.5,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _statusColor(status).withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _statusLabel(status),
                                      style: TextStyle(
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  message.isEmpty ? 'لا يوجد وصف مرفق' : message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 16,
                                    color: AppColors.textLight,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDate(data['createdAt']),
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                              if (adminReply.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(0.12),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'رد الإدارة',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        adminReply,
                                        style: const TextStyle(
                                          color: AppColors.textDark,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (reviewNote.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.14),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ملاحظة الإدارة',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        reviewNote,
                                        style: const TextStyle(
                                          color: AppColors.textDark,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showComplaintDetails(data),
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text('عرض التفاصيل'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}