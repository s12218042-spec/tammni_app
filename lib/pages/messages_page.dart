import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/child_model.dart';
import '../models/message_model.dart';
import '../services/media_storage_service.dart';
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
  final ValueNotifier<bool> _canSendNotifier = ValueNotifier<bool>(false);

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Stream<List<MessageModel>>? _messagesStream;
  StreamSubscription<void>? _audioCompleteSubscription;
StreamSubscription<Duration>? _audioPositionSubscription;
StreamSubscription<Duration>? _audioDurationSubscription;
Timer? _recordingTimer;

Duration currentAudioPosition = Duration.zero;
Duration currentAudioDuration = Duration.zero;

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

  bool isRecordingAudio = false;
  bool isUploadingAudio = false;
  int recordingSeconds = 0;
  String? playingMessageId;

  MessageModel? replyingToMessage;

  bool get hasChildContext => widget.child != null;

  String get targetDisplayName =>
      widget.targetUserName.trim().isEmpty ? 'بدون اسم' : widget.targetUserName;

  String get conversationChildId {
    if (hasChildContext) return widget.child!.id;

    final ids = [
      currentUserId ?? '',
      widget.targetUserId,
    ]..sort();

    return 'direct_${ids.join('_')}';
  }

  String get conversationChildName {
    if (hasChildContext) return widget.child!.name;
    return 'محادثة مباشرة';
  }

  @override
  void initState() {
    super.initState();
    messageCtrl.addListener(_handleMessageTextChanged);
    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
  if (!mounted) return;

  setState(() {
    playingMessageId = null;
    currentAudioPosition = Duration.zero;
    currentAudioDuration = Duration.zero;
  });
});

_audioPositionSubscription = _audioPlayer.onPositionChanged.listen((position) {
  if (!mounted || playingMessageId == null) return;

  setState(() {
    currentAudioPosition = position;
  });
});

_audioDurationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
  if (!mounted || playingMessageId == null) return;

  setState(() {
    currentAudioDuration = duration;
  });
});
    loadCurrentUserIdentity();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioCompleteSubscription?.cancel();
    _audioPositionSubscription?.cancel();
    _audioDurationSubscription?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    messageCtrl.removeListener(_handleMessageTextChanged);
    messageCtrl.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _canSendNotifier.dispose();
    super.dispose();
  }

  void _handleMessageTextChanged() {
    final canSend = messageCtrl.text.trim().isNotEmpty;

    if (_canSendNotifier.value != canSend) {
      _canSendNotifier.value = canSend;
    }
  }

  String normalizeRole(String role) {
    final clean = role.trim().toLowerCase();

    if (clean == 'nursery' ||
        clean == 'nursery staff' ||
        clean == 'nursery_staff') {
      return 'nursery_staff';
    }

    return clean;
  }

  IconData get targetIcon {
    final role = normalizeRole(widget.targetRole);

    if (role == 'nursery_staff') {
      return Icons.child_care_outlined;
    }

    if (role == 'parent') return Icons.person_outline;
    if (role == 'admin') return Icons.business_outlined;

    return Icons.send_outlined;
  }

  Color get targetColor {
    final role = normalizeRole(widget.targetRole);

    if (role == 'nursery_staff') {
      return const Color(0xFFEFA7C8);
    }

    if (role == 'parent') return AppColors.secondary;
    if (role == 'admin') return AppColors.secondary;

    return AppColors.primary;
  }

  String sectionLabel(String section) {
    final clean = section.trim();

    if (clean == 'Nursery') return 'حضانة';
    if (clean == 'all') return 'كل الأقسام';

    return clean.isEmpty ? 'حضانة' : clean;
  }

  String roleLabel(String role) {
    final clean = normalizeRole(role);

    if (clean == 'nursery_staff') return 'موظفة حضانة';
    if (clean == 'parent') return 'ولي أمر';
    if (clean == 'admin') return 'الإدارة';

    return role.trim().isEmpty ? 'مستخدم' : role;
  }

  String headerSubtitle() {
    final targetRole = normalizeRole(widget.targetRole);
    final roleText = roleLabel(targetRole);
    final section = widget.targetSection.trim();

    if (hasChildContext) {
      if (targetRole == 'admin' || section.isEmpty) {
        return '$roleText • متابعة بخصوص الطفل';
      }

      return '$roleText • ${sectionLabel(section)}';
    }

    if (section.isNotEmpty && section != 'all') {
      return '$roleText • ${sectionLabel(section)} • محادثة مباشرة';
    }

    return '$roleText • محادثة مباشرة';
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

      final loadedUserId = user.uid;
      final loadedUserName =
          (data['displayName'] ?? data['name'] ?? data['username'] ?? 'مستخدم')
              .toString();
      final loadedUserRole = normalizeRole((data['role'] ?? '').toString());

      currentUserId = loadedUserId;
      currentUserName = loadedUserName;
      currentUserRole = loadedUserRole;

      _messagesStream = _messageService.getConversationMessages(
        childId: conversationChildId,
        currentUserId: loadedUserId,
        targetUserId: widget.targetUserId,
      );

      await _messageService.markConversationAsRead(
        childId: conversationChildId,
        currentUserId: loadedUserId,
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

  void _showSnack(
    String message, {
    Color backgroundColor = Colors.black87,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
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

  String formatDurationSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;

  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

  String safeMessagePreview(String text) {
    final clean = text.trim();

    if (clean.isEmpty) return 'رسالة';
    if (clean.length <= 45) return clean;

    return '${clean.substring(0, 45)}...';
  }

  String messagePreviewForReply(MessageModel message) {
    if (message.isAudioMessage) return 'رسالة صوتية';
    return safeMessagePreview(message.text);
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

  Future<String> _buildRecordingPath() async {
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    if (kIsWeb) {
      return fileName;
    }

    final dir = await getTemporaryDirectory();
    return '${dir.path}/$fileName';
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    recordingSeconds = 0;

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        recordingSeconds++;
      });
    });
  }

  Future<void> startAudioRecording() async {
    if (isRecordingAudio || isSending || isUploadingAudio) return;

    try {
      final hasPermission = await _audioRecorder.hasPermission();

      if (!hasPermission) {
        _showSnack(
          'يجب السماح باستخدام الميكروفون لتسجيل رسالة صوتية',
          backgroundColor: Colors.redAccent,
        );
        return;
      }

      final path = await _buildRecordingPath();

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (!mounted) return;

      setState(() {
        isRecordingAudio = true;
        recordingSeconds = 0;
      });

      _startRecordingTimer();
    } catch (e) {
      _showSnack(
        'تعذر بدء تسجيل الصوت: $e',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  Future<void> cancelAudioRecording() async {
    try {
      _recordingTimer?.cancel();

      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }

      if (!mounted) return;

      setState(() {
        isRecordingAudio = false;
        recordingSeconds = 0;
      });
    } catch (e) {
      _showSnack(
        'تعذر إلغاء التسجيل: $e',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  Future<void> stopAndSendAudioRecording() async {
    if (!isRecordingAudio || currentUserId == null || currentUserRole.isEmpty) {
      return;
    }

    _recordingTimer?.cancel();

    setState(() {
      isRecordingAudio = false;
      isUploadingAudio = true;
    });

    try {
      final path = await _audioRecorder.stop();

      if (path == null || path.trim().isEmpty) {
        throw Exception('لم يتم إنشاء ملف صوتي');
      }

      if (recordingSeconds < 1) {
        throw Exception('التسجيل قصير جدًا');
      }

      final uploaded = await MediaStorageService.instance.uploadAudio(
        file: XFile(path),
        folder: 'messages_audio/$conversationChildId',
        fileNameWithoutExtension:
            'voice_${DateTime.now().millisecondsSinceEpoch}',
      );

      final signedUrl = await MediaStorageService.instance.createSignedUrl(
        path: uploaded.path,
      );

      await _messageService.sendAudioMessage(
        childId: conversationChildId,
        childName: conversationChildName,
        senderId: currentUserId!,
        senderName: currentUserName,
        senderRole: normalizeRole(currentUserRole),
        receiverId: widget.targetUserId,
        receiverName: widget.targetUserName,
        receiverRole: normalizeRole(widget.targetRole),
        audioPath: uploaded.path,
        audioUrl: signedUrl,
        audioDurationSeconds: recordingSeconds,
        audioMimeType: uploaded.mimeType,
        audioSizeBytes: uploaded.sizeBytes,
        audioBucket: uploaded.bucket,
        audioStorageProvider: uploaded.storageProvider,
        replyToMessageId: replyingToMessage?.id,
        replyToText: replyingToMessage == null
            ? null
            : messagePreviewForReply(replyingToMessage!),
        replyToSenderId: replyingToMessage?.senderId,
        replyToSenderName: replyingToMessage?.senderName,
      );

      if (!mounted) return;

      setState(() {
        replyingToMessage = null;
        recordingSeconds = 0;
      });

      await scrollToBottom();
    } catch (e) {
      _showSnack(
        'تعذر إرسال الرسالة الصوتية: $e',
        backgroundColor: Colors.redAccent,
      );
    } finally {
      if (!mounted) return;

      setState(() {
        isUploadingAudio = false;
        recordingSeconds = 0;
      });
    }
  }

 Future<void> playAudioMessage(MessageModel message) async {
  if (message.isDeletedForEveryone) return;

  try {
    if (playingMessageId == message.id) {
      await _audioPlayer.stop();

      if (!mounted) return;

      setState(() {
        playingMessageId = null;
        currentAudioPosition = Duration.zero;
        currentAudioDuration = Duration.zero;
      });

      return;
    }

    await _audioPlayer.stop();

    String url = '';

    if (message.audioPath.trim().isNotEmpty) {
      url = await MediaStorageService.instance.createSignedUrl(
        path: message.audioPath,
      );
    } else if (message.audioUrl.trim().isNotEmpty) {
      url = message.audioUrl.trim();
    }

    if (url.trim().isEmpty) {
      throw Exception('رابط الصوت غير متوفر');
    }

    if (!mounted) return;

    setState(() {
      playingMessageId = message.id;
      currentAudioPosition = Duration.zero;
      currentAudioDuration = message.audioDurationSeconds > 0
          ? Duration(seconds: message.audioDurationSeconds)
          : Duration.zero;
    });

    await _audioPlayer.play(UrlSource(url));
  } catch (e) {
    if (!mounted) return;

    setState(() {
      playingMessageId = null;
      currentAudioPosition = Duration.zero;
      currentAudioDuration = Duration.zero;
    });

    _showSnack(
      'تعذر تشغيل الرسالة الصوتية: $e',
      backgroundColor: Colors.redAccent,
    );
  }
}

  Future<void> sendCurrentMessage() async {
    final text = messageCtrl.text.trim();

    if (text.isEmpty || currentUserId == null || currentUserRole.isEmpty) {
      return;
    }

    if (isSending || isRecordingAudio || isUploadingAudio) return;

    setState(() {
      isSending = true;
    });

    try {
      await _messageService.sendMessage(
        childId: conversationChildId,
        childName: conversationChildName,
        senderId: currentUserId!,
        senderName: currentUserName,
        senderRole: normalizeRole(currentUserRole),
        receiverId: widget.targetUserId,
        receiverName: widget.targetUserName,
        receiverRole: normalizeRole(widget.targetRole),
        text: text,
        replyToMessageId: replyingToMessage?.id,
        replyToText: replyingToMessage == null
            ? null
            : messagePreviewForReply(replyingToMessage!),
        replyToSenderId: replyingToMessage?.senderId,
        replyToSenderName: replyingToMessage?.senderName,
      );

      messageCtrl.clear();
      _canSendNotifier.value = false;

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

        return allMessageReactions
            .indexOf(a.key)
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
    if (message.isAudioMessage) {
      _showSnack('لا يمكن نسخ رسالة صوتية');
      return;
    }

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
                    final isSelected =
                        message.reactions[currentUserId] == emoji;

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
                      final isSelected =
                          message.reactions[currentUserId] == emoji;

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
                if (!message.isAudioMessage)
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
        color:
            isMe ? AppColors.secondary.withOpacity(0.22) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.block_outlined,
            size: 16,
            color: AppColors.textLight,
          ),
          SizedBox(width: 8),
          Flexible(
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

 Widget buildAudioMessageContent(MessageModel message, bool isMe) {
  final isPlaying = playingMessageId == message.id;

  final fallbackDuration = message.audioDurationSeconds > 0
      ? Duration(seconds: message.audioDurationSeconds)
      : Duration.zero;

  final totalDuration = isPlaying && currentAudioDuration > Duration.zero
      ? currentAudioDuration
      : fallbackDuration;

  final position = isPlaying ? currentAudioPosition : Duration.zero;

  final totalMilliseconds = totalDuration.inMilliseconds;
  final positionMilliseconds = position.inMilliseconds;

  final progress = totalMilliseconds <= 0
      ? 0.0
      : (positionMilliseconds / totalMilliseconds).clamp(0.0, 1.0).toDouble();

  final durationText = totalDuration > Duration.zero
      ? formatDuration(totalDuration)
      : '0:00';

  final positionText = isPlaying ? formatDuration(position) : '0:00';

  final bubbleColor = isMe ? AppColors.secondary : Colors.white;
  final progressColor = isMe
      ? Colors.white.withOpacity(0.18)
      : AppColors.secondary.withOpacity(0.12);

  final textColor = isMe ? Colors.white : AppColors.textDark;
  final secondaryTextColor = isMe ? Colors.white70 : AppColors.textLight;

  return Container(
    margin: const EdgeInsets.only(bottom: 4),
    constraints: const BoxConstraints(maxWidth: 300, minWidth: 210),
    decoration: BoxDecoration(
      color: bubbleColor,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                alignment: Alignment.centerRight,
                widthFactor: progress,
                child: Container(
                  color: progressColor,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                buildReplyPreviewInsideBubble(message, isMe),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => playAudioMessage(message),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: isMe
                            ? Colors.white.withOpacity(0.22)
                            : AppColors.secondary.withOpacity(0.12),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: isMe ? Colors.white : AppColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: CustomPaint(
                          painter: _VoiceWavePainter(
                            progress: progress,
                            activeColor:
                                isMe ? Colors.white : AppColors.secondary,
                            inactiveColor: secondaryTextColor.withOpacity(0.45),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isPlaying ? '$positionText / $durationText' : durationText,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatTime(message.sentAt),
                      style: TextStyle(
                        color: secondaryTextColor,
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
          ),
        ],
      ),
    ),
  );
}

  Widget buildNormalMessageContent(MessageModel message, bool isMe) {
    if (message.isAudioMessage) {
      return buildAudioMessageContent(message, isMe);
    }

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
                  messagePreviewForReply(replyingToMessage!),
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

  Widget buildRecordingBar() {
    if (!isRecordingAudio && !isUploadingAudio) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.red.withOpacity(0.20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUploadingAudio ? Icons.cloud_upload_outlined : Icons.mic_rounded,
            color: Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isUploadingAudio
                  ? 'جاري إرسال الرسالة الصوتية...'
                  : 'جاري التسجيل ${formatDurationSeconds(recordingSeconds)}',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (isRecordingAudio)
            TextButton.icon(
              onPressed: cancelAudioRecording,
              icon: const Icon(Icons.close_rounded),
              label: const Text('إلغاء'),
            ),
        ],
      ),
    );
  }

  Widget buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildReplyBanner(),
        buildRecordingBar(),
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
                  enabled: !isRecordingAudio && !isUploadingAudio,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: replyingToMessage == null
                        ? 'اكتب رسالتك إلى $targetDisplayName...'
                        : 'اكتب ردك...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: _canSendNotifier,
                builder: (context, canSend, _) {
                  final disabled = isSending || isUploadingAudio;

                  IconData icon;
                  VoidCallback? onTap;
                  Color color;

                  if (isRecordingAudio) {
                    icon = Icons.send_rounded;
                    color = Colors.red;
                    onTap = disabled ? null : stopAndSendAudioRecording;
                  } else if (canSend) {
                    icon = Icons.send_rounded;
                    color = AppColors.secondary;
                    onTap = disabled ? null : sendCurrentMessage;
                  } else {
                    icon = Icons.mic_rounded;
                    color = AppColors.secondary;
                    onTap = disabled ? null : startAudioRecording;
                  }

                  return GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: disabled ? color.withOpacity(0.4) : color,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: isSending || isUploadingAudio
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              icon,
                              color: Colors.white,
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildEmptyConversationBox() {
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
              hasChildContext
                  ? 'ابدأ أول رسالة الآن للتواصل مع $targetDisplayName بخصوص الطفل'
                  : 'ابدأ أول رسالة الآن للتواصل مع $targetDisplayName',
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

  Widget buildMessagesList() {
    final stream = _messagesStream;

    if (stream == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return StreamBuilder<List<MessageModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
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
          return buildEmptyConversationBox();
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
              child: buildMessagesList(),
            ),
            const SizedBox(height: 8),
            buildInputArea(),
          ],
        ),
      ),
    );
  }
}
class _VoiceWavePainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  const _VoiceWavePainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const barsCount = 22;
    final gap = size.width / barsCount;

    for (int i = 0; i < barsCount; i++) {
      final x = gap * i + gap / 2;

      final pattern = i % 6;
      final heightFactor = switch (pattern) {
        0 => 0.35,
        1 => 0.65,
        2 => 0.95,
        3 => 0.55,
        4 => 0.80,
        _ => 0.45,
      };

      final barHeight = size.height * heightFactor;
      final startY = (size.height - barHeight) / 2;
      final endY = startY + barHeight;

      final barProgressPoint = i / barsCount;
      final paint = barProgressPoint <= progress ? activePaint : inactivePaint;

      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}