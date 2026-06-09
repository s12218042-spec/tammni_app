import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool isSaving = false;
  final ScrollController _scrollController = ScrollController();

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

  String _docSafe(String value) {
    return value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  bool _isNurseryStaff(Map<String, dynamic> data) {
    final role = _clean(data['role']).toLowerCase();
    return role == 'nursery_staff' ||
        role == 'nursery staff' ||
        role == 'nursery';
  }

  String _staffName(Map<String, dynamic> data) {
    final displayName = _clean(data['displayName']);
    final name = _clean(data['name']);
    final fullName = _clean(data['fullName']);
    final username = _clean(data['username']);

    if (displayName.isNotEmpty) return displayName;
    if (name.isNotEmpty) return name;
    if (fullName.isNotEmpty) return fullName;
    if (username.isNotEmpty) return username;
    return 'موظف بدون اسم';
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

      return {
        'uid': user.uid,
        'name': (_clean(data['displayName']).isNotEmpty
                ? _clean(data['displayName'])
                : _clean(data['name']).isNotEmpty
                    ? _clean(data['name'])
                    : _clean(data['fullName']).isNotEmpty
                        ? _clean(data['fullName'])
                        : _clean(data['username']).isNotEmpty
                            ? _clean(data['username'])
                            : 'الإدارة')
            .trim(),
        'role': (_clean(data['role']).isNotEmpty ? _clean(data['role']) : 'admin')
            .trim(),
      };
    } catch (_) {
      return {
        'uid': user.uid,
        'name': 'الإدارة',
        'role': 'admin',
      };
    }
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
        'tasks': chosen
            .map((task) => {
                  'taskKey': task['key'] ?? '',
                  'taskLabel': task['label'] ?? '',
                })
            .where((task) => _clean(task['taskKey']).isNotEmpty)
            .toList(),
      });
    }

    return rows;
  }

  Future<void> _loadExistingTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> staffDocs,
  ) async {
    try {
      for (final doc in staffDocs) {
        _prepareStaff(doc.id);
      }

      final snapshot = await _firestore
          .collection('staff_tasks')
          .where('dateKey', isEqualTo: dateKey)
          .where('isActive', isEqualTo: true)
          .get();

      for (final taskDoc in snapshot.docs) {
        final data = taskDoc.data();
        final staffUid = _clean(data['staffUid']);
        final taskKey = _clean(data['taskType'].toString().isNotEmpty
            ? data['taskType']
            : data['taskKey']);

        if (staffUid.isEmpty || taskKey.isEmpty) continue;

        _prepareStaff(staffUid);

        if (selectedTasks[staffUid]!.containsKey(taskKey)) {
          selectedTasks[staffUid]![taskKey] = true;
        }
      }

      if (mounted) setState(() {});
    } catch (_) {}
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
        const SnackBar(content: Text('اختر مهمة واحدة على الأقل')),
      );
      return;
    }

    if (isSaving) return;

    setState(() => isSaving = true);

    try {
      final adminInfo = await _currentAdminInfo();
      final adminUid = _clean(adminInfo['uid']);
      final adminName = _clean(adminInfo['name']).isEmpty
          ? 'الإدارة'
          : _clean(adminInfo['name']);
      final adminRole = _clean(adminInfo['role']).isEmpty
          ? 'admin'
          : _clean(adminInfo['role']);

      if (adminUid.isEmpty) {
        throw Exception('يجب تسجيل الدخول كأدمن قبل حفظ المهام');
      }

      final oldTasks = await _firestore
          .collection('staff_tasks')
          .where('dateKey', isEqualTo: dateKey)
          .get();

      WriteBatch batch = _firestore.batch();
      int operationCount = 0;

      for (final oldDoc in oldTasks.docs) {
        batch.set(
          oldDoc.reference,
          {
            'isActive': false,
            'removedFromSchedule': true,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': adminUid,
            'updatedByName': adminName,
            'updatedByRole': adminRole,
          },
          SetOptions(merge: true),
        );

        operationCount++;

        if (operationCount >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          operationCount = 0;
        }
      }

      int totalTasks = 0;
      final notificationRows = <Map<String, dynamic>>[];

      for (final doc in staffDocs) {
        final data = doc.data();
        final uid = doc.id;
        final name = _staffName(data);
        final username = _clean(data['username']);

        _prepareStaff(uid);

        final chosen = taskTypes.where((task) {
          final key = task['key'] ?? '';
          return selectedTasks[uid]?[key] == true;
        }).toList();

        final labelsForNotification = <String>[];

        for (final task in chosen) {
          final taskKey = _clean(task['key']);
          final taskLabel = _clean(task['label']).isEmpty
              ? 'مهمة'
              : _clean(task['label']);

          if (taskKey.isEmpty) continue;

          final safeDocId =
              '${_docSafe(dateKey)}_${_docSafe(uid)}_${_docSafe(taskKey)}';
          final ref = _firestore.collection('staff_tasks').doc(safeDocId);
          final oldTaskDoc = await ref.get();
          final taskAlreadyExists = oldTaskDoc.exists;

          final taskData = <String, dynamic>{
            'taskId': ref.id,
            'scheduleId': dateKey,
            'staffUid': uid,
            'staffName': name,
            'staffUsername': username,
            'staffRole': 'nursery_staff',

            'title': taskLabel,
            'taskTitle': taskLabel,
            'taskType': taskKey,
            'taskKey': taskKey,
            'taskLabel': taskLabel,

            'taskStatus': 'pending',
            'status': 'pending',
            'statusLabel': 'بانتظار اعتماد الإدارة',

            'assignedDate': Timestamp.fromDate(today),
            'date': Timestamp.fromDate(today),
            'dateKey': dateKey,
            'assignedWeekKey': _weekKey(today),

            'isActive': true,
            'removedFromSchedule': false,

            'createdByUid': adminUid,
            'createdByName': adminName,
            'createdByRole': adminRole,
            'assignedByUid': adminUid,
            'assignedByName': adminName,
            'assignedByRole': adminRole,

            'updatedByUid': adminUid,
            'updatedByName': adminName,
            'updatedByRole': adminRole,

            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (!taskAlreadyExists) {
            taskData['createdAt'] = FieldValue.serverTimestamp();
          }

batch.set(ref, taskData, SetOptions(merge: true));
          labelsForNotification.add(taskLabel);
          operationCount++;
          totalTasks++;

          if (operationCount >= 450) {
            await batch.commit();
            batch = _firestore.batch();
            operationCount = 0;
          }
        }

        if (labelsForNotification.isNotEmpty) {
          notificationRows.add({
            'staffUid': uid,
            'staffName': name,
            'staffUsername': username,
            'tasks': labelsForNotification,
          });
        }
      }

      final scheduleRef =
          _firestore.collection('daily_staff_task_schedules').doc(dateKey);

      final oldScheduleDoc = await scheduleRef.get();
      final scheduleAlreadyExists = oldScheduleDoc.exists;

      final scheduleData = <String, dynamic>{
        'scheduleId': dateKey,
        'dateKey': dateKey,
        'date': Timestamp.fromDate(today),
        'assignedWeekKey': _weekKey(today),
        'totalTasks': totalTasks,
        'staffCount': notificationRows.length,
        'createdByUid': adminUid,
        'createdByName': adminName,
        'createdByRole': adminRole,
        'updatedByUid': adminUid,
        'updatedByName': adminName,
        'updatedByRole': adminRole,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!scheduleAlreadyExists) {
        scheduleData['createdAt'] = FieldValue.serverTimestamp();
      }

      batch.set(scheduleRef, scheduleData, SetOptions(merge: true));

      await batch.commit();

      for (final row in notificationRows) {
        final staffUid = _clean(row['staffUid']);
        final staffName = _clean(row['staffName']);
        final staffUsername = _clean(row['staffUsername']);

        final rawTasks = row['tasks'];
        final taskLabels = rawTasks is List
            ? rawTasks
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList()
            : <String>[];

        if (staffUid.isEmpty || taskLabels.isEmpty) continue;

        try {
          await AppNotificationService.instance.notifyUser(
            targetUid: staffUid,
            targetUsername: staffUsername,
            targetRole: 'nursery_staff',
            title: 'مهام اليوم',
            body: taskLabels.join('، '),
            type: 'staff_daily_tasks',
            priority: 'important',
            createdByUid: adminUid,
            createdByName: adminName,
            createdByRole: adminRole,
            extraData: {
              'dateKey': dateKey,
              'assignedDate': Timestamp.fromDate(today),
              'assignedWeekKey': _weekKey(today),
              'staffName': staffName,
              'tasks': taskLabels,
              'category': 'staff_tasks',
              'notificationType': 'staff_daily_tasks',
              'screen': 'staff_tasks',
              'route': 'staff_tasks',
              'relatedCollection': 'staff_tasks',
            },
          );
        } catch (e) {
  debugPrint(
    'AdminDailyTasksTablePage: فشل إرسال إشعار مهام اليوم للموظف $staffUid: $e',
  );
}
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ المهام')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ المهام: $e')),
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
                  'جدول مهام الموظفين اليومية',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('التاريخ: $dateKey'),
                pw.SizedBox(height: 16),
                pw.TableHelper.fromTextArray(
                  headers: ['الموظف', 'المهام'],
                  data: rows.map((row) {
                    final tasksList = row['tasks'];
                    final tasks = tasksList is List
                        ? tasksList
                            .map((item) {
                              if (item is Map) {
                                return _clean(item['taskLabel']);
                              }
                              return _clean(item);
                            })
                            .where((e) => e.isNotEmpty)
                            .join(' - ')
                        : '';

                    return [
                      _clean(row['name']),
                      tasks.isEmpty ? 'لا يوجد' : tasks,
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
    _scrollController.dispose();
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
                    'مهام اليوم: $dateKey',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
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
          child: SizedBox(
            width: double.infinity,
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
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'تعذر تحميل الموظفين',
          textAlign: TextAlign.center,
          style: TextStyle(
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
          'لا يوجد موظفو حضانة',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildContent(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> staffDocs,
  ) {
    return Column(
      children: [
        _buildDateSection(staffDocs),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: staffDocs.length,
              itemBuilder: (context, index) {
                return _buildStaffCard(staffDocs[index]);
              },
            ),
          ),
        ),
        _buildSaveButton(staffDocs),
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
          title: const Text('تحديد مهام الموظفين'),
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
              final data = doc.data();

              final isActive = data['isActive'] != false;
              final accountStatus = _clean(data['accountStatus']).toLowerCase();
              final isLiveStreamStation = data['isLiveStreamStation'] == true;

              return isActive &&
                  accountStatus != 'archived' &&
                  !isLiveStreamStation &&
                  _isNurseryStaff(data);
            }).toList();

            staffDocs.sort((a, b) {
              final aName = _staffName(a.data());
              final bName = _staffName(b.data());
              return aName.compareTo(bName);
            });

            if (staffDocs.isEmpty) {
              return _buildEmptyStaffState();
            }

            if (selectedTasks.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadExistingTasks(staffDocs);
              });
            }

            return _buildContent(staffDocs);
          },
        ),
      ),
    );
  }
}