import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/app_notification_service.dart';

class AdminDailyTasksTablePage extends StatefulWidget {
  const AdminDailyTasksTablePage({super.key});

  @override
  State<AdminDailyTasksTablePage> createState() =>
      _AdminDailyTasksTablePageState();
}

class _AdminDailyTasksTablePageState extends State<AdminDailyTasksTablePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isSaving = false;

  final List<Map<String, String>> taskTypes = const [
    {'key': 'cleaning', 'label': 'تنظيف'},
    {'key': 'cleaning_cooking', 'label': 'تنظيف مع طبخ'},
    {'key': 'diaper_change', 'label': 'غيار للرضع'},
    {'key': 'bathroom_assistance', 'label': 'مساعدة حمام'},
    {'key': 'activities_photography', 'label': 'أنشطة وتصوير'},
    {'key': 'class_management', 'label': 'إدارة صف'},
    {'key': 'indoor_area', 'label': 'مساحة داخلية'},
    {'key': 'outdoor_area', 'label': 'مساحة خارجية'},
  ];

  final Map<String, Map<String, bool>> selectedTasks = {};
  final Map<String, TextEditingController> notesControllers = {};

  DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String get dateKey {
    final d = today;
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _clean(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  bool _isNurseryStaff(Map<String, dynamic> data) {
    final role = _clean(data['role']).toLowerCase();
    return role == 'nursery_staff' ||
        role == 'nursery staff' ||
        role == 'nursery';
  }

  String _staffName(Map<String, dynamic> data) {
    final name = _clean(data['name']);
    final fullName = _clean(data['fullName']);
    final username = _clean(data['username']);

    if (name.isNotEmpty) return name;
    if (fullName.isNotEmpty) return fullName;
    if (username.isNotEmpty) return username;
    return 'موظفة بدون اسم';
  }

  String _weekKey(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final diff = date.difference(firstDay).inDays;
    final week = ((diff + firstDay.weekday) / 7).ceil();
    return '${date.year}-W${week.toString().padLeft(2, '0')}';
  }

  void _prepareStaff(String uid) {
    selectedTasks.putIfAbsent(uid, () {
      return {
        for (final task in taskTypes) task['key']!: false,
      };
    });

    notesControllers.putIfAbsent(uid, () => TextEditingController());
  }

  List<Map<String, dynamic>> _selectedRows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> staffDocs,
  ) {
    final rows = <Map<String, dynamic>>[];

    for (final doc in staffDocs) {
      final data = doc.data();
      final uid = doc.id;

      _prepareStaff(uid);

      final chosen = taskTypes.where((task) {
        final key = task['key'] ?? '';
        return selectedTasks[uid]?[key] == true;
      }).toList();

      rows.add({
        'uid': uid,
        'name': _staffName(data),
        'username': _clean(data['username']),
        'tasks': chosen.map((e) => e['label'] ?? '').where((e) => e.isNotEmpty).toList(),
        'notes': notesControllers[uid]?.text.trim() ?? '',
      });
    }

    return rows;
  }

  Future<void> _saveTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> staffDocs,
  ) async {
    final rows = _selectedRows(staffDocs);
    final hasAnyTask = rows.any((row) {
      final tasks = row['tasks'];
      return tasks is List && tasks.isNotEmpty;
    });

    if (!hasAnyTask) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختاري مهمة واحدة على الأقل')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final batch = _firestore.batch();
      int totalTasks = 0;

      for (final doc in staffDocs) {
        final data = doc.data();
        final uid = doc.id;
        final name = _staffName(data);
        final username = _clean(data['username']);
        final notes = notesControllers[uid]?.text.trim() ?? '';

        _prepareStaff(uid);

        final chosen = taskTypes.where((task) {
          final key = task['key'] ?? '';
          return selectedTasks[uid]?[key] == true;
        }).toList();

        for (final task in chosen) {
          final taskKey = task['key'] ?? '';
          final taskLabel = task['label'] ?? 'مهمة بدون عنوان';

          final ref = _firestore.collection('staff_tasks').doc();

          batch.set(ref, {
            'taskId': ref.id,
            'staffUid': uid,
            'staffName': name,
            'staffUsername': username,
            'title': taskLabel,
            'taskType': taskKey,
            'taskLabel': taskLabel,
            'taskStatus': 'pending',
            'statusLabel': 'بانتظار اعتماد الإدارة',
            'assignedDate': Timestamp.fromDate(today),
            'dateKey': dateKey,
            'assignedWeekKey': _weekKey(today),
            'notes': notes,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          totalTasks++;
        }
      }

      batch.set(
        _firestore.collection('daily_staff_task_schedules').doc(dateKey),
        {
          'scheduleId': dateKey,
          'dateKey': dateKey,
          'date': Timestamp.fromDate(today),
          'totalTasks': totalTasks,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

    for (final row in rows) {
  final staffUid = _clean(row['uid']);
  final staffName = _clean(row['name']);
  final staffUsername = _clean(row['username']);

  final rawTasks = row['tasks'];
  final taskLabels = rawTasks is List
      ? rawTasks.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
      : <String>[];

  final notes = _clean(row['notes']);

  if (staffUid.isEmpty || taskLabels.isEmpty) continue;

  await AppNotificationService.instance.notifyUser(
    targetUid: staffUid,
    targetUsername: staffUsername,
    targetRole: 'nursery_staff',
    title: 'تم تكليفك بمهام اليوم',
    body: 'مهامك بتاريخ $dateKey: ${taskLabels.join('، ')}',
    type: 'staff_daily_tasks',
    priority: 'important',
    createdByRole: 'admin',
    extraData: {
      'dateKey': dateKey,
      'assignedDate': Timestamp.fromDate(today),
      'assignedWeekKey': _weekKey(today),
      'staffName': staffName,
      'tasks': taskLabels,
      'notes': notes,
      'category': 'staff_tasks',
      'notificationType': 'staff_daily_tasks',
      'screen': 'staff_tasks',
      'route': 'staff_tasks',
      'relatedCollection': 'staff_tasks',
    },
  );
}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ مهام اليوم بنجاح')),
      );

      setState(() {
        selectedTasks.clear();
        for (final c in notesControllers.values) {
          c.clear();
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _printTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> staffDocs,
  ) async {
    final rows = _selectedRows(staffDocs);
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'جدول مهام الموظفات اليومية',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('التاريخ: $dateKey'),
                pw.SizedBox(height: 16),
                pw.TableHelper.fromTextArray(
                  headers: ['الموظفة', 'المهام', 'ملاحظات'],
                  data: rows.map((row) {
                    final tasksList = row['tasks'];
                    final tasks = tasksList is List ? tasksList.join(' - ') : '';

                    return [
                      _clean(row['name']),
                      tasks.isEmpty ? 'لا يوجد' : tasks,
                      _clean(row['notes']),
                    ];
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  @override
  void dispose() {
    for (final c in notesControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _buildStaffCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final uid = doc.id;
    final name = _staffName(data);
    final username = _clean(data['username']);

    _prepareStaff(uid);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (username.isNotEmpty)
                        Text(
                          '@$username',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey),
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
              children: taskTypes.map((task) {
                final key = task['key'] ?? '';
                final label = task['label'] ?? '';

                return FilterChip(
                  label: Text(label),
                  selected: selectedTasks[uid]?[key] ?? false,
                  onSelected: isSaving
                      ? null
                      : (value) {
                          setState(() {
                            selectedTasks[uid]?[key] = value;
                          });
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesControllers[uid],
              maxLines: 2,
              enabled: !isSaving,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'ملاحظات للموظفة',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> staffDocs,
  ) {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.today),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'توزيع مهام اليوم: $dateKey',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'هذه الصفحة مخصصة لتوزيع مهام اليوم فقط. الرجوع للتواريخ السابقة يكون من صفحة متابعة مهام الموظفات.',
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isSaving ? null : () => _printTasks(staffDocs),
              icon: const Icon(Icons.print),
              label: const Text('طباعة جدول اليوم'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> staffDocs,
  ) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 50,
            maxHeight: 54,
          ),
          child: ElevatedButton.icon(
            onPressed: isSaving ? null : () => _saveTasks(staffDocs),
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ مهام اليوم'),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'حدث خطأ أثناء تحميل الموظفات:\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStaffState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'لا يوجد موظفات حضانة.\nتأكدي أن role = nursery_staff داخل users.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xffF7F7F7),
        appBar: AppBar(
          title: const Text('توزيع مهام اليوم'),
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error);
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            final staffDocs = docs.where((doc) {
              return _isNurseryStaff(doc.data());
            }).toList();

            staffDocs.sort((a, b) {
              final aName = _staffName(a.data());
              final bName = _staffName(b.data());
              return aName.compareTo(bName);
            });

            if (staffDocs.isEmpty) {
              return _buildEmptyStaffState();
            }

            return Column(
              children: [
                _buildDateSection(staffDocs),
                Expanded(
                  child: ListView.builder(
                    itemCount: staffDocs.length,
                    itemBuilder: (context, index) {
                      return _buildStaffCard(staffDocs[index]);
                    },
                  ),
                ),
                _buildSaveButton(staffDocs),
              ],
            );
          },
        ),
      ),
    );
  }
}