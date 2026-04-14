import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String childId;
  final String childName;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String receiverId;
  final String receiverName;
  final String receiverRole;
  final String text;
  final Timestamp sentAt;
  final bool isRead;
  final List<dynamic> participants;

  final Map<String, String> reactions;

  final List<String> deletedForUserIds;
  final bool isDeletedForEveryone;
  final Timestamp? deletedForEveryoneAt;
  final String deletedForEveryoneBy;

  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderId;
  final String? replyToSenderName;

  MessageModel({
    required this.id,
    required this.childId,
    required this.childName,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.receiverId,
    required this.receiverName,
    required this.receiverRole,
    required this.text,
    required this.sentAt,
    required this.isRead,
    required this.participants,
    required this.reactions,
    required this.deletedForUserIds,
    required this.isDeletedForEveryone,
    required this.deletedForEveryoneAt,
    required this.deletedForEveryoneBy,
    required this.replyToMessageId,
    required this.replyToText,
    required this.replyToSenderId,
    required this.replyToSenderName,
  });

  factory MessageModel.fromMap(String id, Map<String, dynamic> data) {
    final rawReactions = data['reactions'];

    Map<String, String> parsedReactions = {};
    if (rawReactions is Map) {
      parsedReactions = rawReactions.map(
        (key, value) => MapEntry(
          key.toString(),
          value.toString(),
        ),
      );
    }

    return MessageModel(
      id: id,
      childId: (data['childId'] ?? '').toString(),
      childName: (data['childName'] ?? '').toString(),
      senderId: (data['senderId'] ?? '').toString(),
      senderName: (data['senderName'] ?? '').toString(),
      senderRole: (data['senderRole'] ?? '').toString(),
      receiverId: (data['receiverId'] ?? '').toString(),
      receiverName: (data['receiverName'] ?? '').toString(),
      receiverRole: (data['receiverRole'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      sentAt: data['sentAt'] is Timestamp
          ? data['sentAt'] as Timestamp
          : Timestamp.now(),
      isRead: data['isRead'] == true,
      participants: data['participants'] is List
          ? List<dynamic>.from(data['participants'])
          : [],
      reactions: parsedReactions,
      deletedForUserIds: (data['deletedForUserIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      isDeletedForEveryone: data['isDeletedForEveryone'] == true,
      deletedForEveryoneAt: data['deletedForEveryoneAt'] is Timestamp
          ? data['deletedForEveryoneAt'] as Timestamp
          : null,
      deletedForEveryoneBy: (data['deletedForEveryoneBy'] ?? '').toString(),
      replyToMessageId: data['replyToMessageId']?.toString(),
      replyToText: data['replyToText']?.toString(),
      replyToSenderId: data['replyToSenderId']?.toString(),
      replyToSenderName: data['replyToSenderName']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'childId': childId,
      'childName': childName,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverRole': receiverRole,
      'text': text,
      'sentAt': sentAt,
      'isRead': isRead,
      'participants': participants,
      'reactions': reactions,
      'deletedForUserIds': deletedForUserIds,
      'isDeletedForEveryone': isDeletedForEveryone,
      'deletedForEveryoneAt': deletedForEveryoneAt,
      'deletedForEveryoneBy': deletedForEveryoneBy,
      'replyToMessageId': replyToMessageId,
      'replyToText': replyToText,
      'replyToSenderId': replyToSenderId,
      'replyToSenderName': replyToSenderName,
    };
  }
}