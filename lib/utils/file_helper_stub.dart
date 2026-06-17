import 'dart:typed_data';
import 'package:flutter/widgets.dart';

/// Stub implementation for web platform (no dart:io File available)

/// Check if a file exists at the given path
/// On web, always returns false since local files aren't accessible
bool fileExists(String path) => false;

/// Delete a file at the given path
/// On web, this is a no-op
void deleteFile(String path) {}

/// Get file bytes from path
/// On web, returns null since local files aren't accessible
Future<Uint8List?> getFileBytes(String path) async => null;

/// Write bytes to a file at the given path
/// On web, this is a no-op and returns the path unchanged
Future<String> writeFileBytes(String path, Uint8List bytes) async => path;

/// Copy a file from source to destination
/// On web, this is a no-op
Future<void> copyFile(String sourcePath, String destPath) async {}

/// Build an image widget from a file path
/// On web, returns a placeholder since local files aren't accessible
Widget buildFileImage(String path, {BoxFit fit = BoxFit.cover}) {
  return const SizedBox.shrink();
}

/// Check if we're running on native platform with file system access
bool get hasFileSystemAccess => false;
