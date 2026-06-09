import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';

import '../services/live_stream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'live_stream_viewer_page.dart';
import 'parent_consultations_page.dart';
import 'temporary_parent_chat_page.dart';
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
  final LiveStreamService _liveStreamService = LiveStreamService();
  final TextEditingController chatSearchCtrl = TextEditingController();

  late Map<String, dynamic> _childData;
  late Map<String, dynamic> _accessData;
  late String _currentChildId;

  List<_TemporarySiblingOption> _availableSiblings = <_TemporarySiblingOption>[];
  bool _isLoadingSiblings = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _notificationsSubscription;

  final List<Map<String, dynamic>> _popupQueue = [];
  final Set<String> _handledPopupNotificationIds = <String>{};

  bool _receivedInitialNotificationsSnapshot = false;
  bool _isShowingNotificationPopup = false;

  int selectedIndex = 0;
  bool isRequestingLiveStream = false;

  @override
  void initState() {
    super.initState();
    _childData = Map<String, dynamic>.from(widget.childData);
    _accessData = Map<String, dynamic>.from(widget.accessData);
    _currentChildId = widget.childId;
    _listenForNewNotifications();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableSiblings();
    });
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    chatSearchCtrl.dispose();
    super.dispose();
  }

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  bool _isVisibleTemporaryParentNotification(Map<String, dynamic> data) {
    final targetRole = _cleanText(data['targetRole']).toLowerCase();
    final notificationFor =
        _cleanText(data['notificationFor']).toLowerCase();

    const blockedRoles = <String>{
      'admin',
      'nursery',
      'nursery_staff',
      'nursery staff',
      'staff',
      'employee',
    };

    return !blockedRoles.contains(targetRole) &&
        !blockedRoles.contains(notificationFor);
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
    final childName = _cleanText(_childData['childName']);
    final name = _cleanText(_childData['name']);

    if (childName.isNotEmpty) return childName;
    if (name.isNotEmpty) return name;

    return _isTrialChild ? 'طفل تجربة' : 'طفل مؤقت';
  }

  String _parentName() {
    final childParentName = _cleanText(
      _childData['parentName'] ?? _childData['temporaryParentName'],
    );
    final accessParentName = _cleanText(
      _accessData['parentName'] ?? _accessData['temporaryParentName'],
    );

    if (childParentName.isNotEmpty) return childParentName;
    if (accessParentName.isNotEmpty) return accessParentName;

    return '-';
  }

  String _parentPhone() {
    final childPhone = _cleanText(
      _childData['parentPhone'] ?? _childData['temporaryParentPhone'],
    );
    final accessPhone = _cleanText(
      _accessData['parentPhone'] ?? _accessData['temporaryParentPhone'],
    );

    if (childPhone.isNotEmpty) return childPhone;
    if (accessPhone.isNotEmpty) return accessPhone;

    return '-';
  }

  String _groupName() {
    final childGroupName = _cleanText(_childData['groupName']);
    final accessGroupName = _cleanText(_accessData['groupName']);

    if (childGroupName.isNotEmpty) return childGroupName;
    if (accessGroupName.isNotEmpty) return accessGroupName;

    return '-';
  }

  String _staffUid() {
    return _cleanText(_childData['assignedStaffUid']);
  }

  String _staffName() {
    final name = _cleanText(_childData['assignedStaffName']);
    return name.isEmpty ? 'موظف الحضانة' : name;
  }

  bool get _isTrialChild {
    final childType = _cleanText(_childData['childType']).toLowerCase();
    final enrollmentType =
        _cleanText(_childData['enrollmentType']).toLowerCase();
    final childStatus =
        _cleanText(_childData['childStatus']).toLowerCase();

    return _childData['isTrialChild'] == true ||
        childType == 'trial' ||
        enrollmentType == 'trial' ||
        childStatus == 'trial';
  }

  bool get _isTemporaryChild {
    final childType = _cleanText(_childData['childType']).toLowerCase();
    final enrollmentType =
        _cleanText(_childData['enrollmentType']).toLowerCase();
    final childStatus =
        _cleanText(_childData['childStatus']).toLowerCase();

    return _childData['isTemporaryChild'] == true ||
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
    return _childData['temporaryAccessStartAt'] ??
        _childData['temporaryStartAt'] ??
        _childData['temporaryStartDate'] ??
        _childData['trialStartAt'] ??
        _accessData['accessStartAt'];
  }

  dynamic get _accessEnd {
    return _childData['temporaryAccessEndAt'] ??
        _childData['temporaryEndAt'] ??
        _childData['temporaryEndDate'] ??
        _childData['trialEndAt'] ??
        _accessData['accessEndAt'];
  }

  String get _accessCode {
    final code = _cleanText(_accessData['code']);
    if (code.isNotEmpty) return code;

    final childCode = _cleanText(_childData['temporaryAccessCode']);
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

  List<String> _readStringList(dynamic value) {
    if (value is! Iterable) return <String>[];

    return value
        .map(_cleanText)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  bool _isBlockedTemporaryStatus(dynamic value) {
    final status = _cleanText(value).toLowerCase();

    return status == 'cancelled' ||
        status == 'disabled' ||
        status == 'expired' ||
        status == 'archived' ||
        status == 'rejected_after_trial' ||
        status == 'withdrawn' ||
        status == 'inactive' ||
        status == 'logged_out';
  }

  bool _isAvailableSibling(Map<String, dynamic> data) {
    if (data['isActive'] == false) return false;

    if (_isBlockedTemporaryStatus(data['childStatus'] ?? data['status']) ||
        _isBlockedTemporaryStatus(data['accountStatus'])) {
      return false;
    }

    final endAt = data['temporaryAccessEndAt'] ??
        data['temporaryEndAt'] ??
        data['temporaryEndDate'] ??
        data['trialEndAt'];

    final endDate = _dateFromDynamic(endAt);

    return endDate == null || endDate.isAfter(DateTime.now());
  }

  Future<void> _loadAvailableSiblings() async {
    if (_isLoadingSiblings) return;

    _isLoadingSiblings = true;

    try {
      Map<String, dynamic> latestAccessData = _accessData;

      if (widget.accessCodeId.trim().isNotEmpty) {
        final accessDoc = await _firestore
            .collection('temporary_access_codes')
            .doc(widget.accessCodeId)
            .get();

        if (accessDoc.exists) {
          latestAccessData = accessDoc.data() ?? latestAccessData;
        }
      }

      final childIds = <String>{
        ..._readStringList(latestAccessData['childIds']),
        _cleanText(latestAccessData['childId']),
        _currentChildId,
      }..removeWhere((value) => value.isEmpty);

      final siblings = <_TemporarySiblingOption>[];

      for (final childId in childIds) {
        final doc = await _firestore.collection('children').doc(childId).get();
        final data = doc.data();

        if (!doc.exists || data == null || !_isAvailableSibling(data)) {
          continue;
        }

        siblings.add(
          _TemporarySiblingOption(
            childId: doc.id,
            childData: Map<String, dynamic>.from(data),
          ),
        );
      }

      siblings.sort((a, b) => a.childName.compareTo(b.childName));

      if (!mounted) return;

      setState(() {
        _accessData = Map<String, dynamic>.from(latestAccessData);
        _availableSiblings = siblings;
      });
    } catch (e) {
      debugPrint('TEMP LOAD SIBLINGS ERROR: $e');
    } finally {
      _isLoadingSiblings = false;
    }
  }

  Future<void> _switchToSibling(_TemporarySiblingOption sibling) async {
    if (sibling.childId == _currentChildId) return;

    await _notificationsSubscription?.cancel();

    if (!mounted) return;

    setState(() {
      _currentChildId = sibling.childId;
      _childData = Map<String, dynamic>.from(sibling.childData);
      _popupQueue.clear();
      _handledPopupNotificationIds.clear();
      _receivedInitialNotificationsSnapshot = false;
      _isShowingNotificationPopup = false;
      chatSearchCtrl.clear();
    });

    _listenForNewNotifications();
    await _refreshPage();
  }

  Future<void> _openSiblingPicker() async {
    await _loadAvailableSiblings();

    if (!mounted || _availableSiblings.length <= 1) return;

    final selected = await showModalBottomSheet<_TemporarySiblingOption>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'اختيار الطفل',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._availableSiblings.map((sibling) {
                    final isSelected = sibling.childId == _currentChildId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => Navigator.pop(sheetContext, sibling),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.10),
                          child: const Icon(
                            Icons.child_care_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          sibling.childName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(sibling.childTypeLabel),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                              )
                            : const Icon(Icons.chevron_left_rounded),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await _switchToSibling(selected);
    }
  }

  Future<void> _refreshPage() async {
    try {
      final childDoc =
          await _firestore.collection('children').doc(_currentChildId).get();

      Map<String, dynamic>? accessData;

      if (widget.accessCodeId.trim().isNotEmpty) {
        final accessDoc = await _firestore
            .collection('temporary_access_codes')
            .doc(widget.accessCodeId)
            .get();

        if (accessDoc.exists) {
          accessData = accessDoc.data();
        }
      }

      if (!mounted) return;

      setState(() {
        if (childDoc.exists) {
          _childData = childDoc.data() ?? _childData;
        }

        if (accessData != null) {
          _accessData = accessData;
        }
      });

      await _loadAvailableSiblings();
    } catch (e) {
      debugPrint('TEMP CHILD VIEW REFRESH ERROR: $e');
    }
  }

  void _listenForNewNotifications() {
    _notificationsSubscription = _temporaryNotificationsStream().listen(
      (snapshot) {
        if (!_receivedInitialNotificationsSnapshot) {
          _receivedInitialNotificationsSnapshot = true;

          for (final doc in snapshot.docs) {
            _handledPopupNotificationIds.add(doc.id);
          }

          return;
        }

        for (final change in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added) continue;

          final doc = change.doc;
          final data = doc.data();

          if (data == null ||
              !_isVisibleTemporaryParentNotification(data)) {
            continue;
          }

          final isRead = data['isRead'] == true ||
              data['read'] == true ||
              data['seen'] == true;

          if (isRead || _handledPopupNotificationIds.contains(doc.id)) {
            continue;
          }

          _handledPopupNotificationIds.add(doc.id);
          _popupQueue.add({
            'id': doc.id,
            ...data,
          });
        }

        _showNextNotificationPopup();
      },
      onError: (Object error) {
        debugPrint('TEMP NOTIFICATIONS LISTENER ERROR: $error');
      },
    );
  }

  Future<void> _showNextNotificationPopup() async {
    if (!mounted || _isShowingNotificationPopup || _popupQueue.isEmpty) {
      return;
    }

    _isShowingNotificationPopup = true;

    final notification = _popupQueue.removeAt(0);
    final notificationId = _cleanText(notification['id']);

    final title = _cleanText(
      notification['title'] ?? notification['subject'] ?? 'إشعار جديد',
    );

    final body = _cleanText(
      notification['body'] ??
          notification['message'] ??
          notification['text'] ??
          notification['description'],
    );

    final openNotifications = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.isEmpty ? 'إشعار جديد' : title,
                  ),
                ),
              ],
            ),
            content: body.isEmpty ? null : Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إغلاق'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('عرض الإشعارات'),
              ),
            ],
          ),
        );
      },
    );

    if (notificationId.isNotEmpty) {
      try {
        await _markTemporaryNotificationAsRead(notificationId);
      } catch (e) {
        debugPrint('TEMP NOTIFICATION READ UPDATE ERROR: $e');
      }
    }

    _isShowingNotificationPopup = false;

    if (!mounted) return;

    if (openNotifications == true) {
      await _openTemporaryNotificationsPage();
    }

    _showNextNotificationPopup();
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'تسجيل الخروج',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'هل تريد تسجيل الخروج من الدخول المؤقت؟',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('تسجيل خروج'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    try {
      final currentUser = _auth.currentUser;
      String? token;

      if (!kIsWeb) {
        try {
          token = await _messaging.getToken();
        } catch (e) {
          debugPrint('TEMP LOGOUT FCM token skipped: $e');
        }
      }

      if (currentUser != null && currentUser.isAnonymous) {
        final query = await _firestore
            .collection('temporary_parent_devices')
            .where('authUid', isEqualTo: currentUser.uid)
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
      }

      await _auth.signOut();
    } catch (e) {
      debugPrint('TEMP LOGOUT ERROR: $e');
      try {
        await _auth.signOut();
      } catch (signOutError) {
        debugPrint('TEMP LOGOUT signOut fallback failed: $signOutError');
      }
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
          backgroundColor: AppColors.primary.withValues(alpha: 0.10),
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

  Future<void> _openConsultationsPage() async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ParentConsultationsPage(
        childId: _currentChildId,
        isTemporaryParent: true,
      ),
    ),
  );

  if (!mounted) return;

  setState(() {});
}

Widget _buildConsultationsCard() {
  return Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: _openConsultationsPage,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.10),
        child: const Icon(
          Icons.psychology_alt_outlined,
          color: AppColors.primary,
        ),
      ),
      title: const Text(
        'الاستشارات',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_left_rounded,
        color: AppColors.textLight,
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
            backgroundColor: Colors.white.withValues(alpha: 0.22),
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
                        color: Colors.white.withValues(alpha: 0.18),
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
                          color: Colors.white.withValues(alpha: 0.18),
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
    final notes = _cleanText(
      _childData['temporaryNote'] ?? _childData['temporaryNotes'],
    );

    return RefreshIndicator(
      onRefresh: _refreshPage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildChildHeader(),
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
            title: 'الموظف',
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
          if (!_isTrialChild) _buildConsultationsCard(),
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
        .where('childId', isEqualTo: _currentChildId)
        .limit(30)
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
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  bool _isHiddenTemporaryInvoice(Map<String, dynamic> data) {
    final statuses = [
      data['status'],
      data['paymentStatus'],
      data['invoiceStatus'],
    ].map((value) => _cleanText(value).toLowerCase());

    const hiddenStatuses = <String>{
      'superseded',
      'deleted',
      'void',
      'archived',
    };

    return statuses.any(hiddenStatuses.contains);
  }

  String _invoiceStatusLabel(dynamic value) {
    switch (_cleanText(value).toLowerCase()) {
      case 'paid':
      case 'مدفوعة':
        return 'مدفوعة';
      case 'partial':
      case 'partially_paid':
      case 'مدفوعة جزئيًا':
      case 'مدفوعة جزئياً':
        return 'مدفوعة جزئيًا';
      case 'overdue':
      case 'متأخرة':
        return 'متأخرة';
      case 'cancelled':
      case 'canceled':
      case 'ملغاة':
        return 'ملغاة';
      case 'unpaid':
      case 'pending':
      case 'not_paid':
      case 'غير مدفوعة':
      case '':
        return 'غير مدفوعة';
      default:
        return _cleanText(value);
    }
  }

  String _invoicePaymentMethodLabel(dynamic value) {
    switch (_cleanText(value).toLowerCase()) {
      case 'cash':
        return 'كاش';
      case 'visa':
      case 'card':
        return 'بطاقة / فيزا';
      case 'bank_transfer':
        return 'تحويل بنكي';
      case 'other':
        return 'أخرى';
      default:
        return '';
    }
  }

  Map<String, num> _temporaryInvoiceAmounts(Map<String, dynamic> data) {
    final total = _toNum(
      data['totalAmount'] ??
          data['finalAmount'] ??
          data['amount'] ??
          data['total'],
    );

    final paid = _toNum(data['paidAmount'] ?? data['paid']);

    final remaining = _toNum(
      data['remainingAmount'] ?? data['remaining'] ?? (total - paid),
    );

    final extraHoursAmount = _toNum(
      data['extraHoursAmount'] ?? data['extraHoursTotal'],
    );

    final consultationsAmount = _toNum(
      data['consultationsAmount'] ??
          data['consultationAmount'] ??
          data['consultationsTotal'],
    );

    final totalDiscount = _toNum(
      data['totalDiscount'] ??
          data['manualDiscount'] ??
          data['discountAmount'] ??
          data['discount'],
    );

    num nurseryCost = _toNum(
      data['subtotalAmount'] ??
          data['temporaryFee'] ??
          data['baseAmount'] ??
          data['childrenBaseAmount'],
    );

    if (nurseryCost <= 0 && total > 0) {
      nurseryCost =
          total - extraHoursAmount - consultationsAmount + totalDiscount;

      if (nurseryCost < 0) {
        nurseryCost = 0;
      }
    }

    return {
      'nurseryCost': nurseryCost,
      'extraHoursAmount': extraHoursAmount,
      'consultationsAmount': consultationsAmount,
      'totalDiscount': totalDiscount,
      'total': total,
      'paid': paid,
      'remaining': remaining < 0 ? 0 : remaining,
    };
  }

  void _openInvoiceDetails(Map<String, dynamic> data) {
    final amounts = _temporaryInvoiceAmounts(data);

    final hours = _toNum(
      data['hoursCount'] ??
          data['temporaryHoursCount'] ??
          data['serviceUnits'],
    );

    final hourlyRate = _toNum(
      data['hourlyRate'] ??
          data['temporaryHourlyRate'] ??
          data['unitPrice'],
    );

    final status = _invoiceStatusLabel(
      data['paymentStatus'] ?? data['status'] ?? data['invoiceStatus'],
    );

    final paymentMethod =
        _invoicePaymentMethodLabel(data['paymentMethod']);

    final notes = _cleanText(data['notes']);

    final startAt = data['accessStartAt'] ??
        data['startDate'] ??
        data['temporaryAccessStartAt'];

    final endAt = data['accessEndAt'] ??
        data['endDate'] ??
        data['temporaryAccessEndAt'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: SingleChildScrollView(
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
                      Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                      ),
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
                  if (hours > 0) _invoiceLine('عدد الساعات', '$hours'),
                  if (hourlyRate > 0)
                    _invoiceLine('سعر الساعة', _money(hourlyRate)),
                  if (_dateFromDynamic(startAt) != null ||
                      _dateFromDynamic(endAt) != null)
                    _invoiceLine(
                      'الفترة',
                      '${_formatDate(startAt)} إلى ${_formatDate(endAt)}',
                    ),
                  _invoiceLine(
                    'تكلفة الحضانة',
                    _money(amounts['nurseryCost']),
                  ),
                  _invoiceLine(
                    'الساعات الإضافية',
                    _money(amounts['extraHoursAmount']),
                  ),
                  _invoiceLine(
                    'الاستشارات',
                    _money(amounts['consultationsAmount']),
                  ),
                  if ((amounts['totalDiscount'] ?? 0) > 0)
                    _invoiceLine(
                      'الخصم',
                      _money(amounts['totalDiscount']),
                    ),
                  _invoiceLine('الإجمالي', _money(amounts['total'])),
                  _invoiceLine('المدفوع', _money(amounts['paid'])),
                  _invoiceLine('المتبقي', _money(amounts['remaining'])),
                  _invoiceLine('الحالة', status),
                  if (paymentMethod.isNotEmpty)
                    _invoiceLine('طريقة الدفع', paymentMethod),
                  if (notes.isNotEmpty) _invoiceLine('ملاحظات', notes),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTemporaryInvoiceCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _temporaryInvoicesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
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

        final docs = [...(snapshot.data?.docs ?? [])]
            .where((doc) => !_isHiddenTemporaryInvoice(doc.data()))
            .toList();

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
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
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
        final amounts = _temporaryInvoiceAmounts(data);

        final hours = _toNum(
          data['hoursCount'] ??
              data['temporaryHoursCount'] ??
              data['serviceUnits'],
        );

        final hourlyRate = _toNum(
          data['hourlyRate'] ??
              data['temporaryHourlyRate'] ??
              data['unitPrice'],
        );

        final status = _invoiceStatusLabel(
          data['paymentStatus'] ?? data['status'] ?? data['invoiceStatus'],
        );

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
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.10),
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
                          color: AppColors.primary.withValues(alpha: 0.10),
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
                  _invoiceLine(
                    'تكلفة الحضانة',
                    _money(amounts['nurseryCost']),
                  ),
                  _invoiceLine(
                    'الاستشارات',
                    _money(amounts['consultationsAmount']),
                  ),
                  _invoiceLine(
                    'الساعات الإضافية',
                    _money(amounts['extraHoursAmount']),
                  ),
                  if ((amounts['totalDiscount'] ?? 0) > 0)
                    _invoiceLine(
                      'الخصم',
                      _money(amounts['totalDiscount']),
                    ),
                  const Divider(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _invoiceMiniBox(
                          title: 'الإجمالي',
                          value: _money(amounts['total']),
                          icon: Icons.payments_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _invoiceMiniBox(
                          title: 'المتبقي',
                          value: _money(amounts['remaining']),
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
                          value: _money(amounts['paid']),
                          icon: Icons.done_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _invoiceMiniBox(
                          title: hours > 0 ? 'الساعات' : 'سعر الساعة',
                          value: hours > 0 ? '$hours' : _money(hourlyRate),
                          icon: Icons.schedule_rounded,
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
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
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


  Stream<QuerySnapshot<Map<String, dynamic>>> _liveStreamRequestStream() {
    final authUid = _auth.currentUser?.uid ?? '';

    return _firestore
        .collection('live_streams')
        .doc(LiveStreamService.nurseryMainStreamId)
        .collection('queue')
        .where('requesterAuthUid', isEqualTo: authUid)
        .where('childId', isEqualTo: _currentChildId)
        .snapshots();
  }

  bool _isOpenLiveStreamStatus(String status) {
    final clean = status.trim().toLowerCase();

    return clean == 'ready' ||
        clean == 'queued' ||
        clean == 'waiting' ||
        clean == 'active';
  }

  bool _canCancelLiveStreamStatus(String status) {
    final clean = status.trim().toLowerCase();
    return clean == 'ready' || clean == 'queued' || clean == 'waiting';
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _liveStreamStatusText(String status, int queuePosition) {
    switch (status.trim().toLowerCase()) {
      case 'ready':
        return 'دورك متاح الآن';
      case 'active':
        return 'البث مباشر الآن';
      case 'queued':
      case 'waiting':
        return queuePosition > 0
            ? 'أنت في قائمة الانتظار: $queuePosition'
            : 'أنت في قائمة الانتظار';
      default:
        return 'طلب بث قائم';
    }
  }

  String _liveStreamButtonText(String status) {
    switch (status.trim().toLowerCase()) {
      case 'queued':
      case 'waiting':
        return 'متابعة الانتظار';
      case 'active':
        return 'فتح البث';
      default:
        return 'الدخول للبث';
    }
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _latestOpenLiveStreamRequest(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    QueryDocumentSnapshot<Map<String, dynamic>>? result;

    for (final doc in docs) {
      final data = doc.data();
      final status = _cleanText(data['status']);

      if (!_isOpenLiveStreamStatus(status)) continue;

      if (result == null) {
        result = doc;
        continue;
      }

      final resultData = result.data();
      final currentDate = _dateFromDynamic(data['updatedAt']) ??
          _dateFromDynamic(data['createdAt']) ??
          _dateFromDynamic(data['requestedAt']);

      final previousDate = _dateFromDynamic(resultData['updatedAt']) ??
          _dateFromDynamic(resultData['createdAt']) ??
          _dateFromDynamic(resultData['requestedAt']);

      if (currentDate != null &&
          (previousDate == null || currentDate.isAfter(previousDate))) {
        result = doc;
      }
    }

    return result;
  }

  Future<void> _openLiveStreamRequest(String requestId) async {
    final cleanRequestId = requestId.trim();

    if (cleanRequestId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديد طلب البث المباشر')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveStreamViewerPage(
          roomId: LiveStreamService.nurseryMainStreamId,
          title: 'بث مباشر من الحضانة',
          startedByName: 'الحضانة',
          liveStreamRequestId: cleanRequestId,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _requestLiveStream() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولًا')),
      );
      return;
    }

    if (isRequestingLiveStream) return;

    setState(() {
      isRequestingLiveStream = true;
    });

    try {
      final result = await _liveStreamService.requestLiveStreamForChild(
        childId: _currentChildId,
        childName: _childName(),
        parentUid: '',
        parentUsername: '',
        parentName: _parentName() == '-' ? 'ولي الأمر' : _parentName(),
        section: 'Nursery',
        group: _groupName() == '-' ? '' : _groupName(),
      );

      if (!mounted) return;
      await _openLiveStreamRequest(result.requestId);
    } catch (e) {
      if (!mounted) return;

      final errorText = e.toString();
      final message = errorText.contains('permission-denied') ||
              errorText.contains('permission_denied') ||
              errorText.contains('missing or insufficient permissions')
          ? 'لا توجد صلاحية لاستخدام البث المباشر.'
          : errorText.replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          isRequestingLiveStream = false;
        });
      }
    }
  }

  Future<void> _cancelLiveStreamRequest(String requestId) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) return;

    try {
      await _liveStreamService.cancelLiveStreamRequest(
        requestId: requestId,
        cancelledByUid: currentUser.uid,
        cancelledByRole: 'temporary_parent',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إلغاء الطلب')),
      );
    }
  }

  Widget _buildLiveStreamCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _liveStreamRequestStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.10),
                        child: const Icon(
                          Icons.videocam_off_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'البث المباشر',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'تعذر تحميل حالة البث المباشر',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.10),
                        child: const Icon(
                          Icons.videocam_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'البث المباشر',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ),
            ),
          );
        }

        final request = _latestOpenLiveStreamRequest(snapshot.data?.docs ?? []);

        if (request == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.10),
                        child: const Icon(
                          Icons.videocam_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'البث المباشر',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'يمكنك فتح بث الحضانة المباشر',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          isRequestingLiveStream ? null : _requestLiveStream,
                      icon: isRequestingLiveStream
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        isRequestingLiveStream
                            ? 'جاري فتح البث...'
                            : 'فتح البث المباشر',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final data = request.data();
        final status = _cleanText(data['status']);
        final queuePosition = _asInt(data['queuePosition']);
        final canCancel = _canCancelLiveStreamStatus(status);

        return Card(
          color: Colors.red.withValues(alpha: 0.045),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Colors.red.withValues(alpha: 0.22),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.red.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.wifi_tethering_rounded,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'البث المباشر',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _liveStreamStatusText(status, queuePosition),
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _openLiveStreamRequest(request.id),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(_liveStreamButtonText(status)),
                ),
                if (canCancel) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => _cancelLiveStreamRequest(request.id),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('إلغاء الطلب'),
                  ),
                ],
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
        .where('childId', isEqualTo: _currentChildId)
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
              backgroundColor: AppColors.primary.withValues(alpha: 0.10),
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
                              color: AppColors.primary.withValues(alpha: 0.06),
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
                      ? Colors.purple.withValues(alpha: 0.10)
                      : AppColors.primary.withValues(alpha: 0.10),
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
                        color: AppColors.primary.withValues(alpha: 0.06),
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
                  color: Colors.purple.withValues(alpha: 0.10),
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

          if (snapshot.hasError) {
            return const _SimpleEmptyBox(
              icon: Icons.error_outline_rounded,
              title: 'تعذر تحميل التحديثات',
            );
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
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
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
                          color: AppColors.primary.withValues(alpha: 0.12),
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
              if (!_isTrialChild) ...[
                const SizedBox(height: 16),
                _sectionTitle(
                  title: 'الفاتورة',
                  icon: Icons.receipt_long_rounded,
                ),
                const SizedBox(height: 12),
                _buildTemporaryInvoiceCard(),
              ],
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

  Future<void> _openTemporaryChat({
    required String targetRole,
    required String targetUid,
    required String targetName,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemporaryParentChatPage(
          accessCodeId: widget.accessCodeId,
          accessCode: _accessCode,
          childId: _currentChildId,
          childName: _childName(),
          parentName: _parentName(),
          parentPhone: _parentPhone(),
          groupId: _cleanText(_childData['groupId']),
          groupName: _groupName(),
          targetRole: targetRole,
          targetUid: targetUid,
          targetName: targetName,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  bool _isMessageForChatTarget(
    Map<String, dynamic> data, {
    required String targetRole,
    required String targetUid,
  }) {
    final fromRole = _cleanText(data['fromRole']).toLowerCase();
    final messageTargetRole = _cleanText(data['targetRole']).toLowerCase();
    final messageTargetUid = _cleanText(data['targetUid']);

    final cleanTargetRole = targetRole.trim().toLowerCase();
    final cleanTargetUid = targetUid.trim();

    final fromTemporaryToTarget =
        fromRole == 'temporary_parent' && messageTargetRole == cleanTargetRole;

    final fromTargetToTemporary =
        fromRole == cleanTargetRole && messageTargetRole == 'temporary_parent';

    if (!fromTemporaryToTarget && !fromTargetToTemporary) {
      return false;
    }

    if (cleanTargetUid.isEmpty || cleanTargetUid == 'admin') {
      return true;
    }

    return messageTargetUid.isEmpty || messageTargetUid == cleanTargetUid;
  }

  Map<String, dynamic>? _latestMessageForChatTarget(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String targetRole,
    required String targetUid,
  }) {
    final filtered = docs.where((doc) {
      return _isMessageForChatTarget(
        doc.data(),
        targetRole: targetRole,
        targetUid: targetUid,
      );
    }).toList();

    if (filtered.isEmpty) return null;

    filtered.sort((a, b) {
      final aDate = _dateFromDynamic(a.data()['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _dateFromDynamic(b.data()['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return filtered.first.data();
  }

  String _messagePreview(Map<String, dynamic>? data) {
    if (data == null) return '';

    final text = _cleanText(
      data['message'] ?? data['text'] ?? data['body'],
    );

    if (text.isEmpty) return 'رسالة';

    if (text.length <= 45) return text;

    return '${text.substring(0, 45)}...';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _temporaryMessagesStream() {
    return _firestore
        .collection('temporary_messages')
        .where('childId', isEqualTo: _currentChildId)
        .limit(200)
        .snapshots();
  }

  Widget _buildChatOptionCard({
    required IconData icon,
    required String title,
    required Color color,
    required String targetRole,
    required String targetUid,
    required VoidCallback onTap,
    bool enabled = true,
    String disabledText = 'غير محددة حالياً',
  }) {
    if (!enabled) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: color.withValues(alpha: 0.14),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      disabledText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
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

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _temporaryMessagesStream(),
      builder: (context, snapshot) {
        final latest = _latestMessageForChatTarget(
          snapshot.data?.docs ?? [],
          targetRole: targetRole,
          targetUid: targetUid,
        );

        final preview = _messagePreview(latest);
        final time = latest == null ? '' : _formatTime(latest['createdAt']);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: color.withValues(alpha: 0.14),
                    child: Icon(
                      icon,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            if (time.isNotEmpty)
                              Text(
                                time,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        if (preview.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textLight,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatSearchField() {
    return TextField(
      controller: chatSearchCtrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'بحث',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: chatSearchCtrl.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  chatSearchCtrl.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesTab() {
    final staffUid = _staffUid();
    final hasStaff = staffUid.isNotEmpty;
    final query = chatSearchCtrl.text.trim().toLowerCase();

    final showAdmin = query.isEmpty ||
        'الإدارة admin'.toLowerCase().contains(query);

    final staffTitle = hasStaff ? _staffName() : 'الموظف';
    final showStaff = query.isEmpty ||
        '$staffTitle موظف الحضانة'.toLowerCase().contains(query);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        children: [
          _buildChatSearchField(),
          const SizedBox(height: 12),
          if (showAdmin)
            _buildChatOptionCard(
              icon: Icons.admin_panel_settings_outlined,
              title: 'الإدارة',
              color: AppColors.secondary,
              targetRole: 'admin',
              targetUid: 'admin',
              onTap: () {
                _openTemporaryChat(
                  targetRole: 'admin',
                  targetUid: 'admin',
                  targetName: 'الإدارة',
                );
              },
            ),
          if (showStaff)
            _buildChatOptionCard(
              icon: Icons.child_care_outlined,
              title: staffTitle,
              color: const Color(0xFFEFA7C8),
              targetRole: 'nursery_staff',
              targetUid: staffUid,
              enabled: hasStaff,
              disabledText: 'لم يتم تحديد موظف مسؤول بعد',
              onTap: () {
                _openTemporaryChat(
                  targetRole: 'nursery_staff',
                  targetUid: staffUid,
                  targetName: _staffName(),
                );
              },
            ),
          if (!showAdmin && !showStaff)
            const _SimpleEmptyBox(
              icon: Icons.search_off_rounded,
              title: 'لا توجد نتائج',
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _temporaryNotificationsStream() {
    return _firestore
        .collection('notifications')
        .where('childId', isEqualTo: _currentChildId)
        .limit(100)
        .snapshots();
  }


  Future<void> _markTemporaryNotificationAsRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;

    await _firestore.collection('notifications').doc(notificationId).set({
      'isRead': true,
      'read': true,
      'seen': true,
      'readAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _openTemporaryNotificationsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TemporaryNotificationsPage(
          notificationsStream: _temporaryNotificationsStream,
          markAsRead: _markTemporaryNotificationAsRead,
          formatDate: _formatDate,
          formatTime: _formatTime,
          cleanText: _cleanText,
          isVisibleNotification: _isVisibleTemporaryParentNotification,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Widget _buildTemporaryNotificationActionButton() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _temporaryNotificationsStream(),
      builder: (context, snapshot) {
        final count = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data();

          return _isVisibleTemporaryParentNotification(data) &&
              data['isRead'] != true &&
              data['read'] != true &&
              data['seen'] != true;
        }).length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              tooltip: 'الإشعارات',
              onPressed: _openTemporaryNotificationsPage,
            ),
            if (count > 0)
              PositionedDirectional(
                top: 6,
                end: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
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
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                ),
              ),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: _confirmLogout,
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'الإصدار 1.0.0',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w500,
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
        actions: [
          if (_availableSiblings.length > 1)
            IconButton(
              icon: const Icon(Icons.family_restroom_rounded),
              tooltip: 'تبديل الطفل',
              onPressed: _openSiblingPicker,
            ),
          _buildTemporaryNotificationActionButton(),
          if (selectedIndex == 1)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
              onPressed: _refreshPage,
            ),
        ],
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

class _TemporarySiblingOption {
  final String childId;
  final Map<String, dynamic> childData;

  const _TemporarySiblingOption({
    required this.childId,
    required this.childData,
  });

  String _clean(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String get childName {
    final value = _clean(childData['childName'] ?? childData['name']);
    return value.isEmpty ? 'طفل بدون اسم' : value;
  }

  String get childTypeLabel {
    final type = _clean(childData['childType']).toLowerCase();
    final enrollmentType = _clean(childData['enrollmentType']).toLowerCase();
    final status = _clean(childData['childStatus']).toLowerCase();

    if (childData['isTrialChild'] == true ||
        type == 'trial' ||
        enrollmentType == 'trial' ||
        status == 'trial') {
      return 'طفل تجربة';
    }

    return 'طفل مؤقت';
  }
}

class _TemporaryNotificationsPage extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function()
      notificationsStream;
  final Future<void> Function(String notificationId) markAsRead;
  final String Function(dynamic value) formatDate;
  final String Function(dynamic value) formatTime;
  final String Function(dynamic value) cleanText;
  final bool Function(Map<String, dynamic> data) isVisibleNotification;

  const _TemporaryNotificationsPage({
    required this.notificationsStream,
    required this.markAsRead,
    required this.formatDate,
    required this.formatTime,
    required this.cleanText,
    required this.isVisibleNotification,
  });

  IconData _iconForType(String type) {
    final value = type.trim().toLowerCase();

    if (value.contains('invoice')) return Icons.receipt_long_rounded;
    if (value.contains('incident')) return Icons.report_problem_outlined;
    if (value.contains('handoff')) return Icons.how_to_reg_outlined;
    if (value.contains('live_stream')) return Icons.wifi_tethering_rounded;
    if (value.contains('message')) return Icons.chat_bubble_outline_rounded;

    return Icons.notifications_none_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الإشعارات',
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: notificationsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const _SimpleEmptyBox(
                icon: Icons.error_outline_rounded,
                title: 'تعذر تحميل الإشعارات',
              );
            }

            final docs = [...(snapshot.data?.docs ?? [])]
                .where((doc) => isVisibleNotification(doc.data()))
                .toList();

            docs.sort((a, b) {
              DateTime? dateOf(Map<String, dynamic> data) {
                final value = data['createdAt'] ??
                    data['time'] ??
                    data['eventAt'] ??
                    data['updatedAt'];

                if (value is Timestamp) return value.toDate();
                if (value is DateTime) return value;
                return null;
              }

              final aDate =
                  dateOf(a.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate =
                  dateOf(b.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);

              return bDate.compareTo(aDate);
            });

            if (docs.isEmpty) {
              return const _SimpleEmptyBox(
                icon: Icons.notifications_none_rounded,
                title: 'لا توجد إشعارات',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();

                final title = cleanText(
                  data['title'] ?? data['subject'] ?? 'إشعار',
                );

                final body = cleanText(
                  data['body'] ??
                      data['message'] ??
                      data['text'] ??
                      data['description'],
                );

                final type =
                    cleanText(data['type'] ?? data['notificationType']);
                final createdAt = data['createdAt'] ??
                    data['time'] ??
                    data['eventAt'] ??
                    data['updatedAt'];

                final isRead = data['isRead'] == true ||
                    data['read'] == true ||
                    data['seen'] == true;

                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                      child: Icon(
                        _iconForType(type),
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      title.isEmpty ? 'إشعار' : title,
                      style: TextStyle(
                        fontWeight:
                            isRead ? FontWeight.w700 : FontWeight.w900,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          '${formatDate(createdAt)} - ${formatTime(createdAt)}',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: isRead
                        ? null
                        : Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                    onTap: () => markAsRead(doc.id),
                  ),
                );
              },
            );
          },
        ),
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
              backgroundColor: AppColors.primary.withValues(alpha: 0.10),
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