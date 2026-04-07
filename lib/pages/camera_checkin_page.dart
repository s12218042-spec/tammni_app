import 'dart:async';

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
  final TextEditingController descriptionCtrl = TextEditingController();

  XFile? picked;
  Uint8List? imageBytes;

  String mediaType = 'image'; // image / video
  bool isBusy = false;
  int selectedTimer = 0; // 0 / 3 / 5
  CameraDevice selectedCamera = CameraDevice.rear;

  @override
  void dispose() {
    descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _waitForTimer() async {
    if (selectedTimer > 0) {
      await Future.delayed(Duration(seconds: selectedTimer));
    }
  }

  Future<void> takePhoto() async {
    try {
      setState(() {
        isBusy = true;
      });

      await _waitForTimer();

      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        preferredCameraDevice: selectedCamera,
      );

      if (x == null) {
        setState(() {
          isBusy = false;
        });
        return;
      }

      final bytes = await x.readAsBytes();

      setState(() {
        picked = x;
        imageBytes = bytes;
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

  Future<void> pickFromGallery() async {
    try {
      setState(() {
        isBusy = true;
      });

      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (x == null) {
        setState(() {
          isBusy = false;
        });
        return;
      }

      final bytes = await x.readAsBytes();

      setState(() {
        picked = x;
        imageBytes = bytes;
        mediaType = 'image';
        isBusy = false;
      });
    } catch (e) {
      setState(() {
        isBusy = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء اختيار الصورة: $e')),
      );
    }
  }

  Future<void> takeVideo() async {
    try {
      setState(() {
        isBusy = true;
      });

      await _waitForTimer();

      final x = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 15),
        preferredCameraDevice: selectedCamera,
      );

      if (x == null) {
        setState(() {
          isBusy = false;
        });
        return;
      }

      setState(() {
        picked = x;
        imageBytes = null;
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
      imageBytes = null;
      mediaType = 'image';
      descriptionCtrl.clear();
    });
  }

  void sendBack() {
    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('صوّري صورة أو فيديو أولًا')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تجهيز الميديا بنجاح وإرسالها للصفحة السابقة'),
      ),
    );

    Navigator.pop(context, {
      'path': picked!.path,
      'type': mediaType,
      'description': descriptionCtrl.text.trim(),
    });
  }

  String _modeLabel() {
    return mediaType == 'image' ? 'صورة' : 'فيديو';
  }

  String _cameraLabel() {
    return selectedCamera == CameraDevice.front ? 'أمامية' : 'خلفية';
  }

  String _timerLabel() {
    if (selectedTimer == 0) return 'بدون مؤقت';
    return '$selectedTimer ثواني';
  }

  Widget buildTopInfoCard() {
    return Container(
      width: double.infinity,
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
            'التقاط صورة أو فيديو للتحديث',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'هذه الصفحة مخصصة لإرسال ميديا كتحديث لوليّ الأمر، وليست لتسجيل الحضور. يمكنك التقاط صورة، تسجيل فيديو قصير، أو اختيار صورة جاهزة من الجهاز.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: isBusy
                  ? null
                  : () {
                      setState(() {
                        mediaType = 'image';
                      });
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: mediaType == 'image'
                      ? AppColors.primary.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '📷 صورة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: mediaType == 'image'
                        ? AppColors.primary
                        : AppColors.textLight,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isBusy
                  ? null
                  : () {
                      setState(() {
                        mediaType = 'video';
                      });
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: mediaType == 'video'
                      ? AppColors.secondary.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '🎥 فيديو',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: mediaType == 'video'
                        ? AppColors.secondary
                        : AppColors.textLight,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildQuickOptionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withOpacity(0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'خيارات سريعة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _OptionChip(
                label: 'المؤقت: ${_timerLabel()}',
                icon: Icons.timer_outlined,
                isSelected: false,
              ),
              _OptionChip(
                label: 'الكاميرا: ${_cameraLabel()}',
                icon: Icons.cameraswitch_outlined,
                isSelected: false,
              ),
              _OptionChip(
                label: 'الوضع: ${_modeLabel()}',
                icon: mediaType == 'image'
                    ? Icons.image_outlined
                    : Icons.video_library_outlined,
                isSelected: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'المؤقت',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('0 ث'),
                selected: selectedTimer == 0,
                onSelected: isBusy
                    ? null
                    : (_) {
                        setState(() {
                          selectedTimer = 0;
                        });
                      },
              ),
              ChoiceChip(
                label: const Text('3 ث'),
                selected: selectedTimer == 3,
                onSelected: isBusy
                    ? null
                    : (_) {
                        setState(() {
                          selectedTimer = 3;
                        });
                      },
              ),
              ChoiceChip(
                label: const Text('5 ث'),
                selected: selectedTimer == 5,
                onSelected: isBusy
                    ? null
                    : (_) {
                        setState(() {
                          selectedTimer = 5;
                        });
                      },
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'نوع الكاميرا',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('خلفية'),
                selected: selectedCamera == CameraDevice.rear,
                onSelected: isBusy
                    ? null
                    : (_) {
                        setState(() {
                          selectedCamera = CameraDevice.rear;
                        });
                      },
              ),
              ChoiceChip(
                label: const Text('أمامية'),
                selected: selectedCamera == CameraDevice.front,
                onSelected: isBusy
                    ? null
                    : (_) {
                        setState(() {
                          selectedCamera = CameraDevice.front;
                        });
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'ملاحظة: تم تفعيل المؤقت وتبديل الكاميرا بشكل آمن. أما الفلاش فلا يمكن التحكم به مباشرة من هذه الصفحة باستخدام الحزمة الحالية فقط.',
              style: TextStyle(
                fontSize: 12.8,
                color: AppColors.textLight,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPreviewCard() {
    if (isBusy) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border.withOpacity(0.8)),
        ),
        child: Column(
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text(
              'جاري تجهيز الميديا...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المعاينة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          if (picked == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: const [
                  Icon(
                    Icons.photo_camera_outlined,
                    size: 58,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'لا توجد معاينة بعد',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'التقط صورة أو فيديو أو اختَر صورة من الجهاز لتظهر هنا مباشرة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textLight,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          else if (mediaType == 'image' && imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.memory(
                imageBytes!,
                width: double.infinity,
                height: 260,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    size: 58,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'تم تسجيل فيديو بنجاح',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kIsWeb
                        ? 'معاينة الفيديو المحلية الكاملة على الويب قد تكون محدودة، لكن الفيديو تم تجهيزه للإرسال.'
                        : 'الفيديو جاهز للإرسال مع التحديث.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textLight,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          if (picked != null) ...[
            const SizedBox(height: 12),
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
                    'النوع: ${mediaType == 'image' ? 'صورة' : 'فيديو'}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المصدر: ${mediaType == 'image' ? 'صورة مرفوعة أو ملتقطة' : 'فيديو مسجّل'}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600,
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

  Widget buildDescriptionField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'وصف الميديا',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'أضيفي وصفًا قصيرًا ليظهر مع التحديث للأهل.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'مثال: نشاط فني جميل، لحظة لعب، أو مشاركة من يوم الطفل...',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.border.withOpacity(0.8),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.border.withOpacity(0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPrimaryActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isBusy
                    ? null
                    : () {
                        if (mediaType == 'image') {
                          takePhoto();
                        } else {
                          takeVideo();
                        }
                      },
                icon: Icon(
                  mediaType == 'image' ? Icons.photo_camera : Icons.videocam,
                ),
                label: Text(
                  mediaType == 'image' ? 'التقاط صورة' : 'تسجيل فيديو',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy || mediaType != 'image' ? null : pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('اختيار من المعرض'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
                  onPressed: isBusy
                      ? null
                      : () {
                          if (mediaType == 'image') {
                            takePhoto();
                          } else {
                            takeVideo();
                          }
                        },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة الالتقاط'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : clearPicked,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isBusy ? null : sendBack,
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ وإرسال'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
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
          buildTopInfoCard(),
          const SizedBox(height: 16),
          buildModeSelector(),
          const SizedBox(height: 16),
          buildQuickOptionsCard(),
          const SizedBox(height: 16),
          buildPreviewCard(),
          const SizedBox(height: 16),
          buildDescriptionField(),
          const SizedBox(height: 16),
          buildPrimaryActions(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;

  const _OptionChip({
    required this.label,
    required this.icon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withOpacity(0.10)
            : AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? AppColors.primary : AppColors.textLight,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}


