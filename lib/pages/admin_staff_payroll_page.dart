import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminStaffPayrollPage extends StatefulWidget {
  const AdminStaffPayrollPage({super.key});

  @override
  State<AdminStaffPayrollPage> createState() => _AdminStaffPayrollPageState();
}

class _AdminStaffPayrollPageState extends State<AdminStaffPayrollPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  bool isSaving = false;
  bool hasLoadedPayrollSummary = false;

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  String? selectedStaffUid;
  Map<String, dynamic>? selectedStaffData;

  final TextEditingController deductionController = TextEditingController();
  final TextEditingController bonusController = TextEditingController();
  final TextEditingController adminNoteController = TextEditingController();

  double baseSalary = 1800.0;

  int attendanceDays = 0;
  double totalRequiredHours = 0.0;
  double totalWorkedHours = 0.0;
  double totalMissingHours = 0.0;

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

  double _toDouble(String value) {
    return double.tryParse(value.trim()) ?? 0.0;
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

  double get deductionAmount => _toDouble(deductionController.text);
  double get bonusAmount => _toDouble(bonusController.text);

  double get finalSalary {
    final value = baseSalary - deductionAmount + bonusAmount;
    return value < 0 ? 0 : value;
  }

  @override
  void dispose() {
    deductionController.dispose();
    bonusController.dispose();
    adminNoteController.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      helpText: 'اختاري أي يوم من الشهر المطلوب',
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
    loadError = null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _staffStream() {
    return _firestore.collection('users').snapshots();
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
    });

    try {
      final startKey = _formatDate(monthStart);
      final endKey = _formatDate(monthEnd);

      final snapshot = await _firestore
          .collection('staff_attendance')
          .where('staffUid', isEqualTo: selectedStaffUid)
          .where('dateKey', isGreaterThanOrEqualTo: startKey)
          .where('dateKey', isLessThanOrEqualTo: endKey)
          .limit(80)
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

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final requiredRaw = data['requiredHours'];
        final workedRaw = data['workedHours'];
        final missingRaw = data['missingHours'];

        if (requiredRaw is num) required += requiredRaw.toDouble();
        if (workedRaw is num) worked += workedRaw.toDouble();
        if (missingRaw is num) missing += missingRaw.toDouble();
      }

      if (!mounted) return;

      setState(() {
        attendanceDays = snapshot.docs.length;
        totalRequiredHours = double.parse(required.toStringAsFixed(2));
        totalWorkedHours = double.parse(worked.toStringAsFixed(2));
        totalMissingHours = double.parse(missing.toStringAsFixed(2));
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

    if (isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      final staffName = _staffName(selectedStaffData!);
      final staffUsername = _clean(selectedStaffData!['username']);

      final payrollId = '${selectedStaffUid}_$monthKey';

      await _firestore.collection('staff_payroll').doc(payrollId).set({
        'payrollId': payrollId,
        'staffUid': selectedStaffUid,
        'staffName': staffName,
        'staffUsername': staffUsername,
        'monthKey': monthKey,
        'monthStartDate': Timestamp.fromDate(monthStart),
        'monthEndDate': Timestamp.fromDate(monthEnd),
        'monthStartDateKey': _formatDate(monthStart),
        'monthEndDateKey': _formatDate(monthEnd),
        'baseSalary': baseSalary,
        'attendanceDays': attendanceDays,
        'totalRequiredHours': totalRequiredHours,
        'totalWorkedHours': totalWorkedHours,
        'totalMissingHours': totalMissingHours,
        'deductionAmount': deductionAmount,
        'bonusAmount': bonusAmount,
        'finalSalary': double.parse(finalSalary.toStringAsFixed(2)),
        'adminNote': adminNoteController.text.trim(),
        'isApproved': true,
        'createdByRole': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
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
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.18)),
              ),
              child: const Text(
                'هذه الصفحة خاصة برواتب الموظفات فقط، ولا علاقة لها بفواتير أولياء الأمور.',
                textAlign: TextAlign.center,
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
                'لا يوجد موظفات حضانة.\nتأكدي أن role = nursery_staff داخل users.',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اختيار الموظفة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
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
              ],
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
              'ملخص الدوام لهذا الشهر',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            if (selectedStaffUid == null)
              const Text(
                'اختاري موظفة أولًا لعرض ملخص الدوام والراتب.',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
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
                    'لا يوجد دوام محفوظ لهذه الموظفة في هذا الشهر. يمكنك اعتماد الراتب يدويًا إذا قررت الإدارة ذلك.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
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
                      title: 'المطلوبة',
                      value: totalRequiredHours.toStringAsFixed(2),
                      color: Colors.teal,
                      icon: Icons.schedule_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _summaryBox(
                      title: 'الفعلية',
                      value: totalWorkedHours.toStringAsFixed(2),
                      color: Colors.green,
                      icon: Icons.timer_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryBox(
                      title: 'النقص',
                      value: totalMissingHours.toStringAsFixed(2),
                      color:
                          totalMissingHours > 0 ? Colors.orange : Colors.green,
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
            _moneyRow('الراتب الأساسي', baseSalary),
            const SizedBox(height: 8),
            TextField(
              controller: deductionController,
              keyboardType: TextInputType.number,
              enabled: !isSaving,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'الخصم الذي تحدده الإدارة',
                hintText: 'مثال: 100',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.remove_circle_outline),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bonusController,
              keyboardType: TextInputType.number,
              enabled: !isSaving,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'العلاوة التي تحددها الإدارة',
                hintText: 'مثال: 50',
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
                hintText: 'مثال: خصم بسبب نقص ساعات خلال الشهر',
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
                  _moneyRow('الخصم', deductionAmount),
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
          title: const Text('رواتب الموظفات'),
          centerTitle: true,
        ),
        body: RefreshIndicator(
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
      ),
    );
  }
}