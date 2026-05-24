import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'live_stream_viewer_page.dart';
import 'welcome_page.dart';

class TemporaryChildViewPage extends StatefulWidget {
  final String accessCodeId;
  final Map<String, dynamic> accessData;
  final String childId;
  final Map<String, dynamic> childData;

  const TemporaryChildViewPage({
    super.key,
    required this.accessCodeId,
    required this.accessData,
    required this.childId,
    required this.childData,
  });

  @override
  State<TemporaryChildViewPage> createState() => _TemporaryChildViewPageState();
}

class _TemporaryChildViewPageState extends State<TemporaryChildViewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final TextEditingController messageCtrl = TextEditingController();
  
  int selectedIndex = 0;
  String selectedMessageTarget = 'admin';
  bool isSendingMessage = false;

  @override
  void dispose() {
    messageCtrl.dispose();
    super.dispose();
  }

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(dynamic value) {
    final date = _dateFromDynamic(value);
    if (date == null) return '-';

    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }

  String _formatTime(dynamic value) {
    final date = _dateFromDynamic(value);
    if (date == null) return '--:--';

    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');

    return '$h:$m';
  }

  String _money(dynamic value) {
    final amount = _toNum(value);
    final isWhole = amount == amount.truncateToDouble();
    return '${amount.toStringAsFixed(isWhole ? 0 : 2)} شيكل';
  }

  String _childName() {
    final childName = _cleanText(widget.childData['childName']);
    final name = _cleanText(widget.childData['name']);

    if (childName.isNotEmpty) return childName;
    if (name.isNotEmpty) return name;

    return _isTrialChild ? 'طفل تجربة' : 'طفل مؤقت';
  }

  String _parentName() {
    final childParentName = _cleanText(widget.childData['parentName']);
    final accessParentName = _cleanText(widget.accessData['parentName']);

    if (childParentName.isNotEmpty) return childParentName;
    if (accessParentName.isNotEmpty) return accessParentName;

    return '-';
  }

  String _parentPhone() {
    final childPhone = _cleanText(widget.childData['parentPhone']);
    final accessPhone = _cleanText(widget.accessData['parentPhone']);

    if (childPhone.isNotEmpty) return childPhone;
    if (accessPhone.isNotEmpty) return accessPhone;

    return '-';
  }

  String _groupName() {
    final childGroupName = _cleanText(widget.childData['groupName']);
    final accessGroupName = _cleanText(widget.accessData['groupName']);

    if (childGroupName.isNotEmpty) return childGroupName;
    if (accessGroupName.isNotEmpty) return accessGroupName;

    return '-';
  }

  String _staffUid() {
    return _cleanText(widget.childData['assignedStaffUid']);
  }

  String _staffName() {
    final name = _cleanText(widget.childData['assignedStaffName']);
    return name.isEmpty ? 'موظفة الحضانة' : name;
  }

  String _consultationText() {
    final hasConsultation = widget.childData['hasConsultation'] == true;
    if (!hasConsultation) return 'لا';

    final status = _cleanText(widget.childData['consultationStatus']);

    switch (status) {
      case 'pending':
        return 'قيد المتابعة';
      case 'approved':
        return 'مقبولة';
      case 'rejected':
        return 'مرفوضة';
      case 'completed':
        return 'مكتملة';
      default:
        return 'نعم';
    }
  }

  bool get _isTrialChild {
    final childType = _cleanText(widget.childData['childType']).toLowerCase();
    final enrollmentType =
        _cleanText(widget.childData['enrollmentType']).toLowerCase();
    final childStatus =
        _cleanText(widget.childData['childStatus']).toLowerCase();

    return widget.childData['isTrialChild'] == true ||
        childType == 'trial' ||
        enrollmentType == 'trial' ||
        childStatus == 'trial';
  }

  bool get _isTemporaryChild {
    final childType = _cleanText(widget.childData['childType']).toLowerCase();
    final enrollmentType =
        _cleanText(widget.childData['enrollmentType']).toLowerCase();
    final childStatus =
        _cleanText(widget.childData['childStatus']).toLowerCase();

    return widget.childData['isTemporaryChild'] == true ||
        childType == 'temporary' ||
        enrollmentType == 'temporary' ||
        childStatus == 'temporary';
  }

  String get _childTypeLabel {
    if (_isTrialChild) return 'طفل تجربة';
    if (_isTemporaryChild) return 'طفل مؤقت';
    return 'طفل';
  }

  dynamic get _accessStart {
    return widget.childData['temporaryAccessStartAt'] ??
        widget.childData['temporaryStartAt'] ??
        widget.childData['temporaryStartDate'] ??
        widget.childData['trialStartAt'] ??
        widget.accessData['accessStartAt'];
  }

  dynamic get _accessEnd {
    return widget.childData['temporaryAccessEndAt'] ??
        widget.childData['temporaryEndAt'] ??
        widget.childData['temporaryEndDate'] ??
        widget.childData['trialEndAt'] ??
        widget.accessData['accessEndAt'];
  }

  String get _accessCode {
    final code = _cleanText(widget.accessData['code']);
    if (code.isNotEmpty) return code;

    final childCode = _cleanText(widget.childData['temporaryAccessCode']);
    return childCode.isEmpty ? '-' : childCode;
  }

  String get _pageTitle {
    switch (selectedIndex) {
      case 0:
        return 'الرئيسية';
      case 1:
        return 'المتابعة';
      case 2:
        return 'الرسائل';
      case 3:
        return 'الإعدادات';
      default:
        return 'الرئيسية';
    }
  }

  Future<void> _refreshPage() async {
    if (!mounted) return;
    setState(() {});
  }

 Future<void> _logout() async {
  try {
    final currentUser = _auth.currentUser;
    final token = await _messaging.getToken();

    if (currentUser != null && currentUser.isAnonymous) {
      final query = await _firestore
          .collection('temporary_parent_devices')
          .where('authUid', isEqualTo: currentUser.uid)
          .where('childId', isEqualTo: widget.childId)
          .get();

      final batch = _firestore.batch();

      for (final doc in query.docs) {
        final data = doc.data();
        final savedToken = _cleanText(data['fcmToken']);

        if (token == null || token.trim().isEmpty || savedToken == token) {
          batch.set(
            doc.reference,
            {
              'isActive': false,
              'accountStatus': 'logged_out',
              'loggedOutAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      await batch.commit();
      await _auth.signOut();
    }
  } catch (e) {
    debugPrint('TEMP LOGOUT ERROR: $e');
  }

  if (!mounted) return;

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const WelcomePage()),
    (route) => false,
  );
}

  Widget _sectionTitle({
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.10),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(height: 1.4),
        ),
      ),
    );
  }

  Widget _buildChildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: Colors.white.withOpacity(0.22),
            child: Text(
              _childName().trim().isEmpty ? 'ط' : _childName().trim()[0],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _childName(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 21,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _childTypeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    if (_isTrialChild)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'مجاني',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final notes = _cleanText(widget.childData['temporaryNotes']);

    return RefreshIndicator(
      onRefresh: _refreshPage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildChildHeader(),
          const SizedBox(height: 16),
          _buildLiveStreamCard(),
          const SizedBox(height: 16),
          _sectionTitle(
            title: 'بيانات الطفل',
            icon: Icons.child_care_rounded,
          ),
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.groups_2_outlined,
            title: 'المجموعة',
            value: _groupName(),
          ),
          _infoCard(
            icon: Icons.badge_outlined,
            title: 'الموظفة',
            value: _staffName(),
          ),
          _infoCard(
            icon: Icons.event_outlined,
            title: _isTrialChild ? 'بداية التجربة' : 'بداية الوصول',
            value: _formatDate(_accessStart),
          ),
          _infoCard(
            icon: Icons.event_available_outlined,
            title: _isTrialChild ? 'نهاية التجربة' : 'نهاية الوصول',
            value: _formatDate(_accessEnd),
          ),
          if (_isTrialChild)
            _infoCard(
              icon: Icons.volunteer_activism_outlined,
              title: 'الفاتورة',
              value:
                  'طفل التجربة مجاني لمدة 3 أيام ولا يدخل ضمن الاشتراك الشهري.',
            ),
          _infoCard(
            icon: Icons.psychology_alt_outlined,
            title: 'الاستشارة',
            value: _consultationText(),
          ),
          if (notes.isNotEmpty)
            _infoCard(
              icon: Icons.note_alt_outlined,
              title: 'ملاحظات',
              value: notes,
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _temporaryInvoicesStream() {
    return _firestore
        .collection('invoices')
        .where('childId', isEqualTo: widget.childId)
        .limit(20)
        .snapshots();
  }

  Widget _invoiceLine(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: AppColors.textLight),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _openInvoiceDetails(Map<String, dynamic> data) {
    final total = _toNum(
      data['finalAmount'] ??
          data['totalAmount'] ??
          data['amount'] ??
          data['total'],
    );
    final paid = _toNum(data['paidAmount'] ?? data['paid']);
    final remaining = _toNum(
      data['remainingAmount'] ?? data['remaining'] ?? (total - paid),
    );

    String paymentMethod = _cleanText(data['paymentMethod']).isEmpty
        ? '-'
        : _cleanText(data['paymentMethod']);

    if (paymentMethod == 'cash') paymentMethod = 'كاش';
    if (paymentMethod == 'visa' || paymentMethod == 'card') {
      paymentMethod = 'فيزا';
    }

    final status = _cleanText(data['status']).isEmpty
        ? 'غير محددة'
        : _cleanText(data['status']);

    final notes = _cleanText(data['notes']);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'تفاصيل الفاتورة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _invoiceLine('الإجمالي', _money(total)),
                _invoiceLine('المدفوع', _money(paid)),
                _invoiceLine('المتبقي', _money(remaining)),
                _invoiceLine('طريقة الدفع', paymentMethod),
                _invoiceLine('الحالة', status),
                if (notes.isNotEmpty) _invoiceLine('ملاحظات', notes),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTemporaryInvoiceCard() {
    if (_isTrialChild) {
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.teal.withOpacity(0.10),
            child: const Icon(
              Icons.volunteer_activism_outlined,
              color: Colors.teal,
            ),
          ),
          title: const Text(
            'لا توجد فاتورة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'طفل التجربة مجاني لمدة 3 أيام ولا يدخل ضمن الاشتراك الشهري إلا بعد اعتماد الإدارة.',
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _temporaryInvoicesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.10),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                ),
              ),
              title: const Text(
                'الفاتورة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('تعذر تحميل الفاتورة'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final docs = [...(snapshot.data?.docs ?? [])];

        docs.sort((a, b) {
          final aDate = _dateFromDynamic(
                a.data()['createdAt'] ??
                    a.data()['invoiceDate'] ??
                    a.data()['updatedAt'],
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0);

          final bDate = _dateFromDynamic(
                b.data()['createdAt'] ??
                    b.data()['invoiceDate'] ??
                    b.data()['updatedAt'],
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0);

          return bDate.compareTo(aDate);
        });

        if (docs.isEmpty) {
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.10),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                ),
              ),
              title: const Text(
                'الفاتورة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('لا توجد فاتورة'),
            ),
          );
        }

        final data = docs.first.data();

        final total = _toNum(
          data['finalAmount'] ??
              data['totalAmount'] ??
              data['amount'] ??
              data['total'],
        );
        final paid = _toNum(data['paidAmount'] ?? data['paid']);
        final remaining = _toNum(
          data['remainingAmount'] ?? data['remaining'] ?? (total - paid),
        );

        String paymentMethod = _cleanText(data['paymentMethod']).isEmpty
            ? '-'
            : _cleanText(data['paymentMethod']);

        if (paymentMethod == 'cash') paymentMethod = 'كاش';
        if (paymentMethod == 'visa' || paymentMethod == 'card') {
          paymentMethod = 'فيزا';
        }

        final status = _cleanText(data['status']).isEmpty
            ? 'غير محددة'
            : _cleanText(data['status']);

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openInvoiceDetails(data),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.10),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'الفاتورة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _invoiceMiniBox(
                          title: 'الإجمالي',
                          value: _money(total),
                          icon: Icons.payments_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _invoiceMiniBox(
                          title: 'المتبقي',
                          value: _money(remaining),
                          icon: Icons.pending_actions_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _invoiceMiniBox(
                          title: 'المدفوع',
                          value: _money(paid),
                          icon: Icons.done_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _invoiceMiniBox(
                          title: 'الدفع',
                          value: paymentMethod,
                          icon: Icons.credit_card_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _invoiceMiniBox({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }


  Stream<QuerySnapshot<Map<String, dynamic>>> _liveStreamStream() {
    return _firestore
        .collection('live_streams')
        .where('childId', isEqualTo: widget.childId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots();
  }

  Future<void> _openLiveStream(Map<String, dynamic> data) async {
    final roomId = _cleanText(
      data['roomId'] ?? data['id'] ?? data['streamId'],
    );

    if (roomId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات البث غير متاحة حالياً')),
      );
      return;
    }

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveStreamViewerPage(
            roomId: roomId,
            title: _cleanText(data['title']).isEmpty
                ? 'بث مباشر من الحضانة'
                : _cleanText(data['title']),
            startedByName: _cleanText(data['startedByName']).isEmpty
                ? 'الحضانة'
                : _cleanText(data['startedByName']),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final errorText = e.toString().toLowerCase();
      final message = errorText.contains('permission-denied') ||
              errorText.contains('permission_denied') ||
              errorText.contains('missing or insufficient permissions')
          ? 'البث المباشر غير متاح حالياً، يرجى المحاولة لاحقاً.'
          : 'تعذر فتح البث المباشر حالياً.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    if (!mounted) return;
    setState(() {});
  }

  Widget _buildLiveStreamCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _liveStreamStream(),
      builder: (context, snapshot) {
        final hasPermissionOrQueryError = snapshot.hasError;

        if (hasPermissionOrQueryError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.10),
                    child: const Icon(
                      Icons.videocam_off_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'البث المباشر',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'البث المباشر غير متاح حالياً، يرجى المحاولة لاحقاً.',
                          style: TextStyle(
                            color: AppColors.textLight,
                            height: 1.35,
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

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final docs = [...(snapshot.data?.docs ?? [])];
        final hasLive = docs.isNotEmpty;

        return Card(
          color: hasLive ? Colors.red.withOpacity(0.045) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: hasLive ? Colors.red.withOpacity(0.22) : Colors.transparent,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: hasLive
                      ? Colors.red.withOpacity(0.12)
                      : AppColors.primary.withOpacity(0.10),
                  child: Icon(
                    hasLive
                        ? Icons.wifi_tethering_rounded
                        : Icons.videocam_outlined,
                    color: hasLive ? Colors.red : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasLive ? 'بث مباشر الآن' : 'البث المباشر',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                          color: hasLive ? Colors.red : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasLive
                            ? 'يمكنك مشاهدة البث الآن'
                            : 'لا يوجد بث نشط الآن',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 104,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: hasLive
                        ? () {
                            final doc = docs.first;
                            _openLiveStream({
                              ...doc.data(),
                              'id': doc.id,
                            });
                          }
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('لا يوجد بث مباشر نشط الآن'),
                              ),
                            );
                          },
                    icon: Icon(
                      hasLive
                          ? Icons.play_arrow_rounded
                          : Icons.videocam_off_outlined,
                      size: 17,
                    ),
                    label: Text(hasLive ? 'فتح' : 'غير متاح'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _updatesStream() {
    return _firestore
        .collection('updates')
        .where('childId', isEqualTo: widget.childId)
        .limit(80)
        .snapshots();
  }

  dynamic _updateDate(Map<String, dynamic> data) {
    return data['eventAt'] ??
        data['time'] ??
        data['createdAt'] ??
        data['timestamp'] ??
        data['updatedAt'];
  }

  String _updateType(Map<String, dynamic> data) {
    final candidates = [
      data['type'],
      data['category'],
      data['updateType'],
      data['careType'],
      data['title'],
    ];

    final value = candidates
        .map(_cleanText)
        .where((e) => e.isNotEmpty)
        .join(' ')
        .toLowerCase();

    if (value.contains('meal') ||
        value.contains('food') ||
        value.contains('drink') ||
        value.contains('water') ||
        value.contains('وجبة') ||
        value.contains('اكل') ||
        value.contains('أكل') ||
        value.contains('شرب')) {
      return 'meal';
    }

    if (value.contains('sleep') ||
        value.contains('nap') ||
        value.contains('نوم')) {
      return 'sleep';
    }

    if (value.contains('health') ||
        value.contains('medicine') ||
        value.contains('temperature') ||
        value.contains('صحة') ||
        value.contains('دواء') ||
        value.contains('حرارة')) {
      return 'health';
    }

    if (value.contains('activity') ||
        value.contains('play') ||
        value.contains('نشاط') ||
        value.contains('لعب')) {
      return 'activity';
    }

    if (value.contains('media') ||
        value.contains('photo') ||
        value.contains('video') ||
        value.contains('image') ||
        value.contains('صورة') ||
        value.contains('فيديو')) {
      return 'media';
    }

    return 'note';
  }

  String _updateTitle(Map<String, dynamic> data) {
    final title = _cleanText(data['title']);
    if (title.isNotEmpty) return title;

    switch (_updateType(data)) {
      case 'meal':
        return 'الأكل والشرب';
      case 'sleep':
        return 'النوم';
      case 'health':
        return 'الصحة';
      case 'activity':
        return 'النشاط';
      case 'media':
        return 'الصور والفيديو';
      default:
        return 'ملاحظة';
    }
  }

  String _updateNote(Map<String, dynamic> data) {
    final keys = ['note', 'description', 'body', 'message', 'details', 'text'];

    for (final key in keys) {
      final value = _cleanText(data[key]);
      if (value.isNotEmpty) return value;
    }

    return '';
  }

String _mediaUrl(Map<String, dynamic> data) {
  final candidates = [
    data['publicUrl'],
    data['mediaPublicUrl'],
    data['mediaUrl'],
    data['imageUrl'],
    data['videoUrl'],
    data['signedUrl'],
    data['url'],
  ];

  for (final value in candidates) {
    final url = _cleanText(value);
    if (url.isNotEmpty) return url;
  }

  final media = data['media'];
  if (media is Map) {
    final url = _cleanText(
      media['publicUrl'] ??
          media['mediaPublicUrl'] ??
          media['url'] ??
          media['mediaUrl'] ??
          media['signedUrl'],
    );
    if (url.isNotEmpty) return url;
  }

  return '';
}

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'meal':
        return Icons.restaurant_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      case 'health':
        return Icons.health_and_safety_rounded;
      case 'activity':
        return Icons.toys_rounded;
      case 'media':
        return Icons.photo_library_outlined;
      default:
        return Icons.note_alt_outlined;
    }
  }

  String _categoryTitle(String category) {
    switch (category) {
      case 'meal':
        return 'الأكل والشرب';
      case 'sleep':
        return 'النوم';
      case 'health':
        return 'الصحة';
      case 'activity':
        return 'النشاط';
      case 'media':
        return 'الصور والفيديو';
      default:
        return 'الملاحظات';
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = [...docs];

    sorted.sort((a, b) {
      final aDate = _dateFromDynamic(_updateDate(a.data())) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bDate = _dateFromDynamic(_updateDate(b.data())) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return sorted;
  }

  Map<String, Map<String, dynamic>> _latestByCategory(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = <String, Map<String, dynamic>>{};

    for (final doc in docs) {
      final data = doc.data();
      final category = _updateType(data);
      result.putIfAbsent(category, () => data);
    }

    return result;
  }

  Widget _buildDailyItem({
    required String category,
    required Map<String, dynamic>? data,
  }) {
    final hasData = data != null;
    final note = hasData ? _updateNote(data) : '';
    final time = hasData ? _formatTime(_updateDate(data)) : '';
    final mediaUrl = hasData ? _mediaUrl(data) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.10),
              child: Icon(
                _categoryIcon(category),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _categoryTitle(category),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hasData
                        ? (note.isEmpty ? 'تم تسجيل تحديث' : note)
                        : 'لا يوجد',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      height: 1.4,
                    ),
                  ),
                  if (mediaUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        mediaUrl,
                        height: 115,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            height: 90,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                                const Icon(Icons.image_not_supported_outlined),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (time.isNotEmpty)
              Text(
                time,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateCard(Map<String, dynamic> data) {
    final title = _updateTitle(data);
    final note = _updateNote(data);
    final date = _updateDate(data);
    final mediaUrl = _mediaUrl(data);

    final isGroupUpdate = data['isGroupUpdate'] == true ||
        _cleanText(data['groupUpdateId']).isNotEmpty ||
        _cleanText(data['type']) == 'group_update';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isGroupUpdate
                      ? Colors.purple.withOpacity(0.10)
                      : AppColors.primary.withOpacity(0.10),
                  child: Icon(
                    isGroupUpdate
                        ? Icons.groups_2_rounded
                        : _categoryIcon(_updateType(data)),
                    color: isGroupUpdate ? Colors.purple : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                    ),
                  ),
                ),
                Text(
                  _formatTime(date),
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                note,
                style: const TextStyle(height: 1.45, fontSize: 13.5),
              ),
            ],
            if (mediaUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  mediaUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      height: 110,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.image_not_supported_outlined),
                    );
                  },
                ),
              ),
            ],
            if (isGroupUpdate) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'تحديث جماعي',
                  style: TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpTab() {
    return RefreshIndicator(
      onRefresh: _refreshPage,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _updatesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = _sortedDocs(snapshot.data?.docs ?? []);
          final latestByCategory = _latestByCategory(docs);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _sectionTitle(
                title: 'بطاقة الطفل',
                icon: Icons.child_care_rounded,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: Text(
                          _childName().trim().isEmpty
                              ? 'ط'
                              : _childName().trim()[0],
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _childName(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _groupName(),
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _isTrialChild ? 'تجربة' : 'مؤقت',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildLiveStreamCard(),
              const SizedBox(height: 16),
              _sectionTitle(
                title: 'تفاصيل اليوم',
                icon: Icons.today_outlined,
              ),
              const SizedBox(height: 12),
              _buildDailyItem(
                category: 'meal',
                data: latestByCategory['meal'],
              ),
              _buildDailyItem(
                category: 'sleep',
                data: latestByCategory['sleep'],
              ),
              _buildDailyItem(
                category: 'health',
                data: latestByCategory['health'],
              ),
              _buildDailyItem(
                category: 'activity',
                data: latestByCategory['activity'],
              ),
              _buildDailyItem(
                category: 'note',
                data: latestByCategory['note'],
              ),
              _buildDailyItem(
                category: 'media',
                data: latestByCategory['media'],
              ),
              const SizedBox(height: 16),
              _sectionTitle(
                title: 'الفاتورة',
                icon: Icons.receipt_long_rounded,
              ),
              const SizedBox(height: 12),
              _buildTemporaryInvoiceCard(),
              const SizedBox(height: 16),
              _sectionTitle(
                title: 'كل التحديثات',
                icon: Icons.notifications_none_outlined,
              ),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                const _SimpleEmptyBox(
                  icon: Icons.assignment_outlined,
                  title: 'لا توجد تحديثات',
                )
              else
                ...docs.map((doc) => _buildUpdateCard(doc.data())),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  String _targetLabel(String target) {
    if (target == 'staff') return _staffName();
    return 'الإدارة';
  }

  Future<void> _sendMessage() async {
    final text = messageCtrl.text.trim();

    if (text.isEmpty || isSendingMessage) return;

    setState(() {
      isSendingMessage = true;
    });

    try {
      final targetUid =
          selectedMessageTarget == 'staff' ? _staffUid() : 'admin';

      await _firestore.collection('temporary_messages').add({
        'accessCodeId': widget.accessCodeId,
        'accessCode': _accessCode,
        'childId': widget.childId,
        'childName': _childName(),
        'parentName': _parentName(),
        'parentPhone': _parentPhone(),
        'groupId': _cleanText(widget.childData['groupId']),
        'groupName': _groupName(),
        'fromRole': 'temporary_parent',
        'fromName': _parentName(),
        'targetRole':
            selectedMessageTarget == 'staff' ? 'nursery_staff' : 'admin',
        'targetUid': targetUid,
        'targetName': _targetLabel(selectedMessageTarget),
        'message': text,
        'isRead': false,
        'isDelivered': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      messageCtrl.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الرسالة')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الرسالة')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSendingMessage = false;
        });
      }
    }
  }

  Widget _buildMessagesTab() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary,
                ),
              ),
              title: const Text(
                'إرسال رسالة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                selectedMessageTarget == 'staff' ? _staffName() : 'الإدارة',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('الإدارة')),
                  selected: selectedMessageTarget == 'admin',
                  onSelected: (_) {
                    setState(() {
                      selectedMessageTarget = 'admin';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('الموظفة')),
                  selected: selectedMessageTarget == 'staff',
                  onSelected: (_) {
                    setState(() {
                      selectedMessageTarget = 'staff';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اكتبي رسالتك',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: messageCtrl,
                    minLines: 4,
                    maxLines: 6,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: 'اكتبي رسالة',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isSendingMessage ? null : _sendMessage,
                      icon: isSendingMessage
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        isSendingMessage ? 'جاري الإرسال...' : 'إرسال',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return RefreshIndicator(
      onRefresh: _refreshPage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.10),
                child: Text(
                  _parentName().trim().isEmpty || _parentName() == '-'
                      ? 'و'
                      : _parentName().trim()[0],
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
              title: Text(
                _parentName(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle:
                  Text(_isTrialChild ? 'ولي أمر طفل تجربة' : 'ولي أمر مؤقت'),
            ),
          ),
          const SizedBox(height: 16),
          _infoCard(
            icon: Icons.phone_outlined,
            title: 'رقم الهاتف',
            value: _parentPhone(),
          ),
          _infoCard(
            icon: Icons.key_rounded,
            title: 'كود الدخول',
            value: _accessCode,
          ),
          _infoCard(
            icon: Icons.event_available_outlined,
            title: _isTrialChild ? 'نهاية التجربة' : 'نهاية الوصول',
            value: _formatDate(_accessEnd),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('خروج'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withOpacity(0.35)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _currentTab() {
    switch (selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildFollowUpTab();
      case 2:
        return _buildMessagesTab();
      case 3:
        return _buildSettingsTab();
      default:
        return _buildHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = selectedIndex == 2
        ? Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _currentTab(),
          )
        : _currentTab();

    return Scaffold(
      body: AppPageScaffold(
        title: _pageTitle,
        actions: selectedIndex == 1
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'تحديث',
                  onPressed: _refreshPage,
                ),
              ]
            : null,
        child: content,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'المتابعة',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'الرسائل',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}

class _SimpleEmptyBox extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SimpleEmptyBox({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withOpacity(0.10),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}