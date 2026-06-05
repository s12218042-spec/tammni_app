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

  final String messageType;
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
  final Timestamp? readAt;

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

  final bool notificationCreated;

  const MessageModel({
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
    this.readAt,
    this.notificationCreated = false,
  });

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = _string(value);
      if (text.isNotEmpty) return text;
    }

    return '';
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

  static bool _bool(dynamic value) {
    if (value is bool) return value;

    final text = _string(value).toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  static Timestamp _timestampOrNow(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);

    final text = _string(value);
    final parsed = DateTime.tryParse(text);

    return parsed == null ? Timestamp.now() : Timestamp.fromDate(parsed);
  }

  static Timestamp? _timestampOrNull(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);

    final text = _string(value);
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    return parsed == null ? null : Timestamp.fromDate(parsed);
  }

  static String normalizeRole(dynamic value) {
    final role = _string(value).toLowerCase();

    switch (role) {
      case 'nursery':
      case 'nursery staff':
      case 'nursery_staff':
      case 'staff':
      case 'employee':
      case 'teacher':
      case 'موظفة':
      case 'موظفة حضانة':
      case 'حضانة':
        return 'nursery_staff';

      case 'admin':
      case 'manager':
      case 'مدير':
      case 'مدير النظام':
      case 'ادمن':
      case 'أدمن':
        return 'admin';

      case 'parent':
      case 'ولي امر':
      case 'ولي أمر':
      case 'ولي الامر':
      case 'ولي الأمر':
        return 'parent';

      default:
        return role;
    }
  }

  static bool isNurseryRole(dynamic value) {
    return normalizeRole(value) == 'nursery_staff';
  }

  static bool looksLikeAdmin({
    required dynamic role,
    required dynamic name,
    required dynamic userId,
  }) {
    final normalizedRole = normalizeRole(role);
    final cleanName = _string(name).toLowerCase();
    final cleanUserId = _string(userId).toLowerCase();

    return normalizedRole == 'admin' ||
        cleanName == 'admin' ||
        cleanName == 'الإدارة' ||
        cleanName == 'ادارة' ||
        cleanName == 'الإداره' ||
        cleanUserId == 'admin';
  }

  static Map<String, String> _parseReactions(dynamic rawReactions) {
    if (rawReactions is Map) {
      return rawReactions.map(
        (key, value) => MapEntry(
          key.toString(),
          value.toString(),
        ),
      );
    }

    return <String, String>{};
  }

  static List<dynamic> _parseParticipants(
    dynamic rawParticipants, {
    required String senderId,
    required String receiverId,
  }) {
    final participants = <String>{};

    if (rawParticipants is List) {
      participants.addAll(
        rawParticipants
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty),
      );
    }

    if (senderId.trim().isNotEmpty) participants.add(senderId.trim());
    if (receiverId.trim().isNotEmpty) participants.add(receiverId.trim());

    return participants.toList();
  }

  static List<String> _parseDeletedFor(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    return <String>[];
  }

  bool get isAudioMessage => messageType.trim().toLowerCase() == 'audio';

  bool get isTextMessage {
    final type = messageType.trim().toLowerCase();
    return type == 'text' || type.isEmpty;
  }

  bool get hasAudio {
    return audioPath.trim().isNotEmpty || audioUrl.trim().isNotEmpty;
  }

  bool get hasReply {
    return (replyToMessageId ?? '').trim().isNotEmpty ||
        (replyToText ?? '').trim().isNotEmpty;
  }

  bool get senderIsAdmin {
    return looksLikeAdmin(
      role: senderRole,
      name: senderName,
      userId: senderId,
    );
  }

  bool get receiverIsAdmin {
    return looksLikeAdmin(
      role: receiverRole,
      name: receiverName,
      userId: receiverId,
    );
  }

  bool get isAdminConversation => senderIsAdmin || receiverIsAdmin;

  String get normalizedSenderRole => normalizeRole(senderRole);

  String get normalizedReceiverRole => normalizeRole(receiverRole);

  String get displayText {
    if (isDeletedForEveryone) return 'تم حذف هذه الرسالة';
    if (isAudioMessage) return 'رسالة صوتية';

    return text;
  }

  String otherUserId(String currentUserId) {
    if (senderId == currentUserId) return receiverId;
    if (receiverId == currentUserId) return senderId;

    return receiverId.isNotEmpty ? receiverId : senderId;
  }

  String otherUserName(String currentUserId) {
    if (senderId == currentUserId) return receiverName;
    if (receiverId == currentUserId) return senderName;

    return receiverName.isNotEmpty ? receiverName : senderName;
  }

  String otherUserRole(String currentUserId) {
    if (senderId == currentUserId) return normalizedReceiverRole;
    if (receiverId == currentUserId) return normalizedSenderRole;

    return normalizedReceiverRole.isNotEmpty
        ? normalizedReceiverRole
        : normalizedSenderRole;
  }

  /// مفتاح مباشر لمنع تكرار بطاقات المحادثات.
  /// لا يعتمد على childId حتى لا تظهر الموظفة أو الإدارة أكثر من مرة
  /// إذا كان لولي الأمر أكثر من طفل.
  String conversationKeyFor(String currentUserId) {
    final otherId = otherUserId(currentUserId).trim();
    final otherRole = otherUserRole(currentUserId).trim();

    if (isAdminConversation || otherRole == 'admin') {
      return 'admin_chat';
    }

    if (otherRole == 'nursery_staff') {
      return 'nursery_$otherId';
    }

    if (otherRole == 'parent') {
      return 'parent_$otherId';
    }

    return '${otherRole}_$otherId';
  }

  /// للتوافق فقط مع أي منطق قديم كان يفصل المحادثة حسب الطفل.
  String legacyConversationKeyFor(String currentUserId) {
    final otherId = otherUserId(currentUserId).trim();
    final otherRole = otherUserRole(currentUserId).trim();

    if (isAdminConversation || otherRole == 'admin') {
      return 'admin_chat';
    }

    return '${otherRole}_${otherId}_$childId';
  }

  factory MessageModel.fromMap(String id, Map<String, dynamic> data) {
    final senderId = _firstNonEmpty([
      data['senderId'],
      data['senderUid'],
      data['fromUid'],
    ]);

    final receiverId = _firstNonEmpty([
      data['receiverId'],
      data['receiverUid'],
      data['targetUid'],
      data['toUid'],
    ]);

    final audioPath = _firstNonEmpty([
      data['audioPath'],
      data['mediaPath'],
    ]);

    final audioUrl = _firstNonEmpty([
      data['audioUrl'],
      data['mediaUrl'],
      data['url'],
    ]);

    final rawMessageType = _string(data['messageType']).toLowerCase();

    final resolvedMessageType = rawMessageType.isNotEmpty
        ? rawMessageType
        : (audioPath.isNotEmpty || audioUrl.isNotEmpty)
            ? 'audio'
            : 'text';

    return MessageModel(
      id: id,
      childId: _string(data['childId']),
      childName: _string(data['childName']),
      senderId: senderId,
      senderName: _firstNonEmpty([
        data['senderName'],
        data['fromName'],
      ]),
      senderRole: normalizeRole(
        _firstNonEmpty([
          data['senderRole'],
          data['fromRole'],
        ]),
      ),
      receiverId: receiverId,
      receiverName: _firstNonEmpty([
        data['receiverName'],
        data['targetName'],
        data['toName'],
      ]),
      receiverRole: normalizeRole(
        _firstNonEmpty([
          data['receiverRole'],
          data['targetRole'],
          data['toRole'],
        ]),
      ),
      messageType: resolvedMessageType,
      text: _string(data['text']),
      audioPath: audioPath,
      audioUrl: audioUrl,
      audioDurationSeconds: _intFromDynamic(data['audioDurationSeconds']),
      audioMimeType: _string(data['audioMimeType']),
      audioSizeBytes: _intFromDynamic(data['audioSizeBytes']),
      audioBucket: _string(data['audioBucket']),
      audioStorageProvider: _string(data['audioStorageProvider']),
      sentAt: _timestampOrNow(data['sentAt'] ?? data['createdAt']),
      isRead: _bool(data['isRead'] ?? data['read']),
      readAt: _timestampOrNull(data['readAt']),
      participants: _parseParticipants(
        data['participants'],
        senderId: senderId,
        receiverId: receiverId,
      ),
      reactions: _parseReactions(data['reactions']),
      deletedForUserIds: _parseDeletedFor(
        data['deletedForUserIds'] ?? data['deletedForUsers'],
      ),
      isDeletedForEveryone: _bool(data['isDeletedForEveryone']),
      deletedForEveryoneAt: _timestampOrNull(data['deletedForEveryoneAt']),
      deletedForEveryoneBy: _string(data['deletedForEveryoneBy']),
      replyToMessageId: data['replyToMessageId']?.toString(),
      replyToText: data['replyToText']?.toString(),
      replyToSenderId: data['replyToSenderId']?.toString(),
      replyToSenderName: data['replyToSenderName']?.toString(),
      notificationCreated: _bool(data['notificationCreated']),
    );
  }

  factory MessageModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return MessageModel.fromMap(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'childId': childId,
      'childName': childName,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': normalizeRole(senderRole),
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverRole': normalizeRole(receiverRole),
      'messageType': messageType.trim().isEmpty ? 'text' : messageType,
      'text': text,
      'sentAt': sentAt,
      'isRead': isRead,
      'participants': participants,
      'reactions': reactions,
      'deletedForUserIds': deletedForUserIds,
      'isDeletedForEveryone': isDeletedForEveryone,
      'deletedForEveryoneBy': deletedForEveryoneBy,
      'notificationCreated': notificationCreated,
    };

    if (hasAudio || isAudioMessage) {
      data['audioPath'] = audioPath;
      data['audioUrl'] = audioUrl;
      data['audioDurationSeconds'] = audioDurationSeconds;
      data['audioMimeType'] = audioMimeType;
      data['audioSizeBytes'] = audioSizeBytes;
      data['audioBucket'] = audioBucket;
      data['audioStorageProvider'] = audioStorageProvider;
    }

    if (readAt != null) {
      data['readAt'] = readAt;
    }

    if (deletedForEveryoneAt != null) {
      data['deletedForEveryoneAt'] = deletedForEveryoneAt;
    }

    if ((replyToMessageId ?? '').trim().isNotEmpty) {
      data['replyToMessageId'] = replyToMessageId;
    }

    if ((replyToText ?? '').trim().isNotEmpty) {
      data['replyToText'] = replyToText;
    }

    if ((replyToSenderId ?? '').trim().isNotEmpty) {
      data['replyToSenderId'] = replyToSenderId;
    }

    if ((replyToSenderName ?? '').trim().isNotEmpty) {
      data['replyToSenderName'] = replyToSenderName;
    }

    return data;
  }

  MessageModel copyWith({
    String? id,
    String? childId,
    String? childName,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? receiverId,
    String? receiverName,
    String? receiverRole,
    String? messageType,
    String? text,
    String? audioPath,
    String? audioUrl,
    int? audioDurationSeconds,
    String? audioMimeType,
    int? audioSizeBytes,
    String? audioBucket,
    String? audioStorageProvider,
    Timestamp? sentAt,
    bool? isRead,
    Timestamp? readAt,
    List<dynamic>? participants,
    Map<String, String>? reactions,
    List<String>? deletedForUserIds,
    bool? isDeletedForEveryone,
    Timestamp? deletedForEveryoneAt,
    String? deletedForEveryoneBy,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
    bool? notificationCreated,
  }) {
    return MessageModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole:
          senderRole == null ? this.senderRole : normalizeRole(senderRole),
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverRole: receiverRole == null
          ? this.receiverRole
          : normalizeRole(receiverRole),
      messageType: messageType ?? this.messageType,
      text: text ?? this.text,
      audioPath: audioPath ?? this.audioPath,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDurationSeconds:
          audioDurationSeconds ?? this.audioDurationSeconds,
      audioMimeType: audioMimeType ?? this.audioMimeType,
      audioSizeBytes: audioSizeBytes ?? this.audioSizeBytes,
      audioBucket: audioBucket ?? this.audioBucket,
      audioStorageProvider:
          audioStorageProvider ?? this.audioStorageProvider,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      participants: participants ?? this.participants,
      reactions: reactions ?? this.reactions,
      deletedForUserIds: deletedForUserIds ?? this.deletedForUserIds,
      isDeletedForEveryone:
          isDeletedForEveryone ?? this.isDeletedForEveryone,
      deletedForEveryoneAt:
          deletedForEveryoneAt ?? this.deletedForEveryoneAt,
      deletedForEveryoneBy:
          deletedForEveryoneBy ?? this.deletedForEveryoneBy,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      notificationCreated: notificationCreated ?? this.notificationCreated,
    );
  }
}
