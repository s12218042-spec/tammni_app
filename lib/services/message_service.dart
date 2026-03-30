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
            message.senderId == currentUserId || message.receiverId == currentUserId;

        final hasTargetUser =
            message.senderId == targetUserId || message.receiverId == targetUserId;

        return hasCurrentUser && hasTargetUser;
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
          .toList();

      allMessages.sort((a, b) => b.sentAt.compareTo(a.sentAt));

      final Map<String, MessageModel> latestByChat = {};

      for (final message in allMessages) {
        final otherUserId =
            message.senderId == currentUserId ? message.receiverId : message.senderId;

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
        .map((snapshot) => snapshot.docs.length);
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

      return receiverId == currentUserId &&
          senderId == targetUserId &&
          isRead == false;
    }).toList();

    for (final doc in docsToUpdate) {
      await doc.reference.update({'isRead': true});
    }
  }
}
