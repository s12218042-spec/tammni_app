import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/child_model.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class MessagesPage extends StatefulWidget {
  final ChildModel? child;
  final String targetRole;
  final String targetUserId;
  final String targetUserName;
  final String targetSection;

  const MessagesPage({
    super.key,
    this.child,
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
  final FocusNode _messageFocusNode = FocusNode();

  static const List<String> topMessageReactions = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '👏',
  ];

  static const List<String> allMessageReactions = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '👏',
    '🔥',
    '😍',
    '🤔',
    '😡',
    '✅',
    '🎉',
    '🙏',
    '💯',
    '😭',
    '🤍',
    '😅',
    '🙂',
  ];

  String? currentUserId;
  String currentUserName = '';
  String currentUserRole = '';
  bool loadingIdentity = true;
  bool isSending = false;

  MessageModel? replyingToMessage;

  String get targetDisplayName =>
      widget.targetUserName.trim().isEmpty ? 'بدون اسم' : widget.targetUserName;

  bool get hasChildContext => widget.child != null;

  IconData get targetIcon {
    if (widget.targetRole == 'teacher') return Icons.school_outlined;
    if (widget.targetRole == 'nursery' ||
        widget.targetRole == 'nursery_staff') {
      return Icons.child_care_outlined;
    }
    if (widget.targetRole == 'parent') return Icons.person_outline;
    if (widget.targetRole == 'admin') return Icons.business_outlined;
    return Icons.send_outlined;
  }

  Color get targetColor {
    if (widget.targetRole == 'teacher') return const Color(0xFF7BB6FF);
    if (widget.targetRole == 'nursery' ||
        widget.targetRole == 'nursery_staff') {
      return const Color(0xFFEFA7C8);
    }
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
    if (role == 'nursery' || role == 'nursery_staff') return 'موظفة حضانة';
    if (role == 'parent') return 'ولي أمر';
    if (role == 'admin') return 'الإدارة';
    return role;
  }

  String headerSubtitle() {
    final roleText = roleLabel(widget.targetRole);

    if (widget.targetRole == 'admin' || widget.targetSection.trim().isEmpty) {
      return hasChildContext
          ? '$roleText • متابعة بخصوص الطفل'
          : '$roleText • محادثة مباشرة';
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

      if (hasChildContext) {
        await _messageService.markConversationAsRead(
          childId: widget.child!.id,
          currentUserId: user.uid,
          targetUserId: widget.targetUserId,
        );
      }

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
    _messageFocusNode.dispose();
    super.dispose();
  }

  String formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'م' : 'ص';
    return '$hour:$minute $period';
  }

  String safeMessagePreview(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return 'رسالة';
    if (clean.length <= 45) return clean;
    return '${clean.substring(0, 45)}...';
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

    if (text.isEmpty || currentUserId == null || currentUserRole.isEmpty) {
      return;
    }
    if (isSending) return;

    setState(() {
      isSending = true;
    });

    try {
      await _messageService.sendMessage(
        childId: hasChildContext ? widget.child!.id : '',
        childName: hasChildContext ? widget.child!.name : '',
        senderId: currentUserId!,
        senderName: currentUserName,
        senderRole: currentUserRole,
        receiverId: widget.targetUserId,
        receiverName: widget.targetUserName,
        receiverRole: widget.targetRole,
        text: text,
        replyToMessageId: replyingToMessage?.id,
        replyToText: replyingToMessage?.text,
        replyToSenderId: replyingToMessage?.senderId,
        replyToSenderName: replyingToMessage?.senderName,
      );

      messageCtrl.clear();

      if (!mounted) return;
      setState(() {
        replyingToMessage = null;
      });

      await scrollToBottom();
    } finally {
      if (!mounted) return;
      setState(() {
        isSending = false;
      });
    }
  }

  Map<String, int> buildReactionCounts(Map<String, String> reactions) {
    final Map<String, int> counts = {};

    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) {
        final compareCount = b.value.compareTo(a.value);
        if (compareCount != 0) return compareCount;
        return allMessageReactions.indexOf(a.key)
            .compareTo(allMessageReactions.indexOf(b.key));
      });

    return {
      for (final entry in sortedEntries) entry.key: entry.value,
    };
  }

  Future<void> onReactionSelected(MessageModel message, String emoji) async {
  if (currentUserId == null || message.isDeletedForEveryone) return;

  try {
    await _messageService.toggleMessageReaction(
      messageId: message.id,
      userId: currentUserId!,
      emoji: emoji,
    );
  } on FirebaseException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.message ?? 'تعذر تنفيذ التفاعل على الرسالة',
          textAlign: TextAlign.center,
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'حدث خطأ أثناء تنفيذ التفاعل: $e',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

  Future<void> copyMessageText(MessageModel message) async {
    if (message.text.trim().isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: message.text),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الرسالة'),
      ),
    );
  }

  void startReplyToMessage(MessageModel message) {
    setState(() {
      replyingToMessage = message;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _messageFocusNode.requestFocus();
    });
  }

  Future<void> showDeleteOptions(MessageModel message) async {
    if (currentUserId == null) return;

    final isMyMessage = message.senderId == currentUserId;
    final canDeleteForEveryone =
        isMyMessage && !message.isDeletedForEveryone;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'خيارات الحذف',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: const Text(
                    'حذف لدي فقط',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    isMyMessage
                        ? 'ستختفي رسالتك من هذه المحادثة لديك فقط'
                        : 'ستختفي هذه الرسالة من هذه المحادثة لديك فقط',
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _messageService.deleteMessageForMe(
                      messageId: message.id,
                      userId: currentUserId!,
                    );
                  },
                ),
                if (canDeleteForEveryone)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'حذف عند الطرفين',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: const Text(
                      'سيتم حذف رسالتك عند الطرفين واستبدالها بعبارة تم حذف هذه الرسالة',
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _messageService.deleteMessageForEveryone(
                        messageId: message.id,
                        currentUserId: currentUserId!,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showAllReactionsSheet(MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'اختر تفاعلاً',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: allMessageReactions.map((emoji) {
                    final isSelected = message.reactions[currentUserId] == emoji;

                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        Navigator.pop(context);
                        await onReactionSelected(message, emoji);
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.secondary.withOpacity(0.12)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.secondary
                                : Colors.grey.shade300,
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 25),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showMessageActions(MessageModel message) async {
    if (message.isDeletedForEveryone) {
      await showDeleteOptions(message);
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ...topMessageReactions.map((emoji) {
                      final isSelected = message.reactions[currentUserId] == emoji;

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          Navigator.pop(context);
                          await onReactionSelected(message, emoji);
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.secondary.withOpacity(0.12)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.secondary
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                    }),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(context);
                        showAllReactionsSheet(message);
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 20,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: Colors.grey.shade200, height: 1),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text(
                    'رد',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    startReplyToMessage(message);
                  },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text(
                    'نسخ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await copyMessageText(message);
                  },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'حذف',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await showDeleteOptions(message);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildReactionSummary(MessageModel message, bool isMe) {
    if (message.isDeletedForEveryone) return const SizedBox.shrink();

    final counts = buildReactionCounts(message.reactions);
    if (counts.isEmpty) return const SizedBox.shrink();

    final alignment = isMe ? WrapAlignment.end : WrapAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: Wrap(
        alignment: alignment,
        spacing: 6,
        runSpacing: 6,
        children: counts.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value;
          final reactedByMe = message.reactions[currentUserId] == emoji;

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onReactionSelected(message, emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: reactedByMe
                    ? AppColors.secondary.withOpacity(0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: reactedByMe
                      ? AppColors.secondary
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: reactedByMe
                          ? AppColors.secondary
                          : AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildReplyPreviewInsideBubble(MessageModel message, bool isMe) {
    final replyText = (message.replyToText ?? '').trim();
    if (replyText.isEmpty) return const SizedBox.shrink();

    final replySenderName = (message.replyToSenderName ?? '').trim().isEmpty
        ? 'رسالة سابقة'
        : message.replyToSenderName!.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withOpacity(0.18)
            : targetColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          right: BorderSide(
            color: isMe ? Colors.white70 : targetColor,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replySenderName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isMe ? Colors.white : targetColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            safeMessagePreview(replyText),
            style: TextStyle(
              fontSize: 12.5,
              color: isMe ? Colors.white70 : AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDeletedMessageBubble(MessageModel message, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: const BoxConstraints(maxWidth: 290, minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.secondary.withOpacity(0.22) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block_outlined,
            size: 16,
            color: AppColors.textLight,
          ),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'تم حذف هذه الرسالة',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildNormalMessageContent(MessageModel message, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      constraints: const BoxConstraints(maxWidth: 290, minWidth: 120),
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
          buildReplyPreviewInsideBubble(message, isMe),
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
                    color: message.isRead
                        ? Colors.lightBlueAccent
                        : Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget buildMessageBubble(MessageModel message) {
    final isMe = message.senderId == currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: () async {
                await showMessageActions(message);
              },
              child: message.isDeletedForEveryone
                  ? buildDeletedMessageBubble(message, isMe)
                  : buildNormalMessageContent(message, isMe),
            ),
            buildReactionSummary(message, isMe),
          ],
        ),
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
            child: Icon(targetIcon, color: targetColor),
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
                if (hasChildContext) ...[
                  const SizedBox(height: 4),
                  Text(
                    'بخصوص الطفل: ${widget.child!.name}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: targetColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReplyBanner() {
    if (replyingToMessage == null) return const SizedBox.shrink();

    final isReplyingToMe = replyingToMessage!.senderId == currentUserId;
    final replyName = isReplyingToMe
        ? 'نفسك'
        : (replyingToMessage!.senderName.trim().isEmpty
            ? targetDisplayName
            : replyingToMessage!.senderName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الرد على $replyName',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  safeMessagePreview(replyingToMessage!.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                replyingToMessage = null;
              });
            },
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget buildInputArea() {
    final isEmpty = messageCtrl.text.trim().isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildReplyBanner(),
        Container(
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
                  focusNode: _messageFocusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: replyingToMessage == null
                        ? 'اكتب رسالتك إلى $targetDisplayName...'
                        : 'اكتب ردك...',
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
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loadingIdentity) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (currentUserId == null) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: Text('تعذر تحميل هوية المستخدم'))),
      );
    }

    if (!hasChildContext) {
      return AppPageScaffold(
        title: 'المحادثة',
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            buildHeaderCard(),
            const SizedBox(height: 14),
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'هذه المحادثة لا تحتوي على سياق طفل في هذه النسخة بعد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: AppPageScaffold(
        title: 'المحادثة',
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            buildHeaderCard(),
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _messageService.getConversationMessages(
                  childId: widget.child!.id,
                  currentUserId: currentUserId!,
                  targetUserId: widget.targetUserId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
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
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return buildMessageBubble(messages[index]);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            buildInputArea(),
          ],
        ),
      ),
    );
  }
}