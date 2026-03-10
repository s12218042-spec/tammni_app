import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/app_bar_widget.dart';

class CameraCheckinPage extends StatefulWidget {
  const CameraCheckinPage({super.key});

  @override
  State<CameraCheckinPage> createState() => _CameraCheckinPageState();
}

class _CameraCheckinPageState extends State<CameraCheckinPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? picked;
  String mediaType = 'image'; // image / video

  Future<void> takePhoto() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (x == null) return;
    setState(() {
      picked = x;
      mediaType = 'image';
    });
  }

  Future<void> takeVideo() async {
    final x = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 15));
    if (x == null) return;
    setState(() {
      picked = x;
      mediaType = 'video';
    });
  }

  void sendBack() {
    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('صوّري صورة أو فيديو أولاً')),
      );
      return;
    }
    Navigator.pop(context, {
      'path': picked!.path,
      'type': mediaType,
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = picked == null ? null : File(picked!.path);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AppBarWidget(
  title: 'إدارة الأطفال',
),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                  color: const Color(0xFFF6F6FF),
                ),
                child: const Text(
                  'صوّري صورة أو فيديو قصير للطفل، وسيظهر لوليّ الأمر كتحديث "كاميرا".',
                ),
              ),
              const SizedBox(height: 12),

              if (file == null)
                Container(
                  height: 180,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Text('لا يوجد معاينة بعد'),
                )
              else if (mediaType == 'image')
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(file, height: 220, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 180,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Text('تم تسجيل فيديو \n(سيظهر لولي الأمر مع زر تشغيل)'),
                ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: takePhoto,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('صورة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E97FD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: takeVideo,
                      icon: const Icon(Icons.videocam),
                      label: const Text('فيديو 15ث'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: sendBack,
                  icon: const Icon(Icons.send),
                  label: const Text('إرسال لولي الأمر'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E97FD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}