import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class VideoPreviewPage extends StatefulWidget {
  final String path;

  const VideoPreviewPage({
    super.key,
    required this.path,
  });

  @override
  State<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
  late VideoPlayerController controller;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          hasError = true;
        });
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void togglePlayPause() {
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'معاينة الفيديو',
      floatingActionButton: controller.value.isInitialized && !hasError
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: togglePlayPause,
              child: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            )
          : null,
      child: Center(
        child: hasError
            ? Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 42,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'تعذر تشغيل الفيديو',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : controller.value.isInitialized
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        controller.value.isPlaying
                            ? 'الفيديو قيد التشغيل'
                            : 'الفيديو متوقف',
                        style: TextStyle(
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
      ),
    );
  }
}