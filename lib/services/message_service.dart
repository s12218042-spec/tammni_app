import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message_model.dart';
import 'app_notification_service.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _firestore.collection('messages');

  String _normalizeRole(String value) {
    final role = value.trim().toLowerCase();

    if (role == 'nursery' ||
        role == 'nursery staff' ||
        role == 'nursery_staff') {
      return 'nursery_staff';
    }

    return role;
  }

  bool _isParentRole(String value) {
    return _normalizeRole(value) == 'parent';
  }

  String _roleLabel(String value) {
    switch (_normalizeRole(value)) {
      case 'parent':
        return 'وليّ الأمر';
      case 'nursery_staff':
        return 'موظفة الحضانة';
      case 'admin':
        return 'الإدارة';
      default:
        return value.trim().isEmpty ? 'مستخدم' : value.trim();
    }
  }

  String _safePreview(String text) {
    final clean = text.trim();

    if (clean.isEmpty) return 'رسالة جديدة';
    if (clean.length <= 80) return clean;

    return '${clean.substring(0, 80)}...';
  }

  Future<Map<String, String>> _fetchUserInfo(String uid) async {
    if (uid.trim().isEmpty) {
      return {
        'uid': '',
        'name': 'مستخدم',
        'username': '',
        'role': '',
      };
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      return {
        'uid': uid,
        'name': (data['displayName'] ??
                data['name'] ??
                data['username'] ??
                'مستخدم')
            .toString()
            .trim(),
        'username': (data['username'] ?? '').toString().trim().toLowerCase(),
        'role': _normalizeRole((data['role'] ?? '').toString()),
      };
    } catch (_) {
      return {
        'uid': uid,
        'name': 'مستخدم',
        'username': '',
        'role': '',
      };
    }
  }

  Future<void> _createMessageNotification({
    required String childId,
    required String childName,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String receiverId,
    required String receiverName,
    required String receiverRole,
    required String text,
    required String messageId,
  }) async {
    if (senderId.trim().isEmpty || receiverId.trim().isEmpty) return;
    if (senderId == receiverId) return;

    final normalizedReceiverRole = _normalizeRole(receiverRole);
    final normalizedSenderRole = _normalizeRole(senderRole);

    String title;

    if (childName.trim().isNotEmpty && !childName.startsWith('محادثة مباشرة')) {
      title = 'رسالة جديدة بخصوص $childName';
    } else {
      title = 'رسالة جديدة من ${senderName.trim().isEmpty ? _roleLabel(senderRole) : senderName.trim()}';
    }

    final body =
        '${senderName.trim().isEmpty ? _roleLabel(senderRole) : senderName.trim()}: ${_safePreview(text)}';

    await AppNotificationService.instance.createNotification(
      title: title,
      body: body,
      type: 'message',
      notificationFor: normalizedReceiverRole,
      targetUid: receiverId,
      targetRole: normalizedReceiverRole,
      childId: childId,
      childName: childName,
      priority: 'normal',
      parentUid: _isParentRole(receiverRole) ? receiverId : '',
      parentUsername: '',
      createdByUid: senderId,
      createdByName: senderName,
      createdByRole: normalizedSenderRole,
      extraData: {
        'messageId': messageId,
        'conversationChildId': childId,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': normalizedSenderRole,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'receiverRole': normalizedReceiverRole,
        'isMessageNotification': true,
      },
    );
  }

  Future<void> _createReactionNotification({
    required String messageId,
    required String messageText,
    required String childId,
    required String childName,
    required String messageOwnerId,
    required String messageOwnerRole,
    required String reactedByUid,
    required String reactedByName,
    required String reactedByRole,
    required String emoji,
  }) async {
    if (messageOwnerId.trim().isEmpty || reactedByUid.trim().isEmpty) return;
    if (messageOwnerId == reactedByUid) return;

    final normalizedOwnerRole = _normalizeRole(messageOwnerRole);
    final normalizedReactorRole = _normalizeRole(reactedByRole);

    final title = 'تفاعل جديد على رسالتك';
    final body =
        '${reactedByName.trim().isEmpty ? _roleLabel(reactedByRole) : reactedByName.trim()} تفاعل بـ $emoji على رسالتك: ${_safePreview(messageText)}';

    await AppNotificationService.instance.createNotification(
      title: title,
      body: body,
      type: 'message_reaction',
      notificationFor: normalizedOwnerRole,
      targetUid: messageOwnerId,
      targetRole: normalizedOwnerRole,
      childId: childId,
      childName: childName,
      priority: 'normal',
      parentUid: _isParentRole(messageOwnerRole) ? messageOwnerId : '',
      parentUsername: '',
      createdByUid: reactedByUid,
      createdByName: reactedByName,
      createdByRole: normalizedReactorRole,
      extraData: {
        'messageId': messageId,
        'conversationChildId': childId,
        'emoji': emoji,
        'reactedByUid': reactedByUid,
        'reactedByName': reactedByName,
        'reactedByRole': normalizedReactorRole,
        'messageOwnerId': messageOwnerId,
        'messageOwnerRole': normalizedOwnerRole,
        'isReactionNotification': true,
      },
    );
  }

  Stream<List<MessageModel>> getConversationMessages({
    required String childId,
    required String currentUserId,
    required String targetUserId,
  }) {
    return _messagesRef
        .where('childId', isEqualTo: childId)
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
          .where((message) {
        final hasCurrentUser =
            message.senderId == currentUserId ||
            message.receiverId == currentUserId;

        final hasTargetUser =
            message.senderId == targetUserId ||
            message.receiverId == targetUserId;

        final hiddenForCurrentUser =
            message.deletedForUserIds.contains(currentUserId);

        return hasCurrentUser && hasTargetUser && !hiddenForCurrentUser;
      }).toList();

      messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return messages;
    });
  }

  Stream<List<MessageModel>> getLatestChatsForUser({
    required String currentUserId,
  }) {
    return _messagesRef
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      final allMessages = snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
          .where((message) => !message.deletedForUserIds.contains(currentUserId))
          .toList();

      allMessages.sort((a, b) => b.sentAt.compareTo(a.sentAt));

      final Map<String, MessageModel> latestByChat = {};

      for (final message in allMessages) {
        final otherUserId = message.senderId == currentUserId
            ? message.receiverId
            : message.senderId;

        final key = '${message.childId}_$otherUserId';

        latestByChat.putIfAbsent(key, () => message);
      }

      return latestByChat.values.toList()
        ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    });
  }

  Stream<int> getUnreadMessagesCountForUser({
    required String currentUserId,
  }) {
    return _messagesRef
        .where('participants', arrayContains: currentUserId)
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final visibleUnread = snapshot.docs.where((doc) {
        final data = doc.data();
        final deletedForUserIds =
            (data['deletedForUserIds'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();

        return !deletedForUserIds.contains(currentUserId);
      }).length;

      return visibleUnread;
    });
  }

  Future<void> sendMessage({
    required String childId,
    required String childName,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String receiverId,
    required String receiverName,
    required String receiverRole,
    required String text,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final normalizedSenderRole = _normalizeRole(senderRole);
    final normalizedReceiverRole = _normalizeRole(receiverRole);

    final docRef = await _messagesRef.add({
      'childId': childId,
      'childName': childName,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': normalizedSenderRole,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverRole': normalizedReceiverRole,
      'text': cleanText,
      'sentAt': Timestamp.now(),
      'isRead': false,
      'participants': [
        senderId,
        receiverId,
        childId,
      ],
      'reactions': <String, String>{},
      'deletedForUserIds': <String>[],
      'isDeletedForEveryone': false,
      'deletedForEveryoneAt': null,
      'deletedForEveryoneBy': '',
      'replyToMessageId': replyToMessageId,
      'replyToText': replyToText,
      'replyToSenderId': replyToSenderId,
      'replyToSenderName': replyToSenderName,
      'notificationCreated': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _createMessageNotification(
      childId: childId,
      childName: childName,
      senderId: senderId,
      senderName: senderName,
      senderRole: normalizedSenderRole,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverRole: normalizedReceiverRole,
      text: cleanText,
      messageId: docRef.id,
    );
  }

  Future<void> markConversationAsRead({
    required String childId,
    required String currentUserId,
    required String targetUserId,
  }) async {
    final snapshot = await _messagesRef
        .where('childId', isEqualTo: childId)
        .where('participants', arrayContains: currentUserId)
        .get();

    final docsToUpdate = snapshot.docs.where((doc) {
      final data = doc.data();

      final receiverId = data['receiverId'] ?? '';
      final senderId = data['senderId'] ?? '';
      final isRead = data['isRead'] ?? false;
      final deletedForUserIds =
          (data['deletedForUserIds'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();

      return receiverId == currentUserId &&
          senderId == targetUserId &&
          isRead == false &&
          !deletedForUserIds.contains(currentUserId);
    }).toList();

    for (final doc in docsToUpdate) {
      await doc.reference.update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> toggleMessageReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final docRef = _messagesRef.doc(messageId);

    bool shouldNotify = false;
    String messageText = '';
    String childId = '';
    String childName = '';
    String messageOwnerId = '';
    String messageOwnerRole = '';

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};

      final isDeletedForEveryone = data['isDeletedForEveryone'] == true;
      final deletedForUserIds =
          (data['deletedForUserIds'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();

      if (isDeletedForEveryone || deletedForUserIds.contains(userId)) {
        return;
      }

      final rawReactions = data['reactions'];
      final Map<String, String> currentReactions =
          rawReactions is Map<String, dynamic>
              ? rawReactions.map(
                  (key, value) => MapEntry(key, value.toString()),
                )
              : rawReactions is Map
                  ? rawReactions.map(
                      (key, value) =>
                          MapEntry(key.toString(), value.toString()),
                    )
                  : <String, String>{};

      final currentEmoji = currentReactions[userId];

      if (currentEmoji == emoji) {
        currentReactions.remove(userId);
        shouldNotify = false;
      } else {
        currentReactions[userId] = emoji;

        final senderId = (data['senderId'] ?? '').toString();
        if (senderId.isNotEmpty && senderId != userId) {
          shouldNotify = true;
          messageOwnerId = senderId;
          messageOwnerRole = (data['senderRole'] ?? '').toString();
          messageText = (data['text'] ?? '').toString();
          childId = (data['childId'] ?? '').toString();
          childName = (data['childName'] ?? '').toString();
        }
      }

      transaction.update(docRef, {
        'reactions': currentReactions,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    if (!shouldNotify) return;

    final reactorInfo = await _fetchUserInfo(userId);

    await _createReactionNotification(
      messageId: messageId,
      messageText: messageText,
      childId: childId,
      childName: childName,
      messageOwnerId: messageOwnerId,
      messageOwnerRole: messageOwnerRole,
      reactedByUid: userId,
      reactedByName: reactorInfo['name'] ?? 'مستخدم',
      reactedByRole: reactorInfo['role'] ?? '',
      emoji: emoji,
    );
  }

  Future<void> deleteMessageForMe({
    required String messageId,
    required String userId,
  }) async {
    final docRef = _messagesRef.doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};

      final deletedForUserIds =
          (data['deletedForUserIds'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toSet();

      deletedForUserIds.add(userId);

      transaction.update(docRef, {
        'deletedForUserIds': deletedForUserIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteMessageForEveryone({
    required String messageId,
    required String currentUserId,
  }) async {
    final docRef = _messagesRef.doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};

      final senderId = (data['senderId'] ?? '').toString();
      if (senderId != currentUserId) {
        return;
      }

      transaction.update(docRef, {
        'text': 'تم حذف هذه الرسالة',
        'isDeletedForEveryone': true,
        'deletedForEveryoneAt': Timestamp.now(),
        'deletedForEveryoneBy': currentUserId,
        'reactions': <String, String>{},
        'replyToMessageId': null,
        'replyToText': null,
        'replyToSenderId': null,
        'replyToSenderName': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}