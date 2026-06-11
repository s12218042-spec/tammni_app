// VERSION: TEMP_CHAT_CORE_V6_BIDIRECTIONAL_2026_06_11
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/media_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class TemporaryChatCorePage extends StatefulWidget {
  final String accessCodeId;
  final String accessCode;
  final String childId;
  final String childName;
  final String parentName;
  final String parentPhone;
  final String groupId;
  final String groupName;

  final String currentRole;
  final String currentUid;
  final String currentName;

  final String targetRole;
  final String targetUid;
  final String targetName;

  final String headerSubtitle;
  final IconData headerIcon;
  final Color headerColor;

  const TemporaryChatCorePage({
    super.key,
    required this.accessCodeId,
    required this.accessCode,
    required this.childId,
    required this.childName,
    required this.parentName,
    required this.parentPhone,
    required this.groupId,
    required this.groupName,
    required this.currentRole,
    required this.currentUid,
    required this.currentName,
    required this.targetRole,
    required this.targetUid,
    required this.targetName,
    required this.headerSubtitle,
    required this.headerIcon,
    required this.headerColor,
  });

  @override
  State<TemporaryChatCorePage> createState() => _TemporaryChatCorePageState();
}

class _TemporaryChatCorePageState extends State<TemporaryChatCorePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController messageCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final ValueNotifier<bool> _canSendNotifier = ValueNotifier<bool>(false);

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;

  StreamSubscription<void>? _audioCompleteSubscription;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration>? _audioDurationSubscription;
  Timer? _recordingTimer;

  bool isSending = false;
  bool isRecordingAudio = false;
  bool isUploadingAudio = false;
  int recordingSeconds = 0;

  String? playingMessageId;
  Duration currentAudioPosition = Duration.zero;
  Duration currentAudioDuration = Duration.zero;

  _TemporaryMessageData? replyingToMessage;

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

  String get _currentUid => widget.currentUid.trim();

  String get _currentRole => _normalizeRole(widget.currentRole);

  String get _targetRole => _normalizeRole(widget.targetRole);

  String get _currentName => _safeName(
        widget.currentName,
        _currentRole == 'temporary_parent' ? 'ولي أمر زائر' : 'مستخدم',
      );

  String get _targetName => _safeName(widget.targetName, 'مستخدم');

  @override
  void initState() {
    super.initState();

    _messagesStream = _firestore
        .collection('temporary_messages')
        .where('childId', isEqualTo: widget.childId)
        .limit(200)
        .snapshots();

    messageCtrl.addListener(_handleMessageTextChanged);

    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;

      setState(() {
        playingMessageId = null;
        currentAudioPosition = Duration.zero;
        currentAudioDuration = Duration.zero;
      });
    });

    _audioPositionSubscription =
        _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted || playingMessageId == null) return;

      setState(() {
        currentAudioPosition = position;
      });
    });

    _audioDurationSubscription =
        _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted || playingMessageId == null) return;

      setState(() {
        currentAudioDuration = duration;
      });
    });
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

  String _cleanText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _normalizeRole(dynamic value) {
    final role = _cleanText(value).toLowerCase();

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

      case 'temporary_parent':
      case 'temporary parent':
      case 'ولي أمر زائر':
      case 'ولي الامر الزائر':
      case 'ولي الأمر الزائر':
        return 'temporary_parent';

      default:
        return role;
    }
  }

  String _safeName(String value, String fallback) {
    final clean = value.trim();
    return clean.isEmpty || clean == '-' ? fallback : clean;
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

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDurationSeconds(int seconds) {
    return _formatDuration(Duration(seconds: seconds));
  }

  String _safeMessagePreview(String text) {
    final clean = text.trim();

    if (clean.isEmpty) return 'رسالة';
    if (clean.length <= 45) return clean;

    return '${clean.substring(0, 45)}...';
  }

  String _messagePreviewForReply(_TemporaryMessageData message) {
    if (message.isAudioMessage) return 'رسالة صوتية';
    return _safeMessagePreview(message.text);
  }

  bool _isMessageForThisConversation(Map<String, dynamic> data) {
    final fromRole = _normalizeRole(data['fromRole']);
    final messageTargetRole = _normalizeRole(data['targetRole']);
    final messageTargetUid = _cleanText(data['targetUid']);

    final outgoing =
        fromRole == _currentRole &&
        messageTargetRole == _targetRole;

    final incoming =
        fromRole == _targetRole &&
        messageTargetRole == _currentRole;

    if (!outgoing && !incoming) {
      return false;
    }

    final expectedTargetUid = widget.targetUid.trim();

    if (expectedTargetUid.isEmpty || expectedTargetUid == 'admin') {
      return true;
    }

    return messageTargetUid.isEmpty ||
        messageTargetUid == expectedTargetUid;
  }

  List<_TemporaryMessageData> _conversationMessages(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final messages = docs
        .where((doc) => _isMessageForThisConversation(doc.data()))
        .map((doc) => _TemporaryMessageData.fromDocument(doc))
        .where((message) => !message.deletedForUserIds.contains(_currentUid))
        .toList();

    messages.sort((a, b) {
      final aDate = _dateFromDynamic(a.createdAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _dateFromDynamic(b.createdAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return aDate.compareTo(bDate);
    });

    return messages;
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

  Map<String, dynamic> _baseMessageData() {
    return {
      'accessCodeId': widget.accessCodeId,
      'accessCode': widget.accessCode,
      'childId': widget.childId,
      'childName': widget.childName,
      'parentName': widget.parentName,
      'parentPhone': widget.parentPhone,
      'groupId': widget.groupId,
      'groupName': widget.groupName,
      'fromRole': _currentRole,
      'fromUid': _currentUid,
      'fromName': _currentName,
      'targetRole': _targetRole,
      'targetUid': widget.targetUid,
      'targetName': _targetName,
      'isRead': false,
      'isDelivered': true,
      'reactions': <String, String>{},
      'deletedForUserIds': <String>[],
      'isDeletedForEveryone': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  void _addReplyData(
    Map<String, dynamic> data,
    _TemporaryMessageData? reply,
  ) {
    if (reply == null) return;

    data.addAll({
      'replyToMessageId': reply.id,
      'replyToText': _messagePreviewForReply(reply),
      'replyToSenderUid': reply.fromUid,
      'replyToSenderName': reply.fromName,
    });
  }

  Future<void> _sendMessage() async {
    final text = messageCtrl.text.trim();

    if (text.isEmpty || isSending || isRecordingAudio || isUploadingAudio) {
      return;
    }

    if (_currentUid.isEmpty || _currentRole.isEmpty) {
      _showSnack('تعذر تحديد هوية المستخدم');
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      final data = _baseMessageData()
        ..addAll({
          'messageType': 'text',
          'message': text,
          'text': text,
        });

      _addReplyData(data, replyingToMessage);

      await _firestore.collection('temporary_messages').add(data);

      messageCtrl.clear();
      _canSendNotifier.value = false;

      if (!mounted) return;

      setState(() {
        replyingToMessage = null;
      });

      await _scrollToBottom();
    } catch (_) {
      _showSnack('تعذر إرسال الرسالة');
    } finally {
      if (!mounted) return;

      setState(() {
        isSending = false;
      });
    }
  }

  Future<String> _buildRecordingPath() async {
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    if (kIsWeb) return fileName;

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

  Future<void> _startAudioRecording() async {
    if (isRecordingAudio || isSending || isUploadingAudio) return;

    try {
      final hasPermission = await _audioRecorder.hasPermission();

      if (!hasPermission) {
        _showSnack('يجب السماح باستخدام الميكروفون لتسجيل رسالة صوتية');
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
      _showSnack('تعذر بدء تسجيل الصوت: $e');
    }
  }

  Future<void> _cancelAudioRecording() async {
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
      _showSnack('تعذر إلغاء التسجيل: $e');
    }
  }

  Future<void> _stopAndSendAudioRecording() async {
    if (!isRecordingAudio || _currentUid.isEmpty) return;

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
        folder: 'temporary_messages_audio/${widget.childId}',
        fileNameWithoutExtension:
            'voice_${DateTime.now().millisecondsSinceEpoch}',
      );

      final signedUrl = await MediaStorageService.instance.createSignedUrl(
        path: uploaded.path,
      );

      final data = _baseMessageData()
        ..addAll({
          'messageType': 'audio',
          'message': '',
          'text': '',
          'audioPath': uploaded.path,
          'audioUrl': signedUrl,
          'audioDurationSeconds': recordingSeconds,
          'audioMimeType': uploaded.mimeType,
          'audioSizeBytes': uploaded.sizeBytes,
          'audioBucket': uploaded.bucket,
          'audioStorageProvider': uploaded.storageProvider,
        });

      _addReplyData(data, replyingToMessage);

      await _firestore.collection('temporary_messages').add(data);

      if (!mounted) return;

      setState(() {
        replyingToMessage = null;
        recordingSeconds = 0;
      });

      await _scrollToBottom();
    } catch (e) {
      _showSnack('تعذر إرسال الرسالة الصوتية: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        isUploadingAudio = false;
        recordingSeconds = 0;
      });
    }
  }

  Future<void> _playAudioMessage(_TemporaryMessageData message) async {
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

      if (message.audioPath.isNotEmpty) {
        url = await MediaStorageService.instance.createSignedUrl(
          path: message.audioPath,
        );
      } else {
        url = message.audioUrl;
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

      _showSnack('تعذر تشغيل الرسالة الصوتية: $e');
    }
  }

  Map<String, int> _buildReactionCounts(Map<String, String> reactions) {
    final counts = <String, int>{};

    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    return counts;
  }

  Future<void> _onReactionSelected(
    _TemporaryMessageData message,
    String emoji,
  ) async {
    if (_currentUid.isEmpty || message.isDeletedForEveryone) return;

    try {
      final oldReaction = message.reactions[_currentUid];
      final field = 'reactions.$_currentUid';

      await _firestore.collection('temporary_messages').doc(message.id).update({
        field: oldReaction == emoji ? FieldValue.delete() : emoji,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      _showSnack('تعذر تنفيذ التفاعل على الرسالة');
    }
  }

  Future<void> _copyMessageText(_TemporaryMessageData message) async {
    if (message.isAudioMessage) {
      _showSnack('لا يمكن نسخ رسالة صوتية');
      return;
    }

    if (message.text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: message.text));
    _showSnack('تم نسخ الرسالة');
  }

  void _startReplyToMessage(_TemporaryMessageData message) {
    setState(() {
      replyingToMessage = message;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _messageFocusNode.requestFocus();
    });
  }

  Future<void> _deleteMessageForMe(_TemporaryMessageData message) async {
    if (_currentUid.isEmpty) return;

    try {
      await _firestore.collection('temporary_messages').doc(message.id).update({
        'deletedForUserIds': FieldValue.arrayUnion([_currentUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      _showSnack('تعذر حذف الرسالة');
    }
  }

  Future<void> _deleteMessageForEveryone(_TemporaryMessageData message) async {
    if (_currentUid.isEmpty || message.fromUid != _currentUid) return;

    try {
      await _firestore.collection('temporary_messages').doc(message.id).update({
        'isDeletedForEveryone': true,
        'message': '',
        'text': '',
        'audioUrl': '',
        'audioPath': '',
        'reactions': <String, String>{},
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedByUid': _currentUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      _showSnack('تعذر حذف الرسالة عند الطرفين');
    }
  }

  Future<void> _showDeleteOptions(_TemporaryMessageData message) async {
    final canDeleteForEveryone =
        message.fromUid == _currentUid && !message.isDeletedForEveryone;

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
                ListTile(
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: const Text('حذف لدي فقط'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _deleteMessageForMe(message);
                  },
                ),
                if (canDeleteForEveryone)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'حذف عند الطرفين',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _deleteMessageForEveryone(message);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAllReactionsSheet(_TemporaryMessageData message) {
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
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: allMessageReactions.map((emoji) {
                final isSelected = message.reactions[_currentUid] == emoji;

                return InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    await _onReactionSelected(message, emoji);
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
          ),
        );
      },
    );
  }

  Future<void> _showMessageActions(_TemporaryMessageData message) async {
    if (message.isDeletedForEveryone) {
      await _showDeleteOptions(message);
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
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ...topMessageReactions.map((emoji) {
                      return InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          await _onReactionSelected(message, emoji);
                        },
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      );
                    }),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAllReactionsSheet(message);
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('رد'),
                  onTap: () {
                    Navigator.pop(context);
                    _startReplyToMessage(message);
                  },
                ),
                if (!message.isAudioMessage)
                  ListTile(
                    leading: const Icon(Icons.copy_rounded),
                    title: const Text('نسخ'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _copyMessageText(message);
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'حذف',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _showDeleteOptions(message);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReactionSummary(_TemporaryMessageData message, bool isMe) {
    if (message.isDeletedForEveryone || message.reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final counts = _buildReactionCounts(message.reactions);

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: Wrap(
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        spacing: 6,
        runSpacing: 6,
        children: counts.entries.map((entry) {
          final reactedByMe = message.reactions[_currentUid] == entry.key;

          return InkWell(
            onTap: () => _onReactionSelected(message, entry.key),
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
              child: Text('${entry.key} ${entry.value}'),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReplyPreviewInsideBubble(
    _TemporaryMessageData message,
    bool isMe,
  ) {
    if (message.replyToText.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withOpacity(0.18)
            : widget.headerColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${message.replyToSenderName}\n${message.replyToText}',
        style: TextStyle(
          color: isMe ? Colors.white70 : AppColors.textLight,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDeletedMessageBubble(bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.secondary.withOpacity(0.22) : Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'تم حذف هذه الرسالة',
        style: TextStyle(
          color: AppColors.textLight,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAudioMessageContent(
    _TemporaryMessageData message,
    bool isMe,
  ) {
    final isPlaying = playingMessageId == message.id;
    final fallbackDuration = Duration(seconds: message.audioDurationSeconds);
    final totalDuration = isPlaying && currentAudioDuration > Duration.zero
        ? currentAudioDuration
        : fallbackDuration;
    final position = isPlaying ? currentAudioPosition : Duration.zero;

    final progress = totalDuration.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / totalDuration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      constraints: const BoxConstraints(maxWidth: 290, minWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.secondary : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _buildReplyPreviewInsideBubble(message, isMe),
          Row(
            children: [
              IconButton(
                onPressed: () => _playAudioMessage(message),
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: isMe ? Colors.white : AppColors.secondary,
                ),
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  color: isMe ? Colors.white : AppColors.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(totalDuration),
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.textDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            _formatTime(message.createdAt),
            style: TextStyle(
              color: isMe ? Colors.white70 : AppColors.textLight,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextMessageContent(_TemporaryMessageData message, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      constraints: const BoxConstraints(maxWidth: 290, minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.secondary : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _buildReplyPreviewInsideBubble(message, isMe),
          Text(
            message.text.isEmpty ? 'رسالة' : message.text,
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
                _formatTime(message.createdAt),
                style: TextStyle(
                  color: isMe ? Colors.white70 : AppColors.textLight,
                  fontSize: 11.5,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 6),
                Text(
                  message.isRead ? '✔✔' : '✔',
                  style: TextStyle(
                    color: message.isRead
                        ? Colors.lightBlueAccent
                        : Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  bool _isMyDisplayedMessage(_TemporaryMessageData message) {
    if (_currentRole == 'temporary_parent') {
      return message.fromRole == 'temporary_parent';
    }

    return message.fromUid == _currentUid ||
        (message.fromUid.isEmpty && message.fromRole == _currentRole);
  }

  Widget _buildMessageBubble(_TemporaryMessageData message) {
    final isMe = _isMyDisplayedMessage(message);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: () => _showMessageActions(message),
              child: message.isDeletedForEveryone
                  ? _buildDeletedMessageBubble(isMe)
                  : message.isAudioMessage
                      ? _buildAudioMessageContent(message, isMe)
                      : _buildTextMessageContent(message, isMe),
            ),
            _buildReactionSummary(message, isMe),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBanner() {
    final reply = replyingToMessage;
    if (reply == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'الرد على ${reply.fromName}\n${_messagePreviewForReply(reply)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

  Widget _buildRecordingBar() {
    if (!isRecordingAudio && !isUploadingAudio) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isUploadingAudio
                  ? 'جاري إرسال الرسالة الصوتية...'
                  : 'جاري التسجيل ${_formatDurationSeconds(recordingSeconds)}',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isRecordingAudio)
            TextButton(
              onPressed: _cancelAudioRecording,
              child: const Text('إلغاء'),
            ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildReplyBanner(),
        _buildRecordingBar(),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
                        ? 'اكتب رسالة...'
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

                  if (isRecordingAudio) {
                    icon = Icons.send_rounded;
                    onTap = disabled ? null : _stopAndSendAudioRecording;
                  } else if (canSend) {
                    icon = Icons.send_rounded;
                    onTap = disabled ? null : _sendMessage;
                  } else {
                    icon = Icons.mic_rounded;
                    onTap = disabled ? null : _startAudioRecording;
                  }

                  return GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: disabled
                            ? AppColors.secondary.withOpacity(0.45)
                            : AppColors.secondary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: isSending || isUploadingAudio
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(icon, color: Colors.white),
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

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'حدث خطأ أثناء تحميل الرسائل: ${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }

        final messages = _conversationMessages(snapshot.data?.docs ?? []);

        if (messages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(animated: false);
          });
        }

        if (messages.isEmpty) {
          return const Center(child: Text('لا توجد رسائل بعد'));
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return _buildMessageBubble(messages[index]);
          },
        );
      },
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: widget.headerColor.withOpacity(0.14),
            child: Icon(widget.headerIcon, color: widget.headerColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _targetName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.headerSubtitle,
                  style: const TextStyle(
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

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AppPageScaffold(
        title: 'المحادثة',
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 14),
            Expanded(child: _buildMessagesList()),
            const SizedBox(height: 8),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }
}

class _TemporaryMessageData {
  final String id;
  final String fromRole;
  final String fromUid;
  final String fromName;
  final String text;
  final dynamic createdAt;
  final bool isRead;
  final bool isDeletedForEveryone;
  final bool isAudioMessage;
  final String audioPath;
  final String audioUrl;
  final int audioDurationSeconds;
  final Map<String, String> reactions;
  final List<String> deletedForUserIds;
  final String replyToText;
  final String replyToSenderName;

  const _TemporaryMessageData({
    required this.id,
    required this.fromRole,
    required this.fromUid,
    required this.fromName,
    required this.text,
    required this.createdAt,
    required this.isRead,
    required this.isDeletedForEveryone,
    required this.isAudioMessage,
    required this.audioPath,
    required this.audioUrl,
    required this.audioDurationSeconds,
    required this.reactions,
    required this.deletedForUserIds,
    required this.replyToText,
    required this.replyToSenderName,
  });

  factory _TemporaryMessageData.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final rawReactions = data['reactions'];
    final reactions = <String, String>{};

    if (rawReactions is Map) {
      rawReactions.forEach((key, value) {
        final emoji = value?.toString().trim() ?? '';
        if (emoji.isNotEmpty) reactions[key.toString()] = emoji;
      });
    }

    final rawDeletedIds = data['deletedForUserIds'];
    final deletedForUserIds = rawDeletedIds is List
        ? rawDeletedIds.map((e) => e.toString()).toList()
        : <String>[];

    final audioPath = (data['audioPath'] ?? '').toString().trim();
    final audioUrl = (data['audioUrl'] ?? '').toString().trim();
    final messageType = (data['messageType'] ?? '').toString().trim();

    return _TemporaryMessageData(
      id: doc.id,
      fromRole: (data['fromRole'] ?? '').toString().trim().toLowerCase(),
      fromUid: (data['fromUid'] ?? '').toString().trim(),
      fromName: (data['fromName'] ?? 'مستخدم').toString().trim(),
      text: (data['message'] ?? data['text'] ?? '').toString().trim(),
      createdAt: data['createdAt'],
      isRead: data['isRead'] == true,
      isDeletedForEveryone: data['isDeletedForEveryone'] == true,
      isAudioMessage:
          messageType == 'audio' || audioPath.isNotEmpty || audioUrl.isNotEmpty,
      audioPath: audioPath,
      audioUrl: audioUrl,
      audioDurationSeconds:
          (data['audioDurationSeconds'] as num?)?.toInt() ?? 0,
      reactions: reactions,
      deletedForUserIds: deletedForUserIds,
      replyToText: (data['replyToText'] ?? '').toString().trim(),
      replyToSenderName:
          (data['replyToSenderName'] ?? 'رسالة سابقة').toString().trim(),
    );
  }
}
