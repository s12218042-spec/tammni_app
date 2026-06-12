import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import 'messages_page.dart';

class ParentChatsPage extends StatefulWidget {
  final List<ChildModel> children;

  const ParentChatsPage({
    super.key,
    required this.children,
  });

  @override
  State<ParentChatsPage> createState() => _ParentChatsPageState();
}

class _ParentChatsPageState extends State<ParentChatsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MessageService _messageService = MessageService();
  final TextEditingController searchCtrl = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  late Future<List<Map<String, dynamic>>> _allowedPeopleFuture;
  Stream<List<MessageModel>>? _latestChatsStream;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _allowedPeopleFuture = fetchAllowedPeople();

    final uid = currentUserId;
    if (uid != null && uid.trim().isNotEmpty) {
      _latestChatsStream = _messageService.getLatestChatsForUser(
        currentUserId: uid,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ParentChatsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldIds = oldWidget.children.map((child) => child.id).toSet();
    final newIds = widget.children.map((child) => child.id).toSet();

    if (oldIds.length != newIds.length || !oldIds.containsAll(newIds)) {
      _allowedPeopleFuture = fetchAllowedPeople();
    }
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  List<ChildModel> get activeChildren => widget.children;

  bool isNurseryRole(String role) {
    final value = role.trim().toLowerCase();
    return value == 'nursery' ||
        value == 'nursery_staff' ||
        value == 'nursery staff' ||
        value == 'staff' ||
        value == 'employee' ||
        value == 'teacher';
  }

  String normalizeRole(String role) {
    final value = role.trim().toLowerCase();

    if (value == 'nursery' ||
        value == 'nursery staff' ||
        value == 'nursery_staff' ||
        value == 'staff' ||
        value == 'employee' ||
        value == 'teacher') {
      return 'nursery_staff';
    }

    if (value == 'admin') return 'admin';
    if (value == 'parent') return 'parent';

    return value;
  }

  String _normalizeSearchText(dynamic value) {
    var text = (value ?? '').toString().trim().toLowerCase();

    const arabicDiacritics = r'[\u064B-\u065F\u0670\u06D6-\u06ED]';

    text = text
        .replaceAll(RegExp(arabicDiacritics), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ـ', '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return text;
  }

  bool _matchesSearchQuery({
    required String query,
    required List<dynamic> values,
  }) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) return true;

    final combined = values
        .map(_normalizeSearchText)
        .where((value) => value.isNotEmpty)
        .join(' ');

    return combined.contains(normalizedQuery);
  }

  bool looksLikeAdminChat({
    required String role,
    required String name,
  }) {
    final normalizedRole = normalizeRole(role);
    final cleanName = _normalizeSearchText(name);

    return normalizedRole == 'admin' ||
        cleanName == 'admin' ||
        cleanName == 'الاداره';
  }

  String roleLabel(String role) {
    final normalized = normalizeRole(role);

    if (normalized == 'nursery_staff') return 'موظف حضانة';
    if (normalized == 'admin') return 'الإدارة';
    if (normalized == 'parent') return 'ولي أمر';

    return role.trim().isEmpty ? 'مستخدم' : role;
  }

  Color sectionColor() {
    return const Color(0xFFEFA7C8);
  }

  IconData roleIcon(String role) {
    final normalized = normalizeRole(role);

    if (normalized == 'nursery_staff') return Icons.child_care_outlined;
    if (normalized == 'admin') return Icons.business_outlined;
    if (normalized == 'parent') return Icons.person_outline;

    return Icons.person_outline;
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

  bool childBelongsToCurrentParent(String childId) {
    final cleanChildId = childId.trim();
    if (cleanChildId.isEmpty) return false;

    return activeChildren.any((child) => child.id == cleanChildId);
  }

  ChildModel pickChildForMessage(MessageModel message) {
    for (final child in activeChildren) {
      if (child.id == message.childId) {
        return child;
      }
    }

    return activeChildren.first;
  }

  String childSubtitleForConversation({
    required MessageModel message,
    required String targetRole,
    required bool isAdminChat,
  }) {
    if (isAdminChat) return 'الإدارة';

    return roleLabel(targetRole);
  }

  String conversationKeyForMessage(MessageModel message) {
    final currentId = currentUserId ?? '';

    final senderRole = normalizeRole(message.senderRole);
    final receiverRole = normalizeRole(message.receiverRole);

    final isParentSender = message.senderId == currentId || senderRole == 'parent';

    final otherUserId = isParentSender ? message.receiverId : message.senderId;
    final otherUserName =
        isParentSender ? message.receiverName : message.senderName;
    final otherRole = isParentSender ? receiverRole : senderRole;

    final isAdminChat = looksLikeAdminChat(
      role: otherRole,
      name: otherUserName,
    );

    if (isAdminChat || otherRole == 'admin') {
      return 'admin_chat';
    }

    return '${otherRole}_${otherUserId.trim()}';
  }

  List<MessageModel> deduplicateRecentChats(List<MessageModel> rawMessages) {
    final Map<String, MessageModel> uniqueChats = {};

    for (final message in rawMessages) {
      final key = conversationKeyForMessage(message);
      final oldMessage = uniqueChats[key];

      if (oldMessage == null ||
          message.sentAt.compareTo(oldMessage.sentAt) > 0) {
        uniqueChats[key] = message;
      }
    }

    final chats = uniqueChats.values.toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

    return chats;
  }

  Future<List<Map<String, dynamic>>> fetchAllowedPeople() async {
    if (activeChildren.isEmpty) return [];

    final usersSnapshot = await _firestore.collection('users').get();

    Map<String, dynamic>? userDataById(String uid) {
      for (final doc in usersSnapshot.docs) {
        if (doc.id == uid) return doc.data();
      }
      return null;
    }

    final people = <Map<String, dynamic>>[];

    for (final doc in usersSnapshot.docs) {
      final data = doc.data();
      final role = normalizeRole((data['role'] ?? '').toString());
      final isActive = (data['isActive'] ?? true) == true;

      if (!isActive) continue;
      if (doc.id == currentUserId) continue;
      if (role != 'admin') continue;

      people.add({
        'id': doc.id,
        'displayName':
            data['displayName'] ?? data['name'] ?? data['username'] ?? 'الإدارة',
        'username': data['username'] ?? '',
        'email': data['email'] ?? '',
        'role': 'admin',
        'section': data['section'] ?? '',
        'isActive': true,
        'childId': '',
        'childName': '',
      });
    }

    final addedStaffKeys = <String>{};

    for (final child in activeChildren) {
      final staffUid = child.assignedStaffUid.trim();
      if (staffUid.isEmpty) continue;

      final key = staffUid;
      if (addedStaffKeys.contains(key)) continue;
      addedStaffKeys.add(key);

      final staffData = userDataById(staffUid) ?? <String, dynamic>{};

      final childStaffName = child.assignedStaffName.trim();
      final staffName = childStaffName.isNotEmpty
          ? childStaffName
          : (staffData['displayName'] ??
                  staffData['name'] ??
                  staffData['username'] ??
                  'موظف حضانة')
              .toString();

      final username = child.assignedStaffUsername.trim().isNotEmpty
          ? child.assignedStaffUsername.trim()
          : (staffData['username'] ?? '').toString();

      people.add({
        'id': staffUid,
        'displayName': staffName,
        'username': username,
        'email': staffData['email'] ?? '',
        'role': 'nursery_staff',
        'section': staffData['section'] ?? 'Nursery',
        'isActive': true,
        'childId': child.id,
        'childName': child.name,
      });
    }

    people.sort((a, b) {
      final roleA = normalizeRole((a['role'] ?? '').toString());
      final roleB = normalizeRole((b['role'] ?? '').toString());

      if (roleA != roleB) {
        if (roleA == 'admin') return -1;
        if (roleB == 'admin') return 1;
      }

      final childA = (a['childName'] ?? '').toString();
      final childB = (b['childName'] ?? '').toString();
      final childCompare = childA.compareTo(childB);
      if (childCompare != 0) return childCompare;

      final nameA = (a['displayName'] ?? '').toString();
      final nameB = (b['displayName'] ?? '').toString();
      return nameA.compareTo(nameB);
    });

    return people;
  }

  List<Map<String, dynamic>> filterAllowedPeople(
    List<Map<String, dynamic>> people,
    String query,
  ) {
    return people.where((person) {
      return _matchesSearchQuery(
        query: query,
        values: [
          person['displayName'],
          person['username'],
          person['email'],
          person['childName'],
          roleLabel((person['role'] ?? '').toString()),
        ],
      );
    }).toList();
  }

  String contactKeyFromPerson(Map<String, dynamic> person) {
    final role = normalizeRole((person['role'] ?? '').toString());
    final id = (person['id'] ?? '').toString().trim();

    if (role == 'admin') return 'admin_chat';

    return '${role}_$id';
  }

  String contactKeyFromMessage(MessageModel message) {
    final currentId = currentUserId ?? '';

    final senderRole = normalizeRole(message.senderRole);
    final receiverRole = normalizeRole(message.receiverRole);

    final isParentSender = message.senderId == currentId || senderRole == 'parent';

    final otherUserId = isParentSender ? message.receiverId : message.senderId;
    final otherUserName =
        isParentSender ? message.receiverName : message.senderName;
    final otherRole = isParentSender ? receiverRole : senderRole;

    final isAdminChat = looksLikeAdminChat(
      role: otherRole,
      name: otherUserName,
    );

    if (isAdminChat || otherRole == 'admin') return 'admin_chat';

    return '${otherRole}_${otherUserId.trim()}';
  }

  Widget buildRecentChatCard(MessageModel message) {
    if (activeChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentId = currentUserId ?? '';

    final senderRole = normalizeRole(message.senderRole);
    final receiverRole = normalizeRole(message.receiverRole);

    final isParentSender = message.senderId == currentId || senderRole == 'parent';

    final targetUserId = isParentSender ? message.receiverId : message.senderId;
    final targetUserName =
        isParentSender ? message.receiverName : message.senderName;
    final targetRole = isParentSender ? receiverRole : senderRole;

    final isAdminChat = looksLikeAdminChat(
      role: targetRole,
      name: targetUserName,
    );

    const targetSection = 'Nursery';
    final color = sectionColor();

    final displayName = isAdminChat
        ? 'الإدارة'
        : targetUserName.trim().isEmpty
            ? 'بدون اسم'
            : targetUserName.trim();

    final subtitle = childSubtitleForConversation(
      message: message,
      targetRole: targetRole,
      isAdminChat: isAdminChat,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MessagesPage(
                child: activeChildren.first,
                targetRole: isAdminChat ? 'admin' : targetRole,
                targetUserId: targetUserId,
                targetUserName: displayName,
                targetSection: targetSection,
              ),
            ),
          );

          if (!mounted) return;
          setState(() {});
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(
                isAdminChat ? Icons.business_outlined : roleIcon(targetRole),
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (subtitle.trim().isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (subtitle.trim().isNotEmpty) const SizedBox(height: 6),
                  Text(
                    message.displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatTime(message.sentAt),
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
    );
  }

  Widget buildPersonCard(Map<String, dynamic> person) {
    if (activeChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    final name = (person['displayName'] ?? '').toString();
    final role = normalizeRole((person['role'] ?? '').toString());
    const section = 'Nursery';

    final color = sectionColor();
    final isAdmin = role == 'admin';
    final displayName =
        name.isEmpty ? (isAdmin ? 'الإدارة' : 'بدون اسم') : name;

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
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MessagesPage(
                child: activeChildren.first,
                targetRole: isAdmin ? 'admin' : role,
                targetUserId: (person['id'] ?? '').toString(),
                targetUserName: displayName,
                targetSection: section,
              ),
            ),
          );

          if (!mounted) return;
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: color.withValues(alpha: 0.14),
                child: Icon(
                  roleIcon(role),
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAdmin ? 'الإدارة' : 'موظف حضانة',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
  }

  Widget buildSearchHeader() {
    return TextField(
      controller: searchCtrl,
      focusNode: searchFocusNode,
      textAlign: TextAlign.right,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'ابحث',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: searchCtrl.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  searchCtrl.clear();
                  setState(() {});
                  searchFocusNode.requestFocus();
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }

  Widget buildRecentChatsTab() {
    final latestChatsStream = _latestChatsStream;

    if (latestChatsStream == null) {
      return const Center(
        child: Text('تعذر تحميل هوية المستخدم'),
      );
    }

    return StreamBuilder<List<MessageModel>>(
      stream: latestChatsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('تعذر تحميل المحادثات'),
          );
        }

        final searchText = searchCtrl.text;

        final rawChats = (snapshot.data ?? []).where((message) {
          final senderRole = normalizeRole(message.senderRole);
          final receiverRole = normalizeRole(message.receiverRole);

          final senderIsParent =
              message.senderId == currentUserId || senderRole == 'parent';
          final receiverIsParent =
              message.receiverId == currentUserId || receiverRole == 'parent';

          final includesCurrentParent = senderIsParent || receiverIsParent;

          if (!includesCurrentParent) return false;
          if (activeChildren.isEmpty) return false;

          final otherRole = senderIsParent ? receiverRole : senderRole;
          final otherName = senderIsParent ? message.receiverName : message.senderName;

          final isAdminChat = looksLikeAdminChat(
            role: otherRole,
            name: otherName,
          );

          final allowedOtherRole =
              isNurseryRole(otherRole) || isAdminChat || otherRole == 'admin';

          if (!allowedOtherRole) return false;

          if (!childBelongsToCurrentParent(message.childId)) {
            return false;
          }

          final childName = pickChildForMessage(message).name;

          return _matchesSearchQuery(
            query: searchText,
            values: [
              otherName,
              message.displayText,
              childName,
              roleLabel(otherRole),
              message.senderName,
              message.receiverName,
            ],
          );
        }).toList();

        final chats = deduplicateRecentChats(rawChats);
        final chatKeys = chats.map(contactKeyFromMessage).toSet();

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _allowedPeopleFuture,
          builder: (context, peopleSnapshot) {
            final allPeople = peopleSnapshot.data ?? [];
            final people = filterAllowedPeople(allPeople, searchText);

            final extraPeople = people.where((person) {
              return !chatKeys.contains(contactKeyFromPerson(person));
            }).toList();

            if (peopleSnapshot.connectionState == ConnectionState.waiting &&
                chats.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (chats.isEmpty && extraPeople.isEmpty) {
              return const Center(
                child: Text(
                  'لا توجد نتائج مطابقة',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                ...chats.map(buildRecentChatCard),
                ...extraPeople.map(buildPersonCard),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            buildSearchHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: buildRecentChatsTab(),
            ),
          ],
        ),
      ),
    );
  }
}
