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
  });

  factory MessageModel.fromMap(String id, Map<String, dynamic> data) {
    return MessageModel(
      id: id,
      childId: data['childId'] ?? '',
      childName: data['childName'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      receiverRole: data['receiverRole'] ?? '',
      text: data['text'] ?? '',
      sentAt: data['sentAt'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
      participants: data['participants'] ?? [],
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
    };
  }
}
