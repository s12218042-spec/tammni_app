import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChildHandoffLogPage extends StatefulWidget {
  final dynamic child;
  final String? childId;
  final String? childName;
  final String? createdByUid;
  final String? createdByName;
  final String? createdByRole;

  const ChildHandoffLogPage({
    super.key,
    this.child,
    this.childId,
    this.childName,
    this.createdByUid,
    this.createdByName,
    this.createdByRole,
  });

  @override
  State<ChildHandoffLogPage> createState() => _ChildHandoffLogPageState();
}

class _ChildHandoffLogPageState extends State<ChildHandoffLogPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _personNameController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _handoffType = 'delivery';
  bool _isSaving = false;
  Map<String, dynamic>? _lastLog;

  final List<String> _relationSuggestions = [
    'الأب',
    'الأم',
    'الأخ',
    'الأخت',
    'الجد',
    'الجدة',
    'العم',
    'العمة',
    'الخال',
    'الخالة',
    'السائق',
    'مفوض',
  ];

  String get _safeChildId {
    if (widget.childId != null && widget.childId!.trim().isNotEmpty) {
      return widget.childId!.trim();
    }

    final child = widget.child;

    if (child is Map<String, dynamic>) {
      return (child['id'] ??
              child['childId'] ??
              child['uid'] ??
              child['docId'] ??
              '')
          .toString();
    }

    try {
      final dynamic id = child?.id;
      if (id != null) return id.toString();
    } catch (_) {}

    try {
      final dynamic id = child?.childId;
      if (id != null) return id.toString();
    } catch (_) {}

    return '';
  }

  String get _safeChildName {
    if (widget.childName != null && widget.childName!.trim().isNotEmpty) {
      return widget.childName!.trim();
    }

    final child = widget.child;

    if (child is Map<String, dynamic>) {
      return (child['name'] ??
              child['childName'] ??
              child['fullName'] ??
              'الطفل')
          .toString();
    }

    try {
      final dynamic name = child?.name;
      if (name != null) return name.toString();
    } catch (_) {}

    try {
      final dynamic name = child?.childName;
      if (name != null) return name.toString();
    } catch (_) {}

    return 'الطفل';
  }

  @override
  void initState() {
    super.initState();
    _loadLastLog();
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _relationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _fetchParentLinkInfo() async {
    String parentUid = '';
    String parentUsername = '';

    if (_safeChildId.isEmpty) {
      return {
        'parentUid': '',
        'parentUsername': '',
      };
    }

    try {
      final childDoc = await _firestore.collection('children').doc(_safeChildId).get();

      if (childDoc.exists) {
        final data = childDoc.data() ?? <String, dynamic>{};

        parentUid = (data['parentUid'] ?? '').toString().trim();
        parentUsername =
            (data['parentUsername'] ?? '').toString().trim().toLowerCase();
      }
    } catch (_) {
      // ignore and fallback
    }

    if (parentUsername.isEmpty) {
      final child = widget.child;

      if (child is Map<String, dynamic>) {
        parentUsername =
            (child['parentUsername'] ?? '').toString().trim().toLowerCase();
      } else {
        try {
          final dynamic username = child?.parentUsername;
          if (username != null) {
            parentUsername = username.toString().trim().toLowerCase();
          }
        } catch (_) {}
      }
    }

    if (parentUid.isEmpty) {
      final child = widget.child;

      if (child is Map<String, dynamic>) {
        parentUid = (child['parentUid'] ?? '').toString().trim();
      } else {
        try {
          final dynamic uid = child?.parentUid;
          if (uid != null) {
            parentUid = uid.toString().trim();
          }
        } catch (_) {}
      }
    }

    return {
      'parentUid': parentUid,
      'parentUsername': parentUsername,
    };
  }

  Future<void> _loadLastLog() async {
    if (_safeChildId.isEmpty) return;

    try {
      final snap = await _firestore
          .collection('child_handoffs')
          .where('childId', isEqualTo: _safeChildId)
          .orderBy('time', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final last = snap.docs.first.data();
        setState(() {
          _lastLog = last;
          _handoffType =
              last['handoffType'] == 'delivery' ? 'pickup' : 'delivery';
        });
      }
    } catch (_) {}
  }

  String _handoffTypeLabel(String type) {
    switch (type) {
      case 'delivery':
        return 'تسليم للحضانة';
      case 'pickup':
        return 'استلام من الحضانة';
      default:
        return type;
    }
  }

  String _nextExpectedLabel(String? lastType) {
    if (lastType == 'delivery') return 'استلام من الحضانة';
    return 'تسليم للحضانة';
  }

  IconData _handoffTypeIcon(String type) {
    switch (type) {
      case 'delivery':
        return Icons.login_rounded;
      case 'pickup':
        return Icons.logout_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _handoffTypeColor(String type) {
    switch (type) {
      case 'delivery':
        return Colors.teal;
      case 'pickup':
        return Colors.deepOrange;
      default:
        return Colors.blue;
    }
  }

  String _formatDateTime(dynamic value) {
    DateTime? dateTime;

    if (value is Timestamp) {
      dateTime = value.toDate();
    } else if (value is DateTime) {
      dateTime = value;
    }

    if (dateTime == null) return 'غير محدد';

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();

    int hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$year/$month/$day - $hour:$minute $period';
  }

  String _currentOperationHint() {
    return _handoffType == 'delivery'
        ? 'وثّقي هنا الشخص الذي قام بتسليم الطفل للحضانة.'
        : 'وثّقي هنا الشخص الذي قام باستلام الطفل من الحضانة.';
  }

  String _personFieldLabel() {
    return _handoffType == 'delivery'
        ? 'اسم الشخص الذي سلّم الطفل'
        : 'اسم الشخص الذي استلم الطفل';
  }

  String _noteHint() {
    return _handoffType == 'delivery'
        ? 'مثال: وصل الطفل متأخرًا / برفقة السائق / الحالة جيدة'
        : 'مثال: تم الاستلام مبكرًا / استلمه الجد / ملاحظة خاصة';
  }

  Future<void> _saveHandoff() async {
    if (!_formKey.currentState!.validate()) return;

    if (_safeChildId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديد بيانات الطفل'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final lastType = _lastLog?['handoffType'];

    if (lastType == _handoffType) {
      final operation = _handoffType == 'delivery'
          ? 'لا يمكن تسجيل تسليم مرتين متتاليتين'
          : 'لا يمكن تسجيل استلام مرتين متتاليتين';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(operation),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final parentInfo = await _fetchParentLinkInfo();

      await _firestore.collection('child_handoffs').add({
        'childId': _safeChildId,
        'childName': _safeChildName,
        'parentUid': parentInfo['parentUid'],
        'parentUsername': parentInfo['parentUsername'],
        'handoffType': _handoffType,
        'personName': _personNameController.text.trim(),
        'relation': _relationController.text.trim(),
        'note': _noteController.text.trim(),
        'time': Timestamp.fromDate(now),
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': widget.createdByUid,
        'createdByName': widget.createdByName,
        'createdByRole': widget.createdByRole,
      });

      _personNameController.clear();
      _relationController.clear();
      _noteController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _handoffType == 'delivery'
                  ? 'تم تسجيل تسليم الطفل للحضانة بنجاح'
                  : 'تم تسجيل استلام الطفل من الحضانة بنجاح',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadLastLog();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ السجل: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildSectionCard({
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTypeOption(
            type: 'delivery',
            title: 'تسليم للحضانة',
            subtitle: 'الطفل دخل الحضانة',
            icon: Icons.login_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTypeOption(
            type: 'pickup',
            title: 'استلام من الحضانة',
            subtitle: 'الطفل غادر الحضانة',
            icon: Icons.logout_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _handoffType == type;
    final color = _handoffTypeColor(type);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _handoffType = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.10) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor:
                  isSelected ? color.withOpacity(0.16) : Colors.grey.shade200,
              child: Icon(
                icon,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isSelected ? color : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.blue),
          ),
        ),
      ),
    );
  }

  Widget _buildRelationSuggestions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _relationSuggestions.map((relation) {
        final isSelected = _relationController.text.trim() == relation;

        return ChoiceChip(
          label: Text(relation),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              _relationController.text = relation;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildStatusCard() {
    final lastType = _lastLog?['handoffType'];
    final lastPerson = (_lastLog?['personName'] ?? '').toString();
    final lastRelation = (_lastLog?['relation'] ?? '').toString();
    final lastTime = _lastLog?['time'] ?? _lastLog?['createdAt'];

    final statusText = lastType == 'delivery'
        ? 'الطفل داخل الحضانة حاليًا'
        : lastType == 'pickup'
            ? 'الطفل تم استلامه من الحضانة'
            : 'لا يوجد سجل سابق لهذا الطفل';

    final nextExpected = _nextExpectedLabel(lastType);
    final statusColor = lastType == 'delivery'
        ? Colors.teal
        : lastType == 'pickup'
            ? Colors.deepOrange
            : Colors.blueGrey;

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: statusColor.withOpacity(0.12),
                child: Icon(
                  lastType == null
                      ? Icons.info_outline_rounded
                      : _handoffTypeIcon(lastType),
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'حالة الطفل الحالية',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                icon: Icons.history_rounded,
                label: lastType == null
                    ? 'لا توجد عملية سابقة'
                    : 'آخر عملية: ${_handoffTypeLabel(lastType)}',
                color: statusColor,
              ),
              _buildInfoChip(
                icon: Icons.arrow_forward_rounded,
                label: 'المتوقّع التالي: $nextExpected',
                color: Colors.indigo,
              ),
            ],
          ),
          if (lastType != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفاصيل آخر سجل',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'الشخص: ${lastPerson.isEmpty ? 'غير محدد' : lastPerson}',
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'صلة القرابة: ${lastRelation.isEmpty ? 'غير محدد' : lastRelation}',
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الوقت: ${_formatDateTime(lastTime)}',
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTodayLogs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final now = DateTime.now();

    final todayLogs = docs.where((doc) {
      final data = doc.data();
      final dynamic timeValue = data['time'] ?? data['createdAt'];
      DateTime? date;

      if (timeValue is Timestamp) {
        date = timeValue.toDate();
      }

      if (date == null) return false;

      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.today_rounded),
              SizedBox(width: 8),
              Text(
                'سجل اليوم',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (todayLogs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'لا يوجد سجل تسليم/استلام اليوم بعد.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            )
          else
            ...todayLogs.take(4).map((doc) {
              final data = doc.data();
              final type = (data['handoffType'] ?? '').toString();
              final person = (data['personName'] ?? '').toString();
              final relation = (data['relation'] ?? '').toString();
              final note = (data['note'] ?? '').toString();
              final time = data['time'] ?? data['createdAt'];
              final color = _handoffTypeColor(type);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.20)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color.withOpacity(0.15),
                      child: Icon(_handoffTypeIcon(type), color: color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _handoffTypeLabel(type),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  _formatDateTime(time),
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'الشخص: ${person.isEmpty ? 'غير محدد' : person}',
                            style: const TextStyle(fontSize: 13.5),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'القرابة: ${relation.isEmpty ? 'غير محدد' : relation}',
                            style: const TextStyle(fontSize: 13.5),
                          ),
                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'ملاحظة: $note',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSavePreview() {
    final previewColor = _handoffTypeColor(_handoffType);

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.visibility_outlined),
              SizedBox(width: 8),
              Text(
                'معاينة قبل الحفظ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: previewColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: previewColor.withOpacity(0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _handoffTypeLabel(_handoffType),
                  style: TextStyle(
                    color: previewColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'الطفل: $_safeChildName',
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'الشخص: ${_personNameController.text.trim().isEmpty ? '—' : _personNameController.text.trim()}',
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'صلة القرابة: ${_relationController.text.trim().isEmpty ? '—' : _relationController.text.trim()}',
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'الملاحظة: ${_noteController.text.trim().isEmpty ? '—' : _noteController.text.trim()}',
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'الوقت المتوقع للتسجيل: ${_formatDateTime(DateTime.now())}',
                  style: const TextStyle(fontSize: 13.5),
                ),
                if ((_lastLog?['handoffType'] ?? '') == _handoffType) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'تنبيه: هذه العملية مطابقة لآخر سجل، ولن يتم السماح بحفظها.',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsStream = _safeChildId.isEmpty
        ? null
        : _firestore
            .collection('child_handoffs')
            .where('childId', isEqualTo: _safeChildId)
            .orderBy('time', descending: true)
            .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.blue,
        title: const Text(
          'تسليم واستلام الطفل',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: logsStream == null
          ? const Center(
              child: Text('تعذر تحميل بيانات الطفل'),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: logsStream,
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (docs.isNotEmpty && _lastLog == null) {
                  _lastLog = docs.first.data();
                }

                return SafeArea(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSectionCard(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.blue.withOpacity(0.12),
                                child: const Icon(
                                  Icons.child_care_rounded,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'سجل تسليم واستلام $_safeChildName',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'استخدمي هذه الصفحة لتوثيق من قام بتسليم الطفل أو استلامه مع وقت العملية وملاحظات إضافية.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusCard(),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.touch_app_rounded),
                                  SizedBox(width: 8),
                                  Text(
                                    'اختيار العملية',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTypeSelector(),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border:
                                      Border.all(color: Colors.blue.shade100),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentOperationHint(),
                                      style: TextStyle(
                                        color: Colors.blue.shade900,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'العملية المتوقعة حسب آخر سجل: ${_nextExpectedLabel(_lastLog?['handoffType'])}',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.edit_note_rounded),
                                  SizedBox(width: 8),
                                  Text(
                                    'تفاصيل العملية',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _personNameController,
                                label: _personFieldLabel(),
                                hint: _handoffType == 'delivery'
                                    ? 'مثال: الأم / الأب / السائق'
                                    : 'مثال: الأب / الجدة / الشخص المفوض',
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'يرجى إدخال اسم الشخص';
                                  }
                                  return null;
                                },
                                suffixIcon:
                                    const Icon(Icons.person_outline_rounded),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'صلة القرابة أو صفة الشخص',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildRelationSuggestions(),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _relationController,
                                label: 'صلة القرابة / الصفة',
                                hint: 'مثال: الأم، الجد، السائق، مفوض',
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'يرجى إدخال صلة القرابة أو الصفة';
                                  }
                                  return null;
                                },
                                suffixIcon:
                                    const Icon(Icons.family_restroom_rounded),
                              ),
                              if (_relationController.text.trim().isNotEmpty &&
                                  ![
                                    'الأب',
                                    'الأم',
                                    'الأخ',
                                    'الأخت',
                                    'الجد',
                                    'الجدة'
                                  ].contains(_relationController.text.trim())) ...[
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: Colors.orange.shade100),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          color: Colors.orange.shade800),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'يرجى التأكد من أن هذا الشخص مفوض لاستلام الطفل أو تسليمه.',
                                          style: TextStyle(
                                            color: Colors.orange.shade900,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              _buildTextField(
                                controller: _noteController,
                                label: 'ملاحظة',
                                hint: _noteHint(),
                                maxLines: 3,
                                suffixIcon: const Icon(Icons.notes_rounded),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${_noteController.text.length} / 250',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildSavePreview(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveHandoff,
                            icon: _isSaving
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
                              _isSaving
                                  ? 'جاري الحفظ...'
                                  : _handoffType == 'delivery'
                                      ? 'حفظ تسليم الطفل'
                                      : 'حفظ استلام الطفل',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: _handoffTypeColor(_handoffType),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildTodayLogs(docs),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}