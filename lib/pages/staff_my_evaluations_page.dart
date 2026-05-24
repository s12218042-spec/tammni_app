import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class StaffMyEvaluationsPage extends StatefulWidget {
  const StaffMyEvaluationsPage({super.key});

  @override
  State<StaffMyEvaluationsPage> createState() => _StaffMyEvaluationsPageState();
}

class _StaffMyEvaluationsPageState extends State<StaffMyEvaluationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  String? loadError;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> evaluations = [];

  String selectedFilter = 'all';

  String _clean(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyEvaluations();
    });
  }

  Future<void> _loadMyEvaluations() async {
    final currentUser = AuthService().currentUser;

    if (currentUser == null) {
  if (!mounted) return;

  setState(() {
    isLoading = false;
    loadError = 'لم يتم العثور على المستخدم الحالي. سجّلي الدخول مرة أخرى.';
    evaluations = [];
  });

  return;
}

    if (isLoading) return;

    setState(() {
      isLoading = true;
      loadError = null;
      evaluations = [];
    });

    try {
      final snapshot = await _firestore
          .collection('staff_evaluations')
          .where('staffUid', isEqualTo: currentUser.uid)
          .limit(100)
          .get()
          .timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw Exception(
            'انتهت مهلة تحميل التقييمات. تأكدي من الاتصال أو الصلاحيات.',
          );
        },
      );

      final docs = snapshot.docs;

      docs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();

        final aUpdated = aData['updatedAt'];
        final bUpdated = bData['updatedAt'];

        if (aUpdated is Timestamp && bUpdated is Timestamp) {
          return bUpdated.compareTo(aUpdated);
        }

        final aPeriod = _clean(aData['periodKey']);
        final bPeriod = _clean(bData['periodKey']);

        return bPeriod.compareTo(aPeriod);
      });

      if (!mounted) return;

      setState(() {
        evaluations = docs;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = e.toString();
        evaluations = [];
      });
    }
  }

  Color _averageColor(double avg) {
    if (avg >= 4.5) return Colors.green;
    if (avg >= 3.8) return Colors.teal;
    if (avg >= 3.0) return Colors.blueGrey;
    if (avg >= 2.0) return Colors.orange;
    return Colors.redAccent;
  }

  IconData _averageIcon(double avg) {
    if (avg >= 4.5) return Icons.emoji_events_outlined;
    if (avg >= 3.8) return Icons.star_outline_rounded;
    if (avg >= 3.0) return Icons.check_circle_outline;
    if (avg >= 2.0) return Icons.warning_amber_rounded;
    return Icons.error_outline;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get filteredEvaluations {
    if (selectedFilter == 'all') return evaluations;

    return evaluations.where((doc) {
      final type = _clean(doc.data()['evaluationType']);
      return type == selectedFilter;
    }).toList();
  }

  Widget _buildHeader() {
    final weeklyCount = evaluations.where((doc) {
      return _clean(doc.data()['evaluationType']) == 'weekly';
    }).length;

    final monthlyCount = evaluations.where((doc) {
      return _clean(doc.data()['evaluationType']) == 'monthly';
    }).length;

    double latestAverage = 0;
    String latestLabel = 'لا يوجد';

    if (evaluations.isNotEmpty) {
      final data = evaluations.first.data();
      final rawAvg = data['averageScore'];

      if (rawAvg is num) {
        latestAverage = rawAvg.toDouble();
      }

      latestLabel = _clean(data['averageLabel']).isEmpty
          ? 'غير محدد'
          : _clean(data['averageLabel']);
    }

    final color = _averageColor(latestAverage);

    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(
                    _averageIcon(latestAverage),
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تقييماتي',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        evaluations.isEmpty
                            ? 'لم يتم إضافة تقييمات لكِ بعد'
                            : 'آخر تقييم: ${latestAverage.toStringAsFixed(2)} / 5 - $latestLabel',
                        style: TextStyle(
                          color: evaluations.isEmpty ? Colors.grey : color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _summaryBox(
                    title: 'كل التقييمات',
                    value: evaluations.length.toString(),
                    icon: Icons.fact_check_outlined,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryBox(
                    title: 'أسبوعي',
                    value: weeklyCount.toString(),
                    icon: Icons.calendar_view_week_outlined,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryBox(
                    title: 'شهري',
                    value: monthlyCount.toString(),
                    icon: Icons.calendar_month_outlined,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryBox({
    required String title,
    required String value,
    required IconData icon,
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

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(
                label: 'الكل',
                value: 'all',
                icon: Icons.list_alt_outlined,
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: 'أسبوعي',
                value: 'weekly',
                icon: Icons.calendar_view_week_outlined,
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: 'شهري',
                value: 'monthly',
                icon: Icons.calendar_month_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final selected = selectedFilter == value;

    return ChoiceChip(
      selected: selected,
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : Colors.blueGrey,
      ),
      label: Text(label),
      onSelected: (_) {
        setState(() {
          selectedFilter = value;
        });
      },
    );
  }

  Widget _buildEvaluationCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final typeLabel = _clean(data['evaluationTypeLabel']).isEmpty
        ? _clean(data['evaluationType'])
        : _clean(data['evaluationTypeLabel']);

    final periodKey = _clean(data['periodKey']);
    final start = _clean(data['periodStartDateKey']);
    final end = _clean(data['periodEndDateKey']);

    final rawAverage = data['averageScore'];
    final average = rawAverage is num ? rawAverage.toDouble() : 0.0;

    final averageLabel = _clean(data['averageLabel']).isEmpty
        ? 'غير محدد'
        : _clean(data['averageLabel']);

    final adminNotes = _clean(data['adminNotes']);

    final rawScores = data['scores'];
    final rawLabels = data['scoreLabels'];

    final Map<String, dynamic> scores =
        rawScores is Map ? Map<String, dynamic>.from(rawScores) : {};

    final Map<String, dynamic> scoreLabels =
        rawLabels is Map ? Map<String, dynamic>.from(rawLabels) : {};

    final color = _averageColor(average);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(_averageIcon(average), color: color),
        ),
        title: Text(
          '$typeLabel - $periodKey',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'من $start إلى $end',
          style: const TextStyle(color: Colors.grey),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.18)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.analytics_outlined, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'المتوسط: ${average.toStringAsFixed(2)} / 5 - $averageLabel',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (adminNotes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _noteBox(
                    title: 'ملاحظات الإدارة',
                    value: adminNotes,
                    icon: Icons.notes_outlined,
                  ),
                ],
                const SizedBox(height: 10),
                _scoresDetails(scores: scores, labels: scoreLabels),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteBox({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
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
              style: const TextStyle(
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoresDetails({
    required Map<String, dynamic> scores,
    required Map<String, dynamic> labels,
  }) {
    if (scores.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = scores.entries.toList();

    return Column(
      children: entries.map((entry) {
        final key = entry.key;
        final rawValue = entry.value;

        final value = rawValue is num ? rawValue.toInt() : 0;
        final label = _clean(labels[key]).isEmpty ? key : _clean(labels[key]);

        final color = _scoreColor(value);

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
                radius: 15,
                backgroundColor: color.withOpacity(0.12),
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < value ? Icons.star : Icons.star_border,
                    color: color,
                    size: 17,
                  );
                }),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _scoreColor(int value) {
    if (value >= 5) return Colors.green;
    if (value == 4) return Colors.teal;
    if (value == 3) return Colors.blueGrey;
    if (value == 2) return Colors.orange;
    return Colors.redAccent;
  }

  Widget _buildEmptyState() {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.star_border_rounded,
              size: 48,
              color: Colors.blueGrey,
            ),
            SizedBox(height: 12),
            Text(
              'لا توجد تقييمات بعد',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'عند إضافة تقييم من الإدارة سيظهر هنا.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
              'حدث خطأ أثناء تحميل التقييمات',
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
              onPressed: isLoading ? null : _loadMyEvaluations,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'جاري تحميل تقييماتك...',
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

    if (evaluations.isEmpty) {
      return _buildEmptyState();
    }

    final filtered = filteredEvaluations;

    if (filtered.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد تقييمات ضمن هذا الفلتر.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Column(
      children: filtered.map(_buildEvaluationCard).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xffF7F7F7),
        appBar: AppBar(
          title: const Text('تقييماتي'),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: _loadMyEvaluations,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildHeader(),
              _buildFilters(),
              _buildBodyContent(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}