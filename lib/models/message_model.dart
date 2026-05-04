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

  final String messageType; // text / audio
  final String text;

  final String audioPath;
  final String audioUrl;
  final int audioDurationSeconds;
  final String audioMimeType;
  final int audioSizeBytes;
  final String audioBucket;
  final String audioStorageProvider;

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
    required this.messageType,
    required this.text,
    required this.audioPath,
    required this.audioUrl,
    required this.audioDurationSeconds,
    required this.audioMimeType,
    required this.audioSizeBytes,
    required this.audioBucket,
    required this.audioStorageProvider,
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

  bool get isAudioMessage => messageType == 'audio';

  bool get isTextMessage => messageType == 'text' || messageType.trim().isEmpty;

  bool get hasAudio {
    return audioPath.trim().isNotEmpty || audioUrl.trim().isNotEmpty;
  }

  String get displayText {
    if (isDeletedForEveryone) return 'تم حذف هذه الرسالة';
    if (isAudioMessage) return 'رسالة صوتية';
    return text;
  }

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

    final rawMessageType = (data['messageType'] ?? '').toString().trim();

    final audioPath = (data['audioPath'] ?? '').toString();
    final audioUrl = (data['audioUrl'] ?? '').toString();

    final resolvedMessageType = rawMessageType.isNotEmpty
        ? rawMessageType
        : (audioPath.trim().isNotEmpty || audioUrl.trim().isNotEmpty)
            ? 'audio'
            : 'text';

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
      messageType: resolvedMessageType,
      text: (data['text'] ?? '').toString(),
      audioPath: audioPath,
      audioUrl: audioUrl,
      audioDurationSeconds: _intFromDynamic(data['audioDurationSeconds']),
      audioMimeType: (data['audioMimeType'] ?? '').toString(),
      audioSizeBytes: _intFromDynamic(data['audioSizeBytes']),
      audioBucket: (data['audioBucket'] ?? '').toString(),
      audioStorageProvider: (data['audioStorageProvider'] ?? '').toString(),
      sentAt: data['sentAt'] is Timestamp
          ? data['sentAt'] as Timestamp
          : data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
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

  static int _intFromDynamic(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();

    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }

    return 0;
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
      'messageType': messageType,
      'text': text,
      'audioPath': audioPath,
      'audioUrl': audioUrl,
      'audioDurationSeconds': audioDurationSeconds,
      'audioMimeType': audioMimeType,
      'audioSizeBytes': audioSizeBytes,
      'audioBucket': audioBucket,
      'audioStorageProvider': audioStorageProvider,
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