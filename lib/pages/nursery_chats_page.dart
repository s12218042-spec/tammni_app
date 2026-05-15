import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'messages_page.dart';

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

  String selectedTab = 'recent';

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  List<ChildModel> get activeChildren => widget.children;

  bool isNurseryRole(String role) {
    final value = role.trim().toLowerCase();
    return value == 'nursery' ||
        value == 'nursery_staff' ||
        value == 'nursery staff';
  }

  String normalizeRole(String role) {
    final value = role.trim().toLowerCase();

    if (value == 'nursery' ||
        value == 'nursery_staff' ||
        value == 'nursery staff') {
      return 'nursery_staff';
    }

    if (value == 'admin') return 'admin';
    if (value == 'parent') return 'parent';

    return value;
  }

  bool looksLikeAdminChat({
    required String role,
    required String name,
    required String userId,
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

    if (normalized == 'admin') return 'الإدارة';
    if (normalized == 'parent') return 'ولي الأمر';
    if (normalized == 'nursery_staff') return 'موظفة حضانة';

    return role.trim().isEmpty ? 'مستخدم' : role;
  }

  IconData roleIcon(String role) {
    final normalized = normalizeRole(role);

    if (normalized == 'admin') return Icons.admin_panel_settings_outlined;
    if (normalized == 'parent') return Icons.person_outline;
    if (normalized == 'nursery_staff') return Icons.child_care_outlined;

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

  String firstLetter(String name) {
    if (name.trim().isEmpty) return 'و';
    return name.trim().substring(0, 1);
  }

  List<ChildModel> childrenForParentUid(String parentUid) {
    final cleanUid = parentUid.trim();

    if (cleanUid.isEmpty) return [];

    return activeChildren.where((child) {
      return child.parentUid.trim() == cleanUid;
    }).toList();
  }

  List<ChildModel> childrenForParentUsername(String parentUsername) {
    final cleanUsername = parentUsername.trim().toLowerCase();

    if (cleanUsername.isEmpty) return [];

    return activeChildren.where((child) {
      return child.parentUsername.trim().toLowerCase() == cleanUsername;
    }).toList();
  }

  ChildModel pickChildForParentUsername(String parentUsername) {
    final children = childrenForParentUsername(parentUsername);

    if (children.isNotEmpty) {
      return children.first;
    }

    return activeChildren.first;
  }

  ChildModel pickChildForMessage(MessageModel message) {
    try {
      return activeChildren.firstWhere((child) => child.id == message.childId);
    } catch (_) {
      return activeChildren.first;
    }
  }

  ChildModel resolveChildForConversation({
    required MessageModel message,
    required String targetRole,
    required String targetUserId,
    required String targetUserName,
  }) {
    final normalizedTargetRole = normalizeRole(targetRole);

    if (normalizedTargetRole != 'parent') {
      return pickChildForMessage(message);
    }

    var parentChildren = childrenForParentUid(targetUserId);

    if (parentChildren.isEmpty) {
      parentChildren = childrenForParentUsername(targetUserName);
    }

    if (parentChildren.isEmpty) {
      return pickChildForMessage(message);
    }

    for (final child in parentChildren) {
      if (child.id == message.childId) {
        return child;
      }
    }

    return parentChildren.first;
  }

  String childSubtitleForConversation({
    required MessageModel message,
    required String targetRole,
    required String targetUserId,
    required String targetUserName,
    required bool isAdminChat,
  }) {
    if (isAdminChat) return 'الإدارة';

    final normalizedTargetRole = normalizeRole(targetRole);

    if (normalizedTargetRole != 'parent') {
      return '';
    }

    var parentChildren = childrenForParentUid(targetUserId);

    if (parentChildren.isEmpty) {
      parentChildren = childrenForParentUsername(targetUserName);
    }

    if (parentChildren.isEmpty) {
      return 'ولي أمر';
    }

    for (final child in parentChildren) {
      if (child.id == message.childId) {
        return 'بخصوص ${child.name}';
      }
    }

    if (parentChildren.length == 1) {
      return 'بخصوص ${parentChildren.first.name}';
    }

    final names = parentChildren
        .map((child) => child.name.trim())
        .where((name) => name.isNotEmpty)
        .take(3)
        .join(' و ');

    return names.isEmpty ? 'بخصوص أكثر من طفل' : 'بخصوص $names';
  }

  String conversationKeyForMessage(MessageModel message) {
    final senderRole = normalizeRole(message.senderRole);
    final receiverRole = normalizeRole(message.receiverRole);

    final isNurserySender = isNurseryRole(senderRole);

    final otherUserId = isNurserySender ? message.receiverId : message.senderId;
    final otherUserName =
        isNurserySender ? message.receiverName : message.senderName;
    final otherRole = isNurserySender ? receiverRole : senderRole;

    final isAdminChat = looksLikeAdminChat(
      role: otherRole,
      name: otherUserName,
      userId: otherUserId,
    );

    if (isAdminChat) return 'admin_chat';

    if (otherRole == 'parent') {
      var parentChildren = childrenForParentUid(otherUserId);

      if (parentChildren.isEmpty) {
        parentChildren = childrenForParentUsername(otherUserName);
      }

      final childBelongsToParent =
          parentChildren.any((child) => child.id == message.childId);

      if (childBelongsToParent) {
        return 'parent_${otherUserId.trim()}_${message.childId.trim()}';
      }

      if (parentChildren.isNotEmpty) {
        final ownedChildIds = parentChildren.map((c) => c.id).join('_');
        return 'parent_${otherUserId.trim()}_$ownedChildIds';
      }
    }

    return '${otherRole}_${otherUserId.trim()}_${message.childId.trim()}';
  }

  Future<List<Map<String, dynamic>>> fetchParents() async {
    final parentUsernames = activeChildren
        .map((c) => c.parentUsername.trim().toLowerCase())
        .where((u) => u.isNotEmpty)
        .toSet()
        .toList();

    if (parentUsernames.isEmpty) return [];

    final snapshot = await _firestore.collection('users').get();
    final searchText = searchCtrl.text.trim().toLowerCase();

    final results = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'displayName': data['displayName'] ?? data['name'] ?? '',
        'username': data['username'] ?? '',
        'email': data['email'] ?? '',
        'role': data['role'] ?? '',
        'isActive': data['isActive'] ?? true,
      };
    }).where((user) {
      final role = normalizeRole((user['role'] ?? '').toString());
      final username = (user['username'] ?? '').toString().trim().toLowerCase();
      final displayName =
          (user['displayName'] ?? '').toString().trim().toLowerCase();
      final isActive = (user['isActive'] ?? true) == true;

      if (!isActive) return false;
      if (role != 'parent') return false;
      if (!parentUsernames.contains(username)) return false;

      if (searchText.isEmpty) return true;

      return username.contains(searchText) || displayName.contains(searchText);
    }).toList();

    results.sort((a, b) {
      final aName = (a['displayName'] ?? '').toString();
      final bName = (b['displayName'] ?? '').toString();
      return aName.compareTo(bName);
    });

    return results;
  }

  Widget buildTopTab({
    required String label,
    required String value,
  }) {
    final isSelected = selectedTab == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppColors.secondary
                  : AppColors.primary.withOpacity(0.16),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDark,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildRecentChatCard(MessageModel message) {
    final senderRole = normalizeRole(message.senderRole);
    final receiverRole = normalizeRole(message.receiverRole);

    final isNurserySender = isNurseryRole(senderRole);

    final targetUserId = isNurserySender ? message.receiverId : message.senderId;
    final targetUserName =
        isNurserySender ? message.receiverName : message.senderName;
    final targetRole = isNurserySender ? receiverRole : senderRole;

    final isAdminChat = looksLikeAdminChat(
      role: targetRole,
      name: targetUserName,
      userId: targetUserId,
    );

    final childForChat = resolveChildForConversation(
      message: message,
      targetRole: targetRole,
      targetUserId: targetUserId,
      targetUserName: targetUserName,
    );

    final displayName = isAdminChat
        ? 'الإدارة'
        : targetUserName.trim().isEmpty
            ? 'ولي الأمر'
            : targetUserName.trim();

    final subtitle = childSubtitleForConversation(
      message: message,
      targetRole: targetRole,
      targetUserId: targetUserId,
      targetUserName: targetUserName,
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
            color: Colors.black.withOpacity(0.04),
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
                child: childForChat,
                targetRole: isAdminChat ? 'admin' : 'parent',
                targetUserId: targetUserId,
                targetUserName: displayName,
                targetSection: 'Nursery',
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
              backgroundColor: const Color(0xFFEFA7C8).withOpacity(0.14),
              child: Icon(
                isAdminChat
                    ? Icons.admin_panel_settings_outlined
                    : roleIcon(targetRole),
                color: const Color(0xFFEFA7C8),
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

  Widget buildParentCard(Map<String, dynamic> parent) {
    final parentName = (parent['displayName'] ?? '').toString();
    final parentUsername = (parent['username'] ?? '').toString();
    final childForChat = pickChildForParentUsername(parentUsername);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFFEFA7C8).withOpacity(0.14),
            child: Text(
              firstLetter(parentName),
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
                  parentName.isEmpty ? 'ولي الأمر' : parentName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اسم المستخدم: $parentUsername',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'المحادثة عبر الطفل: ${childForChat.name}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFFEFA7C8),
                    fontWeight: FontWeight.w700,
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
                    child: childForChat,
                    targetRole: 'parent',
                    targetUserId: (parent['id'] ?? '').toString(),
                    targetUserName:
                        parentName.isEmpty ? 'ولي الأمر' : parentName,
                    targetSection: 'Nursery',
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

  List<MessageModel> _deduplicateRecentChats(List<MessageModel> rawMessages) {
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
          return Center(
            child: Text(
              'حدث خطأ أثناء تحميل المحادثات: ${snapshot.error}',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        final rawChats = (snapshot.data ?? []).where((message) {
          final senderRole = normalizeRole(message.senderRole);
          final receiverRole = normalizeRole(message.receiverRole);

          final senderIsAdmin = looksLikeAdminChat(
            role: senderRole,
            name: message.senderName,
            userId: message.senderId,
          );

          final receiverIsAdmin = looksLikeAdminChat(
            role: receiverRole,
            name: message.receiverName,
            userId: message.receiverId,
          );

          final includesNursery =
              isNurseryRole(senderRole) || isNurseryRole(receiverRole);

          final includesParent =
              senderRole == 'parent' || receiverRole == 'parent';

          final includesAdmin = senderIsAdmin || receiverIsAdmin;

          return includesNursery && (includesAdmin || includesParent);
        }).toList();

        final chats = _deduplicateRecentChats(rawChats);

        if (chats.isEmpty) {
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
                    'لا توجد محادثات بعد',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'عندما تبدأ أول محادثة مع ولي أمر أو الإدارة ستظهر هنا',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textLight,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            return buildRecentChatCard(chats[index]);
          },
        );
      },
    );
  }

  Widget buildSearchTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
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
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.secondary.withOpacity(0.14),
                    child: const Icon(
                      Icons.person_search_outlined,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'البحث عن أولياء الأمور',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'تظهر لك أولياء أمور أطفال مجموعتك النشطين',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو اسم المستخدم...',
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchParents(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'حدث خطأ أثناء تحميل أولياء الأمور: ${snapshot.error}',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final parents = snapshot.data ?? [];

              if (parents.isEmpty) {
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
                          Icons.person_search_outlined,
                          size: 52,
                          color: AppColors.textLight,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'لا توجد نتائج',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'لم يتم العثور على أولياء أمور مطابقين للبحث',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: parents.length,
                itemBuilder: (context, index) {
                  return buildParentCard(parents[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'المراسلات',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              buildTopTab(label: 'المحادثات', value: 'recent'),
              const SizedBox(width: 10),
              buildTopTab(label: 'البحث', value: 'search'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: selectedTab == 'recent'
                ? buildRecentChatsTab()
                : buildSearchTab(),
          ),
        ],
      ),
    );
  }
}