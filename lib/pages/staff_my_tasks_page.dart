import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StaffMyTasksPage extends StatefulWidget {
  const StaffMyTasksPage({super.key});

  @override
  State<StaffMyTasksPage> createState() => _StaffMyTasksPageState();
}

class _StaffMyTasksPageState extends State<StaffMyTasksPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime selectedDate = DateTime.now();

  bool isLoading = false;
  String? loadError;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks = [];

  String get dateKey {
    final y = selectedDate.year;
    final m = selectedDate.month.toString().padLeft(2, '0');
    final d = selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get isSelectedDateToday {
    return selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
  }

  String _clean(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyTasks();
    });
  }

  String _statusLabel(String status) {
    switch (status.trim()) {
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
    switch (status.trim()) {
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

  IconData _statusIcon(String status) {
    switch (status.trim()) {
      case 'done':
        return Icons.check_circle_outline;
      case 'not_done':
        return Icons.cancel_outlined;
      case 'partially_done':
        return Icons.timelapse;
      case 'needs_follow_up':
        return Icons.flag_outlined;
      case 'pending':
      default:
        return Icons.hourglass_empty;
    }
  }

  IconData _taskIcon(String taskType) {
    switch (taskType.trim()) {
      case 'cleaning':
        return Icons.cleaning_services_outlined;
      case 'cleaning_cooking':
        return Icons.restaurant_menu_outlined;
      case 'diaper_change':
        return Icons.child_friendly_outlined;
      case 'bathroom_assistance':
        return Icons.wc_outlined;
      case 'activities_photography':
        return Icons.palette_outlined;
      case 'class_management':
        return Icons.groups_2_outlined;
      case 'indoor_area':
        return Icons.home_work_outlined;
      case 'outdoor_area':
        return Icons.park_outlined;
      default:
        return Icons.task_alt_outlined;
    }
  }

  Future<void> _loadMyTasks() async {
    final user = _auth.currentUser;

    if (user == null) {
      setState(() {
        isLoading = false;
        loadError = 'لم يتم العثور على المستخدم الحالي. سجّلي الدخول مرة أخرى.';
        tasks = [];
      });
      return;
    }

    setState(() {
      isLoading = true;
      loadError = null;
      tasks = [];
    });

    try {
      final snapshot = await _firestore
          .collection('staff_tasks')
          .where('staffUid', isEqualTo: user.uid)
          .where('dateKey', isEqualTo: dateKey)
          .get()
          .timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw Exception(
            'انتهت مهلة تحميل المهام. تأكدي من الاتصال أو صلاحيات Firestore.',
          );
        },
      );

      final docs = snapshot.docs;

      docs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();

        final aTask = _clean(aData['taskLabel']).isEmpty
            ? _clean(aData['title'])
            : _clean(aData['taskLabel']);

        final bTask = _clean(bData['taskLabel']).isEmpty
            ? _clean(bData['title'])
            : _clean(bData['taskLabel']);

        return aTask.compareTo(bTask);
      });

      if (!mounted) return;

      setState(() {
        tasks = docs;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = e.toString();
        tasks = [];
      });
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

    await _loadMyTasks();
  }

  Widget _buildHeader() {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.assignment_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isSelectedDateToday
                        ? 'مهامي اليوم: $dateKey'
                        : 'مهامي بتاريخ: $dateKey',
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
                    onPressed: isLoading ? null : _pickDate,
                    icon: const Icon(Icons.date_range),
                    label: const Text('اختيار تاريخ'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.18)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blueGrey,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذه الصفحة للعرض فقط. حالة الإنجاز والملاحظات تعتمدها الإدارة.',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    int pending = 0;
    int done = 0;
    int notDone = 0;
    int partial = 0;
    int followUp = 0;

    for (final doc in tasks) {
      final status = _clean(doc.data()['taskStatus']).isEmpty
          ? 'pending'
          : _clean(doc.data()['taskStatus']);

      switch (status) {
        case 'done':
          done++;
          break;
        case 'not_done':
          notDone++;
          break;
        case 'partially_done':
          partial++;
          break;
        case 'needs_follow_up':
          followUp++;
          break;
        default:
          pending++;
      }
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _summaryChip(
              label: 'كل المهام',
              value: tasks.length,
              color: Colors.blue,
              icon: Icons.task_alt_outlined,
            ),
            _summaryChip(
              label: 'بانتظار',
              value: pending,
              color: Colors.blueGrey,
              icon: Icons.hourglass_empty,
            ),
            _summaryChip(
              label: 'تم الإنجاز',
              value: done,
              color: Colors.green,
              icon: Icons.check_circle_outline,
            ),
            _summaryChip(
              label: 'لم يتم',
              value: notDone,
              color: Colors.redAccent,
              icon: Icons.cancel_outlined,
            ),
            _summaryChip(
              label: 'جزئي',
              value: partial,
              color: Colors.orange,
              icon: Icons.timelapse,
            ),
            _summaryChip(
              label: 'متابعة',
              value: followUp,
              color: Colors.purple,
              icon: Icons.flag_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final taskLabel = _clean(data['taskLabel']).isEmpty
        ? _clean(data['title'])
        : _clean(data['taskLabel']);

    final taskType = _clean(data['taskType']);

    final status = _clean(data['taskStatus']).isEmpty
        ? 'pending'
        : _clean(data['taskStatus']);

    final statusLabel = _clean(data['statusLabel']).isEmpty
        ? _statusLabel(status)
        : _clean(data['statusLabel']);

    final notes = _clean(data['notes']);

    final adminNote = _clean(data['adminReviewNote']).isNotEmpty
        ? _clean(data['adminReviewNote'])
        : _clean(data['reviewNote']);

    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.14),
                  child: Icon(_taskIcon(taskType), color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    taskLabel.isEmpty ? 'مهمة بدون عنوان' : taskLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusIcon(status),
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildNoteBox(
                title: 'ملاحظات التوزيع',
                value: notes,
                icon: Icons.notes_outlined,
              ),
            ],
            if (adminNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildNoteBox(
                title: 'ملاحظات الإدارة',
                value: adminNote,
                icon: Icons.rate_review_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoteBox({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$title: $value',
              style: const TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.assignment_late_outlined,
              size: 48,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 12),
            Text(
              isSelectedDateToday
                  ? 'لا توجد مهام موزعة عليك اليوم'
                  : 'لا توجد مهام لكِ في هذا التاريخ',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ستظهر هنا المهام التي توزعها الإدارة عليكِ.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loadError ?? 'خطأ غير معروف',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isLoading ? null : _loadMyTasks,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (isLoading) {
      return Card(
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'جاري تحميل مهامك...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    if (loadError != null) {
      return _buildErrorState();
    }

    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildSummary(),
        ...tasks.map(_buildTaskCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xffF7F7F7),
        appBar: AppBar(
          title: const Text('مهامي اليومية'),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: _loadMyTasks,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildHeader(),
              _buildBodyContent(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}