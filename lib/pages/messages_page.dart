import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child_model.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class MessagesPage extends StatefulWidget {
  final ChildModel child;
  final String targetRole;
  final String targetUserId;
  final String targetUserName;
  final String targetSection;

  const MessagesPage({
    super.key,
    required this.child,
    required this.targetRole,
    required this.targetUserId,
    required this.targetUserName,
    required this.targetSection,
  });

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final MessageService _messageService = MessageService();
  final TextEditingController messageCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? currentUserId;
  String currentUserName = '';
  String currentUserRole = '';
  bool loadingIdentity = true;
  bool isSending = false;

  String get targetDisplayName =>
      widget.targetUserName.trim().isEmpty ? 'بدون اسم' : widget.targetUserName;

  IconData get targetIcon {
    if (widget.targetRole == 'teacher') return Icons.school_outlined;
    if (widget.targetRole == 'nursery') return Icons.child_care_outlined;
    if (widget.targetRole == 'parent') return Icons.person_outline;
    if (widget.targetRole == 'admin') return Icons.business_outlined;
    return Icons.send_outlined;
  }

  Color get targetColor {
    if (widget.targetRole == 'teacher') return const Color(0xFF7BB6FF);
    if (widget.targetRole == 'nursery') return const Color(0xFFEFA7C8);
    if (widget.targetRole == 'parent') return AppColors.secondary;
    if (widget.targetRole == 'admin') return AppColors.secondary;
    return AppColors.primary;
  }

  String sectionLabel(String section) {
    if (section == 'Nursery') return 'حضانة';
    if (section == 'Kindergarten') return 'روضة';
    return section;
  }

  String roleLabel(String role) {
    if (role == 'teacher') return 'معلمة';
    if (role == 'nursery') return 'موظف حضانة';
    if (role == 'parent') return 'ولي أمر';
    if (role == 'admin') return 'الإدارة';
    return role;
  }

  String headerSubtitle() {
    final roleText = roleLabel(widget.targetRole);

    if (widget.targetRole == 'admin' || widget.targetSection.trim().isEmpty) {
      return '$roleText • متابعة بخصوص الطفل';
    }

    return '$roleText • ${sectionLabel(widget.targetSection)}';
  }

  @override
  void initState() {
    super.initState();
    loadCurrentUserIdentity();
  }

  Future<void> loadCurrentUserIdentity() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          loadingIdentity = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      currentUserId = user.uid;
      currentUserName =
          (data['displayName'] ?? data['name'] ?? data['username'] ?? 'مستخدم')
              .toString();
      currentUserRole = (data['role'] ?? '').toString();

      await _messageService.markConversationAsRead(
        childId: widget.child.id,
        currentUserId: user.uid,
        targetUserId: widget.targetUserId,
      );

      if (!mounted) return;
      setState(() {
        loadingIdentity = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingIdentity = false;
      });
    }
  }

  @override
  void dispose() {
    messageCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'م' : 'ص';
    return '$hour:$minute $period';
  }

  Future<void> scrollToBottom({bool animated = true}) async {
    await Future.delayed(const Duration(milliseconds: 60));

    if (!_scrollController.hasClients) return;

    final target = _scrollController.position.maxScrollExtent;

    if (animated) {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> sendCurrentMessage() async {
    final text = messageCtrl.text.trim();

    if (text.isEmpty || currentUserId == null || currentUserRole.isEmpty) return;
    if (isSending) return;

    setState(() {
      isSending = true;
    });

    try {
      await _messageService.sendMessage(
        childId: widget.child.id,
        childName: widget.child.name,
        senderId: currentUserId!,
        senderName: currentUserName,
        senderRole: currentUserRole,
        receiverId: widget.targetUserId,
        receiverName: widget.targetUserName,
        receiverRole: widget.targetRole,
        text: text,
      );

      messageCtrl.clear();

      if (!mounted) return;
      setState(() {});
      await scrollToBottom();
    } finally {
      if (!mounted) return;
      setState(() {
        isSending = false;
      });
    }
  }

  Widget buildMessageBubble(MessageModel message) {
    final isMe = message.senderId == currentUserId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            constraints: const BoxConstraints(maxWidth: 290),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? AppColors.secondary : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.senderName.isNotEmpty
                          ? message.senderName
                          : targetDisplayName,
                      style: TextStyle(
                        color: targetColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                Text(
                  message.text,
                  style: TextStyle(
                    color: isMe ? Colors.white : AppColors.textDark,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatTime(message.sentAt),
                      style: TextStyle(
                        color: isMe ? Colors.white70 : AppColors.textLight,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Text(
                        message.isRead ? '✔✔' : '✔',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: message.isRead ? Colors.lightBlueAccent : Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: targetColor.withOpacity(0.14),
            child: Icon(
              targetIcon,
              color: targetColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  targetDisplayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  headerSubtitle(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'بخصوص الطفل: ${widget.child.name}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: targetColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInputArea() {
    final isEmpty = messageCtrl.text.trim().isEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: messageCtrl,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك إلى $targetDisplayName...',
                border: InputBorder.none,
              ),
              onChanged: (_) {
                setState(() {});
              },
              onSubmitted: (_) {},
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSending || isEmpty ? null : sendCurrentMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isSending || isEmpty)
                    ? AppColors.secondary.withOpacity(0.4)
                    : AppColors.secondary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: isSending
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loadingIdentity) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (currentUserId == null) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Text('تعذر تحميل هوية المستخدم'),
          ),
        ),
      );
    }

    return AppPageScaffold(
      title: 'المحادثة',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          buildHeaderCard(),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _messageService.getConversationMessages(
                childId: widget.child.id,
                currentUserId: currentUserId!,
                targetUserId: widget.targetUserId,
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
                      'حدث خطأ أثناء تحميل الرسائل: ${snapshot.error}',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    scrollToBottom(animated: false);
                  });
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            targetIcon,
                            size: 54,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'لا توجد رسائل بعد',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ابدأ أول رسالة الآن للتواصل مع $targetDisplayName بخصوص الطفل',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 4, bottom: 10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return buildMessageBubble(messages[index]);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          buildInputArea(),
        ],
      ),
    );
  }
}