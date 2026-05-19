import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminStaffEvaluationsPage extends StatefulWidget {
  const AdminStaffEvaluationsPage({super.key});

  @override
  State<AdminStaffEvaluationsPage> createState() =>
      _AdminStaffEvaluationsPageState();
}

class _AdminStaffEvaluationsPageState
    extends State<AdminStaffEvaluationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isSaving = false;

  String selectedEvaluationType = 'weekly';
  String? selectedStaffUid;
  Map<String, dynamic>? selectedStaffData;

  final TextEditingController adminNotesController = TextEditingController();

  final Map<String, int> scores = {
    'attendanceCommitment': 3,
    'taskCommitment': 3,
    'cleanliness': 3,
    'childControl': 3,
    'childrenInteraction': 3,
    'parentsInteraction': 3,
    'adminInteraction': 3,
    'staffInteraction': 3,
    'classroomCare': 3,
    'indoorOutdoorCare': 3,
    'initiativePressure': 3,
    'documentationQuality': 3,
  };

  final Map<String, String> scoreLabels = {
    'attendanceCommitment': 'الالتزام بالدوام',
    'taskCommitment': 'الالتزام بالمهام',
    'cleanliness': 'النظافة والترتيب',
    'childControl': 'ضبط الأطفال',
    'childrenInteraction': 'التعامل مع الأطفال',
    'parentsInteraction': 'التعامل مع الأهالي',
    'adminInteraction': 'التعامل مع الإدارة',
    'staffInteraction': 'التعامل مع الموظفات',
    'classroomCare': 'المحافظة على الصف',
    'indoorOutdoorCare': 'المحافظة على الساحة الداخلية/الخارجية',
    'initiativePressure': 'المبادرة وتحمل الضغط',
    'documentationQuality': 'جودة التوثيق والتصوير',
  };

  @override
  void dispose() {
    adminNotesController.dispose();
    super.dispose();
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
    final displayName = _clean(data['displayName']);
    final username = _clean(data['username']);

    if (name.isNotEmpty) return name;
    if (fullName.isNotEmpty) return fullName;
    if (displayName.isNotEmpty) return displayName;
    if (username.isNotEmpty) return username;

    return 'موظفة بدون اسم';
  }

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

  DateTime get monthStart {
    return DateTime(today.year, today.month, 1);
  }

  DateTime get monthEnd {
    return DateTime(today.year, today.month + 1, 0);
  }

  String get monthKey {
    final m = today.month.toString().padLeft(2, '0');
    return '${today.year}-$m';
  }

  String get currentPeriodKey {
    return selectedEvaluationType == 'weekly' ? weekKey : monthKey;
  }

  DateTime get currentPeriodStart {
    return selectedEvaluationType == 'weekly' ? weekStart : monthStart;
  }

  DateTime get currentPeriodEnd {
    return selectedEvaluationType == 'weekly' ? weekEnd : monthEnd;
  }

  String _formatDate(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  double get averageScore {
    if (scores.isEmpty) return 0;
    final total = scores.values.fold<int>(0, (sum, value) => sum + value);
    return total / scores.length;
  }

  String get averageLabel {
    final avg = averageScore;

    if (avg >= 4.5) return 'ممتاز';
    if (avg >= 3.8) return 'جيد جدًا';
    if (avg >= 3.0) return 'جيد';
    if (avg >= 2.0) return 'بحاجة تحسين';
    return 'ضعيف';
  }

  Color get averageColor {
    final avg = averageScore;

    if (avg >= 4.5) return Colors.green;
    if (avg >= 3.8) return Colors.teal;
    if (avg >= 3.0) return Colors.blueGrey;
    if (avg >= 2.0) return Colors.orange;
    return Colors.redAccent;
  }

  Future<void> _saveEvaluation() async {
    if (selectedStaffUid == null || selectedStaffData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختاري الموظفة أولًا')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final staffName = _staffName(selectedStaffData!);
      final staffUsername = _clean(selectedStaffData!['username']);

      final evaluationId =
          '${selectedStaffUid}_${selectedEvaluationType}_$currentPeriodKey';

      await _firestore.collection('staff_evaluations').doc(evaluationId).set({
        'evaluationId': evaluationId,
        'staffUid': selectedStaffUid,
        'staffName': staffName,
        'staffUsername': staffUsername,
        'evaluationType': selectedEvaluationType,
        'evaluationTypeLabel':
            selectedEvaluationType == 'weekly' ? 'أسبوعي' : 'شهري',
        'periodKey': currentPeriodKey,
        'periodStartDate': Timestamp.fromDate(currentPeriodStart),
        'periodEndDate': Timestamp.fromDate(currentPeriodEnd),
        'periodStartDateKey': _formatDate(currentPeriodStart),
        'periodEndDateKey': _formatDate(currentPeriodEnd),
        'scores': scores,
        'scoreLabels': scoreLabels,
        'averageScore': double.parse(averageScore.toStringAsFixed(2)),
        'averageLabel': averageLabel,
        'adminNotes': adminNotesController.text.trim(),
        'createdByRole': 'admin',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ تقييم الموظفة بنجاح')),
      );

      setState(() {
        selectedStaffUid = null;
        selectedStaffData = null;
        selectedEvaluationType = 'weekly';

        for (final key in scores.keys.toList()) {
          scores[key] = 3;
        }

        adminNotesController.clear();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ التقييم: $e')),
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
    return _firestore.collection('users').snapshots();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadEvaluationArchive() async {
    final snapshot = await _firestore
        .collection('staff_evaluations')
        .limit(50)
        .get()
        .timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        throw Exception('انتهت مهلة تحميل أرشيف التقييمات');
      },
    );

    final docs = snapshot.docs;

    docs.sort((a, b) {
      final aUpdated = a.data()['updatedAt'];
      final bUpdated = b.data()['updatedAt'];

      if (aUpdated is Timestamp && bUpdated is Timestamp) {
        return bUpdated.compareTo(aUpdated);
      }

      return _clean(b.data()['periodKey'])
          .compareTo(_clean(a.data()['periodKey']));
    });

    return docs;
  }

  Widget _buildPeriodCard() {
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
                  child: Icon(Icons.fact_check_outlined),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'فترة التقييم',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'weekly',
                  label: Text('أسبوعي'),
                  icon: Icon(Icons.calendar_view_week_outlined),
                ),
                ButtonSegment(
                  value: 'monthly',
                  label: Text('شهري'),
                  icon: Icon(Icons.calendar_month_outlined),
                ),
              ],
              selected: {selectedEvaluationType},
              onSelectionChanged: isSaving
                  ? null
                  : (value) {
                      setState(() {
                        selectedEvaluationType = value.first;
                      });
                    },
            ),
            const SizedBox(height: 12),
            _infoRow('رمز الفترة', currentPeriodKey),
            const SizedBox(height: 6),
            _infoRow('بداية الفترة', _formatDate(currentPeriodStart)),
            const SizedBox(height: 6),
            _infoRow('نهاية الفترة', _formatDate(currentPeriodEnd)),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
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
                  onChanged: isSaving
                      ? null
                      : (value) {
                          if (value == null) return;

                          final selectedDoc = staffDocs.firstWhere(
                            (doc) => doc.id == value,
                          );

                          setState(() {
                            selectedStaffUid = selectedDoc.id;
                            selectedStaffData = selectedDoc.data();
                          });
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoresSection() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معايير التقييم',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'كل معيار من 1 إلى 5',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...scores.keys.map((key) {
              final value = scores[key] ?? 3;
              final label = scoreLabels[key] ?? key;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.star_border_rounded,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: _scoreColor(value).withOpacity(0.12),
                          child: Text(
                            '$value',
                            style: TextStyle(
                              color: _scoreColor(value),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: value.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '$value',
                      onChanged: isSaving
                          ? null
                          : (newValue) {
                              setState(() {
                                scores[key] = newValue.round();
                              });
                            },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(int value) {
    if (value >= 5) return Colors.green;
    if (value == 4) return Colors.teal;
    if (value == 3) return Colors.blueGrey;
    if (value == 2) return Colors.orange;
    return Colors.redAccent;
  }

  Widget _buildAverageCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: averageColor.withOpacity(0.12),
              child: Icon(Icons.analytics_outlined, color: averageColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'متوسط التقييم',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${averageScore.toStringAsFixed(2)} / 5 - $averageLabel',
                    style: TextStyle(
                      color: averageColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
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

  Widget _buildNotesAndSaveCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: adminNotesController,
              maxLines: 4,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'ملاحظات الإدارة',
                hintText: 'اكتبي ملاحظات حول أداء الموظفة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _saveEvaluation,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  isSaving ? 'جاري الحفظ...' : 'حفظ التقييم',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveSection() {
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _loadEvaluationArchive(),
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
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'حدث خطأ أثناء تحميل أرشيف التقييمات:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
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
                'لا يوجد أرشيف تقييمات بعد.',
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
                  'آخر التقييمات',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                ...docs.map((doc) {
                  final data = doc.data();

                  final staffName = _clean(data['staffName']).isEmpty
                      ? 'موظفة بدون اسم'
                      : _clean(data['staffName']);

                  final typeLabel = _clean(data['evaluationTypeLabel']).isEmpty
                      ? _clean(data['evaluationType'])
                      : _clean(data['evaluationTypeLabel']);

                  final key = _clean(data['periodKey']);
                  final avg = data['averageScore'];
                  final avgLabel = _clean(data['averageLabel']);

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
                        CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.12),
                          child: const Icon(
                            Icons.star_outline_rounded,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                staffName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$typeLabel • $key • $avg / 5 ${avgLabel.isNotEmpty ? "- $avgLabel" : ""}',
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
          title: const Text('تقييم الموظفات'),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildPeriodCard(),
              _buildStaffPicker(),
              _buildScoresSection(),
              _buildAverageCard(),
              _buildNotesAndSaveCard(),
              _buildArchiveSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}