import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class TemporaryStaffChatPage extends StatefulWidget {
  final String accessCodeId;
  final String accessCode;
  final String childId;
  final String childName;
  final String parentName;
  final String parentPhone;
  final String groupId;
  final String groupName;

  const TemporaryStaffChatPage({
    super.key,
    required this.accessCodeId,
    required this.accessCode,
    required this.childId,
    required this.childName,
    required this.parentName,
    required this.parentPhone,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<TemporaryStaffChatPage> createState() =>
      _TemporaryStaffChatPageState();
}

class _TemporaryStaffChatPageState extends State<TemporaryStaffChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController messageCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  bool isSending = false;

  String get _currentUid => _auth.currentUser?.uid.trim() ?? '';

  @override
  void dispose() {
    messageCtrl.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatTime(dynamic value) {
    final date = _dateFromDynamic(value);
    if (date == null) return '';

    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'م' : 'ص';

    return '$hour:$minute $period';
  }

  String _safeName(String value, String fallback) {
    final clean = value.trim();
    return clean.isEmpty || clean == '-' ? fallback : clean;
  }

  bool _isMessageForThisConversation(Map<String, dynamic> data) {
    final fromRole = _cleanText(data['fromRole']).toLowerCase();
    final targetRole = _cleanText(data['targetRole']).toLowerCase();
    final targetUid = _cleanText(data['targetUid']);
    final fromUid = _cleanText(data['fromUid']);

    final fromTemporaryParent =
        fromRole == 'temporary_parent' &&
        targetRole == 'nursery_staff' &&
        (targetUid.isEmpty || targetUid == _currentUid);

    final fromCurrentStaff =
        fromRole == 'nursery_staff' &&
        targetRole == 'temporary_parent' &&
        (fromUid.isEmpty || fromUid == _currentUid);

    return fromTemporaryParent || fromCurrentStaff;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    return _firestore
        .collection('temporary_messages')
        .where('childId', isEqualTo: widget.childId)
        .limit(200)
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _conversationDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final filtered = docs.where((doc) {
      return _isMessageForThisConversation(doc.data());
    }).toList();

    filtered.sort((a, b) {
      final aDate = _dateFromDynamic(a.data()['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bDate = _dateFromDynamic(b.data()['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return aDate.compareTo(bDate);
    });

    return filtered;
  }

  Future<Map<String, String>> _currentStaffInfo() async {
    final uid = _currentUid;

    if (uid.isEmpty) {
      return {
        'uid': '',
        'name': 'موظف الحضانة',
      };
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      return {
        'uid': uid,
        'name': _safeName(
          _cleanText(
            data['displayName'] ?? data['name'] ?? data['username'],
          ),
          'موظف الحضانة',
        ),
      };
    } catch (_) {
      return {
        'uid': uid,
        'name': 'موظف الحضانة',
      };
    }
  }

  Future<void> _scrollToBottom({bool animated = true}) async {
    await Future.delayed(const Duration(milliseconds: 80));

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

  Future<void> _sendMessage() async {
    final text = messageCtrl.text.trim();

    if (text.isEmpty || isSending) return;

    FocusScope.of(context).unfocus();

    setState(() {
      isSending = true;
    });

    try {
      final staffInfo = await _currentStaffInfo();

      await _firestore.collection('temporary_messages').add({
        'accessCodeId': widget.accessCodeId,
        'accessCode': widget.accessCode,
        'childId': widget.childId,
        'childName': widget.childName,
        'parentName': widget.parentName,
        'parentPhone': widget.parentPhone,
        'groupId': widget.groupId,
        'groupName': widget.groupName,
        'fromRole': 'nursery_staff',
        'fromUid': staffInfo['uid'] ?? _currentUid,
        'fromName': staffInfo['name'] ?? 'موظف الحضانة',
        'targetRole': 'temporary_parent',
        'targetUid': '',
        'targetName': _safeName(widget.parentName, 'ولي أمر زائر'),
        'message': text,
        'isRead': false,
        'isDelivered': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      messageCtrl.clear();

      await _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الرسالة')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        isSending = false;
      });
    }
  }

  Widget _buildHeaderCard() {
    final parentName = _safeName(widget.parentName, 'ولي أمر زائر');

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
            backgroundColor: const Color(0xFFEFA7C8).withOpacity(0.14),
            child: Text(
              parentName.substring(0, 1),
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
                  parentName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ولي أمر زائر',
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
    );
  }

  Widget _buildEmptyConversationBox() {
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
              size: 54,
              color: AppColors.textLight,
            ),
            SizedBox(height: 12),
            Text(
              'لا توجد رسائل بعد',
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

  Widget _buildMessageBubble(Map<String, dynamic> data) {
    final fromRole = _cleanText(data['fromRole']).toLowerCase();
    final isMe = fromRole == 'nursery_staff';

    final text = _cleanText(
      data['message'] ?? data['text'] ?? data['body'],
    );

    final createdAt = data['createdAt'];
    final isRead = data['isRead'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
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
              Text(
                text.isEmpty ? 'رسالة' : text,
                textAlign: TextAlign.right,
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
                    _formatTime(createdAt),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : AppColors.textLight,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Text(
                      isRead ? '✔✔' : '✔',
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                            isRead ? Colors.lightBlueAccent : Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
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

        final docs = _conversationDocs(snapshot.data?.docs ?? []);

        if (docs.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(animated: false);
          });
        }

        if (docs.isEmpty) {
          return _buildEmptyConversationBox();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _buildMessageBubble(docs[index].data());
          },
        );
      },
    );
  }

  Widget _buildInputArea() {
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
              focusNode: _messageFocusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'اكتب رسالة...',
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSending ? null : _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSending
                    ? AppColors.secondary.withOpacity(0.45)
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: AppPageScaffold(
        title: 'المحادثة',
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 14),
            Expanded(
              child: _buildMessagesList(),
            ),
            const SizedBox(height: 8),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }
}
