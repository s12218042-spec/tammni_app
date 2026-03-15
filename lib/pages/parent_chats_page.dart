import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  Set<String> get allowedSections {
    final sections = <String>{};

    for (final child in widget.children) {
      if (child.section.trim().isNotEmpty) {
        sections.add(child.section.trim());
      }
    }

    return sections;
  }

  List<ChildModel> get nurseryChildren =>
      widget.children.where((c) => c.section == 'Nursery').toList();

  List<ChildModel> get kgChildren =>
      widget.children.where((c) => c.section == 'Kindergarten').toList();

  String sectionLabel(String section) {
    if (section == 'Nursery') return 'حضانة';
    if (section == 'Kindergarten') return 'روضة';
    return section;
  }

  String roleLabel(String role) {
    if (role == 'nursery') return 'موظف حضانة';
    if (role == 'teacher') return 'معلمة';
    if (role == 'admin') return 'إدارة';
    return role;
  }

  Color sectionColor(String section) {
    if (section == 'Nursery') return const Color(0xFFEFA7C8);
    if (section == 'Kindergarten') return const Color(0xFF7BB6FF);
    return AppColors.primary;
  }

  IconData roleIcon(String role) {
    if (role == 'nursery') return Icons.child_care_outlined;
    if (role == 'teacher') return Icons.school_outlined;
    if (role == 'admin') return Icons.business_outlined;
    return Icons.person_outline;
  }

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

  Future<List<Map<String, dynamic>>> fetchAllowedPeople() async {
    final sections = allowedSections.toList();

    if (sections.isEmpty) return [];

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
        'group': data['group'] ?? '',
      };
    }).where((person) {
      final role = (person['role'] ?? '').toString();
      final section = (person['section'] ?? '').toString();
      final name = (person['displayName'] ?? '').toString().toLowerCase();
      final username = (person['username'] ?? '').toString().toLowerCase();

      final allowedRole =
          role == 'teacher' || role == 'nursery' || role == 'admin';

      if (!allowedRole) return false;

      if (role == 'admin') {
        if (section.isNotEmpty && !sections.contains(section)) {
          return false;
        }
      } else {
        if (!sections.contains(section)) {
          return false;
        }
      }

      if (selectedFilter == 'nursery' && section != 'Nursery') return false;
      if (selectedFilter == 'kg' && section != 'Kindergarten') return false;
      if (selectedFilter == 'admin' && role != 'admin') return false;
      if (selectedFilter == 'staff' &&
          !(role == 'teacher' || role == 'nursery')) {
        return false;
      }

      if (searchText.isEmpty) return true;

      return name.contains(searchText) || username.contains(searchText);
    }).toList();

    results.sort((a, b) {
      final nameA = (a['displayName'] ?? '').toString();
      final nameB = (b['displayName'] ?? '').toString();
      return nameA.compareTo(nameB);
    });

    return results;
  }

  ChildModel pickChildForPerson(Map<String, dynamic> person) {
    final personSection = (person['section'] ?? '').toString();

    if (personSection == 'Nursery' && nurseryChildren.isNotEmpty) {
      return nurseryChildren.first;
    }

    if (personSection == 'Kindergarten' && kgChildren.isNotEmpty) {
      return kgChildren.first;
    }

    return widget.children.first;
  }

  ChildModel pickChildForMessage(MessageModel message) {
    try {
      return widget.children.firstWhere((child) => child.id == message.childId);
    } catch (_) {
      return widget.children.first;
    }
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

  Widget buildRecentChatCard(MessageModel message) {
    final childForChat = pickChildForMessage(message);
    final isParentSender = message.senderRole == 'parent';

    final targetUserId = isParentSender ? message.receiverId : message.senderId;
    final targetUserName =
        isParentSender ? message.receiverName : message.senderName;
    final targetRole =
        isParentSender ? message.receiverRole : message.senderRole;
    final targetSection = childForChat.section;

    final color = sectionColor(targetSection);

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
                targetRole: targetRole,
                targetUserId: targetUserId,
                targetUserName:
                    targetUserName.isEmpty ? 'بدون اسم' : targetUserName,
                targetSection: targetSection,
              ),
            ),
          );
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withOpacity(0.14),
              child: Icon(
                roleIcon(targetRole),
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    targetUserName.isEmpty ? 'بدون اسم' : targetUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${roleLabel(targetRole)} • بخصوص ${childForChat.name}',
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

  Widget buildPersonCard(Map<String, dynamic> person) {
    final name = (person['displayName'] ?? '').toString();
    final role = (person['role'] ?? '').toString();
    final section = (person['section'] ?? '').toString();
    final group = (person['group'] ?? '').toString();

    final color = sectionColor(section);
    final childForChat = pickChildForPerson(person);

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
                  name.isEmpty ? 'بدون اسم' : name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${roleLabel(role)} • ${sectionLabel(section)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (group.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'المجموعة: $group',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
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
                    targetRole: role,
                    targetUserId: (person['id'] ?? '').toString(),
                    targetUserName: name,
                    targetSection: section,
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
                Icons.chat_bubble_outline_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRecentChatsTab() {
    final parentUsername = widget.children.first.parentUsername;

    return StreamBuilder<List<MessageModel>>(
      stream: _messageService.getLatestChatsForParent(
        parentUsername: parentUsername,
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

        final chats = snapshot.data ?? [];

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
                    Icons.chat_bubble_outline_rounded,
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
                          'تظهر لك الجهات المسموح لك بالتواصل معها حسب أطفالك',
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
                  children: [
                    buildFilterChip(label: 'الكل', value: 'all'),
                    const SizedBox(width: 8),
                    buildFilterChip(label: 'الحضانة', value: 'nursery'),
                    const SizedBox(width: 8),
                    buildFilterChip(label: 'الروضة', value: 'kg'),
                    const SizedBox(width: 8),
                    buildFilterChip(label: 'الموظفون', value: 'staff'),
                    const SizedBox(width: 8),
                    buildFilterChip(label: 'الإدارة', value: 'admin'),
                  ],
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
                    'حدث خطأ أثناء تحميل الأشخاص',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                    ),
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
