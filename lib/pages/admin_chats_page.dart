import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import 'messages_page.dart';
import 'temporary_staff_chat_page.dart';

class AdminChatsPage extends StatefulWidget {
  const AdminChatsPage({super.key});

  @override
  State<AdminChatsPage> createState() => _AdminChatsPageState();
}

class _AdminChatsPageState extends State<AdminChatsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MessageService _messageService = MessageService();
  final TextEditingController searchCtrl = TextEditingController();

  String searchText = '';
  String selectedRole = 'all';

  String? get currentUserId => _auth.currentUser?.uid;

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  String cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String normalizeLower(dynamic value) {
    return cleanText(value).toLowerCase();
  }

  String normalizePhone(dynamic value) {
    return cleanText(value).replaceAll(RegExp(r'[^0-9+]'), '');
  }

  String firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = cleanText(value);

      if (text.isNotEmpty) return text;
    }

    return '';
  }

  String normalizeRole(dynamic value) {
    final role = normalizeLower(value);

    switch (role) {
      case 'nursery':
      case 'nursery staff':
      case 'nursery_staff':
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

      case 'temporary_parent':
      case 'temporary parent':
      case 'ولي أمر زائر':
      case 'ولي الامر الزائر':
      case 'ولي الأمر الزائر':
        return 'temporary_parent';

      default:
        return role;
    }
  }

  bool isLiveStreamStationAccount(Map<String, dynamic> data) {
    final username = normalizeLower(data['username']);
    final email = normalizeLower(data['email']);

    return data['isLiveStreamStation'] == true ||
        username == 'stream_station' ||
        email == 'stream.station@tammni.com';
  }

  String roleLabel(String role) {
    switch (normalizeRole(role)) {
      case 'nursery_staff':
        return 'موظف حضانة';
      case 'parent':
        return 'ولي أمر';
      default:
        return role.trim().isEmpty ? 'مستخدم' : role;
    }
  }

  Color roleColor(String role) {
    switch (normalizeRole(role)) {
      case 'nursery_staff':
        return Colors.orange;
      case 'parent':
        return Colors.teal;
      default:
        return AppColors.primary;
    }
  }

  IconData roleIcon(String role) {
    switch (normalizeRole(role)) {
      case 'nursery_staff':
        return Icons.child_care_rounded;
      case 'parent':
        return Icons.family_restroom_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String firstLetter(String name) {
    final value = name.trim();
    return value.isEmpty ? 'و' : value.substring(0, 1);
  }

  String formatTime(Timestamp timestamp) {
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

  Timestamp? timestampFromDynamic(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);

    return null;
  }

  List<String> userAliases({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    final aliases = <String>[];

    final profileId = firstNonEmpty([
      data['parentProfileId'],
      data['parentRecordId'],
      data['familyId'],
    ]).toLowerCase();

    final phone = normalizePhone(
      firstNonEmpty([
        data['phone'],
        data['mobile'],
        data['phoneNumber'],
        data['parentPhone'],
      ]),
    );

    final username = normalizeLower(data['username']);

    if (profileId.isNotEmpty) aliases.add('profile_$profileId');
    if (phone.isNotEmpty) aliases.add('phone_$phone');
    if (uid.trim().isNotEmpty) aliases.add('uid_${uid.trim()}');
    if (username.isNotEmpty) aliases.add('username_$username');

    return aliases;
  }

  List<String> childAliases(ChildModel child) {
    final aliases = <String>[];

    final profileId = child.resolvedParentProfileId.trim().toLowerCase();
    final phone = normalizePhone(child.resolvedParentPhone);
    final uid = child.resolvedParentUid.trim();
    final username = child.resolvedParentUsername.trim().toLowerCase();

    if (profileId.isNotEmpty) aliases.add('profile_$profileId');
    if (phone.isNotEmpty) aliases.add('phone_$phone');
    if (uid.isNotEmpty) aliases.add('uid_$uid');
    if (username.isNotEmpty) aliases.add('username_$username');

    return aliases;
  }

  Map<String, dynamic> createParentGroup({
    required String key,
    required String name,
  }) {
    return {
      'key': key,
      'kind': 'parent_group',
      'name': name.trim().isEmpty ? 'ولي الأمر' : name.trim(),
      'role': 'parent',
      'subtitle': 'ولي أمر',
      'officialUids': <String>{},
      'usernames': <String>{},
      'emails': <String>{},
      'phones': <String>{},
      'children': <ChildModel>[],
    };
  }

  Future<List<Map<String, dynamic>>> fetchAdminContacts() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) return [];

    final usersSnapshot = await _firestore.collection('users').get();
    final childrenSnapshot = await _firestore.collection('children').get();

    final query = searchText.trim().toLowerCase();

    final staffContacts = <Map<String, dynamic>>[];
    final parentGroups = <String, Map<String, dynamic>>{};
    final aliasToGroupKey = <String, String>{};
    final officialParentUids = <String>{};

    String ensureGroup({
      required List<String> aliases,
      required String fallbackKey,
      required String name,
    }) {
      String? groupKey;

      for (final alias in aliases) {
        final existingKey = aliasToGroupKey[alias];

        if (existingKey != null) {
          groupKey = existingKey;
          break;
        }
      }

      groupKey ??= fallbackKey;

      parentGroups.putIfAbsent(
        groupKey,
        () => createParentGroup(
          key: groupKey!,
          name: name,
        ),
      );

      for (final alias in aliases) {
        aliasToGroupKey[alias] = groupKey;
      }

      return groupKey;
    }

    for (final doc in usersSnapshot.docs) {
      final data = doc.data();
      final role = normalizeRole(data['role']);
      final isActive = (data['isActive'] ?? true) == true;
      final accountStatus = normalizeLower(data['accountStatus']);

      if (!isActive || accountStatus == 'archived') continue;
      if (doc.id == currentUser.uid) continue;
      if (isLiveStreamStationAccount(data)) continue;

      final name = firstNonEmpty([
        data['displayName'],
        data['name'],
        data['fullName'],
        data['username'],
        'مستخدم',
      ]);

      if (role == 'nursery_staff') {
        staffContacts.add({
          'key': 'staff_${doc.id}',
          'kind': 'nursery_staff',
          'uid': doc.id,
          'name': name,
          'username': cleanText(data['username']),
          'email': cleanText(data['email']),
          'role': 'nursery_staff',
          'section': cleanText(data['section']),
        });

        continue;
      }

      if (role != 'parent') continue;

      officialParentUids.add(doc.id);

      final aliases = userAliases(
        uid: doc.id,
        data: data,
      );

      final fallbackKey = aliases.isNotEmpty
          ? aliases.first
          : 'official_parent_${doc.id}';

      final groupKey = ensureGroup(
        aliases: aliases,
        fallbackKey: fallbackKey,
        name: name,
      );

      final group = parentGroups[groupKey]!;
      final uids = group['officialUids'] as Set<String>;
      final usernames = group['usernames'] as Set<String>;
      final emails = group['emails'] as Set<String>;
      final phones = group['phones'] as Set<String>;

      uids.add(doc.id);

      final username = normalizeLower(data['username']);
      final email = normalizeLower(data['email']);
      final phone = normalizePhone(
        firstNonEmpty([
          data['phone'],
          data['mobile'],
          data['phoneNumber'],
          data['parentPhone'],
        ]),
      );

      if (username.isNotEmpty) usernames.add(username);
      if (email.isNotEmpty) emails.add(email);
      if (phone.isNotEmpty) phones.add(phone);
    }

    for (final doc in childrenSnapshot.docs) {
      final child = ChildModel.fromDocument(doc);

      if (!child.isActiveChild) continue;

      final aliases = childAliases(child);

      final fallbackKey = aliases.isNotEmpty
          ? aliases.first
          : 'child_${child.id}';

      final groupKey = ensureGroup(
        aliases: aliases,
        fallbackKey: fallbackKey,
        name: child.displayParentName,
      );

      final group = parentGroups[groupKey]!;
      final children = group['children'] as List<ChildModel>;
      final officialUids = group['officialUids'] as Set<String>;
      final usernames = group['usernames'] as Set<String>;
      final phones = group['phones'] as Set<String>;

      if (!children.any((item) => item.id == child.id)) {
        children.add(child);
      }

      final resolvedUid = child.resolvedParentUid.trim();

      if (officialParentUids.contains(resolvedUid)) {
        officialUids.add(resolvedUid);
      }

      final username = child.resolvedParentUsername.trim().toLowerCase();
      final phone = normalizePhone(child.resolvedParentPhone);

      if (username.isNotEmpty) usernames.add(username);
      if (phone.isNotEmpty) phones.add(phone);

      if (cleanText(group['name']).isEmpty ||
          cleanText(group['name']) == 'ولي الأمر') {
        group['name'] = child.displayParentName;
      }
    }

    final parentContacts = parentGroups.values.toList();

    for (final contact in parentContacts) {
      final children = contact['children'] as List<ChildModel>;
      children.sort((a, b) => a.displayName.compareTo(b.displayName));

      final childrenNames = children
          .map((child) => child.displayName.trim())
          .where((name) => name.isNotEmpty)
          .join('، ');

      final officialUids = contact['officialUids'] is Set<String>
          ? contact['officialUids'] as Set<String>
          : <String>{};

      final isVisitorParent = officialUids.isEmpty &&
          children.isNotEmpty &&
          children.every(
            (child) => child.isTemporaryChild || child.isTrialChild,
          );

      final parentLabel = isVisitorParent ? 'ولي أمر زائر' : 'ولي أمر';

      contact['subtitle'] = childrenNames.isEmpty
          ? parentLabel
          : children.length == 1
              ? '$parentLabel • الطفل: $childrenNames'
              : '$parentLabel • الأطفال: $childrenNames';
    }

    final contacts = <Map<String, dynamic>>[
      ...staffContacts,
      ...parentContacts,
    ].where((contact) {
      final role = normalizeRole(contact['role']);

      if (selectedRole != 'all' && role != selectedRole) {
        return false;
      }

      if (query.isEmpty) return true;

      final children = contact['children'] is List<ChildModel>
          ? contact['children'] as List<ChildModel>
          : <ChildModel>[];

      final childrenNames =
          children.map((child) => child.displayName).join(' ');

      final values = [
        contact['name'],
        contact['username'],
        contact['email'],
        contact['subtitle'],
        childrenNames,
        ...(contact['usernames'] is Set<String>
            ? (contact['usernames'] as Set<String>)
            : <String>{}),
        ...(contact['emails'] is Set<String>
            ? (contact['emails'] as Set<String>)
            : <String>{}),
        ...(contact['phones'] is Set<String>
            ? (contact['phones'] as Set<String>)
            : <String>{}),
      ].join(' ').toLowerCase();

      return values.contains(query);
    }).toList();

    contacts.sort((a, b) {
      final roleA = normalizeRole(a['role']);
      final roleB = normalizeRole(b['role']);

      if (roleA != roleB) {
        if (roleA == 'nursery_staff') return -1;
        if (roleB == 'nursery_staff') return 1;
      }

      return cleanText(a['name']).compareTo(cleanText(b['name']));
    });

    return contacts;
  }

  Future<Map<String, String>> loadTemporaryAccessData(
    ChildModel child,
  ) async {
    String accessCodeId = child.temporaryAccessCodeId.trim();
    String accessCode = child.temporaryAccessCode.trim();

    if (accessCodeId.isEmpty || accessCode.isEmpty) {
      try {
        final childDoc =
            await _firestore.collection('children').doc(child.id).get();

        final data = childDoc.data() ?? <String, dynamic>{};

        accessCodeId = accessCodeId.isEmpty
            ? cleanText(
                data['temporaryAccessCodeId'] ??
                    data['sharedAccessCodeId'] ??
                    data['accessCodeId'],
              )
            : accessCodeId;

        accessCode = accessCode.isEmpty
            ? cleanText(
                data['temporaryAccessCode'] ??
                    data['accessCode'] ??
                    data['code'],
              )
            : accessCode;
      } catch (_) {}
    }

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
              accessCode.isEmpty ? cleanText(data['code']) : accessCode;
        }
      } catch (_) {}
    }

    return {
      'accessCodeId': accessCodeId,
      'accessCode': accessCode,
    };
  }

  Future<String> resolveOfficialParentUid(
    Map<String, dynamic> contact,
  ) async {
    final officialUids = contact['officialUids'] is Set<String>
        ? contact['officialUids'] as Set<String>
        : <String>{};

    if (officialUids.isNotEmpty) {
      return officialUids.first;
    }

    final children = contact['children'] is List<ChildModel>
        ? contact['children'] as List<ChildModel>
        : <ChildModel>[];

    for (final child in children) {
      if (child.isTemporaryChild || child.isTrialChild) continue;

      final uid = child.resolvedParentUid.trim();

      if (uid.isNotEmpty) return uid;
    }

    final usernames = contact['usernames'] is Set<String>
        ? contact['usernames'] as Set<String>
        : <String>{};

    for (final username in usernames) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .where('role', isEqualTo: 'parent')
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs.first.id;
        }
      } catch (_) {}
    }

    return '';
  }

  Future<void> openOfficialParentChat(
    Map<String, dynamic> contact,
  ) async {
    final uid = await resolveOfficialParentUid(contact);

    if (!mounted) return;

    if (uid.isEmpty) {
      showMessage('تعذر العثور على حساب ولي الأمر');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesPage(
          child: null,
          targetRole: 'parent',
          targetUserId: uid,
          targetUserName: cleanText(contact['name']).isEmpty
              ? 'ولي الأمر'
              : cleanText(contact['name']),
          targetSection: 'Nursery',
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  bool contactHasOfficialConversation(
    Map<String, dynamic> contact,
  ) {
    final officialUids = contact['officialUids'] is Set<String>
        ? contact['officialUids'] as Set<String>
        : <String>{};

    if (officialUids.isNotEmpty) return true;

    final children = contact['children'] is List<ChildModel>
        ? contact['children'] as List<ChildModel>
        : <ChildModel>[];

    return children.any((child) {
      return !child.isTemporaryChild && !child.isTrialChild;
    });
  }

  List<ChildModel> temporaryChildrenForContact(
    Map<String, dynamic> contact,
  ) {
    final children = contact['children'] is List<ChildModel>
        ? contact['children'] as List<ChildModel>
        : <ChildModel>[];

    return children.where((child) {
      return child.isTemporaryChild || child.isTrialChild;
    }).toList();
  }

  Future<void> openTemporaryParentChat(
    Map<String, dynamic> contact,
  ) async {
    final children = temporaryChildrenForContact(contact);

    if (children.isEmpty) {
      showMessage('لا توجد محادثة متاحة لولي الأمر');
      return;
    }

    final child = children.first;
    final access = await loadTemporaryAccessData(child);

    if (!mounted) return;

    final accessCodeId = access['accessCodeId'] ?? '';
    final accessCode = access['accessCode'] ?? '';

    if (accessCodeId.trim().isEmpty || accessCode.trim().isEmpty) {
      showMessage('تعذر العثور على رمز دخول ولي الأمر');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemporaryStaffChatPage(
          accessCodeId: accessCodeId,
          accessCode: accessCode,
          childId: child.id,
          childName: child.displayName,
          parentName: child.displayParentName,
          parentPhone: child.resolvedParentPhone,
          groupId: child.groupId,
          groupName: child.displayGroup,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> openParentContact(
    Map<String, dynamic> contact,
  ) async {
    if (contactHasOfficialConversation(contact)) {
      await openOfficialParentChat(contact);
      return;
    }

    await openTemporaryParentChat(contact);
  }

  Future<void> openStaffChat(
    Map<String, dynamic> contact,
  ) async {
    final uid = cleanText(contact['uid']);

    if (uid.isEmpty) {
      showMessage('تعذر العثور على حساب موظف الحضانة');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesPage(
          child: null,
          targetRole: 'nursery_staff',
          targetUserId: uid,
          targetUserName: cleanText(contact['name']).isEmpty
              ? 'موظف حضانة'
              : cleanText(contact['name']),
          targetSection: cleanText(contact['section']).isEmpty
              ? 'Nursery'
              : cleanText(contact['section']),
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> temporaryMessagesStream() {
    return _firestore
        .collection('temporary_messages')
        .limit(500)
        .snapshots();
  }

  bool isTemporaryMessageForAdmin(Map<String, dynamic> data) {
    final fromRole = normalizeRole(data['fromRole']);
    final targetRole = normalizeRole(data['targetRole']);

    final fromParent =
        fromRole == 'temporary_parent' && targetRole == 'admin';

    final fromAdmin =
        fromRole == 'admin' && targetRole == 'temporary_parent';

    return fromParent || fromAdmin;
  }

  String temporaryConversationKeyFromMessage(
    Map<String, dynamic> data,
  ) {
    final storedConversationKey = cleanText(data['conversationKey']);

    if (storedConversationKey.isNotEmpty) {
      return storedConversationKey;
    }

    final accessCodeId = firstNonEmpty([
      data['accessCodeId'],
      data['temporaryAccessCodeId'],
      data['sharedAccessCodeId'],
    ]);

    if (accessCodeId.isNotEmpty) {
      return '${accessCodeId}__admin';
    }

    final childId = cleanText(data['childId']);

    if (childId.isNotEmpty) {
      return 'legacy_child__$childId';
    }

    return '';
  }

  Set<String> temporaryConversationKeysForChild(
    ChildModel child,
  ) {
    final keys = <String>{};

    final accessCodeId = child.temporaryAccessCodeId.trim();

    if (accessCodeId.isNotEmpty) {
      keys.add('${accessCodeId}__admin');
    }

    if (child.id.trim().isNotEmpty) {
      keys.add('legacy_child__${child.id.trim()}');
    }

    return keys;
  }

  Map<String, Map<String, dynamic>>
      latestTemporaryMessagesByConversationKey(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = <String, Map<String, dynamic>>{};

    for (final doc in docs) {
      final data = doc.data();

      if (!isTemporaryMessageForAdmin(data)) continue;

      final conversationKey = temporaryConversationKeyFromMessage(data);

      if (conversationKey.isEmpty) continue;

      final old = result[conversationKey];

      final currentDate = timestampFromDynamic(
            data['createdAt'] ??
                data['sentAt'] ??
                data['time'],
          ) ??
          Timestamp.fromMillisecondsSinceEpoch(0);

      final oldDate = timestampFromDynamic(
            old?['createdAt'] ??
                old?['sentAt'] ??
                old?['time'],
          ) ??
          Timestamp.fromMillisecondsSinceEpoch(0);

      if (old == null || currentDate.compareTo(oldDate) > 0) {
        result[conversationKey] = data;
      }
    }

    return result;
  }

  MessageModel? latestOfficialMessageForContact({
    required Map<String, dynamic> contact,
    required List<MessageModel> messages,
  }) {
    final kind = cleanText(contact['kind']);
    final myUid = currentUserId ?? '';

    final targetUids = <String>{};

    if (kind == 'nursery_staff') {
      final uid = cleanText(contact['uid']);

      if (uid.isNotEmpty) targetUids.add(uid);
    }

    if (kind == 'parent_group' &&
        contact['officialUids'] is Set<String>) {
      targetUids.addAll(contact['officialUids'] as Set<String>);
    }

    if (targetUids.isEmpty) return null;

    MessageModel? latest;

    for (final message in messages) {
      final belongsToContact =
          (message.senderId == myUid &&
                  targetUids.contains(message.receiverId)) ||
              (message.receiverId == myUid &&
                  targetUids.contains(message.senderId));

      if (!belongsToContact) continue;

      if (latest == null || message.sentAt.compareTo(latest.sentAt) > 0) {
        latest = message;
      }
    }

    return latest;
  }

  Map<String, dynamic>? latestTemporaryMessageForContact({
    required Map<String, dynamic> contact,
    required Map<String, Map<String, dynamic>>
        temporaryMessagesByConversationKey,
  }) {
    if (cleanText(contact['kind']) != 'parent_group') return null;

    if (contactHasOfficialConversation(contact)) {
      return null;
    }

    final children = temporaryChildrenForContact(contact);

    Map<String, dynamic>? latest;
    Timestamp? latestTime;

    for (final child in children) {
      final keys = temporaryConversationKeysForChild(child);

      for (final key in keys) {
        final message = temporaryMessagesByConversationKey[key];

        if (message == null) continue;

        final time = timestampFromDynamic(
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
    }

    return latest;
  }

  Timestamp? latestContactTime({
    required MessageModel? officialMessage,
    required Map<String, dynamic>? temporaryMessage,
  }) {
    final officialTime = officialMessage?.sentAt;

    final temporaryTime = timestampFromDynamic(
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

  String previewForContact({
    required MessageModel? officialMessage,
    required Map<String, dynamic>? temporaryMessage,
  }) {
    final officialTime = officialMessage?.sentAt;

    final temporaryTime = timestampFromDynamic(
      temporaryMessage?['createdAt'] ??
          temporaryMessage?['sentAt'] ??
          temporaryMessage?['time'],
    );

    final temporaryMessageType =
        normalizeLower(temporaryMessage?['messageType']);

    final temporaryPreview = temporaryMessageType == 'audio'
        ? 'رسالة صوتية'
        : cleanText(
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

  List<Map<String, dynamic>> sortedContacts({
    required List<Map<String, dynamic>> contacts,
    required List<MessageModel> officialMessages,
    required Map<String, Map<String, dynamic>>
        temporaryMessagesByConversationKey,
  }) {
    final sorted = [...contacts];

    sorted.sort((a, b) {
      final aOfficial = latestOfficialMessageForContact(
        contact: a,
        messages: officialMessages,
      );

      final aTemporary = latestTemporaryMessageForContact(
        contact: a,
        temporaryMessagesByConversationKey:
            temporaryMessagesByConversationKey,
      );

      final bOfficial = latestOfficialMessageForContact(
        contact: b,
        messages: officialMessages,
      );

      final bTemporary = latestTemporaryMessageForContact(
        contact: b,
        temporaryMessagesByConversationKey:
            temporaryMessagesByConversationKey,
      );

      final aTime = latestContactTime(
        officialMessage: aOfficial,
        temporaryMessage: aTemporary,
      );

      final bTime = latestContactTime(
        officialMessage: bOfficial,
        temporaryMessage: bTemporary,
      );

      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime);
      }

      if (aTime != null) return -1;
      if (bTime != null) return 1;

      return cleanText(a['name']).compareTo(cleanText(b['name']));
    });

    return sorted;
  }

  Widget buildSearchCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: searchCtrl,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'ابحث',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchText.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchCtrl.clear();

                          setState(() {
                            searchText = '';
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(
                labelText: 'تصفية حسب الدور',
                prefixIcon: Icon(Icons.filter_list_rounded),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('الكل'),
                ),
                DropdownMenuItem(
                  value: 'nursery_staff',
                  child: Text('موظفو الحضانة'),
                ),
                DropdownMenuItem(
                  value: 'parent',
                  child: Text('أولياء الأمور'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedRole = value ?? 'all';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary.withOpacity(0.10),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'لا توجد جهات اتصال مطابقة حاليًا',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildContactCard({
    required Map<String, dynamic> contact,
    required MessageModel? officialMessage,
    required Map<String, dynamic>? temporaryMessage,
  }) {
    final role = normalizeRole(contact['role']);
    final kind = cleanText(contact['kind']);
    final name = cleanText(contact['name']).isEmpty
        ? roleLabel(role)
        : cleanText(contact['name']);

    final color = roleColor(role);

    final preview = previewForContact(
      officialMessage: officialMessage,
      temporaryMessage: temporaryMessage,
    );

    final time = latestContactTime(
      officialMessage: officialMessage,
      temporaryMessage: temporaryMessage,
    );

    final subtitle = kind == 'parent_group'
        ? cleanText(contact['subtitle'])
        : roleLabel(role);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: kind == 'parent_group'
              ? Text(
                  firstLetter(name),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : Icon(
                  roleIcon(role),
                  color: color,
                ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle.isEmpty ? roleLabel(role) : subtitle,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (time != null)
              Text(
                formatTime(time),
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            const SizedBox(height: 5),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 17,
              color: AppColors.textLight,
            ),
          ],
        ),
        onTap: () async {
          if (kind == 'nursery_staff') {
            await openStaffChat(contact);
          } else {
            await openParentContact(contact);
          }
        },
      ),
    );
  }

  Widget buildChatsList() {
    final uid = currentUserId;

    if (uid == null) {
      return const Center(
        child: Text('تعذر تحميل هوية المستخدم'),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchAdminContacts(),
      builder: (context, contactsSnapshot) {
        if (contactsSnapshot.connectionState == ConnectionState.waiting &&
            !contactsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (contactsSnapshot.hasError) {
          return Center(
            child: Text(
              'حدث خطأ أثناء تحميل جهات الاتصال:\n${contactsSnapshot.error}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final contacts = contactsSnapshot.data ?? [];

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
                  'حدث خطأ أثناء تحميل المحادثات:\n${officialSnapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: temporaryMessagesStream(),
              builder: (context, temporarySnapshot) {
                if (temporarySnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !temporarySnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (temporarySnapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ أثناء تحميل رسائل أولياء الأمور الزائرين:\n'
                      '${temporarySnapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                final officialMessages = officialSnapshot.data ?? [];

                final temporaryMessagesByConversationKey =
                    latestTemporaryMessagesByConversationKey(
                  temporarySnapshot.data?.docs ?? [],
                );

                final sorted = sortedContacts(
                  contacts: contacts,
                  officialMessages: officialMessages,
                  temporaryMessagesByConversationKey:
                      temporaryMessagesByConversationKey,
                );

                if (sorted.isEmpty) {
                  return buildEmptyState();
                }

                return ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final contact = sorted[index];

                    final officialMessage = latestOfficialMessageForContact(
                      contact: contact,
                      messages: officialMessages,
                    );

                    final temporaryMessage =
                        latestTemporaryMessageForContact(
                      contact: contact,
                      temporaryMessagesByConversationKey:
                          temporaryMessagesByConversationKey,
                    );

                    return buildContactCard(
                      contact: contact,
                      officialMessage: officialMessage,
                      temporaryMessage: temporaryMessage,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildSearchCard(),
        const SizedBox(height: 12),
        Expanded(
          child: buildChatsList(),
        ),
      ],
    );
  }
}
