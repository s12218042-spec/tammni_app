import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaUploadResult {
  final String storageProvider;
  final String bucket;
  final String path;
  final String? publicUrl;
  final String mimeType;
  final int sizeBytes;

  MediaUploadResult({
    required this.storageProvider,
    required this.bucket,
    required this.path,
    required this.publicUrl,
    required this.mimeType,
    required this.sizeBytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'storageProvider': storageProvider,
      'bucket': bucket,
      'path': path,
      'publicUrl': publicUrl,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
    };
  }
}

class MediaStorageService {
  MediaStorageService._();

  static final MediaStorageService instance = MediaStorageService._();

  final SupabaseClient _client = Supabase.instance.client;

  static const String bucketName = 'tammni-media';

  Future<MediaUploadResult> uploadImageOrVideo({
    required XFile file,
    required String folder,
    required String fileNameWithoutExtension,
  }) async {
    final normalizedFolder = folder.toLowerCase();
    final isVideo = normalizedFolder.contains('/videos') ||
        normalizedFolder.endsWith('videos') ||
        normalizedFolder.contains('video');

    final extension = _extractExtension(
      file,
      isVideo: isVideo,
    );

    final fullPath = '$folder/$fileNameWithoutExtension$extension';
    final mimeType = _detectMimeType(extension);

    final Uint8List bytes = await file.readAsBytes();
    final int sizeBytes = bytes.length;

    await _client.storage.from(bucketName).uploadBinary(
          fullPath,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: mimeType,
          ),
        );

    return MediaUploadResult(
      storageProvider: 'supabase',
      bucket: bucketName,
      path: fullPath,
      publicUrl: null,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
    );
  }

  Future<String> createSignedUrl({
    required String path,
    int expiresInSeconds = 3600,
  }) async {
    return _client.storage
        .from(bucketName)
        .createSignedUrl(path, expiresInSeconds);
  }

  Future<void> deleteFile(String path) async {
    await _client.storage.from(bucketName).remove([path]);
  }

  String _extractExtension(
    XFile file, {
    required bool isVideo,
  }) {
    final fileName = file.name.trim().toLowerCase();

    if (fileName.isNotEmpty) {
      final ext = p.extension(fileName).toLowerCase();
      if (ext.isNotEmpty) return ext;
    }

    final pathExt = p.extension(file.path).toLowerCase();
    if (pathExt.isNotEmpty) return pathExt;

    return isVideo ? '.mp4' : '.jpg';
  }

  String _detectMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.webm':
        return 'video/webm';
      case '.m4v':
        return 'video/x-m4v';
      case '.avi':
        return 'video/x-msvideo';
      case '.mkv':
        return 'video/x-matroska';
      default:
        return 'application/octet-stream';
    }
  }
}