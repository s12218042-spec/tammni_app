import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminStaffTasksReviewPage extends StatefulWidget {
  const AdminStaffTasksReviewPage({super.key});

  @override
  State<AdminStaffTasksReviewPage> createState() =>
      _AdminStaffTasksReviewPageState();
}

class _AdminStaffTasksReviewPageState extends State<AdminStaffTasksReviewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get isToday {
    return selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
  }

  String get dateKey {
    final y = selectedDate.year;
    final m = selectedDate.month.toString().padLeft(2, '0');
    final d = selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _clean(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _safeStatus(dynamic value) {
    final raw = _clean(value).toLowerCase();

    const allowed = {
      'pending',
      'done',
      'not_done',
      'partially_done',
      'needs_follow_up',
    };

    if (allowed.contains(raw)) return raw;
    return 'pending';
  }

  String _statusLabel(String status) {
    switch (_safeStatus(status)) {
      case 'done':
        return 'تم الإنجاز';
      case 'not_done':
        return 'لم يتم الإنجاز';
      case 'partially_done':
        return 'تم الإنجاز جزئيًا';
      case 'needs_follow_up':
        return 'بحاجة متابعة';
      case 'pending':
      default:
        return 'بانتظار اعتماد الإدارة';
    }
  }

  Color _statusColor(String status) {
    switch (_safeStatus(status)) {
      case 'done':
        return Colors.green;
      case 'not_done':
        return Colors.redAccent;
      case 'partially_done':
        return Colors.orange;
      case 'needs_follow_up':
        return Colors.purple;
      case 'pending':
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );

    if (picked == null) return;

    setState(() {
      selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _fetchTasksForSelectedDate() async {
    final snapshot = await _firestore
        .collection('staff_tasks')
        .where('dateKey', isEqualTo: dateKey)
        .get();

    final docs = snapshot.docs.toList();

    docs.sort((a, b) {
      final aName = _clean(a.data()['staffName']);
      final bName = _clean(b.data()['staffName']);
      if (aName != bName) return aName.compareTo(bName);

      final aTask = _clean(a.data()['taskLabel']);
      final bTask = _clean(b.data()['taskLabel']);
      return aTask.compareTo(bTask);
    });

    return docs;
  }

  Future<void> _updateTaskStatus({
    required String taskId,
    required String newStatus,
    required String note,
  }) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final safeStatus = _safeStatus(newStatus);

      await _firestore.collection('staff_tasks').doc(taskId).update({
        'taskStatus': safeStatus,
        'statusLabel': _statusLabel(safeStatus),
        'adminReviewNote': note,
        'reviewNote': note,
        'reviewedByRole': 'admin',
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث حالة المهمة بنجاح')),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحديث المهمة: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _openReviewDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (!isToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن تعديل مهام الأيام السابقة. العرض فقط.'),
        ),
      );
      return;
    }

    final data = doc.data();

    String selectedStatus = _safeStatus(data['taskStatus']);

    final noteController = TextEditingController(
      text: _clean(data['adminReviewNote']).isNotEmpty
          ? _clean(data['adminReviewNote'])
          : _clean(data['reviewNote']),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('متابعة مهمة الموظفة'),
                content: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _dialogInfo(
                          'الموظفة',
                          _clean(data['staffName']).isEmpty
                              ? 'غير محددة'
                              : _clean(data['staffName']),
                        ),
                        const SizedBox(height: 8),
                        _dialogInfo(
                          'المهمة',
                          _clean(data['taskLabel']).isEmpty
                              ? (_clean(data['title']).isEmpty
                                  ? 'مهمة بدون عنوان'
                                  : _clean(data['title']))
                              : _clean(data['taskLabel']),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'حالة المهمة',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'pending',
                              child: Text('بانتظار اعتماد الإدارة'),
                            ),
                            DropdownMenuItem(
                              value: 'done',
                              child: Text('تم الإنجاز'),
                            ),
                            DropdownMenuItem(
                              value: 'not_done',
                              child: Text('لم يتم الإنجاز'),
                            ),
                            DropdownMenuItem(
                              value: 'partially_done',
                              child: Text('تم الإنجاز جزئيًا'),
                            ),
                            DropdownMenuItem(
                              value: 'needs_follow_up',
                              child: Text('بحاجة متابعة'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              selectedStatus = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteController,
                          maxLines: 3,
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات الإدارة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogContext);

                      await _updateTaskStatus(
                        taskId: doc.id,
                        newStatus: selectedStatus,
                        note: noteController.text.trim(),
                      );
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('حفظ'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    noteController.dispose();
  }

  Widget _dialogInfo(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.fact_check_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'مهام تاريخ: $dateKey',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  fit: FlexFit.loose,
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.date_range),
                    label: const Text('اختيار تاريخ'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isToday
                    ? Colors.green.withOpacity(0.08)
                    : Colors.blueGrey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isToday
                    ? 'مهام اليوم: يمكن تعديل الحالة وملاحظات الإدارة.'
                    : 'أرشيف يوم سابق: عرض فقط بدون تعديل.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isToday ? Colors.green : Colors.blueGrey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final staffName = _clean(data['staffName']).isEmpty
        ? 'موظفة غير محددة'
        : _clean(data['staffName']);

    final staffUsername = _clean(data['staffUsername']);

    final taskLabel = _clean(data['taskLabel']).isEmpty
        ? (_clean(data['title']).isEmpty
            ? 'مهمة بدون عنوان'
            : _clean(data['title']))
        : _clean(data['taskLabel']);

    final status = _safeStatus(data['taskStatus']);
    final notes = _clean(data['notes']);
    final adminNote = _clean(data['adminReviewNote']).isNotEmpty
        ? _clean(data['adminReviewNote'])
        : _clean(data['reviewNote']);

    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(Icons.task_alt_outlined, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staffName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (staffUsername.isNotEmpty)
                        Text(
                          '@$staffUsername',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  fit: FlexFit.loose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              taskLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'التاريخ: ${_clean(data['dateKey']).isEmpty ? dateKey : _clean(data['dateKey'])}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _noteBox('ملاحظات التوزيع', notes),
            ],
            if (adminNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              _noteBox('ملاحظات الإدارة', adminNote),
            ],
            const SizedBox(height: 12),
            if (isToday)
              OutlinedButton.icon(
                onPressed: isLoading ? null : () => _openReviewDialog(doc),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تعديل حالة المهمة'),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'عرض فقط - لا يمكن تعديل مهام الأيام السابقة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _noteBox(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$title: $value',
        style: const TextStyle(
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Colors.blueGrey,
            ),
            SizedBox(height: 12),
            Text(
              'لا توجد مهام في هذا التاريخ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'اختاري تاريخ المهمة من زر اختيار تاريخ.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'حدث خطأ أثناء تحميل المهام',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksList() {
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _fetchTasksForSelectedDate(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.all(12),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'جاري تحميل المهام...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data ?? [];

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: docs.map(_buildTaskCard).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xffF7F7F7),
        appBar: AppBar(
          title: const Text('متابعة مهام الموظفات'),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildHeader(),
              _buildTasksList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}