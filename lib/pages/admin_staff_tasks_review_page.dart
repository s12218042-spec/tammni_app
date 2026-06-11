import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminStaffTasksReviewPage extends StatefulWidget {
  const AdminStaffTasksReviewPage({super.key});

  @override
  State<AdminStaffTasksReviewPage> createState() =>
      _AdminStaffTasksReviewPageState();
}

class _AdminStaffTasksReviewPageState
    extends State<AdminStaffTasksReviewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  final ScrollController _scrollController = ScrollController();

  String selectedStatus = 'all';

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

    if (raw == 'done' || raw == 'completed') {
      return 'done';
    }

    return 'not_done';
  }

  String _statusLabel(String status) {
    switch (_safeStatus(status)) {
      case 'done':
        return 'تم الإنجاز';
      case 'not_done':
      default:
        return 'لم يتم الإنجاز';
    }
  }

  Color _statusColor(String status) {
    switch (_safeStatus(status)) {
      case 'done':
        return Colors.green;
      case 'not_done':
      default:
        return Colors.redAccent;
    }
  }

  IconData _statusIcon(String status) {
    switch (_safeStatus(status)) {
      case 'done':
        return Icons.check_circle_rounded;
      case 'not_done':
      default:
        return Icons.cancel_rounded;
    }
  }

  Future<Map<String, String>> _currentAdminInfo() async {
    final user = _auth.currentUser;

    if (user == null) {
      return {
        'uid': '',
        'name': 'الإدارة',
        'role': 'admin',
      };
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      final name = _clean(data['displayName']).isNotEmpty
          ? _clean(data['displayName'])
          : _clean(data['name']).isNotEmpty
              ? _clean(data['name'])
              : _clean(data['fullName']).isNotEmpty
                  ? _clean(data['fullName'])
                  : _clean(data['username']).isNotEmpty
                      ? _clean(data['username'])
                      : 'الإدارة';

      return {
        'uid': user.uid,
        'name': name,
        'role':
            _clean(data['role']).isNotEmpty ? _clean(data['role']) : 'admin',
      };
    } catch (_) {
      return {
        'uid': user.uid,
        'name': 'الإدارة',
        'role': 'admin',
      };
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2025),
      lastDate: today,
    );

    if (picked == null) return;

    setState(() {
      selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
      );

      selectedStatus = 'all';
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _fetchTasksForSelectedDate() async {
    final snapshot = await _firestore
        .collection('staff_tasks')
        .where('dateKey', isEqualTo: dateKey)
        .where('isActive', isEqualTo: true)
        .get();

    final docs = snapshot.docs.where((doc) {
      final data = doc.data();

      final removed = data['removedFromSchedule'] == true;

      final staffUsername =
          _clean(data['staffUsername']).toLowerCase();

      final isLiveStreamStation =
          data['isLiveStreamStation'] == true ||
          staffUsername == 'stream_station';

      if (removed || isLiveStreamStation) {
        return false;
      }

      if (selectedStatus == 'all') {
        return true;
      }

      final status = _safeStatus(
        data['status'] ?? data['taskStatus'],
      );

      return status == selectedStatus;
    }).toList();

    docs.sort((a, b) {
      final aName = _clean(a.data()['staffName']);
      final bName = _clean(b.data()['staffName']);

      if (aName != bName) {
        return aName.compareTo(bName);
      }

      final aTask = _clean(
        a.data()['taskLabel'] ?? a.data()['title'],
      );

      final bTask = _clean(
        b.data()['taskLabel'] ?? b.data()['title'],
      );

      return aTask.compareTo(bTask);
    });

    return docs;
  }

  Future<void> _updateTaskStatus({
    required String taskId,
    required String newStatus,
  }) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final safeStatus = _safeStatus(newStatus);
      final adminInfo = await _currentAdminInfo();

      await _firestore.collection('staff_tasks').doc(taskId).update({
        'taskStatus': safeStatus,
        'status': safeStatus,
        'statusLabel': _statusLabel(safeStatus),
        'reviewedByUid': adminInfo['uid'] ?? '',
        'reviewedByName': adminInfo['name'] ?? 'الإدارة',
        'reviewedByRole': adminInfo['role'] ?? 'admin',
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedByUid': adminInfo['uid'] ?? '',
        'updatedByName': adminInfo['name'] ?? 'الإدارة',
        'updatedByRole': adminInfo['role'] ?? 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث حالة المهمة'),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحديث المهمة: $e'),
        ),
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
          content: Text('لا يمكن تعديل مهام الأيام السابقة'),
        ),
      );

      return;
    }

    final data = doc.data();

    String selectedTaskStatus = _safeStatus(
      data['status'] ?? data['taskStatus'],
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('تحديث حالة المهمة'),
                content: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _dialogInfo(
                          'الموظف',
                          _clean(data['staffName']).isEmpty
                              ? 'غير محددة'
                              : _clean(data['staffName']),
                        ),
                        const SizedBox(height: 8),
                        _dialogInfo(
                          'المهمة',
                          _taskTitle(data),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: selectedTaskStatus,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'حالة المهمة',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'done',
                              child: Text('تم الإنجاز'),
                            ),
                            DropdownMenuItem(
                              value: 'not_done',
                              child: Text('لم يتم الإنجاز'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;

                            setDialogState(() {
                              selectedTaskStatus = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogContext);

                      await _updateTaskStatus(
                        taskId: doc.id,
                        newStatus: selectedTaskStatus,
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
  }

  String _taskTitle(Map<String, dynamic> data) {
    final taskLabel = _clean(data['taskLabel']);
    final taskTitle = _clean(data['taskTitle']);
    final title = _clean(data['title']);

    if (taskLabel.isNotEmpty) return taskLabel;
    if (taskTitle.isNotEmpty) return taskTitle;
    if (title.isNotEmpty) return title;

    return 'مهمة بدون عنوان';
  }

  Widget _dialogInfo(
    String title,
    String value,
  ) {
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
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
            SizedBox(
              width: 112,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                icon: const Icon(
                  Icons.date_range,
                  size: 18,
                ),
                label: const Text(
                  'تاريخ',
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          value: selectedStatus,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'فلترة الحالة',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'all',
              child: Text('كل المهام'),
            ),
            DropdownMenuItem(
              value: 'done',
              child: Text('تم الإنجاز'),
            ),
            DropdownMenuItem(
              value: 'not_done',
              child: Text('لم يتم الإنجاز'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              selectedStatus = value ?? 'all';
            });
          },
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final staffName = _clean(data['staffName']).isEmpty
        ? 'موظف غير محدد'
        : _clean(data['staffName']);

    final staffUsername = _clean(data['staffUsername']);

    final taskLabel = _taskTitle(data);

    final status = _safeStatus(
      data['status'] ?? data['taskStatus'],
    );

    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(
                    _statusIcon(status),
                    color: color,
                  ),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        height: 1.25,
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
            const SizedBox(height: 12),
            if (isToday)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () {
                          _openReviewDialog(doc);
                        },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text(
                    'تعديل حالة المهمة',
                    maxLines: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    Object? error,
  ) {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.redAccent,
            ),
            SizedBox(height: 12),
            Text(
              'حدث خطأ أثناء تحميل المهام',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksList() {
    return FutureBuilder<
        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _fetchTasksForSelectedDate(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error);
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.all(12),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final docs = snapshot.data ?? [];

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: docs
              .map(
                (doc) => _buildTaskCard(doc),
              )
              .toList(),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xffF7F7F7),
        appBar: AppBar(
          title: const Text('متابعة مهام الموظفين'),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                bottom: 24,
              ),
              children: [
                _buildHeader(),
                _buildStatusFilter(),
                _buildTasksList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}