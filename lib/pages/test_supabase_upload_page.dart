import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/media_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';

class TestSupabaseUploadPage extends StatefulWidget {
  const TestSupabaseUploadPage({super.key});

  @override
  State<TestSupabaseUploadPage> createState() => _TestSupabaseUploadPageState();
}

class _TestSupabaseUploadPageState extends State<TestSupabaseUploadPage> {
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedFile;
  Uint8List? _webPreviewBytes;

  bool _isUploading = false;
  String? _uploadedPath;
  String? _signedUrl;
  String? _error;

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      Uint8List? previewBytes;
      if (kIsWeb) {
        previewBytes = await file.readAsBytes();
      }

      setState(() {
        _selectedFile = file;
        _webPreviewBytes = previewBytes;
        _uploadedPath = null;
        _signedUrl = null;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'فشل اختيار الصورة: $e';
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedFile == null) {
      setState(() {
        _error = 'يرجى اختيار صورة أولاً';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final result = await MediaStorageService.instance.uploadImageOrVideo(
        file: _selectedFile!,
        folder: 'test-uploads',
        fileNameWithoutExtension:
            'test_${DateTime.now().millisecondsSinceEpoch}',
      );

      final signedUrl = await MediaStorageService.instance.createSignedUrl(
        path: result.path,
      );

      setState(() {
        _uploadedPath = result.path;
        _signedUrl = signedUrl;
      });
    } catch (e) {
      setState(() {
        _error = 'فشل رفع الصورة: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Widget _buildPreview() {
    if (_selectedFile == null) {
      return Container(
        height: 220,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text('لم يتم اختيار صورة بعد'),
      );
    }

    if (kIsWeb) {
      if (_webPreviewBytes == null) {
        return Container(
          height: 220,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Text('تعذر عرض المعاينة على الويب'),
        );
      }

      return Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(
          _webPreviewBytes!,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        _selectedFile!.path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return const Center(
            child: Text('تعذر عرض الصورة المختارة'),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'اختبار رفع Supabase',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'هذه الصفحة فقط لاختبار رفع صورة إلى Supabase قبل ربطه بصفحات التطبيق الأساسية.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          _buildPreview(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _pickImage,
            child: const Text('اختيار صورة'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isUploading ? null : _uploadImage,
            child: Text(
              _isUploading ? 'جاري الرفع...' : 'رفع الصورة إلى Supabase',
            ),
          ),
          const SizedBox(height: 16),
          if (_uploadedPath != null) ...[
            const Text(
              'تم الرفع بنجاح',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText('Path: $_uploadedPath'),
            const SizedBox(height: 8),
          ],
          if (_signedUrl != null) ...[
            const Text(
              'Signed URL:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(_signedUrl!),
            const SizedBox(height: 12),
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                _signedUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const Center(
                    child: Text('تعذر عرض الصورة المرفوعة'),
                  );
                },
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}