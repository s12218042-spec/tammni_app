import 'package:image_picker/image_picker.dart';

import 'media_storage_service.dart';

class GalleryUploadResult {
  final String storageProvider;
  final String bucket;
  final String path;
  final String publicUrl;
  final String mediaType;
  final String mimeType;
  final int sizeBytes;

  GalleryUploadResult({
    required this.storageProvider,
    required this.bucket,
    required this.path,
    required this.publicUrl,
    required this.mediaType,
    required this.mimeType,
    required this.sizeBytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'storageProvider': storageProvider,
      'bucket': bucket,
      'path': path,
      'mediaPath': path,
      'publicUrl': publicUrl,
      'mediaUrl': publicUrl,
      'url': publicUrl,
      'mediaType': mediaType,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'isSignedUrl': false,
      'mediaUrlExpiresAt': null,
    };
  }
}

class GalleryService {
  Future<String?> uploadChildMedia({
    required String childId,
    required String localPath,
    required String mediaType,
  }) async {
    try {
      final cleanMediaType = _normalizeMediaType(mediaType);
      final folder = cleanMediaType == 'video' ? 'videos' : 'images';
      final xFile = XFile(localPath);

      final result = await MediaStorageService.instance.uploadImageOrVideo(
        file: xFile,
        folder: 'children_media/$childId/$folder',
        fileNameWithoutExtension:
            DateTime.now().millisecondsSinceEpoch.toString(),
      );

      final publicUrl = (result.publicUrl ?? '').trim();

      if (publicUrl.isEmpty) {
        return null;
      }

      return publicUrl;
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

      final publicUrl = (uploaded.publicUrl ?? '').trim();

      if (publicUrl.isEmpty) {
        return null;
      }

      return GalleryUploadResult(
        storageProvider: uploaded.storageProvider,
        bucket: uploaded.bucket,
        path: uploaded.path,
        publicUrl: publicUrl,
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
    required String path,
    int expiresInSeconds = 21600,
  }) async {
    try {
      final cleanPath = path.trim();

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
    int expiresInSeconds = 21600,
  }) async {
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

    final storageProvider = _firstNonEmpty([
      mediaData['storageProvider'],
      mediaData['provider'],
    ]).toLowerCase();

    final isSignedUrl = mediaData['isSignedUrl'] == true;

    if (mediaPath.isNotEmpty &&
        !mediaPath.startsWith('blob:') &&
        !_isRemoteUrl(mediaPath) &&
        (storageProvider.isEmpty || storageProvider == 'supabase')) {
      final freshUrl = await createFreshSignedUrl(
        path: mediaPath,
        expiresInSeconds: expiresInSeconds,
      );

      if (freshUrl != null && freshUrl.trim().isNotEmpty) {
        return freshUrl;
      }
    }

    if (publicUrl.isNotEmpty) {
      return publicUrl;
    }

    if (oldUrl.isNotEmpty && !isSignedUrl) {
      return oldUrl;
    }

    if (isSignedUrl && mediaPath.isNotEmpty) {
      return createFreshSignedUrl(
        path: mediaPath,
        expiresInSeconds: expiresInSeconds,
      );
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
    int expiresInSeconds = 21600,
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

  bool _isRemoteUrl(String value) {
    final clean = value.trim().toLowerCase();
    return clean.startsWith('http://') || clean.startsWith('https://');
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

