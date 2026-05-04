import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class VideoPreviewPage extends StatefulWidget {
  final String path;
  final String? title;

  final String? mediaPath;
  final String? mediaUrl;
  final String? publicUrl;
  final String? storageProvider;

  const VideoPreviewPage({
    super.key,
    required this.path,
    this.title,
    this.mediaPath,
    this.mediaUrl,
    this.publicUrl,
    this.storageProvider,
  });

  @override
  State<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
  final GalleryService _galleryService = GalleryService();

  VideoPlayerController? _controller;

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;


  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool _isNetworkUrl(String value) {
    final lower = value.trim().toLowerCase();

    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  bool _isBlobUrl(String value) {
    return value.trim().toLowerCase().startsWith('blob:');
  }

  bool _looksLikeSupabaseStoragePath(String value) {
    final clean = value.trim();

    if (clean.isEmpty) return false;
    if (_isNetworkUrl(clean)) return false;
    if (_isBlobUrl(clean)) return false;
    if (clean.startsWith('file://')) return false;

    return clean.contains('/') &&
        (clean.contains('children_media') ||
            clean.contains('videos') ||
            clean.endsWith('.mp4') ||
            clean.endsWith('.mov') ||
            clean.endsWith('.webm') ||
            clean.endsWith('.m4v'));
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }

  Future<String?> _resolveVideoUrl() async {
    final rawPath = widget.path.trim();

    final explicitMediaPath = _firstNonEmpty([
      widget.mediaPath,
      _looksLikeSupabaseStoragePath(rawPath) ? rawPath : null,
    ]);

    final oldUrl = _firstNonEmpty([
      widget.mediaUrl,
      _isNetworkUrl(rawPath) ? rawPath : null,
    ]);

    final publicUrl = _firstNonEmpty([
      widget.publicUrl,
    ]);

    final storageProvider = _firstNonEmpty([
      widget.storageProvider,
      explicitMediaPath.isNotEmpty ? 'supabase' : '',
    ]);

    final freshUrl = await _galleryService.resolveFreshMediaUrlFromFields(
      storageProvider: storageProvider,
      mediaPath: explicitMediaPath,
      oldMediaUrl: oldUrl,
      publicUrl: publicUrl,
    );

    if (freshUrl != null && freshUrl.trim().isNotEmpty) {
      return freshUrl.trim();
    }

    if (_isNetworkUrl(rawPath)) {
      return rawPath;
    }

    return null;
  }

  Future<void> _initializeVideo() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      await _controller?.dispose();
      _controller = null;

      final rawPath = widget.path.trim();

      if (rawPath.isEmpty &&
          (widget.mediaPath == null || widget.mediaPath!.trim().isEmpty) &&
          (widget.mediaUrl == null || widget.mediaUrl!.trim().isEmpty)) {
        throw Exception('لا يوجد مصدر فيديو صالح');
      }

      if (_isBlobUrl(rawPath)) {
        throw Exception(
          'رابط blob مؤقت من المتصفح ولا يمكن استخدامه بعد مغادرة صفحة الالتقاط. يجب عرض الفيديو من mediaPath بعد رفعه إلى Supabase.',
        );
      }

      final videoUrl = await _resolveVideoUrl();

      if (videoUrl == null || videoUrl.trim().isEmpty) {
        throw Exception(
          'تعذر إنشاء رابط تشغيل للفيديو. تأكدي من وجود mediaPath محفوظ في Firestore.',
        );
      }

      if (!_isNetworkUrl(videoUrl)) {
        throw Exception(
          'مصدر الفيديو ليس رابط شبكة صالح. يجب استخدام mediaPath لتوليد رابط Supabase جديد.',
        );
      }

    

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );

      _controller = controller;

      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(1.0);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  void _seekForward() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final current = controller.value.position;
    final duration = controller.value.duration;
    final target = current + const Duration(seconds: 10);

    controller.seekTo(target < duration ? target : duration);
  }

  void _seekBackward() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final current = controller.value.position;
    final target = current - const Duration(seconds: 10);

    controller.seekTo(target > Duration.zero ? target : Duration.zero);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }

    return '${duration.inMinutes}:$seconds';
  }

  Widget _buildErrorState() {
    final rawPath = widget.path.trim();

    String message = 'تعذر تحميل الفيديو.';

    if (_isBlobUrl(rawPath)) {
      message =
          'هذا رابط مؤقت من المتصفح ولا يصلح للعرض لاحقًا. يجب فتح الفيديو من mediaPath بعد رفعه إلى Supabase.';
    } else if (widget.mediaPath == null || widget.mediaPath!.trim().isEmpty) {
      message =
          'لا يوجد mediaPath محفوظ لهذا الفيديو، لذلك لا يمكن توليد رابط Supabase جديد.';
    } else if (_errorMessage.contains('403') ||
        _errorMessage.toLowerCase().contains('unauthorized') ||
        _errorMessage.toLowerCase().contains('expired')) {
      message =
          'رابط الفيديو القديم انتهت صلاحيته. تمت محاولة توليد رابط جديد، لكن العملية فشلت.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.video_file_outlined,
              color: AppColors.danger,
              size: 46,
            ),
            const SizedBox(height: 12),
            const Text(
              'تعذر تشغيل الفيديو',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                height: 1.6,
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    height: 1.5,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _initializeVideo,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final controller = _controller!;
    final position = controller.value.position;
    final duration = controller.value.duration;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0
                  ? 16 / 9
                  : controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(controller),
                  if (_showControls)
                    Container(
                      color: Colors.black.withOpacity(0.18),
                    ),
                  if (_showControls)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _seekBackward,
                          icon: const Icon(
                            Icons.replay_10_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            onPressed: _togglePlayPause,
                            icon: Icon(
                              controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _seekForward,
                          icon: const Icon(
                            Icons.forward_10_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  colors: VideoProgressColors(
                    playedColor: AppColors.primary,
                    bufferedColor: AppColors.primary.withOpacity(0.25),
                    backgroundColor: AppColors.border,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            controller.value.isPlaying ? 'الفيديو قيد التشغيل' : 'الفيديو متوقف',
            style: const TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return AppPageScaffold(
      title: widget.title ?? 'معاينة الفيديو',
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _hasError || controller == null || !controller.value.isInitialized
                ? _buildErrorState()
                : _buildVideoPlayer(),
      ),
    );
  }
}