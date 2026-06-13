import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminStaffAttendancePage extends StatefulWidget {
  const AdminStaffAttendancePage({super.key});

  @override
  State<AdminStaffAttendancePage> createState() =>
      _AdminStaffAttendancePageState();
}

class _AdminStaffAttendancePageState extends State<AdminStaffAttendancePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime selectedDate = DateTime.now();

  bool isSaving = false;
  bool isLoadingSaved = false;
  bool hasLoadedSavedAttendance = false;

  final Map<String, TimeOfDay?> checkInTimes = {};
  final Map<String, TimeOfDay?> checkOutTimes = {};
  final Map<String, TextEditingController> noteControllers = {};
  final Map<String, bool> isAbsentMap = {};
  final Map<String, Map<String, dynamic>> savedAttendanceByStaffUid = {};

  static const double hourlyRate = 8.0;

  DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isFutureDate(DateTime date) {
    final normalizedDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    return normalizedDate.isAfter(today);
  }

  bool get isSelectedDateToday {
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

  double get requiredHours {
    if (selectedDate.weekday == DateTime.friday) return 0;
    if (selectedDate.weekday == DateTime.saturday) return 4.5;

    return 9;
  }

  String get dayTypeLabel {
    if (selectedDate.weekday == DateTime.friday) {
      return 'عطلة رسمية';
    }

    if (selectedDate.weekday == DateTime.saturday) {
      return 'دوام نصف يوم';
    }

    return 'دوام كامل';
  }

  String _clean(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  bool _isNurseryStaff(Map<String, dynamic> data) {
    final role = _clean(data['role']).toLowerCase();

    return role == 'nursery_staff' ||
        role == 'nursery staff' ||
        role == 'nursery';
  }

  bool _isLiveStreamStation(Map<String, dynamic> data) {
    final username = _clean(data['username']).toLowerCase();
    final email = _clean(data['email']).toLowerCase();

    return data['isLiveStreamStation'] == true ||
        username == 'stream_station' ||
        email == 'stream.station@tammni.com';
  }

  String _staffName(Map<String, dynamic> data) {
    final name = _clean(data['name']);
    final fullName = _clean(data['fullName']);
    final displayName = _clean(data['displayName']);
    final username = _clean(data['username']);

    if (displayName.isNotEmpty) return displayName;
    if (name.isNotEmpty) return name;
    if (fullName.isNotEmpty) return fullName;
    if (username.isNotEmpty) return username;

    return 'موظف بدون اسم';
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return 'غير محدد';

    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');

    return '$h:$m';
  }

  TimeOfDay? _timeOfDayFromString(dynamic value) {
    final text = _clean(value);

    if (text.isEmpty || !text.contains(':')) return null;

    final parts = text.split(':');

    if (parts.length < 2) return null;

    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);

    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;

    return TimeOfDay(
      hour: h,
      minute: m,
    );
  }

  DateTime _dateTimeFromTime(TimeOfDay time) {
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      time.hour,
      time.minute,
    );
  }

  Timestamp? _timestampFromTime(TimeOfDay? time) {
    if (time == null) return null;

    return Timestamp.fromDate(
      _dateTimeFromTime(time),
    );
  }

  double _workedHours(
    TimeOfDay? checkIn,
    TimeOfDay? checkOut,
  ) {
    if (checkIn == null || checkOut == null) return 0;

    final start = _dateTimeFromTime(checkIn);
    var end = _dateTimeFromTime(checkOut);

    if (end.isBefore(start)) {
      end = end.add(
        const Duration(days: 1),
      );
    }

    final minutes = end.difference(start).inMinutes;

    if (minutes <= 0) return 0;

    return double.parse(
      (minutes / 60).toStringAsFixed(2),
    );
  }

  String _hoursText(double value) {
    return value.toStringAsFixed(2);
  }

  double _money(double value) {
    return double.parse(
      value.toStringAsFixed(2),
    );
  }

  void _prepareStaff(String uid) {
    noteControllers.putIfAbsent(
      uid,
      () => TextEditingController(),
    );

    isAbsentMap.putIfAbsent(
      uid,
      () => false,
    );
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
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

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

  @override
  void dispose() {
    for (final controller in noteControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _loadSavedAttendance() async {
    if (isLoadingSaved) return;

    setState(() {
      isLoadingSaved = true;
      hasLoadedSavedAttendance = false;
      savedAttendanceByStaffUid.clear();
    });

    try {
      final snapshot = await _firestore
          .collection('staff_attendance')
          .where('dateKey', isEqualTo: dateKey)
          .limit(300)
          .get()
          .timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw Exception('انتهت مهلة تحميل سجلات الدوام');
        },
      );

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final staffUid = _clean(data['staffUid']);

        if (staffUid.isEmpty) continue;

        savedAttendanceByStaffUid[staffUid] = {
          ...data,
          '_docId': doc.id,
        };

        checkInTimes[staffUid] = _timeOfDayFromString(
          data['checkInTime'],
        );

        checkOutTimes[staffUid] = _timeOfDayFromString(
          data['checkOutTime'],
        );

        isAbsentMap[staffUid] = data['isAbsent'] == true;

        noteControllers.putIfAbsent(
          staffUid,
          () => TextEditingController(),
        );

        noteControllers[staffUid]!.text = _clean(
          data['adminNote'],
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحميل الدوام: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoadingSaved = false;
          hasLoadedSavedAttendance = true;
        });
      }
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

      checkInTimes.clear();
      checkOutTimes.clear();
      isAbsentMap.clear();
      savedAttendanceByStaffUid.clear();
      hasLoadedSavedAttendance = false;

      for (final controller in noteControllers.values) {
        controller.clear();
      }
    });

    await _loadSavedAttendance();
  }

  Future<void> _pickTime({
    required String staffUid,
    required bool isCheckIn,
  }) async {
    final currentValue =
        isCheckIn ? checkInTimes[staffUid] : checkOutTimes[staffUid];

    final picked = await showTimePicker(
      context: context,
      initialTime: currentValue ??
          const TimeOfDay(
            hour: 7,
            minute: 0,
          ),
    );

    if (picked == null) return;

    setState(() {
      if (isCheckIn) {
        checkInTimes[staffUid] = picked;
      } else {
        checkOutTimes[staffUid] = picked;
      }

      isAbsentMap[staffUid] = false;
    });
  }

  Future<void> _saveAttendanceForStaff(
    QueryDocumentSnapshot<Map<String, dynamic>> staffDoc,
  ) async {
    final uid = staffDoc.id;
    final data = staffDoc.data();

    if (_isLiveStreamStation(data)) return;

    final isAbsent = isAbsentMap[uid] == true;
    final checkIn = checkInTimes[uid];
    final checkOut = checkOutTimes[uid];

    if (!isAbsent &&
        requiredHours > 0 &&
        (checkIn == null || checkOut == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدد وقت الحضور والانصراف للموظف ${_staffName(data)}',
          ),
        ),
      );

      return;
    }

    if (!isAbsent && checkIn != null && checkOut != null) {
      final worked = _workedHours(
        checkIn,
        checkOut,
      );

      if (worked <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'وقت الانصراف غير صحيح للموظف ${_staffName(data)}',
            ),
          ),
        );

        return;
      }
    }

    await _saveManyAttendance(
      [staffDoc],
    );
  }

  Future<void> _saveAllAttendance(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> staffDocs,
  ) async {
    for (final staffDoc in staffDocs) {
      final uid = staffDoc.id;
      final data = staffDoc.data();

      if (_isLiveStreamStation(data)) continue;

      final isAbsent = isAbsentMap[uid] == true;
      final checkIn = checkInTimes[uid];
      final checkOut = checkOutTimes[uid];

      if (!isAbsent &&
          requiredHours > 0 &&
          (checkIn == null || checkOut == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدد وقت الحضور والانصراف للموظف ${_staffName(data)}',
            ),
          ),
        );

        return;
      }

      if (!isAbsent && checkIn != null && checkOut != null) {
        final worked = _workedHours(
          checkIn,
          checkOut,
        );

        if (worked <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'وقت الانصراف غير صحيح للموظف ${_staffName(data)}',
              ),
            ),
          );

          return;
        }
      }
    }

    await _saveManyAttendance(
      staffDocs,
    );
  }

  Future<void> _saveManyAttendance(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> staffDocs,
  ) async {
    if (isSaving) return;

    if (_isFutureDate(selectedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن تسجيل دوام بتاريخ مستقبلي'),
        ),
      );

      return;
    }

    setState(() {
      isSaving = true;
    });

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
        throw Exception(
          'يجب تسجيل الدخول كأدمن قبل حفظ الدوام',
        );
      }

      final batch = _firestore.batch();

      for (final staffDoc in staffDocs) {
        final uid = staffDoc.id;
        final data = staffDoc.data();

        if (_isLiveStreamStation(data)) continue;

        _prepareStaff(uid);

        final staffName = _staffName(data);
        final staffUsername = _clean(data['username']);

        final isAbsent = isAbsentMap[uid] == true;
        final checkIn = checkInTimes[uid];
        final checkOut = checkOutTimes[uid];

        final worked = isAbsent
            ? 0.0
            : _workedHours(
                checkIn,
                checkOut,
              );

        final required = requiredHours;

        final completed =
            required == 0 ? true : !isAbsent && worked >= required;

        final missing = required == 0
            ? 0.0
            : completed
                ? 0.0
                : double.parse(
                    (required - worked).toStringAsFixed(2),
                  );

        final dailyAmount = _money(
          worked * hourlyRate,
        );

        final attendanceStatus = required == 0
            ? 'holiday'
            : isAbsent
                ? 'absent'
                : completed
                    ? 'completed'
                    : 'incomplete';

        final docId = '${uid}_$dateKey';

        final ref = _firestore
            .collection('staff_attendance')
            .doc(docId);

        final existing = savedAttendanceByStaffUid[uid];
        final alreadyCreatedAt = existing?['createdAt'];

        batch.set(
          ref,
          {
            'attendanceId': docId,
            'staffUid': uid,
            'staffName': staffName,
            'staffUsername': staffUsername,
            'staffRole': 'nursery_staff',
            'dateKey': dateKey,
            'date': Timestamp.fromDate(selectedDate),
            'dayTypeLabel': dayTypeLabel,
            'requiredHours': required,
            'hourlyRate': hourlyRate,
            'workedHours': worked,
            'dailyAmount': dailyAmount,
            'missingHours': missing,
            'isAbsent': isAbsent,
            'attendanceStatus': attendanceStatus,
            'isCompletedRequiredHours': completed,
            'checkInTime': isAbsent ? '' : _formatTimeOfDay(checkIn),
            'checkOutTime': isAbsent ? '' : _formatTimeOfDay(checkOut),
            'checkInAt': isAbsent ? null : _timestampFromTime(checkIn),
            'checkOutAt': isAbsent ? null : _timestampFromTime(checkOut),
            'adminNote': noteControllers[uid]?.text.trim() ?? '',
            'createdByUid': existing == null
                ? adminUid
                : (existing['createdByUid'] ?? adminUid),
            'createdByName': existing == null
                ? adminName
                : (existing['createdByName'] ?? adminName),
            'createdByRole': existing == null
                ? adminRole
                : (existing['createdByRole'] ?? adminRole),
            'updatedByUid': adminUid,
            'updatedByName': adminName,
            'updatedByRole': adminRole,
            'isActive': true,
            'createdAt':
                alreadyCreatedAt ?? FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ دوام الموظفين بنجاح'),
        ),
      );

      setState(() {
        hasLoadedSavedAttendance = false;
      });

      await _loadSavedAttendance();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ الدوام: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _staffStream() {
    return _firestore
        .collection('users')
        .snapshots();
  }

  Widget _buildHeader(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> staffDocs,
  ) {
    return Card(
      margin: const EdgeInsets.all(12),
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
                const CircleAvatar(
                  child: Icon(Icons.access_time_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'دوام تاريخ: $dateKey',
                    maxLines: 1,
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
                    onPressed:
                        isSaving || isLoadingSaved ? null : _pickDate,
                    icon: const Icon(Icons.date_range),
                    label: const Text(
                      'اختيار تاريخ',
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(
              'نوع اليوم',
              dayTypeLabel,
            ),
            const SizedBox(height: 6),
            _infoRow(
              'الساعات المطلوبة',
              '${_hoursText(requiredHours)} ساعة',
            ),
            const SizedBox(height: 6),
            _infoRow(
              'سعر الساعة',
              '${_hoursText(hourlyRate)} شيكل',
            ),
            if (isSaving || isLoadingSaved) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 58,
              child: ElevatedButton.icon(
                onPressed: isSaving || isLoadingSaved
                    ? null
                    : () => _saveAllAttendance(
                          staffDocs,
                        ),
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  isSaving
                      ? 'جاري الحفظ...'
                      : 'حفظ دوام كل الموظفين',
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    String title,
    String value,
  ) {
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffAttendanceCard(
    QueryDocumentSnapshot<Map<String, dynamic>> staffDoc,
  ) {
    final data = staffDoc.data();
    final uid = staffDoc.id;

    _prepareStaff(uid);

    final staffName = _staffName(data);
    final staffUsername = _clean(data['username']);

    final isAbsent = isAbsentMap[uid] == true;
    final checkIn = checkInTimes[uid];
    final checkOut = checkOutTimes[uid];

    final worked = isAbsent
        ? 0.0
        : _workedHours(
            checkIn,
            checkOut,
          );

    final required = requiredHours;

    final completed =
        required == 0 ? true : !isAbsent && worked >= required;

    final missing = required == 0
        ? 0.0
        : completed
            ? 0.0
            : double.parse(
                (required - worked).toStringAsFixed(2),
              );

    final dailyAmount = _money(
      worked * hourlyRate,
    );

    final statusColor = required == 0
        ? Colors.blueGrey
        : isAbsent
            ? Colors.redAccent
            : completed
                ? Colors.green
                : Colors.orange;

    final statusText = required == 0
        ? 'عطلة / لا ساعات مطلوبة'
        : isAbsent
            ? 'غياب'
            : completed
                ? 'أكملت الساعات المطلوبة'
                : 'نقص ${_hoursText(missing)} ساعة';

    return Card(
      margin: const EdgeInsets.fromLTRB(
        12,
        0,
        12,
        12,
      ),
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
                  backgroundColor:
                      statusColor.withOpacity(0.12),
                  child: Icon(
                    Icons.person_outline,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        staffName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (staffUsername.isNotEmpty)
                        Text(
                          '@$staffUsername',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
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
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusColor,
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
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: isAbsent,
              title: const Text(
                'غياب',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              onChanged: isSaving
                  ? null
                  : (value) {
                      setState(() {
                        isAbsentMap[uid] = value == true;

                        if (value == true) {
                          checkInTimes[uid] = null;
                          checkOutTimes[uid] = null;
                        }
                      });
                    },
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSaving || isAbsent
                        ? null
                        : () => _pickTime(
                              staffUid: uid,
                              isCheckIn: true,
                            ),
                    icon: const Icon(Icons.login_outlined),
                    label: Text(
                      'حضور: ${_formatTimeOfDay(checkIn)}',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSaving || isAbsent
                        ? null
                        : () => _pickTime(
                              staffUid: uid,
                              isCheckIn: false,
                            ),
                    icon: const Icon(Icons.logout_outlined),
                    label: Text(
                      'انصراف: ${_formatTimeOfDay(checkOut)}',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniInfoBox(
                    title: 'المطلوبة',
                    value: _hoursText(required),
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniInfoBox(
                    title: 'الفعلية',
                    value: _hoursText(worked),
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniInfoBox(
                    title: 'المبلغ',
                    value:
                        '${_hoursText(dailyAmount)} ش',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteControllers[uid],
              maxLines: 2,
              enabled: !isSaving,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'ملاحظة الإدارة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.notes_outlined,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 58,
              child: OutlinedButton.icon(
                onPressed: isSaving
                    ? null
                    : () => _saveAttendanceForStaff(
                          staffDoc,
                        ),
                icon: const Icon(
                  Icons.save_outlined,
                ),
                label: const Text(
                  'حفظ دوام هذا الموظف',
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInfoBox({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'حدث خطأ أثناء تحميل الموظفين:\n$error',
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
        padding: EdgeInsets.all(18),
        child: Text(
          'لا يوجد موظفو حضانة',
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
          title: const Text('دوام الموظفين'),
          centerTitle: true,
        ),
        body: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: _staffStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(
                snapshot.error,
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final staffDocs = snapshot.data!.docs.where((doc) {
              final data = doc.data();

              final isActive =
                  data['isActive'] != false;

              final accountStatus =
                  _clean(data['accountStatus']).toLowerCase();

              return isActive &&
                  accountStatus != 'archived' &&
                  _isNurseryStaff(data) &&
                  !_isLiveStreamStation(data);
            }).toList();

            staffDocs.sort((a, b) {
              return _staffName(a.data()).compareTo(
                _staffName(b.data()),
              );
            });

            if (staffDocs.isEmpty) {
              return _buildEmptyStaffState();
            }

            if (!isLoadingSaved &&
                !hasLoadedSavedAttendance) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) {
                  if (mounted) {
                    _loadSavedAttendance();
                  }
                },
              );
            }

            return RefreshIndicator(
              onRefresh: _loadSavedAttendance,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  bottom: 24,
                ),
                children: [
                  _buildHeader(
                    staffDocs,
                  ),
                  ...staffDocs.map(
                    _buildStaffAttendanceCard,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}