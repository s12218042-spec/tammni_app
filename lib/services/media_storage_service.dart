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
      'mediaPath': path,
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
    final normalizedFolder = folder.trim().toLowerCase();

    final isVideo = normalizedFolder.contains('/videos') ||
        normalizedFolder.endsWith('videos') ||
        normalizedFolder.contains('video');

    final extension = _extractExtension(
      file,
      fallbackExtension: isVideo ? '.mp4' : '.jpg',
    );

    final cleanFolder = _cleanStorageSegment(folder);
    final cleanFileName = _cleanFileNameWithoutExtension(
      fileNameWithoutExtension,
    );

    final fullPath = '$cleanFolder/$cleanFileName$extension';
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

  Future<MediaUploadResult> uploadAudio({
    required XFile file,
    required String folder,
    required String fileNameWithoutExtension,
  }) async {
    final extension = _extractExtension(
      file,
      fallbackExtension: '.m4a',
    );

    final safeExtension = _isAudioExtension(extension) ? extension : '.m4a';

    final cleanFolder = _cleanStorageSegment(folder);
    final cleanFileName = _cleanFileNameWithoutExtension(
      fileNameWithoutExtension,
    );

    final fullPath = '$cleanFolder/$cleanFileName$safeExtension';
    final mimeType = _detectMimeType(safeExtension);

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
    final cleanPath = path.trim();

    if (cleanPath.isEmpty) {
      throw Exception('mediaPath فارغ ولا يمكن إنشاء رابط عرض');
    }

    return _client.storage
        .from(bucketName)
        .createSignedUrl(cleanPath, expiresInSeconds);
  }

  Future<String?> tryCreateSignedUrl({
    required String path,
    int expiresInSeconds = 3600,
  }) async {
    try {
      final cleanPath = path.trim();

      if (cleanPath.isEmpty) return null;

      return await createSignedUrl(
        path: cleanPath,
        expiresInSeconds: expiresInSeconds,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteFile(String path) async {
    final cleanPath = path.trim();

    if (cleanPath.isEmpty) return;

    await _client.storage.from(bucketName).remove([cleanPath]);
  }

  String _cleanStorageSegment(String value) {
    return value
        .trim()
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+'), '/')
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');
  }

  String _cleanFileNameWithoutExtension(String value) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }

    final withoutExt = p.basenameWithoutExtension(clean);

    return withoutExt
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  String _extractExtension(
    XFile file, {
    required String fallbackExtension,
  }) {
    final fileName = file.name.trim().toLowerCase();

    if (fileName.isNotEmpty) {
      final ext = p.extension(fileName).toLowerCase();
      if (ext.isNotEmpty) return ext;
    }

    final pathExt = p.extension(file.path).toLowerCase();
    if (pathExt.isNotEmpty) return pathExt;

    return fallbackExtension;
  }

  bool _isAudioExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.m4a':
      case '.aac':
      case '.mp3':
      case '.wav':
      case '.ogg':
      case '.opus':
      case '.webm':
        return true;
      default:
        return false;
    }
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
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
        return 'audio/ogg';
      case '.opus':
        return 'audio/opus';
      default:
        return 'application/octet-stream';
    }
  }
}