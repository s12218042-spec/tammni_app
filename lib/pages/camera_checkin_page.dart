import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class CameraCheckinPage extends StatefulWidget {
  const CameraCheckinPage({super.key});

  @override
  State<CameraCheckinPage> createState() => _CameraCheckinPageState();
}

class _CameraCheckinPageState extends State<CameraCheckinPage> {
  final ImagePicker _picker = ImagePicker();

  XFile? picked;
  String mediaType = 'image'; // image / video
  bool isBusy = false;

  Future<void> takePhoto() async {
    try {
      setState(() {
        isBusy = true;
      });

      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
      );

      if (x == null) {
        setState(() {
          isBusy = false;
        });
        return;
      }

      setState(() {
        picked = x;
        mediaType = 'image';
        isBusy = false;
      });
    } catch (e) {
      setState(() {
        isBusy = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التقاط الصورة: $e')),
      );
    }
  }

  Future<void> takeVideo() async {
    try {
      setState(() {
        isBusy = true;
      });

      final x = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 15),
      );

      if (x == null) {
        setState(() {
          isBusy = false;
        });
        return;
      }

      setState(() {
        picked = x;
        mediaType = 'video';
        isBusy = false;
      });
    } catch (e) {
      setState(() {
        isBusy = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تسجيل الفيديو: $e')),
      );
    }
  }

  void sendBack() {
    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('صوّري صورة أو فيديو أولًا')),
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
    return AppPageScaffold(
      title: 'الكاميرا',
      child: ListView(
        children: [
          Text(
            'إرسال تحديث بالكاميرا',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'صوّري صورة أو فيديو قصير للطفل، وسيظهر لوليّ الأمر كتحديث داخل التطبيق.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: const Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'يمكنك التقاط صورة أو تسجيل فيديو قصير ثم إرساله مباشرة كجزء من تحديثات الطفل.',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (isBusy)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (picked == null)
            Container(
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
                color: Colors.white,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    size: 48,
                    color: AppColors.primary.withOpacity(0.8),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'لا توجد معاينة بعد',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          else if (mediaType == 'image')
            Container(
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
                color: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  kIsWeb
                      ? 'تم اختيار صورة بنجاح 📸\nالمعاينة المحلية غير مدعومة على Flutter Web'
                      : 'تم اختيار صورة بنجاح 📸\nيمكنك إرسالها الآن لوليّ الأمر',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            )
          else
            Container(
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
                color: Colors.white,
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'تم تسجيل فيديو بنجاح 🎥\nسيظهر لوليّ الأمر مع زر تشغيل',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isBusy ? null : takePhoto,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('صورة'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : takeVideo,
                  icon: const Icon(Icons.videocam),
                  label: const Text('فيديو 15ث'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: isBusy ? null : sendBack,
            icon: const Icon(Icons.send_outlined),
            label: const Text('إرسال التحديث'),
          ),
        ],
      ),
    );
  }
}
