import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'messages_page.dart';
import 'temporary_staff_chat_page.dart';

class NurseryChatsPage extends StatefulWidget {
  final List<ChildModel> children;

  const NurseryChatsPage({
    super.key,
    required this.children,
  });

  @override
  State<NurseryChatsPage> createState() => _NurseryChatsPageState();
}

class _NurseryChatsPageState extends State<NurseryChatsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MessageService _messageService = MessageService();
  final TextEditingController searchCtrl = TextEditingController();

  Future<Map<String, dynamic>?>? _adminFuture;
  Future<Map<String, Map<String, dynamic>>>? _childrenIdentityFuture;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  List<ChildModel> get activeChildren {
    return widget.children.where((child) => child.isActiveChild).toList();
  }

  List<ChildModel> get temporaryChildren {
    return activeChildren.where((child) {
      return child.isTemporaryChild || child.isTrialChild;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _adminFuture = _fetchAdminContact();
    _childrenIdentityFuture = _loadChildrenIdentityData();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  String _clean(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _normalizeLower(dynamic value) {
    return _clean(value).toLowerCase();
  }

  String _normalizePhone(dynamic value) {
    return _clean(value).replaceAll(RegExp(r'[^0-9+]'), '');
  }

  String _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final clean = _clean(value);
      if (clean.isNotEmpty) return clean;
    }

    return '';
  }

  String _normalizeRole(String role) {
    final value = role.trim().toLowerCase();

    switch (value) {
      case 'nursery':
      case 'nursery_staff':
      case 'nursery staff':
      case 'staff':
      case 'employee':
      case 'teacher':
      case 'موظفة':
      case 'موظفة حضانة':
      case 'حضانة':
        return 'nursery_staff';

      case 'admin':
      case 'manager':
      case 'مدير':
      case 'مدير النظام':
      case 'ادمن':
      case 'أدمن':
        return 'admin';

      case 'parent':
      case 'ولي امر':
      case 'ولي أمر':
      case 'ولي الامر':
      case 'ولي الأمر':
        return 'parent';

      default:
        return value;
    }
  }

  String _roleLabel(String role) {
    switch (_normalizeRole(role)) {
      case 'admin':
        return 'الإدارة';

      case 'parent':
        return 'ولي الأمر';

      default:
        return role.trim().isEmpty ? 'مستخدم' : role.trim();
    }
  }

  String _firstLetter(String name) {
    final cleanName = name.trim();

    if (cleanName.isEmpty) return 'و';

    return cleanName.substring(0, 1);
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;

    if (sameDay) {
      final hour = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);

      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'م' : 'ص';

      return '$hour:$minute $period';
    }

    return '${date.day}/${date.month}';
  }

  Timestamp? _timestampFromDynamic(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);

    return null;
  }

  Future<Map<String, dynamic>?> _fetchAdminContact() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;

      return {
        'key': 'admin_chat',
        'kind': 'admin',
        'id': doc.id,
        'name': 'الإدارة',
        'role': 'admin',
        'subtitle': 'الإدارة',
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Map<String, dynamic>>> _loadChildrenIdentityData() async {
    final result = <String, Map<String, dynamic>>{};
    final parentUserCache = <String, Map<String, dynamic>>{};

    for (final child in activeChildren) {
      Map<String, dynamic> raw = <String, dynamic>{};

      try {
        final childDoc =
            await _firestore.collection('children').doc(child.id).get();

        raw = childDoc.data() ?? <String, dynamic>{};
      } catch (_) {}

      final parentUid = _firstNonEmpty([
        raw['parentUid'],
        child.parentUid,
      ]);

      Map<String, dynamic> parentUser = <String, dynamic>{};

      if (parentUid.isNotEmpty) {
        if (parentUserCache.containsKey(parentUid)) {
          parentUser = parentUserCache[parentUid]!;
        } else {
          try {
            final userDoc =
                await _firestore.collection('users').doc(parentUid).get();

            parentUser = userDoc.data() ?? <String, dynamic>{};
          } catch (_) {
            parentUser = <String, dynamic>{};
          }

          parentUserCache[parentUid] = parentUser;
        }
      }

      result[child.id] = {
        ...raw,
        '_resolvedParentUid': parentUid,
        '_resolvedParentUsername': _firstNonEmpty([
          raw['parentUsername'],
          child.parentUsername,
          parentUser['username'],
        ]).toLowerCase(),
        '_resolvedParentName': _firstNonEmpty([
          raw['parentName'],
          child.parentName,
          parentUser['displayName'],
          parentUser['name'],
          parentUser['fullName'],
          parentUser['username'],
          'ولي الأمر',
        ]),
        '_resolvedParentPhone': _firstNonEmpty([
          raw['parentPhone'],
          raw['phone'],
          raw['parentMobile'],
          raw['mobile'],
          parentUser['phone'],
          parentUser['mobile'],
          parentUser['phoneNumber'],
        ]),
        '_resolvedParentProfileId': _firstNonEmpty([
          raw['parentProfileId'],
          raw['parentRecordId'],
          raw['familyId'],
          parentUser['parentProfileId'],
          parentUser['parentRecordId'],
          parentUser['familyId'],
        ]),
      };
    }

    return result;
  }

  String _familyKeyForChild(
    ChildModel child,
    Map<String, dynamic> raw,
  ) {
    final profileId = _firstNonEmpty([
      raw['_resolvedParentProfileId'],
      raw['parentProfileId'],
      raw['parentRecordId'],
      raw['familyId'],
    ]);

    if (profileId.isNotEmpty) {
      return 'profile_${profileId.toLowerCase()}';
    }

    final phone = _normalizePhone(
      _firstNonEmpty([
        raw['_resolvedParentPhone'],
        raw['parentPhone'],
        raw['phone'],
        raw['parentMobile'],
        raw['mobile'],
      ]),
    );

    if (phone.isNotEmpty) {
      return 'phone_$phone';
    }

    final parentUid = _firstNonEmpty([
      raw['_resolvedParentUid'],
      raw['parentUid'],
      child.parentUid,
    ]);

    if (parentUid.isNotEmpty) {
      return 'uid_$parentUid';
    }

    final username = _normalizeLower(
      _firstNonEmpty([
        raw['_resolvedParentUsername'],
        raw['parentUsername'],
        child.parentUsername,
      ]),
    );

    if (username.isNotEmpty) {
      return 'username_$username';
    }

    final parentName = _normalizeLower(
      _firstNonEmpty([
        raw['_resolvedParentName'],
        raw['parentName'],
        child.parentName,
      ]),
    );

    return parentName.isEmpty ? 'child_${child.id}' : 'legacy_name_$parentName';
  }

  String _childrenCountLabel(int count) {
    if (count == 1) return 'طفل واحد';
    if (count == 2) return 'طفلان';
    if (count >= 3 && count <= 10) return '$count أطفال';
    return '$count طفل';
  }

  List<Map<String, dynamic>> _buildGroupedParentContacts(
    Map<String, Map<String, dynamic>> identityByChildId,
  ) {
    final groups = <String, Map<String, dynamic>>{};

    for (final child in activeChildren) {
      final raw = identityByChildId[child.id] ?? <String, dynamic>{};
      final familyKey = _familyKeyForChild(child, raw);

      final parentName = _firstNonEmpty([
        raw['_resolvedParentName'],
        raw['parentName'],
        child.parentName,
        'ولي الأمر',
      ]);

      final group = groups.putIfAbsent(
        familyKey,
        () => {
          'key': familyKey,
          'kind': 'parent_group',
          'name': parentName,
          'role': 'parent',
          'children': <ChildModel>[],
          'rawChildren': <String, Map<String, dynamic>>{},
        },
      );

      final children = group['children'] as List<ChildModel>;
      final rawChildren =
          group['rawChildren'] as Map<String, Map<String, dynamic>>;

      if (!children.any((item) => item.id == child.id)) {
        children.add(child);
      }

      rawChildren[child.id] = raw;

      if (_clean(group['name']).isEmpty || group['name'] == 'ولي الأمر') {
        group['name'] = parentName;
      }
    }

    final contacts = groups.values.toList();

    for (final contact in contacts) {
      final children = contact['children'] as List<ChildModel>;

      children.sort((a, b) => a.name.compareTo(b.name));

      if (children.length == 1) {
        final child = children.first;

        contact['subtitle'] = child.isTrialChild
            ? 'ولي أمر طفل تجربة'
            : child.isTemporaryChild
                ? 'ولي أمر زائر'
                : 'ولي الأمر';
      } else {
        final childrenNames = children
            .map((child) => child.name.trim())
            .where((name) => name.isNotEmpty)
            .join('، ');

        contact['subtitle'] = childrenNames.isEmpty
            ? 'ولي الأمر • ${_childrenCountLabel(children.length)}'
            : 'ولي الأمر • الأطفال: $childrenNames';
      }
    }

    return contacts;
  }

  Future<String> _resolveOfficialParentUidForChild({
    required ChildModel child,
    required Map<String, dynamic> raw,
  }) async {
    final currentUid = _firstNonEmpty([
      raw['_resolvedParentUid'],
      raw['parentUid'],
      child.parentUid,
    ]);

    if (currentUid.isNotEmpty) {
      return currentUid;
    }

    final username = _normalizeLower(
      _firstNonEmpty([
        raw['_resolvedParentUsername'],
        raw['parentUsername'],
        child.parentUsername,
      ]),
    );

    if (username.isEmpty) {
      return '';
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .where('role', isEqualTo: 'parent')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return '';

      return snapshot.docs.first.id;
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, dynamic>> _loadTemporaryAccessData(
    ChildModel child,
  ) async {
    String accessCodeId = '';
    String accessCode = '';

    try {
      final childDoc =
          await _firestore.collection('children').doc(child.id).get();

      final data = childDoc.data() ?? <String, dynamic>{};

      accessCodeId = _clean(
        data['temporaryAccessCodeId'] ??
            data['sharedAccessCodeId'] ??
            data['accessCodeId'],
      );

      accessCode = _clean(
        data['temporaryAccessCode'] ?? data['accessCode'] ?? data['code'],
      );
    } catch (_) {}

    if (accessCodeId.isEmpty || accessCode.isEmpty) {
      try {
        final snapshot = await _firestore
            .collection('temporary_access_codes')
            .where('childId', isEqualTo: child.id)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          final data = doc.data();

          accessCodeId = accessCodeId.isEmpty ? doc.id : accessCodeId;
          accessCode =
              accessCode.isEmpty ? _clean(data['code']) : accessCode;
        }
      } catch (_) {}
    }

    return {
      'accessCodeId': accessCodeId,
      'accessCode': accessCode,
    };
  }

  Future<void> _openOfficialChildChat({
    required ChildModel child,
    required Map<String, dynamic> raw,
    required String parentName,
  }) async {
    final parentUid = await _resolveOfficialParentUidForChild(
      child: child,
      raw: raw,
    );

    if (!mounted) return;

    if (parentUid.isEmpty) {
      _showMessage('تعذر العثور على حساب ولي الأمر');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesPage(
          child: null,
          targetRole: 'parent',
          targetUserId: parentUid,
          targetUserName: parentName,
          targetSection: 'Nursery',
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openTemporaryChildChat({
    required ChildModel child,
    required Map<String, dynamic> raw,
  }) async {
    final access = await _loadTemporaryAccessData(child);

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemporaryStaffChatPage(
          accessCodeId: _clean(access['accessCodeId']),
          accessCode: _clean(access['accessCode']),
          childId: child.id,
          childName: child.name,
          parentName: _firstNonEmpty([
            raw['_resolvedParentName'],
            raw['parentName'],
            child.parentName,
          ]),
          parentPhone: _firstNonEmpty([
            raw['_resolvedParentPhone'],
            raw['parentPhone'],
            raw['phone'],
            raw['parentMobile'],
            raw['mobile'],
          ]),
          groupId: child.groupId,
          groupName: child.displayGroup,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openParentChild({
    required ChildModel child,
    required Map<String, dynamic> raw,
    required String parentName,
  }) async {
    if (child.isTemporaryChild || child.isTrialChild) {
      await _openTemporaryChildChat(
        child: child,
        raw: raw,
      );

      return;
    }

    await _openOfficialChildChat(
      child: child,
      raw: raw,
      parentName: parentName,
    );
  }

  Future<void> _openContact(Map<String, dynamic> contact) async {
    final kind = _clean(contact['kind']);

    if (kind == 'admin') {
      final adminUid = _clean(contact['id']);

      if (adminUid.isEmpty) {
        _showMessage('تعذر العثور على حساب الإدارة');
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MessagesPage(
            child: null,
            targetRole: 'admin',
            targetUserId: adminUid,
            targetUserName: 'الإدارة',
            targetSection: 'Nursery',
          ),
        ),
      );

      if (!mounted) return;
      setState(() {});

      return;
    }

    if (kind != 'parent_group') return;

    final children = List<ChildModel>.from(
      contact['children'] as List<ChildModel>,
    );

    final rawChildren = Map<String, Map<String, dynamic>>.from(
      contact['rawChildren'] as Map<String, Map<String, dynamic>>,
    );

    if (children.isEmpty) {
      _showMessage('تعذر تحميل بيانات الأطفال');
      return;
    }

    final parentName = _clean(contact['name']).isEmpty
        ? 'ولي الأمر'
        : _clean(contact['name']);

    ChildModel? officialChild;

    for (final child in children) {
      if (!child.isTemporaryChild && !child.isTrialChild) {
        officialChild = child;
        break;
      }
    }

    final selectedChild = officialChild ?? children.first;
    final raw = rawChildren[selectedChild.id] ?? <String, dynamic>{};

    await _openParentChild(
      child: selectedChild,
      raw: raw,
      parentName: parentName,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>?
      _temporaryMessagesStream() {
    final uid = currentUserId;

    if (temporaryChildren.isEmpty || uid == null || uid.trim().isEmpty) {
      return null;
    }

    final receivedByCurrentStaff = _firestore
        .collection('temporary_messages')
        .where('targetUid', isEqualTo: uid)
        .limit(500);

    final sentByCurrentStaff = _firestore
        .collection('temporary_messages')
        .where('fromUid', isEqualTo: uid)
        .limit(500);

    late final StreamController<
        List<QueryDocumentSnapshot<Map<String, dynamic>>>> controller;

    final latestByQuery =
        List<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.generate(
      2,
      (_) => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
    );

    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emitMergedDocs() {
      final uniqueById =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

      for (final docs in latestByQuery) {
        for (final doc in docs) {
          uniqueById[doc.id] = doc;
        }
      }

      controller.add(uniqueById.values.toList());
    }

    controller =
        StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      onListen: () {
        final queries = [
          receivedByCurrentStaff,
          sentByCurrentStaff,
        ];

        for (int index = 0; index < queries.length; index++) {
          subscriptions.add(
            queries[index].snapshots().listen(
              (snapshot) {
                latestByQuery[index] = snapshot.docs;
                emitMergedDocs();
              },
              onError: controller.addError,
            ),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  bool _isTemporaryMessageForCurrentStaff(
    Map<String, dynamic> data,
  ) {
    final uid = currentUserId ?? '';
    if (uid.isEmpty) return false;

    final fromRole = _normalizeRole(_clean(data['fromRole']));
    final targetRole = _normalizeRole(_clean(data['targetRole']));
    final fromUid = _clean(data['fromUid']);
    final targetUid = _clean(data['targetUid']);

    final receivedByCurrentStaff =
        fromRole == 'temporary_parent' &&
        targetRole == 'nursery_staff' &&
        targetUid == uid;

    final sentByCurrentStaff =
        fromRole == 'nursery_staff' &&
        fromUid == uid &&
        targetRole == 'temporary_parent';

    return receivedByCurrentStaff || sentByCurrentStaff;
  }

  Map<String, Map<String, dynamic>> _latestTemporaryMessagesByChildId(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final allowedChildIds =
        temporaryChildren.map((child) => child.id).toSet();

    final result = <String, Map<String, dynamic>>{};

    for (final doc in docs) {
      final data = doc.data();

      if (!_isTemporaryMessageForCurrentStaff(data)) {
        continue;
      }

      final childId = _clean(data['childId']);

      if (childId.isEmpty || !allowedChildIds.contains(childId)) {
        continue;
      }

      final old = result[childId];

      final currentDate = _timestampFromDynamic(
            data['createdAt'] ??
                data['sentAt'] ??
                data['time'],
          ) ??
          Timestamp.fromMillisecondsSinceEpoch(0);

      final oldDate = _timestampFromDynamic(
            old?['createdAt'] ??
                old?['sentAt'] ??
                old?['time'],
          ) ??
          Timestamp.fromMillisecondsSinceEpoch(0);

      if (old == null || currentDate.compareTo(oldDate) > 0) {
        result[childId] = data;
      }
    }

    return result;
  }

  MessageModel? _latestOfficialMessageForContact({
    required Map<String, dynamic> contact,
    required List<MessageModel> messages,
  }) {
    final kind = _clean(contact['kind']);
    final myUid = currentUserId ?? '';

    MessageModel? latest;

    if (kind == 'admin') {
      final adminUid = _clean(contact['id']);

      for (final message in messages) {
        final belongsToAdmin =
            (message.senderId == myUid && message.receiverId == adminUid) ||
                (message.senderId == adminUid &&
                    message.receiverId == myUid);

        if (!belongsToAdmin) continue;

        if (latest == null || message.sentAt.compareTo(latest.sentAt) > 0) {
          latest = message;
        }
      }

      return latest;
    }

    final children = List<ChildModel>.from(
      contact['children'] as List<ChildModel>,
    );

    final rawChildren = contact['rawChildren']
            is Map<String, Map<String, dynamic>>
        ? contact['rawChildren'] as Map<String, Map<String, dynamic>>
        : <String, Map<String, dynamic>>{};

    final officialChildIds = children
        .where((child) => !child.isTemporaryChild && !child.isTrialChild)
        .map((child) => child.id)
        .toSet();

    final parentUids = <String>{};

    for (final child in children) {
      if (child.isTemporaryChild || child.isTrialChild) continue;

      final raw = rawChildren[child.id] ?? <String, dynamic>{};
      final parentUid = _firstNonEmpty([
        raw['_resolvedParentUid'],
        raw['parentUid'],
        child.parentUid,
      ]);

      if (parentUid.isNotEmpty) {
        parentUids.add(parentUid);
      }
    }

    if (officialChildIds.isEmpty && parentUids.isEmpty) return null;

    for (final message in messages) {
      final belongsToParent =
          (message.senderId == myUid &&
                  parentUids.contains(message.receiverId)) ||
              (message.receiverId == myUid &&
                  parentUids.contains(message.senderId));

      final belongsToLegacyChild =
          officialChildIds.contains(message.childId);

      if (!belongsToParent && !belongsToLegacyChild) continue;

      if (latest == null || message.sentAt.compareTo(latest.sentAt) > 0) {
        latest = message;
      }
    }

    return latest;
  }

  Map<String, dynamic>? _latestTemporaryMessageForContact({
    required Map<String, dynamic> contact,
    required Map<String, Map<String, dynamic>> temporaryMessagesByChildId,
  }) {
    if (_clean(contact['kind']) != 'parent_group') return null;

    final children = List<ChildModel>.from(
      contact['children'] as List<ChildModel>,
    );

    Map<String, dynamic>? latest;
    Timestamp? latestTime;

    for (final child in children) {
      if (!child.isTemporaryChild && !child.isTrialChild) continue;

      final message = temporaryMessagesByChildId[child.id];

      if (message == null) continue;

      final time = _timestampFromDynamic(
            message['createdAt'] ??
                message['sentAt'] ??
                message['time'],
          ) ??
          Timestamp.fromMillisecondsSinceEpoch(0);

      if (latest == null ||
          latestTime == null ||
          time.compareTo(latestTime) > 0) {
        latest = message;
        latestTime = time;
      }
    }

    return latest;
  }

  Timestamp? _latestContactTime({
    required MessageModel? officialMessage,
    required Map<String, dynamic>? temporaryMessage,
  }) {
    final officialTime = officialMessage?.sentAt;

    final temporaryTime = _timestampFromDynamic(
      temporaryMessage?['createdAt'] ??
          temporaryMessage?['sentAt'] ??
          temporaryMessage?['time'],
    );

    if (officialTime == null) return temporaryTime;
    if (temporaryTime == null) return officialTime;

    return officialTime.compareTo(temporaryTime) >= 0
        ? officialTime
        : temporaryTime;
  }

  String _previewForContact({
    required MessageModel? officialMessage,
    required Map<String, dynamic>? temporaryMessage,
  }) {
    final officialTime = officialMessage?.sentAt;

    final temporaryTime = _timestampFromDynamic(
      temporaryMessage?['createdAt'] ??
          temporaryMessage?['sentAt'] ??
          temporaryMessage?['time'],
    );

    final temporaryPreview = _clean(
      temporaryMessage?['message'] ??
          temporaryMessage?['text'] ??
          temporaryMessage?['body'],
    );

    if (officialTime == null) return temporaryPreview;
    if (temporaryTime == null) {
      return officialMessage?.displayText.trim() ?? '';
    }

    return temporaryTime.compareTo(officialTime) > 0
        ? temporaryPreview
        : officialMessage?.displayText.trim() ?? '';
  }

  Widget _buildContactCard({
    required Map<String, dynamic> contact,
    required MessageModel? officialMessage,
    required Map<String, dynamic>? temporaryMessage,
  }) {
    final name = _clean(contact['name']).isEmpty
        ? 'ولي الأمر'
        : _clean(contact['name']);

    final subtitle = _clean(contact['subtitle']);
    final kind = _clean(contact['kind']);
    final isAdmin = kind == 'admin';

    final preview = _previewForContact(
      officialMessage: officialMessage,
      temporaryMessage: temporaryMessage,
    );

    final time = _latestContactTime(
      officialMessage: officialMessage,
      temporaryMessage: temporaryMessage,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _openContact(contact),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFFEFA7C8).withOpacity(0.14),
                child: isAdmin
                    ? const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Color(0xFFEFA7C8),
                      )
                    : Text(
                        _firstLetter(name),
                        style: const TextStyle(
                          color: Color(0xFFEFA7C8),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle.isEmpty
                          ? _roleLabel(_clean(contact['role']))
                          : subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (time != null)
                    Text(
                      _formatTime(time),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textLight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _sortedContacts({
    required List<Map<String, dynamic>> contacts,
    required List<MessageModel> officialMessages,
    required Map<String, Map<String, dynamic>> temporaryMessagesByChildId,
  }) {
    final search = searchCtrl.text.trim().toLowerCase();

    final filtered = contacts.where((contact) {
      final officialMessage = _latestOfficialMessageForContact(
        contact: contact,
        messages: officialMessages,
      );

      final temporaryMessage = _latestTemporaryMessageForContact(
        contact: contact,
        temporaryMessagesByChildId: temporaryMessagesByChildId,
      );

      final preview = _previewForContact(
        officialMessage: officialMessage,
        temporaryMessage: temporaryMessage,
      );

      final children = contact['children'] is List<ChildModel>
          ? contact['children'] as List<ChildModel>
          : <ChildModel>[];

      final childrenNames = children.map((child) => child.name).join(' ');

      final values = [
        contact['name'],
        contact['subtitle'],
        childrenNames,
        preview,
      ].join(' ').toLowerCase();

      return search.isEmpty || values.contains(search);
    }).toList();

    filtered.sort((a, b) {
      final aOfficial = _latestOfficialMessageForContact(
        contact: a,
        messages: officialMessages,
      );

      final aTemporary = _latestTemporaryMessageForContact(
        contact: a,
        temporaryMessagesByChildId: temporaryMessagesByChildId,
      );

      final bOfficial = _latestOfficialMessageForContact(
        contact: b,
        messages: officialMessages,
      );

      final bTemporary = _latestTemporaryMessageForContact(
        contact: b,
        temporaryMessagesByChildId: temporaryMessagesByChildId,
      );

      final aTime = _latestContactTime(
        officialMessage: aOfficial,
        temporaryMessage: aTemporary,
      );

      final bTime = _latestContactTime(
        officialMessage: bOfficial,
        temporaryMessage: bTemporary,
      );

      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime);
      }

      if (aTime != null) return -1;
      if (bTime != null) return 1;

      final aKind = _clean(a['kind']);
      final bKind = _clean(b['kind']);

      if (aKind == 'admin' && bKind != 'admin') return -1;
      if (aKind != 'admin' && bKind == 'admin') return 1;

      return _clean(a['name']).compareTo(_clean(b['name']));
    });

    return filtered;
  }

  Widget _buildSearchField() {
    return TextField(
      controller: searchCtrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'بحث',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: searchCtrl.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  searchCtrl.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.primary.withOpacity(0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppColors.primary.withOpacity(0.12),
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

  Widget _buildChatsList() {
    final uid = currentUserId;

    if (uid == null) {
      return const Center(
        child: Text('تعذر تحميل هوية المستخدم'),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _adminFuture,
      builder: (context, adminSnapshot) {
        return FutureBuilder<Map<String, Map<String, dynamic>>>(
          future: _childrenIdentityFuture,
          builder: (context, identitySnapshot) {
            if (identitySnapshot.connectionState ==
                    ConnectionState.waiting &&
                !identitySnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final identityByChildId =
                identitySnapshot.data ?? <String, Map<String, dynamic>>{};

            final baseContacts = <Map<String, dynamic>>[
              if (adminSnapshot.data != null) adminSnapshot.data!,
              ..._buildGroupedParentContacts(identityByChildId),
            ];

            return StreamBuilder<List<MessageModel>>(
              stream: _messageService.getLatestChatsForUser(
                currentUserId: uid,
              ),
              builder: (context, officialSnapshot) {
                if (officialSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !officialSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (officialSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل المحادثات: ${officialSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                final officialMessages = officialSnapshot.data ?? [];
                final temporaryStream = _temporaryMessagesStream();

                if (temporaryStream == null) {
                  final contacts = _sortedContacts(
                    contacts: baseContacts,
                    officialMessages: officialMessages,
                    temporaryMessagesByChildId: const {},
                  );

                  return _buildContactsList(
                    contacts: contacts,
                    officialMessages: officialMessages,
                    temporaryMessagesByChildId: const {},
                  );
                }

                return StreamBuilder<
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                  stream: temporaryStream,
                  builder: (context, temporarySnapshot) {
                    if (temporarySnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !temporarySnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (temporarySnapshot.hasError) {
                      return Center(
                        child: Text(
                          'حدث خطأ أثناء تحميل محادثات ولي الأمر الزائر: ${temporarySnapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }

                    final temporaryMessagesByChildId =
                        _latestTemporaryMessagesByChildId(
                      temporarySnapshot.data ?? [],
                    );

                    final contacts = _sortedContacts(
                      contacts: baseContacts,
                      officialMessages: officialMessages,
                      temporaryMessagesByChildId:
                          temporaryMessagesByChildId,
                    );

                    return _buildContactsList(
                      contacts: contacts,
                      officialMessages: officialMessages,
                      temporaryMessagesByChildId:
                          temporaryMessagesByChildId,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContactsList({
    required List<Map<String, dynamic>> contacts,
    required List<MessageModel> officialMessages,
    required Map<String, Map<String, dynamic>>
        temporaryMessagesByChildId,
  }) {
    if (contacts.isEmpty) {
      return Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.send_outlined,
                size: 52,
                color: AppColors.textLight,
              ),
              SizedBox(height: 12),
              Text(
                'لا توجد محادثات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];

        final officialMessage = _latestOfficialMessageForContact(
          contact: contact,
          messages: officialMessages,
        );

        final temporaryMessage = _latestTemporaryMessageForContact(
          contact: contact,
          temporaryMessagesByChildId: temporaryMessagesByChildId,
        );

        return _buildContactCard(
          contact: contact,
          officialMessage: officialMessage,
          temporaryMessage: temporaryMessage,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'المراسلات',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          _buildSearchField(),
          const SizedBox(height: 12),
          Expanded(
            child: _buildChatsList(),
          ),
        ],
      ),
    );
  }
}
