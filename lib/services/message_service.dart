import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message_model.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _firestore.collection('messages');

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

    await _messagesRef.add({
      'childId': childId,
      'childName': childName,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverRole': receiverRole,
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
    });
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
      await doc.reference.update({'isRead': true});
    }
  }

  Future<void> toggleMessageReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final docRef = _messagesRef.doc(messageId);

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
      } else {
        currentReactions[userId] = emoji;
      }

      transaction.update(docRef, {
        'reactions': currentReactions,
      });
    });
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
      });
    });
  }
}