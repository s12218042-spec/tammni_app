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

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  List<ChildModel> get activeChildren => widget.children;

  List<ChildModel> get nurseryChildren => activeChildren;

  bool isNurseryRole(String role) {
    final value = role.trim().toLowerCase();
    return value == 'nursery' ||
        value == 'nursery_staff' ||
        value == 'nursery staff';
  }

  String normalizeRole(String role) {
    final value = role.trim().toLowerCase();

    if (value == 'nursery' ||
        value == 'nursery staff' ||
        value == 'nursery_staff') {
      return 'nursery_staff';
    }

    if (value == 'admin') return 'admin';
    if (value == 'parent') return 'parent';

    return value;
  }

  bool looksLikeAdminChat({
    required String role,
    required String name,
  }) {
    final normalizedRole = normalizeRole(role);
    final cleanName = name.trim().toLowerCase();

    return normalizedRole == 'admin' ||
        cleanName == 'admin' ||
        cleanName == 'الإدارة' ||
        cleanName == 'ادارة' ||
        cleanName == 'الإداره';
  }

  String roleLabel(String role) {
    final normalized = normalizeRole(role);

    if (normalized == 'nursery_staff') return 'موظفة حضانة';
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

  ChildModel pickChildForPerson(Map<String, dynamic> person) {
    final role = normalizeRole((person['role'] ?? '').toString());

    if (role == 'admin') {
      return activeChildren.first;
    }

    final childId = (person['childId'] ?? '').toString().trim();

    for (final child in nurseryChildren) {
      if (child.id == childId) {
        return child;
      }
    }

    if (nurseryChildren.isNotEmpty) {
      return nurseryChildren.first;
    }

    return activeChildren.first;
  }

  ChildModel pickChildForMessage(MessageModel message) {
    for (final child in activeChildren) {
      if (child.id == message.childId) {
        return child;
      }
    }

    return activeChildren.first;
  }

  ChildModel resolveChildForConversation({
    required MessageModel message,
    required bool isAdminChat,
  }) {
    if (activeChildren.isEmpty) {
      throw StateError('لا يوجد أطفال مرتبطون بحساب ولي الأمر');
    }

    if (isAdminChat) {
      return activeChildren.first;
    }

    if (childBelongsToCurrentParent(message.childId)) {
      return pickChildForMessage(message);
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

    final searchText = searchCtrl.text.trim().toLowerCase();
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
        'displayName': data['displayName'] ?? data['name'] ?? data['username'] ?? 'الإدارة',
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
                  'موظفة حضانة')
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

    final filtered = people.where((person) {
      if (searchText.isEmpty) return true;

      final name = (person['displayName'] ?? '').toString().toLowerCase();
      final username = (person['username'] ?? '').toString().toLowerCase();
      final childName = (person['childName'] ?? '').toString().toLowerCase();
      final role = roleLabel((person['role'] ?? '').toString()).toLowerCase();

      return name.contains(searchText) ||
          username.contains(searchText) ||
          childName.contains(searchText) ||
          role.contains(searchText);
    }).toList();

    filtered.sort((a, b) {
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

    return filtered;
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

    final childForChat = resolveChildForConversation(
      message: message,
      isAdminChat: isAdminChat,
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
              child: isAdminChat ? null : childForChat,
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
                isAdminChat
                    ? Icons.business_outlined
                    : roleIcon(targetRole),
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
                    message.text,
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
    final childForChat = pickChildForPerson(person);
    final isAdmin = role == 'admin';

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
                  name.isEmpty
                      ? (isAdmin ? 'الإدارة' : 'بدون اسم')
                      : name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAdmin ? 'الإدارة' : 'موظفة حضانة',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MessagesPage(
                  child: isAdmin ? null : childForChat,
                  targetRole: isAdmin ? 'admin' : role,
                  targetUserId: (person['id'] ?? '').toString(),
                  targetUserName: name.isEmpty
                      ? (isAdmin ? 'الإدارة' : 'بدون اسم')
                      : name,
                  targetSection: section,
                ),
                ),
              );

              if (!mounted) return;
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.send_outlined,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget buildSearchHeader() {
    return TextField(
      controller: searchCtrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'البحث',
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
      ),
    );
  }


  Widget buildRecentChatsTab() {
    if (currentUserId == null) {
      return const Center(
        child: Text('تعذر تحميل هوية المستخدم'),
      );
    }

    return StreamBuilder<List<MessageModel>>(
      stream: _messageService.getLatestChatsForUser(
        currentUserId: currentUserId!,
      ),
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

        final searchText = searchCtrl.text.trim().toLowerCase();

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
          final otherName =
              senderIsParent ? message.receiverName : message.senderName;


          final isAdminChat = looksLikeAdminChat(
            role: otherRole,
            name: otherName,
          );

          final allowedOtherRole =
              isNurseryRole(otherRole) || isAdminChat || otherRole == 'admin';

          if (!allowedOtherRole) return false;
          if (searchText.isEmpty) return true;

          final childName = childBelongsToCurrentParent(message.childId)
              ? pickChildForMessage(message).name.toLowerCase()
              : '';
          final messageText = message.text.toLowerCase();
          final otherNameText = otherName.toLowerCase();
          final roleText = roleLabel(otherRole).toLowerCase();

          return otherNameText.contains(searchText) ||
              messageText.contains(searchText) ||
              childName.contains(searchText) ||
              roleText.contains(searchText);
        }).toList();

        final chats = deduplicateRecentChats(rawChats);
        final chatKeys = chats.map(contactKeyFromMessage).toSet();

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchAllowedPeople(),
          builder: (context, peopleSnapshot) {
            final people = peopleSnapshot.data ?? [];
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
                  'لا توجد محادثات',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            return ListView(
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