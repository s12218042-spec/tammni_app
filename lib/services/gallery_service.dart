import 'package:image_picker/image_picker.dart';

import 'media_storage_service.dart';

class GalleryUploadResult {
  final String storageProvider;
  final String bucket;
  final String path;
  final String signedUrl;
  final String mediaType;
  final String mimeType;
  final int sizeBytes;

  GalleryUploadResult({
    required this.storageProvider,
    required this.bucket,
    required this.path,
    required this.signedUrl,
    required this.mediaType,
    required this.mimeType,
    required this.sizeBytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'storageProvider': storageProvider,
      'bucket': bucket,
      'mediaPath': path,
      'mediaUrl': signedUrl,
      'mediaType': mediaType,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
    };
  }
}

class GalleryService {
  Future<String?> uploadChildMedia({
    required String childId,
    required String localPath,
    required String mediaType, // image / video
  }) async {
    try {
      final extension = _extractExtensionFromPath(
        localPath,
        mediaType: mediaType,
      );

      final folder = mediaType == 'video' ? 'videos' : 'images';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';

      final xFile = XFile(localPath);

      final result = await MediaStorageService.instance.uploadImageOrVideo(
        file: xFile,
        folder: 'children_media/$childId/$folder',
        fileNameWithoutExtension: fileName.replaceFirst('.$extension', ''),
      );

      final signedUrl = await MediaStorageService.instance.createSignedUrl(
        path: result.path,
      );

      return signedUrl;
    } catch (e) {
      print('Supabase upload error: $e');
      return null;
    }
  }

  Future<GalleryUploadResult?> uploadChildMediaDetailed({
    required String childId,
    required XFile file,
    required String mediaType, // image / video
  }) async {
    try {
      final folder = mediaType == 'video' ? 'videos' : 'images';
      final extension = _extractExtensionFromFile(
        file,
        mediaType: mediaType,
      );
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';

      final uploaded = await MediaStorageService.instance.uploadImageOrVideo(
        file: file,
        folder: 'children_media/$childId/$folder',
        fileNameWithoutExtension: fileName.replaceFirst('.$extension', ''),
      );

      final signedUrl = await MediaStorageService.instance.createSignedUrl(
        path: uploaded.path,
      );

      return GalleryUploadResult(
        storageProvider: uploaded.storageProvider,
        bucket: uploaded.bucket,
        path: uploaded.path,
        signedUrl: signedUrl,
        mediaType: mediaType,
        mimeType: uploaded.mimeType,
        sizeBytes: uploaded.sizeBytes,
      );
    } catch (e) {
      print('Supabase detailed upload error: $e');
      return null;
    }
  }

  String _extractExtensionFromPath(
    String path, {
    required String mediaType,
  }) {
    final clean = path.trim().toLowerCase();

    if (clean.endsWith('.jpeg')) return 'jpeg';
    if (clean.endsWith('.jpg')) return 'jpg';
    if (clean.endsWith('.png')) return 'png';
    if (clean.endsWith('.webp')) return 'webp';
    if (clean.endsWith('.gif')) return 'gif';

    if (clean.endsWith('.mp4')) return 'mp4';
    if (clean.endsWith('.mov')) return 'mov';
    if (clean.endsWith('.webm')) return 'webm';
    if (clean.endsWith('.m4v')) return 'm4v';
    if (clean.endsWith('.avi')) return 'avi';
    if (clean.endsWith('.mkv')) return 'mkv';

    return mediaType == 'video' ? 'mp4' : 'jpg';
  }

  String _extractExtensionFromFile(
    XFile file, {
    required String mediaType,
  }) {
    final name = file.name.trim().toLowerCase();

    if (name.endsWith('.jpeg')) return 'jpeg';
    if (name.endsWith('.jpg')) return 'jpg';
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    if (name.endsWith('.gif')) return 'gif';

    if (name.endsWith('.mp4')) return 'mp4';
    if (name.endsWith('.mov')) return 'mov';
    if (name.endsWith('.webm')) return 'webm';
    if (name.endsWith('.m4v')) return 'm4v';
    if (name.endsWith('.avi')) return 'avi';
    if (name.endsWith('.mkv')) return 'mkv';

    return _extractExtensionFromPath(
      file.path,
      mediaType: mediaType,
    );
  }
}