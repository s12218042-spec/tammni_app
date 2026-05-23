import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_page_scaffold.dart';

class AdminStaffPayrollPage extends StatefulWidget {
  const AdminStaffPayrollPage({super.key});

  @override
  State<AdminStaffPayrollPage> createState() => _AdminStaffPayrollPageState();
}

class _AdminStaffPayrollPageState extends State<AdminStaffPayrollPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool isLoading = false;
  bool isSaving = false;
  bool hasLoadedPayrollSummary = false;

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  String? selectedStaffUid;
  Map<String, dynamic>? selectedStaffData;

  final TextEditingController bonusController = TextEditingController();
  final TextEditingController adminNoteController = TextEditingController();

  static const double defaultHourlyRate = 8.0;

  int attendanceDays = 0;
  double totalRequiredHours = 0.0;
  double totalWorkedHours = 0.0;
  double totalMissingHours = 0.0;
  double totalAttendanceAmount = 0.0;
  double resolvedHourlyRate = defaultHourlyRate;

  String? loadError;

  String get monthKey {
    final y = selectedMonth.year;
    final m = selectedMonth.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  DateTime get monthStart {
    return DateTime(selectedMonth.year, selectedMonth.month, 1);
  }

  DateTime get monthEnd {
    return DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
  }

  String _clean(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  double _toDouble(String value) {
    return double.tryParse(value.trim()) ?? 0.0;
  }

  double _round2(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  String _money(double value) {
    return value.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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

    return 'موظفة بدون اسم';
  }

  double get bonusAmount {
    final value = _toDouble(bonusController.text);
    return value < 0 ? 0 : value;
  }

  double get grossSalary {
    if (totalAttendanceAmount > 0) {
      return _round2(totalAttendanceAmount);
    }

    return _round2(totalWorkedHours * resolvedHourlyRate);
  }

  double get finalSalary {
    final value = grossSalary + bonusAmount;
    return value < 0 ? 0 : _round2(value);
  }

  @override
  void dispose() {
    bonusController.dispose();
    adminNoteController.dispose();
    super.dispose();
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
        'role': _clean(data['role']).isNotEmpty ? _clean(data['role']) : 'admin',
      };
    } catch (_) {
      return {
        'uid': user.uid,
        'name': 'الإدارة',
        'role': 'admin',
      };
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );

    if (picked == null) return;

    setState(() {
      selectedMonth = DateTime(picked.year, picked.month);
      _resetSummary();
      hasLoadedPayrollSummary = false;
    });

    if (selectedStaffUid != null) {
      await _loadPayrollSummary();
    }
  }

  void _resetSummary() {
    attendanceDays = 0;
    totalRequiredHours = 0.0;
    totalWorkedHours = 0.0;
    totalMissingHours = 0.0;
    totalAttendanceAmount = 0.0;
    resolvedHourlyRate = defaultHourlyRate;
    loadError = null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _staffStream() {
    return _firestore.collection('users').snapshots();
  }

  Future<void> _loadExistingPayroll() async {
    if (selectedStaffUid == null) return;

    final payrollId = '${selectedStaffUid}_$monthKey';

    try {
      final doc = await _firestore.collection('staff_payroll').doc(payrollId).get();

      if (!doc.exists) {
        bonusController.text = '';
        adminNoteController.text = '';
        return;
      }

      final data = doc.data() ?? {};

      final bonus = _num(data['bonusAmount']);
      bonusController.text = bonus == 0 ? '' : _money(bonus);

      adminNoteController.text = _clean(data['adminNote']);
    } catch (_) {}
  }

  Future<void> _loadPayrollSummary() async {
    if (selectedStaffUid == null) {
      setState(() {
        hasLoadedPayrollSummary = true;
        _resetSummary();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختاري الموظفة أولًا')),
      );
      return;
    }

    if (isLoading) return;

    setState(() {
      isLoading = true;
      hasLoadedPayrollSummary = false;
      loadError = null;
      attendanceDays = 0;
      totalRequiredHours = 0.0;
      totalWorkedHours = 0.0;
      totalMissingHours = 0.0;
      totalAttendanceAmount = 0.0;
      resolvedHourlyRate = defaultHourlyRate;
    });

    try {
      await _loadExistingPayroll();

      final startKey = _formatDate(monthStart);
      final endKey = _formatDate(monthEnd);

      final snapshot = await _firestore
          .collection('staff_attendance')
          .where('staffUid', isEqualTo: selectedStaffUid)
          .where('dateKey', isGreaterThanOrEqualTo: startKey)
          .where('dateKey', isLessThanOrEqualTo: endKey)
          .limit(120)
          .get()
          .timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw Exception('انتهت مهلة تحميل دوام الموظفة لهذا الشهر');
        },
      );

      double required = 0;
      double worked = 0;
      double missing = 0;
      double attendanceAmount = 0;
      double latestHourlyRate = defaultHourlyRate;
      int countedDays = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        if (data['isActive'] == false) continue;

        final requiredHours = _num(data['requiredHours']);
        final workedHours = _num(data['workedHours']);
        final missingHours = _num(data['missingHours']);
        final dayHourlyRate = _num(data['hourlyRate']);
        final dailyAmount = _num(data['dailyAmount']);

        if (dayHourlyRate > 0) {
          latestHourlyRate = dayHourlyRate;
        }

        required += requiredHours;
        worked += workedHours;
        missing += missingHours;

        if (dailyAmount > 0) {
          attendanceAmount += dailyAmount;
        } else {
          attendanceAmount += workedHours * (dayHourlyRate > 0 ? dayHourlyRate : latestHourlyRate);
        }

        countedDays++;
      }

      if (!mounted) return;

      setState(() {
        attendanceDays = countedDays;
        totalRequiredHours = _round2(required);
        totalWorkedHours = _round2(worked);
        totalMissingHours = _round2(missing);
        totalAttendanceAmount = _round2(attendanceAmount);
        resolvedHourlyRate = latestHourlyRate;
        isLoading = false;
        hasLoadedPayrollSummary = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        hasLoadedPayrollSummary = true;
        loadError = e.toString();
      });
    }
  }

  Future<void> _savePayroll() async {
    if (selectedStaffUid == null || selectedStaffData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختاري الموظفة أولًا')),
      );
      return;
    }

    if (!hasLoadedPayrollSummary || isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حمّلي ملخص الدوام أولًا')),
      );
      return;
    }

    if (attendanceDays == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد دوام محفوظ لهذا الشهر')),
      );
      return;
    }

    if (bonusAmount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('العلاوة لا يمكن أن تكون أقل من صفر')),
      );
      return;
    }

    if (isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      final adminInfo = await _currentAdminInfo();
      final adminUid = _clean(adminInfo['uid']);
      final adminName =
          _clean(adminInfo['name']).isEmpty ? 'الإدارة' : _clean(adminInfo['name']);
      final adminRole =
          _clean(adminInfo['role']).isEmpty ? 'admin' : _clean(adminInfo['role']);

      if (adminUid.isEmpty) {
        throw Exception('يجب تسجيل الدخول كأدمن قبل اعتماد الراتب');
      }

      final staffName = _staffName(selectedStaffData!);
      final staffUsername = _clean(selectedStaffData!['username']);
      final payrollId = '${selectedStaffUid}_$monthKey';

      final ref = _firestore.collection('staff_payroll').doc(payrollId);
      final oldDoc = await ref.get();
      final oldData = oldDoc.data() ?? {};

      await ref.set({
        'payrollId': payrollId,
        'staffUid': selectedStaffUid,
        'staffName': staffName,
        'staffUsername': staffUsername,
        'staffRole': 'nursery_staff',

        'monthKey': monthKey,
        'monthStartDate': Timestamp.fromDate(monthStart),
        'monthEndDate': Timestamp.fromDate(monthEnd),
        'monthStartDateKey': _formatDate(monthStart),
        'monthEndDateKey': _formatDate(monthEnd),

        'salaryCalculationType': 'hourly',
        'hourlyRate': resolvedHourlyRate,
        'defaultHourlyRate': defaultHourlyRate,

        'attendanceDays': attendanceDays,
        'totalWorkedHours': totalWorkedHours,
        'totalRequiredHours': totalRequiredHours,
        'totalMissingHours': totalMissingHours,

        'attendanceAmount': grossSalary,
        'grossSalary': grossSalary,
        'bonusAmount': bonusAmount,
        'deductionAmount': 0.0,
        'finalSalary': finalSalary,

        'adminNote': adminNoteController.text.trim(),

        'isApproved': true,
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedByUid': adminUid,
        'approvedByName': adminName,
        'approvedByRole': adminRole,

        'createdByUid': oldDoc.exists
            ? (oldData['createdByUid'] ?? adminUid)
            : adminUid,
        'createdByName': oldDoc.exists
            ? (oldData['createdByName'] ?? adminName)
            : adminName,
        'createdByRole': oldDoc.exists
            ? (oldData['createdByRole'] ?? adminRole)
            : adminRole,

        'updatedByUid': adminUid,
        'updatedByName': adminName,
        'updatedByRole': adminRole,

        'createdAt': oldDoc.exists
            ? (oldData['createdAt'] ?? FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم اعتماد راتب الموظفة بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ الراتب: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget _buildMonthCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.payments_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'رواتب شهر: $monthKey',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: OutlinedButton.icon(
                    onPressed: isLoading || isSaving ? null : _pickMonth,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('اختيار شهر'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('بداية الشهر', _formatDate(monthStart)),
            const SizedBox(height: 6),
            _infoRow('نهاية الشهر', _formatDate(monthEnd)),
            const SizedBox(height: 6),
            _infoRow('طريقة الحساب', 'بالساعات فقط'),
          ],
        ),
      ),
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
                'حدث خطأ أثناء تحميل الموظفات:\n${snapshot.error}',
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
                'لا يوجد موظفات حضانة',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: DropdownButtonFormField<String>(
              value: selectedStaffUid,
              decoration: const InputDecoration(
                labelText: 'الموظفة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: staffDocs.map((doc) {
                final data = doc.data();
                final name = _staffName(data);
                final username = _clean(data['username']);

                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(
                    username.isEmpty ? name : '$name - @$username',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: isLoading || isSaving
                  ? null
                  : (value) async {
                      if (value == null) return;

                      final selectedDoc = staffDocs.firstWhere(
                        (doc) => doc.id == value,
                      );

                      setState(() {
                        selectedStaffUid = selectedDoc.id;
                        selectedStaffData = selectedDoc.data();
                        _resetSummary();
                        hasLoadedPayrollSummary = false;
                      });

                      await _loadPayrollSummary();
                    },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص الشهر',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            if (selectedStaffUid == null)
              const Text(
                'اختاري موظفة أولًا',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              )
            else if (isLoading || !hasLoadedPayrollSummary)
              const LinearProgressIndicator()
            else if (loadError != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حدث خطأ أثناء تحميل الملخص:\n$loadError',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _loadPayrollSummary,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              )
            else ...[
              if (attendanceDays == 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.22)),
                  ),
                  child: const Text(
                    'لا يوجد دوام محفوظ لهذه الموظفة في هذا الشهر',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _summaryBox(
                      title: 'أيام الدوام',
                      value: '$attendanceDays',
                      color: Colors.blueGrey,
                      icon: Icons.event_available_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryBox(
                      title: 'الساعات',
                      value: totalWorkedHours.toStringAsFixed(2),
                      color: Colors.green,
                      icon: Icons.timer_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _summaryBox(
                      title: 'المطلوبة',
                      value: totalRequiredHours.toStringAsFixed(2),
                      color: Colors.teal,
                      icon: Icons.schedule_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryBox(
                      title: 'النقص',
                      value: totalMissingHours.toStringAsFixed(2),
                      color: totalMissingHours > 0 ? Colors.orange : Colors.green,
                      icon: Icons.warning_amber_outlined,
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

  Widget _summaryBox({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const Text(
              'اعتماد الراتب',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _hoursRow('عدد الساعات', totalWorkedHours),
            const SizedBox(height: 6),
            _moneyRow('سعر الساعة', resolvedHourlyRate),
            const SizedBox(height: 6),
            _moneyRow('أجر الساعات', grossSalary),
            const SizedBox(height: 12),
            TextField(
              controller: bonusController,
              keyboardType: TextInputType.number,
              enabled: !isSaving,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'علاوة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add_circle_outline),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: adminNoteController,
              maxLines: 3,
              enabled: !isSaving,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'ملاحظات الإدارة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withOpacity(0.20)),
              ),
              child: Column(
                children: [
                  _hoursRow('عدد الساعات', totalWorkedHours),
                  const SizedBox(height: 6),
                  _moneyRow('سعر الساعة', resolvedHourlyRate),
                  const SizedBox(height: 6),
                  _moneyRow('أجر الساعات', grossSalary),
                  const SizedBox(height: 6),
                  _moneyRow('العلاوة', bonusAmount),
                  const SizedBox(height: 6),
                  const Divider(),
                  _moneyRow(
                    'الراتب النهائي',
                    finalSalary,
                    isBold: true,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _savePayroll,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                label: Text(
                  isSaving ? 'جاري الاعتماد...' : 'اعتماد الراتب',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyRow(
    String title,
    double value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: color ?? Colors.black87,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
        Text(
          '${_money(value)} شيكل',
          style: TextStyle(
            color: color ?? Colors.black87,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _hoursRow(
    String title,
    double value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: color ?? Colors.black87,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
        Text(
          '${value.toStringAsFixed(2)} ساعة',
          style: TextStyle(
            color: color ?? Colors.black87,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
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
    return AppPageScaffold(
      title: 'رواتب الموظفات',
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: RefreshIndicator(
        onRefresh: _loadPayrollSummary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildMonthCard(),
            _buildStaffPicker(),
            _buildSummaryCard(),
            _buildSalaryCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}