import 'package:image_picker/image_picker.dart';

import 'media_storage_service.dart';

class GalleryUploadResult {
  final String storageProvider;
  final String bucket;
  final String path;
  final String signedUrl;
  final DateTime signedUrlExpiresAt;
  final String mediaType;
  final String mimeType;
  final int sizeBytes;

  GalleryUploadResult({
    required this.storageProvider,
    required this.bucket,
    required this.path,
    required this.signedUrl,
    required this.signedUrlExpiresAt,
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
      'mediaUrlExpiresAt': signedUrlExpiresAt.toIso8601String(),
      'mediaType': mediaType,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'isSignedUrl': true,
    };
  }
}

class GalleryService {
  static const int defaultSignedUrlSeconds = 3600;

  Future<String?> uploadChildMedia({
    required String childId,
    required String localPath,
    required String mediaType,
  }) async {
    try {
      final folder = mediaType == 'video' ? 'videos' : 'images';
      final xFile = XFile(localPath);

      final result = await MediaStorageService.instance.uploadImageOrVideo(
        file: xFile,
        folder: 'children_media/$childId/$folder',
        fileNameWithoutExtension:
            DateTime.now().millisecondsSinceEpoch.toString(),
      );

      final signedUrl = await MediaStorageService.instance.createSignedUrl(
        path: result.path,
        expiresInSeconds: defaultSignedUrlSeconds,
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
    required String mediaType,
  }) async {
    try {
      final cleanMediaType = _normalizeMediaType(mediaType);
      final folder = cleanMediaType == 'video' ? 'videos' : 'images';

      final uploaded = await MediaStorageService.instance.uploadImageOrVideo(
        file: file,
        folder: 'children_media/$childId/$folder',
        fileNameWithoutExtension:
            DateTime.now().millisecondsSinceEpoch.toString(),
      );

      final signedUrl = await MediaStorageService.instance.createSignedUrl(
        path: uploaded.path,
        expiresInSeconds: defaultSignedUrlSeconds,
      );

      final expiresAt = DateTime.now().add(
        const Duration(seconds: defaultSignedUrlSeconds),
      );

      return GalleryUploadResult(
        storageProvider: uploaded.storageProvider,
        bucket: uploaded.bucket,
        path: uploaded.path,
        signedUrl: signedUrl,
        signedUrlExpiresAt: expiresAt,
        mediaType: cleanMediaType,
        mimeType: uploaded.mimeType,
        sizeBytes: uploaded.sizeBytes,
      );
    } catch (e) {
      print('Supabase detailed upload error: $e');
      return null;
    }
  }

  Future<String?> createFreshSignedUrl({
    required String mediaPath,
    int expiresInSeconds = defaultSignedUrlSeconds,
  }) async {
    try {
      final cleanPath = mediaPath.trim();

      if (cleanPath.isEmpty) return null;

      return await MediaStorageService.instance.createSignedUrl(
        path: cleanPath,
        expiresInSeconds: expiresInSeconds,
      );
    } catch (e) {
      print('Create fresh signed URL error: $e');
      return null;
    }
  }

  Future<String?> resolveFreshMediaUrl({
    required Map<String, dynamic> mediaData,
    int expiresInSeconds = defaultSignedUrlSeconds,
  }) async {
    final storageProvider =
        (mediaData['storageProvider'] ?? '').toString().trim().toLowerCase();

    final mediaPath = _firstNonEmpty([
      mediaData['mediaPath'],
      mediaData['path'],
      mediaData['imagePath'],
      mediaData['videoPath'],
    ]);

    final publicUrl = _firstNonEmpty([
      mediaData['publicUrl'],
      mediaData['mediaPublicUrl'],
    ]);

    final oldUrl = _firstNonEmpty([
      mediaData['mediaUrl'],
      mediaData['imageUrl'],
      mediaData['videoUrl'],
      mediaData['url'],
    ]);

    if (storageProvider == 'supabase' && mediaPath.isNotEmpty) {
      return createFreshSignedUrl(
        mediaPath: mediaPath,
        expiresInSeconds: expiresInSeconds,
      );
    }

    if (mediaPath.isNotEmpty && oldUrl.contains('supabase')) {
      return createFreshSignedUrl(
        mediaPath: mediaPath,
        expiresInSeconds: expiresInSeconds,
      );
    }

    if (publicUrl.isNotEmpty) {
      return publicUrl;
    }

    if (oldUrl.isNotEmpty) {
      return oldUrl;
    }

    return null;
  }

  Future<String?> resolveFreshMediaUrlFromFields({
    String? storageProvider,
    String? mediaPath,
    String? oldMediaUrl,
    String? publicUrl,
    int expiresInSeconds = defaultSignedUrlSeconds,
  }) async {
    return resolveFreshMediaUrl(
      mediaData: {
        'storageProvider': storageProvider ?? '',
        'mediaPath': mediaPath ?? '',
        'mediaUrl': oldMediaUrl ?? '',
        'publicUrl': publicUrl ?? '',
      },
      expiresInSeconds: expiresInSeconds,
    );
  }

  String _normalizeMediaType(String value) {
    final clean = value.trim().toLowerCase();

    if (clean == 'video') return 'video';
    return 'image';
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }
}