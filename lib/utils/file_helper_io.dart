import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';

/// Native implementation with dart:io File support

/// Check if a file exists at the given path
bool fileExists(String path) => File(path).existsSync();

/// Delete a file at the given path
void deleteFile(String path) {
  final file = File(path);
  if (file.existsSync()) {
    file.deleteSync();
  }
}

/// Get file bytes from path
Future<Uint8List?> getFileBytes(String path) async {
  final file = File(path);
  if (file.existsSync()) {
    return await file.readAsBytes();
  }
  return null;
}

/// Write bytes to a file at the given path
Future<String> writeFileBytes(String path, Uint8List bytes) async {
  final file = File(path);
  await file.writeAsBytes(bytes);
  return path;
}

/// Copy a file from source to destination
Future<void> copyFile(String sourcePath, String destPath) async {
  final file = File(sourcePath);
  await file.copy(destPath);
}

/// Build an image widget from a file path
Widget buildFileImage(String path, {BoxFit fit = BoxFit.cover}) {
  return Image.file(
    File(path),
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      return const SizedBox.shrink();
    },
  );
}

/// Check if we're running on native platform with file system access
bool get hasFileSystemAccess => true;
