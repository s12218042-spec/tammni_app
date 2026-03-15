import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import 'messages_page.dart';

class TeacherChatsPage extends StatefulWidget {
  final List<ChildModel> children;

  const TeacherChatsPage({
    super.key,
    required this.children,
  });

  @override
  State<TeacherChatsPage> createState() => _TeacherChatsPageState();
}

class _TeacherChatsPageState extends State<TeacherChatsPage> {
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

  String formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    final sameDay = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

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

  ChildModel pickChildForParentUsername(String parentUsername) {
    try {
      return activeChildren.firstWhere(
        (child) => child.parentUsername == parentUsername,
      );
    } catch (_) {
      return activeChildren.first;
    }
  }

  ChildModel pickChildForMessage(MessageModel message) {
    try {
      return activeChildren.firstWhere((child) => child.id == message.childId);
    } catch (_) {
      return activeChildren.first;
    }
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
      };
    }).where((user) {
      final role = (user['role'] ?? '').toString();
      final username = (user['username'] ?? '').toString().trim().toLowerCase();
      final displayName =
          (user['displayName'] ?? '').toString().trim().toLowerCase();

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
    final childForChat = pickChildForMessage(message);
    final isTeacherSender = message.senderRole == 'teacher';

    final targetUserId = isTeacherSender ? message.receiverId : message.senderId;
    final targetUserName =
        isTeacherSender ? message.receiverName : message.senderName;

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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MessagesPage(
                child: childForChat,
                targetRole: 'parent',
                targetUserId: targetUserId,
                targetUserName:
                    targetUserName.isEmpty ? 'ولي الأمر' : targetUserName,
                targetSection: 'Kindergarten',
              ),
            ),
          );
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFF7BB6FF).withOpacity(0.14),
              child: const Icon(
                Icons.person_outline,
                color: Color(0xFF7BB6FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    targetUserName.isEmpty ? 'ولي الأمر' : targetUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'بخصوص ${childForChat.name}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
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
            backgroundColor: const Color(0xFF7BB6FF).withOpacity(0.14),
            child: Text(
              firstLetter(parentName),
              style: const TextStyle(
                color: Color(0xFF7BB6FF),
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
                    color: Color(0xFF7BB6FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MessagesPage(
                    child: childForChat,
                    targetRole: 'parent',
                    targetUserId: (parent['id'] ?? '').toString(),
                    targetUserName:
                        parentName.isEmpty ? 'ولي الأمر' : parentName,
                    targetSection: 'Kindergarten',
                  ),
                ),
              );
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
              'حدث خطأ أثناء تحميل المحادثات',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final chats = (snapshot.data ?? [])
            .where((m) => m.senderRole == 'teacher' || m.receiverRole == 'teacher')
            .toList();

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
                    'عندما تبدأ أول محادثة مع ولي أمر ستظهر هنا',
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
                          'تظهر لك أولياء أمور أطفال الروضة النشطين',
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
                    'حدث خطأ أثناء تحميل أولياء الأمور',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                    ),
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
