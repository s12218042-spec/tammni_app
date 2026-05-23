import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';

class AdminWeeklyDutyPage extends StatefulWidget {
  const AdminWeeklyDutyPage({super.key});

  @override
  State<AdminWeeklyDutyPage> createState() => _AdminWeeklyDutyPageState();
}

class _AdminWeeklyDutyPageState extends State<AdminWeeklyDutyPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isSaving = false;

  final Set<String> selectedStaffUids = {};
  final Map<String, Map<String, dynamic>> selectedStaffDataByUid = {};

  DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get weekStart {
    final d = today;
    final daysFromSunday = d.weekday == DateTime.sunday ? 0 : d.weekday;
    return d.subtract(Duration(days: daysFromSunday));
  }

  DateTime get weekEnd {
    return weekStart.add(const Duration(days: 6));
  }

  String get weekKey {
    final firstDay = DateTime(today.year, 1, 1);
    final diff = today.difference(firstDay).inDays;
    final week = ((diff + firstDay.weekday) / 7).ceil();
    return '${today.year}-W${week.toString().padLeft(2, '0')}';
  }

  String _clean(dynamic value) => value?.toString().trim() ?? '';

  bool _isNurseryStaff(Map<String, dynamic> data) {
    final role = _clean(data['role']).toLowerCase();

    return role == 'nursery_staff' ||
        role == 'nursery staff' ||
        role == 'nursery';
  }

  String _staffName(Map<String, dynamic> data) {
    final name = _clean(data['name']);
    final fullName = _clean(data['fullName']);
    final displayName = _clean(data['displayName']);
    final username = _clean(data['username']);

    if (name.isNotEmpty) return name;
    if (fullName.isNotEmpty) return fullName;
    if (displayName.isNotEmpty) return displayName;
    if (username.isNotEmpty) return username;

    return 'موظفة بدون اسم';
  }

  String _formatDate(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }

  List<Map<String, dynamic>> _selectedDutyStaffList() {
    final list = <Map<String, dynamic>>[];

    for (final uid in selectedStaffUids) {
      final data = selectedStaffDataByUid[uid];
      if (data == null) continue;

      list.add({
        'uid': uid,
        'name': _staffName(data),
        'username': _clean(data['username']),
      });
    }

    list.sort((a, b) => _clean(a['name']).compareTo(_clean(b['name'])));
    return list;
  }

  String _staffNamesFromDutyData(Map<String, dynamic>? data) {
    if (data == null) return 'لم يتم التحديد';

    final rawDutyStaff = data['dutyStaff'];

    if (rawDutyStaff is List && rawDutyStaff.isNotEmpty) {
      final names = rawDutyStaff
          .map((e) {
            if (e is Map) {
              return _clean(e['name'] ?? e['staffName']);
            }
            return '';
          })
          .where((name) => name.isNotEmpty)
          .toList();

      if (names.isNotEmpty) return names.join('، ');
    }

    final legacyName = _clean(data['staffName']);
    if (legacyName.isNotEmpty) return legacyName;

    return 'لم يتم التحديد';
  }

  Future<void> _saveWeeklyDuty() async {
    if (selectedStaffUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختاري موظفة للمناوبة')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final dutyStaff = _selectedDutyStaffList();
      final dutyStaffUids = dutyStaff.map((e) => _clean(e['uid'])).toList();
      final firstStaff = dutyStaff.isNotEmpty ? dutyStaff.first : null;

      await _firestore.collection('weekly_duties').doc(weekKey).set({
        'dutyId': weekKey,
        'weekKey': weekKey,
        'weekStartDate': Timestamp.fromDate(weekStart),
        'weekEndDate': Timestamp.fromDate(weekEnd),
        'weekStartDateKey': _formatDate(weekStart),
        'weekEndDateKey': _formatDate(weekEnd),
        'dutyStaffUids': dutyStaffUids,
        'dutyStaff': dutyStaff,
        'dutyStaffCount': dutyStaff.length,
        'staffUid': firstStaff == null ? '' : _clean(firstStaff['uid']),
        'staffName': firstStaff == null ? '' : _clean(firstStaff['name']),
        'staffUsername':
            firstStaff == null ? '' : _clean(firstStaff['username']),
        'isActive': true,
        'createdByRole': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (final staff in dutyStaff) {
        final staffUid = _clean(staff['uid']);
        final staffName = _clean(staff['name']);
        final staffUsername = _clean(staff['username']);

        if (staffUid.isEmpty) continue;

        await AppNotificationService.instance.notifyUser(
          targetUid: staffUid,
          targetUsername: staffUsername,
          targetRole: 'nursery_staff',
          title: 'مناوبة الأسبوع',
          body:
              'تم تحديدك ضمن مناوبة الأسبوع من ${_formatDate(weekStart)} إلى ${_formatDate(weekEnd)}.',
          type: 'weekly_duty',
          priority: 'important',
          createdByRole: 'admin',
          extraData: {
            'weekKey': weekKey,
            'weekStartDateKey': _formatDate(weekStart),
            'weekEndDateKey': _formatDate(weekEnd),
            'staffName': staffName,
            'category': 'weekly_duty',
            'notificationType': 'weekly_duty',
            'screen': 'weekly_duty',
            'route': 'staff_weekly_duty',
            'relatedCollection': 'weekly_duties',
          },
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ المناوبة')),
      );

      setState(() {
        selectedStaffUids.clear();
        selectedStaffDataByUid.clear();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ المناوبة: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _currentDutyStream() {
    return _firestore.collection('weekly_duties').doc(weekKey).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _staffStream() {
    return _firestore.collection('users').snapshots();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadDutyArchive() async {
    final snapshot = await _firestore.collection('weekly_duties').limit(40).get();

    final docs = snapshot.docs;

    docs.sort((a, b) {
      final aStart = a.data()['weekStartDate'];
      final bStart = b.data()['weekStartDate'];

      if (aStart is Timestamp && bStart is Timestamp) {
        return bStart.compareTo(aStart);
      }

      return _clean(b.data()['weekKey']).compareTo(_clean(a.data()['weekKey']));
    });

    return docs;
  }

  Widget _buildCurrentWeekCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                CircleAvatar(
                  child: Icon(Icons.calendar_month_outlined),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'الأسبوع الحالي',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('من', _formatDate(weekStart)),
            const SizedBox(height: 6),
            _infoRow('إلى', _formatDate(weekEnd)),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentDutyCard() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _currentDutyStream(),
      builder: (context, snapshot) {
        final exists = snapshot.data?.exists == true;
        final data = snapshot.data?.data();

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          );
        }

        if (!exists || data == null) {
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Icon(Icons.info_outline),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'لم يتم تحديد مناوبة هذا الأسبوع',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final staffNames = _staffNamesFromDutyData(data);

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.12),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مناوبة هذا الأسبوع',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        staffNames,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaffPicker() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _staffStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'تعذر تحميل الموظفات',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Card(
            margin: EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          );
        }

        final staffDocs = snapshot.data!.docs.where((doc) {
          return _isNurseryStaff(doc.data());
        }).toList();

        staffDocs.sort((a, b) {
          return _staffName(a.data()).compareTo(_staffName(b.data()));
        });

        if (staffDocs.isEmpty) {
          return const Card(
            margin: EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'لا توجد موظفات حضانة',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تحديد المناوبة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ...staffDocs.map((doc) {
                  final data = doc.data();
                  final uid = doc.id;
                  final name = _staffName(data);
                  final username = _clean(data['username']);
                  final isSelected = selectedStaffUids.contains(uid);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.green.withOpacity(0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? Colors.green.withOpacity(0.35)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: username.isEmpty ? null : Text('@$username'),
                      secondary: CircleAvatar(
                        backgroundColor: isSelected
                            ? Colors.green.withOpacity(0.12)
                            : Colors.blueGrey.withOpacity(0.10),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle_outline
                              : Icons.person_outline,
                          color: isSelected ? Colors.green : Colors.blueGrey,
                        ),
                      ),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              setState(() {
                                if (value == true) {
                                  selectedStaffUids.add(uid);
                                  selectedStaffDataByUid[uid] = data;
                                } else {
                                  selectedStaffUids.remove(uid);
                                  selectedStaffDataByUid.remove(uid);
                                }
                              });
                            },
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : _saveWeeklyDuty,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ المناوبة'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildArchiveSection() {
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _loadDutyArchive(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Card(
            margin: EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'تعذر تحميل الأرشيف',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final docs = snapshot.data ?? [];

        if (docs.isEmpty) {
          return const Card(
            margin: EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'لا يوجد أرشيف مناوبات',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الأرشيف',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                ...docs.map((doc) {
                  final data = doc.data();

                  final staffNames = _staffNamesFromDutyData(data);
                  final start = _clean(data['weekStartDateKey']);
                  final end = _clean(data['weekEndDateKey']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          child: Icon(Icons.calendar_today_outlined),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                staffNames,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$start - $end',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String title, String value) {
    return Row(
      children: [
        Text(
          '$title: ',
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
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
          title: const Text('المناوبة الأسبوعية'),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildCurrentWeekCard(),
              _buildCurrentDutyCard(),
              _buildStaffPicker(),
              _buildArchiveSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
