import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class StaffEmployeeFilePage extends StatefulWidget {
  const StaffEmployeeFilePage({super.key});

  @override
  State<StaffEmployeeFilePage> createState() => _StaffEmployeeFilePageState();
}

class _StaffEmployeeFilePageState extends State<StaffEmployeeFilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  String? loadError;

  Map<String, dynamic>? latestEvaluation;
  Map<String, dynamic>? latestPayroll;
  Map<String, dynamic>? currentDuty;
  List<Map<String, dynamic>> attendanceThisMonth = [];

  DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String get monthKey {
    final m = today.month.toString().padLeft(2, '0');
    return '${today.year}-$m';
  }

  DateTime get monthStart => DateTime(today.year, today.month, 1);

  DateTime get monthEnd => DateTime(today.year, today.month + 1, 0);

  DateTime get weekStart {
    final d = today;
    final daysFromSunday = d.weekday == DateTime.sunday ? 0 : d.weekday;
    return d.subtract(Duration(days: daysFromSunday));
  }

  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  String get weekKey {
    final firstDay = DateTime(today.year, 1, 1);
    final diff = today.difference(firstDay).inDays;
    final week = ((diff + firstDay.weekday) / 7).ceil();
    return '${today.year}-W${week.toString().padLeft(2, '0')}';
  }

  String _clean(dynamic value) => value?.toString().trim() ?? '';

  String _formatDate(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _money(dynamic value) {
    return _toDouble(value).toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    _loadEmployeeFile();
  }

  Future<void> _loadEmployeeFile() async {
    final currentUser = AuthService().currentUser;

    if (currentUser == null) {
      setState(() {
        loadError = 'لم يتم العثور على المستخدم الحالي. سجّلي الدخول مرة أخرى.';
      });
      return;
    }

    if (isLoading) return;

    setState(() {
      isLoading = true;
      loadError = null;
      latestEvaluation = null;
      latestPayroll = null;
      currentDuty = null;
      attendanceThisMonth = [];
    });

    try {
      final uid = currentUser.uid;
      final startKey = _formatDate(monthStart);
      final endKey = _formatDate(monthEnd);

      final evaluationSnapshot = await _firestore
          .collection('staff_evaluations')
          .where('staffUid', isEqualTo: uid)
          .limit(20)
          .get();

      final payrollSnapshot = await _firestore
          .collection('staff_payroll')
          .where('staffUid', isEqualTo: uid)
          .where('monthKey', isEqualTo: monthKey)
          .limit(1)
          .get();

      final attendanceSnapshot = await _firestore
          .collection('staff_attendance')
          .where('staffUid', isEqualTo: uid)
          .where('dateKey', isGreaterThanOrEqualTo: startKey)
          .where('dateKey', isLessThanOrEqualTo: endKey)
          .limit(80)
          .get();

      final dutyDoc =
          await _firestore.collection('weekly_duties').doc(weekKey).get();

      Map<String, dynamic>? latestEvalData;

      if (evaluationSnapshot.docs.isNotEmpty) {
        final docs = evaluationSnapshot.docs.toList();

        docs.sort((a, b) {
          final aData = a.data();
          final bData = b.data();

          final aUpdated = aData['updatedAt'];
          final bUpdated = bData['updatedAt'];

          if (aUpdated is Timestamp && bUpdated is Timestamp) {
            return bUpdated.compareTo(aUpdated);
          }

          return _clean(bData['periodKey']).compareTo(_clean(aData['periodKey']));
        });

        latestEvalData = docs.first.data();
      }

      final attendanceItems = attendanceSnapshot.docs.map((doc) {
        return {
          ...doc.data(),
          '_docId': doc.id,
        };
      }).toList();

      attendanceItems.sort((a, b) {
        return _clean(b['dateKey']).compareTo(_clean(a['dateKey']));
      });

      if (!mounted) return;

      setState(() {
        latestEvaluation = latestEvalData;
        latestPayroll = payrollSnapshot.docs.isEmpty
            ? null
            : payrollSnapshot.docs.first.data();
        currentDuty = dutyDoc.data();
        attendanceThisMonth = attendanceItems;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = e.toString();
      });
    }
  }

  bool _isMyDuty() {
    final currentUser = AuthService().currentUser;
    if (currentUser == null || currentDuty == null) return false;

    final rawUids = currentDuty!['dutyStaffUids'];

    if (rawUids is List) {
      final uids = rawUids.map((e) => e.toString().trim()).toList();
      return uids.contains(currentUser.uid);
    }

    final oldStaffUid = _clean(currentDuty!['staffUid']);
    return oldStaffUid == currentUser.uid;
  }

  String _dutyNames() {
    if (currentDuty == null) return 'لا توجد مناوبة محددة لهذا الأسبوع';

    final rawDutyStaff = currentDuty!['dutyStaff'];

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

    final oldName = _clean(currentDuty!['staffName']);
    if (oldName.isNotEmpty) return oldName;

    return 'لا توجد مناوبة محددة لهذا الأسبوع';
  }

  double get totalWorkedHours {
    double total = 0;
    for (final item in attendanceThisMonth) {
      total += _toDouble(item['workedHours']);
    }
    return total;
  }

  double get totalMissingHours {
    double total = 0;
    for (final item in attendanceThisMonth) {
      total += _toDouble(item['missingHours']);
    }
    return total;
  }

  int get absentDays {
    return attendanceThisMonth.where((e) => e['isAbsent'] == true).length;
  }

  Color _averageColor(double avg) {
    if (avg >= 4.5) return Colors.green;
    if (avg >= 3.8) return Colors.teal;
    if (avg >= 3.0) return Colors.blueGrey;
    if (avg >= 2.0) return Colors.orange;
    return Colors.redAccent;
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.blueGrey.withOpacity(0.12),
              child: const Icon(
                Icons.badge_outlined,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ملفي الوظيفي',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ملخص مهامكِ الوظيفية: التقييم، الدوام، الراتب، والمناوبة',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
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

  Widget _buildDutyCard() {
    final isMyDuty = _isMyDuty();

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isMyDuty
                  ? Colors.green.withOpacity(0.12)
                  : Colors.blueGrey.withOpacity(0.10),
              child: Icon(
                isMyDuty
                    ? Icons.verified_user_outlined
                    : Icons.event_note_outlined,
                color: isMyDuty ? Colors.green : Colors.blueGrey,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMyDuty
                        ? 'أنتِ ضمن مناوبات هذا الأسبوع'
                        : 'لا توجد مناوبة عليكِ هذا الأسبوع',
                    style: TextStyle(
                      color: isMyDuty ? Colors.green : Colors.black87,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المناوبات: ${_dutyNames()}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الأسبوع: $weekKey من ${_formatDate(weekStart)} إلى ${_formatDate(weekEnd)}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
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

  Widget _buildEvaluationCard() {
    if (latestEvaluation == null) {
      return _emptyCard(
        icon: Icons.star_border_rounded,
        title: 'لا يوجد تقييم بعد',
        subtitle: 'عند إضافة تقييم من الإدارة سيظهر هنا.',
      );
    }

    final avg = _toDouble(latestEvaluation!['averageScore']);
    final label = _clean(latestEvaluation!['averageLabel']).isEmpty
        ? 'غير محدد'
        : _clean(latestEvaluation!['averageLabel']);

    final type = _clean(latestEvaluation!['evaluationTypeLabel']).isEmpty
        ? _clean(latestEvaluation!['evaluationType'])
        : _clean(latestEvaluation!['evaluationTypeLabel']);

    final period = _clean(latestEvaluation!['periodKey']);
    final note = _clean(latestEvaluation!['adminNotes']);

    final color = _averageColor(avg);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(Icons.star_rate_outlined, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$type - $period',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المتوسط: ${avg.toStringAsFixed(2)} / 5 - $label',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'ملاحظة الإدارة: $note',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص دوام الشهر الحالي',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniBox(
                    title: 'أيام مسجلة',
                    value: '${attendanceThisMonth.length}',
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniBox(
                    title: 'ساعات العمل',
                    value: totalWorkedHours.toStringAsFixed(2),
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _miniBox(
                    title: 'ساعات النقص',
                    value: totalMissingHours.toStringAsFixed(2),
                    color: totalMissingHours > 0 ? Colors.orange : Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniBox(
                    title: 'أيام الغياب',
                    value: '$absentDays',
                    color: absentDays > 0 ? Colors.redAccent : Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryCard() {
    if (latestPayroll == null) {
      return _emptyCard(
        icon: Icons.payments_outlined,
        title: 'لم يتم اعتماد راتب هذا الشهر بعد',
        subtitle: 'بعد اعتماد الراتب من الإدارة سيظهر هنا.',
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const Row(
              children: [
                CircleAvatar(
                  child: Icon(Icons.payments_outlined),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'راتبي لهذا الشهر',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _moneyRow('الشهر', _clean(latestPayroll!['monthKey']), isText: true),
            _moneyRow('الراتب الأساسي', _money(latestPayroll!['baseSalary'])),
            _moneyRow('الخصم', _money(latestPayroll!['deductionAmount'])),
            _moneyRow('العلاوة', _money(latestPayroll!['bonusAmount'])),
            const Divider(),
            _moneyRow(
              'الراتب النهائي',
              _money(latestPayroll!['finalSalary']),
              isBold: true,
              color: Colors.green,
            ),
            if (_clean(latestPayroll!['adminNote']).isNotEmpty) ...[
              const SizedBox(height: 8),
              _noteBox('ملاحظات الإدارة', _clean(latestPayroll!['adminNote'])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniBox({
    required String title,
    required String value,
    required Color color,
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
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blueGrey.withOpacity(0.10),
              child: Icon(icon, color: Colors.blueGrey),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
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

  Widget _moneyRow(
    String title,
    String value, {
    bool isBold = false,
    bool isText = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? Colors.black87,
              ),
            ),
          ),
          Text(
            isText ? value : '$value شيكل',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
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
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 42,
              ),
              const SizedBox(height: 12),
              const Text(
                'حدث خطأ أثناء تحميل الملف الوظيفي',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loadError ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadEmployeeFile,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
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
          title: const Text('ملفي الوظيفي'),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: _loadEmployeeFile,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : loadError != null
                  ? _buildErrorState()
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _buildHeaderCard(),
                        _sectionTitle('المناوبة الأسبوعية', Icons.event_note_outlined),
                        _buildDutyCard(),
                        _sectionTitle('آخر تقييم', Icons.star_rate_outlined),
                        _buildEvaluationCard(),
                        _sectionTitle('دوامي', Icons.access_time_outlined),
                        _buildAttendanceCard(),
                        _sectionTitle('راتبي', Icons.payments_outlined),
                        _buildSalaryCard(),
                        const SizedBox(height: 20),
                      ],
                    ),
        ),
      ),
    );
  }
}