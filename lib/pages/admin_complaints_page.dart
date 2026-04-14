import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class AdminComplaintsPage extends StatefulWidget {
  const AdminComplaintsPage({super.key});

  @override
  State<AdminComplaintsPage> createState() => _AdminComplaintsPageState();
}

class _AdminComplaintsPageState extends State<AdminComplaintsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  final Set<String> _selectedStatuses = {};

  final List<Map<String, String>> _statusOptions = const [
    {'value': 'pending', 'label': 'قيد الانتظار'},
    {'value': 'in_review', 'label': 'قيد المراجعة'},
    {'value': 'resolved', 'label': 'تم الحل'},
    {'value': 'rejected', 'label': 'مرفوضة'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  void _toggleStatusFilter(String value) {
    setState(() {
      if (_selectedStatuses.contains(value)) {
        _selectedStatuses.remove(value);
      } else {
        _selectedStatuses.add(value);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedStatuses.clear();
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Future<void> _updateComplaintStatus({
    required String docId,
    required String newStatus,
    String? adminReply,
  }) async {
    try {
      final data = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'resolved') {
        data['resolvedAt'] = FieldValue.serverTimestamp();
      }

      if (adminReply != null) {
        data['adminReply'] = adminReply.trim();
      }

      await _firestore.collection('complaints').doc(docId).set(
            data,
            SetOptions(merge: true),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تحديث حالة الشكوى بنجاح',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تحديث الشكوى: $e',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  Future<void> _showComplaintDetails({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final replyController = TextEditingController(
      text: (data['adminReply'] ?? '').toString(),
    );

    final currentStatus = (data['status'] ?? 'pending').toString();
    String selectedStatus = currentStatus.isEmpty ? 'pending' : currentStatus;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('تفاصيل الشكوى'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailItem(
                        label: 'عنوان الشكوى',
                        value: (data['title'] ?? 'بدون عنوان').toString(),
                      ),
                      _detailItem(
                        label: 'وليّ الأمر',
                        value: (data['parentName'] ?? 'غير محدد').toString(),
                      ),
                      _detailItem(
                        label: 'اسم المستخدم',
                        value:
                            (data['parentUsername'] ?? 'غير محدد').toString(),
                      ),
                      _detailItem(
                        label: 'الحالة الحالية',
                        value: _statusLabel(
                          (data['status'] ?? 'pending').toString(),
                        ),
                      ),
                      _detailItem(
                        label: 'تاريخ الإرسال',
                        value: _formatDate(data['createdAt']),
                      ),
                      _detailItem(
                        label: 'محتوى الشكوى',
                        value: (data['message'] ?? 'لا يوجد نص').toString(),
                        isMultiline: true,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'تحديث الحالة',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: _statusOptions
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option['value']!,
                                child: Text(option['label']!),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setLocalState(() {
                            selectedStatus = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: replyController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'رد الأدمن / ملاحظة إدارية',
                          hintText: 'اكتبي ردًا أو ملاحظة داخلية على الشكوى',
                          prefixIcon: Icon(Icons.reply_all_rounded),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _updateComplaintStatus(
                        docId: docId,
                        newStatus: selectedStatus,
                        adminReply: replyController.text,
                      );

                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('حفظ التحديث'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    replyController.dispose();
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();

      final status = (data['status'] ?? 'pending').toString().trim();
      final title = (data['title'] ?? '').toString().toLowerCase();
      final message = (data['message'] ?? '').toString().toLowerCase();
      final parentName = (data['parentName'] ?? '').toString().toLowerCase();
      final parentUsername =
          (data['parentUsername'] ?? '').toString().toLowerCase();

      final matchesStatus =
          _selectedStatuses.isEmpty || _selectedStatuses.contains(status);

      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          title.contains(q) ||
          message.contains(q) ||
          parentName.contains(q) ||
          parentUsername.contains(q);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'شكاوي أولياء الأمور',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('complaints')
            .orderBy('createdAt', descending: true)
            .snapshots(),
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

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildTopSummary(allDocs, docs),
                const SizedBox(height: 16),
                _buildSearchAndFilters(),
                const SizedBox(height: 16),
                if (docs.isEmpty)
                  _buildEmptyState()
                else
                  ...docs.map((doc) {
                    final data = doc.data();
                    final title =
                        (data['title'] ?? 'شكوى بدون عنوان').toString();
                    final message = (data['message'] ?? '').toString();
                    final parentName =
                        (data['parentName'] ?? 'وليّ أمر غير محدد').toString();
                    final parentUsername =
                        (data['parentUsername'] ?? '').toString();
                    final status = (data['status'] ?? 'pending').toString();

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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15.5,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          parentUsername.isNotEmpty
                                              ? '$parentName • @$parentUsername'
                                              : parentName,
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
                                  message.isEmpty
                                      ? 'لا يوجد وصف مرفق للشكوى'
                                      : message,
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
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        _showComplaintDetails(
                                          docId: doc.id,
                                          data: data,
                                        );
                                      },
                                      icon: const Icon(Icons.visibility_outlined),
                                      label: const Text('عرض التفاصيل'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        _showComplaintDetails(
                                          docId: doc.id,
                                          data: data,
                                        );
                                      },
                                      icon: const Icon(Icons.edit_note_rounded),
                                      label: const Text('مراجعة الشكوى'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopSummary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs,
  ) {
    final pendingCount = allDocs.where((doc) {
      return (doc.data()['status'] ?? 'pending').toString() == 'pending';
    }).length;

    final reviewCount = allDocs.where((doc) {
      return (doc.data()['status'] ?? '').toString() == 'in_review';
    }).length;

    final resolvedCount = allDocs.where((doc) {
      return (doc.data()['status'] ?? '').toString() == 'resolved';
    }).length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'إجمالي الشكاوى',
                value: allDocs.length.toString(),
                icon: Icons.feedback_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                title: 'قيد الانتظار',
                value: pendingCount.toString(),
                icon: Icons.schedule_rounded,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'قيد المراجعة',
                value: reviewCount.toString(),
                icon: Icons.manage_search_rounded,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                title: 'تم الحل',
                value: resolvedCount.toString(),
                icon: Icons.verified_rounded,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'عدد الشكاوى الظاهرة بعد الفلترة: ${filteredDocs.length}',
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final hasCustomFilters =
        _searchQuery.trim().isNotEmpty || _selectedStatuses.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'ابحثي بالعنوان أو اسم ولي الأمر أو اسم المستخدم',
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statusOptions.map((option) {
                  final value = option['value']!;
                  final selected = _selectedStatuses.contains(value);

                  return FilterChip(
                    label: Text(option['label']!),
                    selected: selected,
                    onSelected: (_) {
                      _toggleStatusFilter(value);
                    },
                    selectedColor: _statusColor(value).withOpacity(0.18),
                    labelStyle: TextStyle(
                      color: selected
                          ? _statusColor(value)
                          : AppColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: selected
                          ? _statusColor(value)
                          : AppColors.border,
                    ),
                    backgroundColor: Colors.white,
                    checkmarkColor: _statusColor(value),
                  );
                }).toList(),
              ),
            ),
            if (hasCustomFilters) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('إعادة تعيين الفلاتر'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: const [
            Icon(
              Icons.inbox_outlined,
              size: 44,
              color: AppColors.textLight,
            ),
            SizedBox(height: 12),
            Text(
              'لا توجد شكاوى مطابقة حاليًا',
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'جرّبي تغيير البحث أو الفلاتر أو انتظري شكاوى جديدة.',
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
}