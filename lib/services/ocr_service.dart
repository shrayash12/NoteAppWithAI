import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class OcrService {
  /// Extract text from a single local file path or remote URL.
  Future<String?> extractTextFromImagePath(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final localPath = await _resolveToLocalPath(imagePath);
      if (localPath == null) return null;
      final inputImage = InputImage.fromFilePath(localPath);
      final recognized = await recognizer.processImage(inputImage);
      final text = recognized.text.trim();
      return text.isEmpty ? null : text;
    } catch (e) {
      debugPrint('OcrService: extractTextFromImagePath error: $e');
      return null;
    } finally {
      await recognizer.close();
    }
  }

  /// Extract and concatenate text from multiple image paths (multi-page docs).
  Future<String?> extractTextFromImagePaths(List<String> paths) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final buffer = StringBuffer();
      for (final path in paths) {
        final localPath = await _resolveToLocalPath(path);
        if (localPath == null) continue;
        final inputImage = InputImage.fromFilePath(localPath);
        final recognized = await recognizer.processImage(inputImage);
        final text = recognized.text.trim();
        if (text.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.write('\n\n');
          buffer.write(text);
        }
      }
      final result = buffer.toString().trim();
      return result.isEmpty ? null : result;
    } catch (e) {
      debugPrint('OcrService: extractTextFromImagePaths error: $e');
      return null;
    } finally {
      await recognizer.close();
    }
  }

  /// If [path] is a URL, download it to a temp file and return the local path.
  /// If it's already a local path, return it as-is.
  Future<String?> _resolveToLocalPath(String path) async {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      try {
        final response = await http.get(Uri.parse(path));
        if (response.statusCode != 200) return null;
        final tempDir = await getTemporaryDirectory();
        final fileName = 'ocr_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      } catch (e) {
        debugPrint('OcrService: download error: $e');
        return null;
      }
    }
    return path;
  }
}

// ---------------------------------------------------------------------------
// Top-level functions for use with Flutter compute()
// ---------------------------------------------------------------------------

/// Extract OCR text from a single image path (local or URL).
Future<String?> extractOcrFromPath(String imagePath) async {
  return OcrService().extractTextFromImagePath(imagePath);
}

/// Extract and concatenate OCR text from multiple image paths.
Future<String?> extractOcrFromPaths(List<String> imagePaths) async {
  return OcrService().extractTextFromImagePaths(imagePaths);
}
