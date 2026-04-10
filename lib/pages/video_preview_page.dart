import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class VideoPreviewPage extends StatefulWidget {
  final String path;
  final String? title;

  const VideoPreviewPage({
    super.key,
    required this.path,
    this.title,
  });

  @override
  State<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
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

  bool _isWebBlobPath(String value) {
    final lower = value.trim().toLowerCase();
    return lower.startsWith('blob:');
  }

  bool _isNetworkPath(String value) {
    final lower = value.trim().toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('blob:');
  }

  bool _isFilePath(String value) {
    final lower = value.trim().toLowerCase();

    if (lower.startsWith('file://') ||
        lower.startsWith('/storage/') ||
        lower.startsWith('/data/') ||
        lower.startsWith('c:\\') ||
        lower.startsWith('d:\\')) {
      return true;
    }

    if (kIsWeb) {
      return false;
    }

    try {
      return File(value).existsSync();
    } catch (_) {
      return false;
    }
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

      if (rawPath.isEmpty) {
        throw Exception('رابط أو مسار الفيديو فارغ');
      }

      VideoPlayerController controller;

      if (_isNetworkPath(rawPath)) {
        controller = VideoPlayerController.networkUrl(Uri.parse(rawPath));
      } else if (_isFilePath(rawPath)) {
        if (kIsWeb) {
          throw Exception('معاينة الملف المحلي غير مدعومة على الويب');
        }

        String cleanPath = rawPath;
        if (rawPath.startsWith('file://')) {
          cleanPath = rawPath.replaceFirst('file://', '');
        }

        final file = File(cleanPath);

        if (!file.existsSync()) {
          throw Exception('ملف الفيديو غير موجود على هذا الجهاز');
        }

        controller = VideoPlayerController.file(file);
      } else {
        throw Exception('مصدر الفيديو غير صالح أو غير معروف');
      }

      _controller = controller;

      await _controller!.initialize();
      await _controller!.setLooping(false);
      await _controller!.setVolume(1.0);

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
    final isBlob = _isWebBlobPath(widget.path);
    final isLikelyLocalPath = !_isNetworkPath(widget.path);

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
              isBlob
                  ? 'تم التقاط الفيديو لكن المتصفح لم يتمكن من تشغيل رابط الـ blob داخل المعاينة الحالية. هذا لا يعني بالضرورة أن الرفع سيفشل، لكنه يعني أن المعاينة المحلية لم تعمل.'
                  : isLikelyLocalPath
                      ? 'هذا الفيديو يبدو أنه محفوظ كملف محلي على جهاز آخر، لذلك لا يمكن فتحه هنا. يجب رفعه إلى التخزين وحفظ رابط التحميل ليتمكن وليّ الأمر من مشاهدته.'
                      : 'تعذر تحميل رابط الفيديو. تأكدي من صحة الرابط واتصال الإنترنت.',
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