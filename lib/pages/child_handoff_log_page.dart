import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _personNameController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _logSearchController = TextEditingController();

  String _handoffType = 'delivery';
  bool _isSaving = false;
  bool _isUpdatingLast = false;

  String? _lastLogId;
  Map<String, dynamic>? _lastLog;

  String _logSearchText = '';
  final Set<String> _selectedLogTypes = {};

  String _selectedRelationOption = '';

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
    'أخرى',
  ];

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
    _logSearchController.dispose();
    super.dispose();
  }

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
          .toString()
          .trim();
    }

    try {
      final dynamic id = child?.id;
      if (id != null) return id.toString().trim();
    } catch (_) {}

    try {
      final dynamic id = child?.childId;
      if (id != null) return id.toString().trim();
    } catch (_) {}

    return '';
  }

  String get _safeChildName {
    if (widget.childName != null && widget.childName!.trim().isNotEmpty) {
      return widget.childName!.trim();
    }

    final child = widget.child;

    if (child is Map<String, dynamic>) {
      return (child['name'] ?? child['childName'] ?? child['fullName'] ?? 'الطفل')
          .toString()
          .trim();
    }

    try {
      final dynamic name = child?.name;
      if (name != null) return name.toString().trim();
    } catch (_) {}

    try {
      final dynamic name = child?.childName;
      if (name != null) return name.toString().trim();
    } catch (_) {}

    return 'الطفل';
  }

  String get _safeChildSection {
    final child = widget.child;

    if (child is Map<String, dynamic>) {
      final section = (child['section'] ?? '').toString().trim();
      return section.isEmpty ? 'Nursery' : section;
    }

    try {
      final dynamic section = child?.section;
      if (section != null && section.toString().trim().isNotEmpty) {
        return section.toString().trim();
      }
    } catch (_) {}

    return 'Nursery';
  }

  String get _safeChildGroup {
    final child = widget.child;

    if (child is Map<String, dynamic>) {
      return (child['group'] ?? '').toString().trim();
    }

    try {
      final dynamic group = child?.group;
      if (group != null) return group.toString().trim();
    } catch (_) {}

    return '';
  }

  bool get _isOtherRelationSelected => _selectedRelationOption == 'أخرى';

  bool get _lastLogIsSameType {
    final lastType = (_lastLog?['handoffType'] ?? '').toString().trim();
    return _lastLogId != null && lastType == _handoffType;
  }

  String _normalizeRole(String value) {
    final role = value.trim().toLowerCase();

    if (role == 'nursery' || role == 'nursery staff') {
      return 'nursery_staff';
    }

    if (role == 'admin') return 'admin';
    if (role == 'parent') return 'parent';
    if (role == 'nursery_staff') return 'nursery_staff';

    return role.isEmpty ? 'nursery_staff' : role;
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  DateTime? _logDate(Map<String, dynamic> data) {
    return _dateFromDynamic(data['time']) ??
        _dateFromDynamic(data['eventAt']) ??
        _dateFromDynamic(data['createdAt']) ??
        _dateFromDynamic(data['updatedAt']);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _showSnack(
    String message, {
    Color backgroundColor = Colors.redAccent,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<Map<String, String>> _fetchCurrentUserInfo() async {
    final currentUser = _auth.currentUser;

    String uid = widget.createdByUid?.trim() ?? '';
    String name = widget.createdByName?.trim() ?? '';
    String role = _normalizeRole(widget.createdByRole ?? '');

    if (currentUser != null) {
      uid = uid.isNotEmpty ? uid : currentUser.uid;

      try {
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();

        final data = userDoc.data() ?? <String, dynamic>{};

        name = name.isNotEmpty
            ? name
            : (data['displayName'] ??
                    data['name'] ??
                    data['fullName'] ??
                    data['username'] ??
                    currentUser.displayName ??
                    'مستخدم')
                .toString()
                .trim();

        role = _normalizeRole(
          role.isNotEmpty ? role : (data['role'] ?? 'nursery_staff').toString(),
        );
      } catch (_) {
        name = name.isNotEmpty
            ? name
            : currentUser.displayName?.trim().isNotEmpty == true
                ? currentUser.displayName!.trim()
                : 'مستخدم';

        role = _normalizeRole(role);
      }
    }

    return {
      'uid': uid,
      'name': name.isEmpty ? 'مستخدم' : name,
      'role': _normalizeRole(role),
    };
  }

  Future<Map<String, String>> _fetchParentLinkInfo() async {
    String parentUid = '';
    String parentUsername = '';
    String parentName = '';

    if (_safeChildId.isNotEmpty) {
      try {
        final childDoc =
            await _firestore.collection('children').doc(_safeChildId).get();

        if (childDoc.exists) {
          final data = childDoc.data() ?? <String, dynamic>{};

          parentUid = (data['parentUid'] ?? '').toString().trim();
          parentUsername =
              (data['parentUsername'] ?? '').toString().trim().toLowerCase();
          parentName = (data['parentName'] ?? '').toString().trim();
        }
      } catch (_) {}
    }

    final child = widget.child;

    if (child is Map<String, dynamic>) {
      if (parentUid.isEmpty) {
        parentUid = (child['parentUid'] ?? '').toString().trim();
      }

      if (parentUsername.isEmpty) {
        parentUsername =
            (child['parentUsername'] ?? '').toString().trim().toLowerCase();
      }

      if (parentName.isEmpty) {
        parentName = (child['parentName'] ?? '').toString().trim();
      }
    } else {
      if (parentUid.isEmpty) {
        try {
          final dynamic uid = child?.parentUid;
          if (uid != null) parentUid = uid.toString().trim();
        } catch (_) {}
      }

      if (parentUsername.isEmpty) {
        try {
          final dynamic username = child?.parentUsername;
          if (username != null) {
            parentUsername = username.toString().trim().toLowerCase();
          }
        } catch (_) {}
      }

      if (parentName.isEmpty) {
        try {
          final dynamic name = child?.parentName;
          if (name != null) parentName = name.toString().trim();
        } catch (_) {}
      }
    }

    return {
      'parentUid': parentUid,
      'parentUsername': parentUsername,
      'parentName': parentName,
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

      if (snap.docs.isNotEmpty && mounted) {
        final doc = snap.docs.first;
        final last = doc.data();

        setState(() {
          _lastLogId = doc.id;
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
    final dateTime = _dateFromDynamic(value);

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

  String _buildNotificationTitle({bool isUpdate = false}) {
    if (isUpdate) {
      return _handoffType == 'delivery'
          ? 'تم تعديل سجل تسليم الطفل للحضانة'
          : 'تم تعديل سجل استلام الطفل من الحضانة';
    }

    return _handoffType == 'delivery'
        ? 'تم تسجيل تسليم الطفل للحضانة'
        : 'تم تسجيل استلام الطفل من الحضانة';
  }

  String _buildNotificationBody() {
    final person = _personNameController.text.trim();
    final relation = _relationController.text.trim();
    final note = _noteController.text.trim();

    final action = _handoffType == 'delivery'
        ? 'تم تسجيل تسليم $_safeChildName للحضانة'
        : 'تم تسجيل استلام $_safeChildName من الحضانة';

    final parts = <String>[
      action,
      if (person.isNotEmpty) 'الشخص: $person',
      if (relation.isNotEmpty) 'الصفة/القرابة: $relation',
      if (note.isNotEmpty) 'ملاحظة: $note',
    ];

    return parts.join(' - ');
  }

  bool _validateInputs() {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return false;

    if (_safeChildId.isEmpty) {
      _showSnack('تعذر تحديد بيانات الطفل');
      return false;
    }

    final personName = _personNameController.text.trim();
    final relation = _relationController.text.trim();

    if (personName.isEmpty) {
      _showSnack('يرجى إدخال اسم الشخص');
      return false;
    }

    if (personName.length < 2) {
      _showSnack('اسم الشخص قصير جدًا');
      return false;
    }

    if (relation.isEmpty) {
      _showSnack('يرجى اختيار أو إدخال صلة القرابة / الصفة');
      return false;
    }

    if (relation.length < 2) {
      _showSnack('صلة القرابة أو الصفة قصيرة جدًا');
      return false;
    }

    return true;
  }

  Map<String, dynamic> _buildHandoffData({
    required Timestamp now,
    required Map<String, String> parentInfo,
    required Map<String, String> userInfo,
  }) {
    final parentUid = (parentInfo['parentUid'] ?? '').trim();
    final parentUsername = (parentInfo['parentUsername'] ?? '').trim().toLowerCase();
    final parentName = (parentInfo['parentName'] ?? '').trim();

    final personName = _personNameController.text.trim();
    final relation = _relationController.text.trim();
    final note = _noteController.text.trim();
    final message = _buildNotificationBody();

    return {
      'childId': _safeChildId,
      'childName': _safeChildName,
      'parentUid': parentUid,
      'parentUsername': parentUsername,
      'parentName': parentName,
      'section': _safeChildSection,
      'group': _safeChildGroup,
      'handoffType': _handoffType,
      'handoffTypeLabel': _handoffTypeLabel(_handoffType),
      'personName': personName,
      'relation': relation,
      'note': note,
      'message': message,
      'description': message,
      'time': now,
      'eventAt': now,
      'updatedAt': now,
      'createdByUid': userInfo['uid'],
      'createdByName': userInfo['name'],
      'createdByRole': userInfo['role'],
      'byRole': userInfo['role'],
    };
  }

  Map<String, dynamic> _buildNotificationData({
    required Timestamp now,
    required Map<String, String> parentInfo,
    required Map<String, String> userInfo,
    required String handoffId,
    required bool isUpdate,
  }) {
    final parentUid = (parentInfo['parentUid'] ?? '').trim();
    final parentUsername = (parentInfo['parentUsername'] ?? '').trim().toLowerCase();
    final parentName = (parentInfo['parentName'] ?? '').trim();

    final personName = _personNameController.text.trim();
    final relation = _relationController.text.trim();
    final message = _buildNotificationBody();

    return {
      'uid': parentUid,
      'targetUid': parentUid,
      'targetRole': 'parent',
      'receiverUid': parentUid,
      'receiverRole': 'parent',
      'parentUid': parentUid,
      'parentUsername': parentUsername,
      'parentName': parentName,
      'childId': _safeChildId,
      'childName': _safeChildName,
      'section': _safeChildSection,
      'group': _safeChildGroup,
      'title': _buildNotificationTitle(isUpdate: isUpdate),
      'body': message,
      'message': message,
      'description': message,
      'type': isUpdate ? 'child_handoff_updated' : 'child_handoff',
      'notificationType': isUpdate ? 'child_handoff_updated' : 'child_handoff',
      'category': 'child_handoff',
      'templateType': _handoffType,
      'handoffId': handoffId,
      'handoffType': _handoffType,
      'handoffTypeLabel': _handoffTypeLabel(_handoffType),
      'personName': personName,
      'relation': relation,
      'priority': 'normal',
      'importance': 'normal',
      'isRead': false,
      'read': false,
      'seen': false,
      'createdAt': now,
      'time': now,
      'eventAt': now,
      'updatedAt': now,
      'createdByUid': userInfo['uid'],
      'createdByName': userInfo['name'],
      'createdByRole': userInfo['role'],
      'byRole': userInfo['role'],
      'senderUid': userInfo['uid'],
      'senderName': userInfo['name'],
      'senderRole': userInfo['role'],
    };
  }

  Future<void> _saveHandoff() async {
    if (!_validateInputs()) return;

    final lastType = (_lastLog?['handoffType'] ?? '').toString().trim();

    if (lastType == _handoffType) {
      _showSnack(
        _handoffType == 'delivery'
            ? 'لا يمكن تسجيل تسليم مرتين متتاليتين. إذا كان السجل السابق خاطئًا استخدمي زر تعديل آخر سجل.'
            : 'لا يمكن تسجيل استلام مرتين متتاليتين. إذا كان السجل السابق خاطئًا استخدمي زر تعديل آخر سجل.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = Timestamp.now();
      final parentInfo = await _fetchParentLinkInfo();
      final userInfo = await _fetchCurrentUserInfo();

      final handoffRef = _firestore.collection('child_handoffs').doc();
      final notificationRef = _firestore.collection('notifications').doc();

      final handoffData = _buildHandoffData(
        now: now,
        parentInfo: parentInfo,
        userInfo: userInfo,
      );

      final notificationData = _buildNotificationData(
        now: now,
        parentInfo: parentInfo,
        userInfo: userInfo,
        handoffId: handoffRef.id,
        isUpdate: false,
      );

      final batch = _firestore.batch();

      batch.set(handoffRef, {
        ...handoffData,
        'createdAt': now,
      });

      batch.set(notificationRef, notificationData);

      await batch.commit();

      _clearFormAfterSave();

      _showSnack(
        _handoffType == 'delivery'
            ? 'تم تسجيل تسليم الطفل للحضانة وإشعار ولي الأمر'
            : 'تم تسجيل استلام الطفل من الحضانة وإشعار ولي الأمر',
        backgroundColor: Colors.green,
      );

      await _loadLastLog();
    } catch (e) {
      _showSnack('حدث خطأ أثناء حفظ السجل: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _updateLastHandoff() async {
    if (!_validateInputs()) return;

    if (_lastLogId == null || !_lastLogIsSameType) {
      _showSnack('لا يوجد سجل مطابق قابل للتعديل');
      return;
    }

    setState(() {
      _isUpdatingLast = true;
    });

    try {
      final now = Timestamp.now();
      final parentInfo = await _fetchParentLinkInfo();
      final userInfo = await _fetchCurrentUserInfo();

      final handoffRef = _firestore.collection('child_handoffs').doc(_lastLogId);
      final notificationRef = _firestore.collection('notifications').doc();

      final message = _buildNotificationBody();

      final batch = _firestore.batch();

      batch.update(handoffRef, {
        'personName': _personNameController.text.trim(),
        'relation': _relationController.text.trim(),
        'note': _noteController.text.trim(),
        'message': message,
        'description': message,
        'updatedAt': now,
        'correctedAt': now,
        'correctedByUid': userInfo['uid'],
        'correctedByName': userInfo['name'],
        'correctedByRole': userInfo['role'],
        'isCorrected': true,
      });

      batch.set(
        notificationRef,
        _buildNotificationData(
          now: now,
          parentInfo: parentInfo,
          userInfo: userInfo,
          handoffId: _lastLogId!,
          isUpdate: true,
        ),
      );

      await batch.commit();

      _clearFormAfterSave();

      _showSnack(
        'تم تعديل آخر سجل وإشعار ولي الأمر',
        backgroundColor: Colors.green,
      );

      await _loadLastLog();
    } catch (e) {
      _showSnack('حدث خطأ أثناء تعديل آخر سجل: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLast = false;
        });
      }
    }
  }

  void _clearFormAfterSave() {
    _personNameController.clear();
    _relationController.clear();
    _noteController.clear();
    _selectedRelationOption = '';
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
            subtitle: 'دخول الطفل',
            icon: Icons.login_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTypeOption(
            type: 'pickup',
            title: 'استلام من الحضانة',
            subtitle: 'مغادرة الطفل',
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
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: (_) => setState(() {}),
        maxLength: controller == _noteController ? 250 : null,
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
        final isOther = relation == 'أخرى';

        final isSelected = isOther
            ? _isOtherRelationSelected
            : _selectedRelationOption == relation ||
                _relationController.text.trim() == relation;

        return ChoiceChip(
          label: Text(relation),
          selected: isSelected,
          selectedColor: Colors.blue.withOpacity(0.16),
          checkmarkColor: Colors.blue,
          onSelected: (_) {
            setState(() {
              _selectedRelationOption = relation;

              if (isOther) {
                _relationController.clear();
              } else {
                _relationController.text = relation;
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildRelationField() {
    if (_isOtherRelationSelected) {
      return _buildTextField(
        controller: _relationController,
        label: 'اكتبي صلة القرابة / الصفة',
        hint: 'مثال: جارة، مرافقة، شخص آخر مفوض',
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'يرجى إدخال صلة القرابة أو الصفة';
          }

          if (value.trim().length < 2) {
            return 'القيمة قصيرة جدًا';
          }

          return null;
        },
        suffixIcon: const Icon(Icons.edit_rounded),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.family_restroom_rounded, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _relationController.text.trim().isEmpty
                  ? 'اختاري صلة القرابة أو الصفة'
                  : _relationController.text.trim(),
              style: TextStyle(
                color: _relationController.text.trim().isEmpty
                    ? Colors.grey.shade600
                    : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final lastType = (_lastLog?['handoffType'] ?? '').toString().trim();
    final lastPerson = (_lastLog?['personName'] ?? '').toString();
    final lastRelation = (_lastLog?['relation'] ?? '').toString();
    final lastTime = _lastLog == null ? null : _logDate(_lastLog!);

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
                  lastType.isEmpty
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
                label: lastType.isEmpty
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
          if (lastType.isNotEmpty) ...[
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

  void _toggleLogType(String value) {
    setState(() {
      if (_selectedLogTypes.contains(value)) {
        _selectedLogTypes.remove(value);
      } else {
        _selectedLogTypes.add(value);
      }
    });
  }

  void _clearLogFilters() {
    setState(() {
      _selectedLogTypes.clear();
      _logSearchText = '';
      _logSearchController.clear();
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterTodayLogs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final todayLogs = docs.where((doc) {
      final data = doc.data();
      final date = _logDate(data);
      if (date == null) return false;
      return _isToday(date);
    }).toList();

    return todayLogs.where((doc) {
      final data = doc.data();
      final type = (data['handoffType'] ?? '').toString().trim();
      final person = (data['personName'] ?? '').toString().toLowerCase();
      final relation = (data['relation'] ?? '').toString().toLowerCase();
      final note = (data['note'] ?? '').toString().toLowerCase();
      final childName = (data['childName'] ?? '').toString().toLowerCase();

      final matchesType =
          _selectedLogTypes.isEmpty || _selectedLogTypes.contains(type);

      final q = _logSearchText.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          person.contains(q) ||
          relation.contains(q) ||
          note.contains(q) ||
          childName.contains(q) ||
          _handoffTypeLabel(type).toLowerCase().contains(q);

      return matchesType && matchesSearch;
    }).toList();
  }

  Widget _buildLogFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : color,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color,
      checkmarkColor: Colors.white,
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.22)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildTodayLogs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final allTodayLogs = docs.where((doc) {
      final date = _logDate(doc.data());
      return date != null && _isToday(date);
    }).toList();

    final filteredLogs = _filterTodayLogs(docs);
    final hasCustomFilters =
        _logSearchText.trim().isNotEmpty || _selectedLogTypes.isNotEmpty;

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
          TextField(
            controller: _logSearchController,
            onChanged: (value) {
              setState(() {
                _logSearchText = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'ابحثي بالشخص أو القرابة أو الملاحظة',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _logSearchText.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        setState(() {
                          _logSearchText = '';
                          _logSearchController.clear();
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLogFilterChip(
                label: 'تسليم',
                selected: _selectedLogTypes.contains('delivery'),
                onTap: () => _toggleLogType('delivery'),
                color: Colors.teal,
              ),
              _buildLogFilterChip(
                label: 'استلام',
                selected: _selectedLogTypes.contains('pickup'),
                onTap: () => _toggleLogType('pickup'),
                color: Colors.deepOrange,
              ),
            ],
          ),
          if (hasCustomFilters) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearLogFilters,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('إعادة تعيين الفلاتر'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (filteredLogs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                allTodayLogs.isEmpty
                    ? 'لا يوجد سجل تسليم/استلام اليوم بعد.'
                    : 'لا توجد نتائج مطابقة للفلاتر.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            )
          else
            ...filteredLogs.take(20).map((doc) {
              final data = doc.data();
              final type = (data['handoffType'] ?? '').toString();
              final person = (data['personName'] ?? '').toString();
              final relation = (data['relation'] ?? '').toString();
              final note = (data['note'] ?? '').toString();
              final time = _logDate(data);
              final color = _handoffTypeColor(type);
              final isCorrected = data['isCorrected'] == true;

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
                      child: Icon(
                        _handoffTypeIcon(type),
                        color: color,
                        size: 18,
                      ),
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
                              if (isCorrected)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.amber.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    'معدّل',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.w700,
                                    ),
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
                            'القرابة/الصفة: ${relation.isEmpty ? 'غير محدد' : relation}',
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
                  'صلة القرابة/الصفة: ${_relationController.text.trim().isEmpty ? '—' : _relationController.text.trim()}',
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'الملاحظة: ${_noteController.text.trim().isEmpty ? '—' : _noteController.text.trim()}',
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'وقت التسجيل: ${_formatDateTime(DateTime.now())}',
                  style: const TextStyle(fontSize: 13.5),
                ),
                if (_lastLogIsSameType) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'آخر سجل من نفس نوع العملية. لا يمكن إنشاء سجل جديد مكرر، ويمكن تعديل آخر سجل إذا كانت بياناته خاطئة.',
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

  Widget _buildUpdateLastButton() {
    if (!_lastLogIsSameType) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isSaving || _isUpdatingLast ? null : _updateLastHandoff,
          icon: _isUpdatingLast
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.edit_note_rounded),
          label: Text(
            _isUpdatingLast ? 'جاري تعديل آخر سجل...' : 'تعديل آخر سجل محفوظ',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            foregroundColor: Colors.orange.shade800,
            side: BorderSide(color: Colors.orange.shade300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
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

                if (docs.isNotEmpty) {
                  final firstDoc = docs.first;
                  final firstData = firstDoc.data();

                  if (_lastLogId != firstDoc.id) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;

                      setState(() {
                        _lastLogId = firstDoc.id;
                        _lastLog = firstData;
                      });
                    });
                  }
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
                                child: Text(
                                  'سجل تسليم واستلام $_safeChildName',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
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
                              _buildInfoChip(
                                icon: Icons.arrow_forward_rounded,
                                label:
                                    'المتوقّع حسب آخر سجل: ${_nextExpectedLabel((_lastLog?['handoffType'] ?? '').toString())}',
                                color: Colors.indigo,
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

                                  if (value.trim().length < 2) {
                                    return 'اسم الشخص قصير جدًا';
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
                              _buildRelationField(),
                              _buildTextField(
                                controller: _noteController,
                                label: 'ملاحظة',
                                hint: _noteHint(),
                                maxLines: 3,
                                suffixIcon: const Icon(Icons.notes_rounded),
                              ),
                            ],
                          ),
                        ),
                        _buildSavePreview(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving || _isUpdatingLast
                                ? null
                                : _saveHandoff,
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
                        _buildUpdateLastButton(),
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