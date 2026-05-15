import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
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

  String selectedFilter = 'all';
  String selectedTab = 'recent';

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshPage() async {
    if (!mounted) return;
    setState(() {});
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

  String sectionLabel(String section) {
    return 'حضانة';
  }

  String roleLabel(String role) {
    final normalized = normalizeRole(role);

    if (normalized == 'nursery_staff') return 'موظفة حضانة';
    if (normalized == 'admin') return 'الإدارة';
    if (normalized == 'parent') return 'ولي أمر';

    return role.trim().isEmpty ? 'مستخدم' : role;
  }

  Color sectionColor(String section) {
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

  String firstLetter(String name) {
    if (name.trim().isEmpty) return 'م';
    return name.trim().substring(0, 1);
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
    required String targetRole,
    required String targetUserId,
    required String targetUserName,
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
    required String targetUserId,
    required String targetUserName,
    required bool isAdminChat,
  }) {
    if (isAdminChat) return 'الإدارة';

    final normalizedTargetRole = normalizeRole(targetRole);

    if (normalizedTargetRole == 'admin') {
      return 'الإدارة';
    }

    if (activeChildren.isEmpty) {
      return roleLabel(targetRole);
    }

    if (childBelongsToCurrentParent(message.childId)) {
      final child = pickChildForMessage(message);
      return '${roleLabel(targetRole)} • بخصوص ${child.name}';
    }

    if (activeChildren.length == 1) {
      return '${roleLabel(targetRole)} • بخصوص ${activeChildren.first.name}';
    }

    final names = activeChildren
        .map((child) => child.name.trim())
        .where((name) => name.isNotEmpty)
        .take(3)
        .join(' و ');

    return names.isEmpty
        ? '${roleLabel(targetRole)} • بخصوص أكثر من طفل'
        : '${roleLabel(targetRole)} • بخصوص $names';
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
      userId: otherUserId,
    );

    if (isAdminChat || otherRole == 'admin') {
      return 'admin_chat';
    }

    if (childBelongsToCurrentParent(message.childId)) {
      return '${otherRole}_${otherUserId.trim()}_${message.childId.trim()}';
    }

    if (activeChildren.isNotEmpty) {
      final ownedChildIds = activeChildren.map((child) => child.id).join('_');
      return '${otherRole}_${otherUserId.trim()}_$ownedChildIds';
    }

    return '${otherRole}_${otherUserId.trim()}_${message.childId.trim()}';
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
        'section': data['section'] ?? '',
        'isActive': data['isActive'] ?? true,
      };
    }).where((person) {
      final id = (person['id'] ?? '').toString();
      final role = normalizeRole((person['role'] ?? '').toString());
      final section = (person['section'] ?? '').toString().trim();
      final name = (person['displayName'] ?? '').toString().toLowerCase();
      final username = (person['username'] ?? '').toString().toLowerCase();
      final isActive = (person['isActive'] ?? true) == true;

      if (!isActive) return false;
      if (id == currentUserId) return false;

      final allowedRole = isNurseryRole(role) || role == 'admin';
      if (!allowedRole) return false;

      if (role == 'admin') {
        if (selectedFilter == 'nursery') return false;
      } else {
        if (section.isNotEmpty && section != 'Nursery') return false;
        if (selectedFilter == 'admin') return false;
      }

      if (searchText.isEmpty) return true;

      return name.contains(searchText) || username.contains(searchText);
    }).toList();

    results.sort((a, b) {
      final roleA = normalizeRole((a['role'] ?? '').toString());
      final roleB = normalizeRole((b['role'] ?? '').toString());

      if (roleA != roleB) {
        if (roleA == 'admin') return -1;
        if (roleB == 'admin') return 1;
      }

      final nameA = (a['displayName'] ?? '').toString();
      final nameB = (b['displayName'] ?? '').toString();
      return nameA.compareTo(nameB);
    });

    return results;
  }

  bool matchesRecentFilter(MessageModel message) {
    if (selectedFilter == 'all') return true;

    final currentId = currentUserId ?? '';

    final senderRole = normalizeRole(message.senderRole);
    final receiverRole = normalizeRole(message.receiverRole);

    final isParentSender = message.senderId == currentId || senderRole == 'parent';

    final otherRole = isParentSender ? receiverRole : senderRole;
    final otherName = isParentSender ? message.receiverName : message.senderName;
    final otherId = isParentSender ? message.receiverId : message.senderId;

    final isAdminChat = looksLikeAdminChat(
      role: otherRole,
      name: otherName,
      userId: otherId,
    );

    if (selectedFilter == 'admin') {
      return isAdminChat || otherRole == 'admin';
    }

    if (selectedFilter == 'nursery') {
      return isNurseryRole(otherRole);
    }

    return true;
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

  Widget buildFilterChip({
    required String label,
    required String value,
  }) {
    final isSelected = selectedFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.secondary
                : AppColors.primary.withOpacity(0.16),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  List<Widget> buildDynamicFilterChips() {
    return [
      buildFilterChip(label: 'الكل', value: 'all'),
      const SizedBox(width: 8),
      buildFilterChip(label: 'الحضانة', value: 'nursery'),
      const SizedBox(width: 8),
      buildFilterChip(label: 'الإدارة', value: 'admin'),
    ];
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
      userId: targetUserId,
    );

    final childForChat = resolveChildForConversation(
      message: message,
      targetRole: targetRole,
      targetUserId: targetUserId,
      targetUserName: targetUserName,
      isAdminChat: isAdminChat,
    );

    const targetSection = 'Nursery';
    final color = sectionColor(targetSection);

    final displayName = isAdminChat
        ? 'الإدارة'
        : targetUserName.trim().isEmpty
            ? 'بدون اسم'
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
              backgroundColor: color.withOpacity(0.14),
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

    final color = sectionColor(section);
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
            backgroundColor: color.withOpacity(0.14),
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
                if (!isAdmin) ...[
                  const SizedBox(height: 6),
                  Text(
                    'سيتم فتح المحادثة عبر الطفل: ${childForChat.name}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
                    targetRole: role,
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

  Widget buildRecentChatsTab() {
    if (currentUserId == null) {
      return const Center(
        child: Text('تعذر تحميل هوية المستخدم'),
      );
    }

    return Column(
      children: [
        if (activeChildren.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: buildDynamicFilterChips(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
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
                final otherId =
                    senderIsParent ? message.receiverId : message.senderId;

                final isAdminChat = looksLikeAdminChat(
                  role: otherRole,
                  name: otherName,
                  userId: otherId,
                );

                final allowedOtherRole =
                    isNurseryRole(otherRole) || isAdminChat || otherRole == 'admin';

                if (!allowedOtherRole) return false;

                return true;
              }).where(matchesRecentFilter).toList();

              final chats = deduplicateRecentChats(rawChats);

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
                          'عندما تبدأ أول محادثة ستظهر هنا آخر الرسائل',
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
          ),
        ),
      ],
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
                          'البحث عن الأشخاص',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'تظهر لك الإدارة وموظفات الحضانة المسموح لك بالتواصل معهم',
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
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: buildDynamicFilterChips(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchAllowedPeople(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'حدث خطأ أثناء تحميل الأشخاص: ${snapshot.error}',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final people = snapshot.data ?? [];

              if (people.isEmpty) {
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
                          'لم يتم العثور على أشخاص مطابقين للبحث أو للفلاتر الحالية',
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
                itemCount: people.length,
                itemBuilder: (context, index) {
                  return buildPersonCard(people[index]);
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
      child: RefreshIndicator(
        onRefresh: _refreshPage,
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
      ),
    );
  }
}