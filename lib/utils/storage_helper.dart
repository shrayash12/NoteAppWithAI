import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Helper class for Firebase Storage operations on web platform
class StorageHelper {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload bytes to Firebase Storage and return download URL
  static Future<String> uploadToFirebase(
    Uint8List bytes,
    String path,
    String contentType,
  ) async {
    try {
      debugPrint('StorageHelper: Uploading to Firebase Storage: $path');
      debugPrint('StorageHelper: Bytes length: ${bytes.length}');

      final ref = _storage.ref(path);
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      debugPrint('StorageHelper: Upload complete, getting download URL...');
      final downloadUrl = await ref.getDownloadURL();
      debugPrint('StorageHelper: Download URL: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      debugPrint('StorageHelper: Error uploading to Firebase: $e');
      rethrow;
    }
  }

  /// Check if path is a URL (Firebase Storage) or local file
  static bool isUrl(String? path) {
    return path != null &&
        (path.startsWith('http://') || path.startsWith('https://'));
  }
}
