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

  void clearPicked() {
    setState(() {
      picked = null;
      mediaType = 'image';
    });
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

  String pickedTitle() {
    if (picked == null) return 'لا توجد معاينة بعد';
    return mediaType == 'image' ? 'تم اختيار صورة' : 'تم تسجيل فيديو';
  }

  String pickedHint() {
    if (picked == null) {
      return 'التقطي صورة أو فيديو قصير لإرساله كتحديث للطفل داخل التطبيق.';
    }

    if (mediaType == 'image') {
      return kIsWeb
          ? 'تم اختيار صورة بنجاح.\nالمعاينة المحلية غير مدعومة على Flutter Web، لكن سيتم إرسالها مع التحديث.'
          : 'تم اختيار صورة بنجاح.\nيمكنك الآن إرسالها كتحديث لوليّ الأمر.';
    }

    return kIsWeb
        ? 'تم تسجيل فيديو بنجاح.\nالمعاينة المحلية غير مدعومة على Flutter Web، لكن سيتم إرسال الفيديو مع التحديث.'
        : 'تم تسجيل فيديو بنجاح.\nسيُرسل كتحديث مع إمكانية عرضه لاحقًا.';
  }

  IconData previewIcon() {
    if (picked == null) return Icons.photo_camera_outlined;
    return mediaType == 'image'
        ? Icons.image_outlined
        : Icons.video_library_outlined;
  }

  Color previewColor() {
    if (picked == null) return AppColors.primary;
    return mediaType == 'image' ? AppColors.primary : AppColors.secondary;
  }

  Widget buildPreviewCard() {
    if (isBusy) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: previewColor().withOpacity(0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              previewIcon(),
              size: 36,
              color: previewColor(),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            pickedTitle(),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            pickedHint(),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (picked != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تفاصيل الملف',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mediaType == 'image' ? 'النوع: صورة' : 'النوع: فيديو',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المسار المحلي: ${picked!.path}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : takePhoto,
                icon: const Icon(Icons.photo_camera),
                label: Text(picked == null ? 'التقاط صورة' : 'إعادة تصوير'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : takeVideo,
                icon: const Icon(Icons.videocam),
                label: Text(picked == null ? 'فيديو 15ث' : 'إعادة فيديو'),
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
        if (picked != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : clearPicked,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف المرفق'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isBusy ? null : sendBack,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('إرسال التحديث'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'الكاميرا',
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.14),
                  AppColors.secondary.withOpacity(0.10),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'إرسال تحديث بالكاميرا',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'التقطي صورة أو فيديو قصير ليظهر كتحديث داخل التطبيق للأهل. هذه الصفحة خاصة بإضافة وسائط للتحديث وليست حضورًا يوميًا.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textLight,
                    height: 1.5,
                  ),
                ),
              ],
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
                      'استخدمي الكاميرا للتوثيق السريع: نشاط، لحظة لطيفة، أو ملاحظة مرئية يحتاجها وليّ الأمر.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          buildPreviewCard(),
          const SizedBox(height: 16),
          buildActionButtons(),
        ],
      ),
    );
  }
}