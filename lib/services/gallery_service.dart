import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class GalleryService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadChildMedia({
    required String childId,
    required String localPath,
    required String mediaType, // image / video
  }) async {
    try {
      final file = File(localPath);

      if (!file.existsSync()) {
        return null;
      }

      final extension = localPath.split('.').last.toLowerCase();
      final folder = mediaType == 'video' ? 'videos' : 'images';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';

      final ref = _storage.ref().child(
        'children_media/$childId/$folder/$fileName',
      );

      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }
}