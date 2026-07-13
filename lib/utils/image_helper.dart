import 'package:flutter/material.dart';
import 'storage_helper.dart';
import 'file_helper.dart' as file_helper;

/// Helper for building image widgets that work with both URLs and local file paths
class ImageHelper {
  /// Build an image widget from either a URL or local file path
  static Widget buildImage(
    String? imagePath, {
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    double? width,
    double? height,
  }) {
    final defaultPlaceholder = placeholder ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: Icon(
            Icons.broken_image,
            size: 40,
            color: Colors.grey.shade400,
          ),
        );

    if (imagePath == null) {
      return defaultPlaceholder;
    }

    // If it's a URL (Firebase Storage), use Image.network
    if (StorageHelper.isUrl(imagePath)) {
      return Image.network(
        imagePath,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey.shade100,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => defaultPlaceholder,
      );
    }

    // Otherwise, it's a local file path (native only)
    if (file_helper.hasFileSystemAccess && file_helper.fileExists(imagePath)) {
      return file_helper.buildFileImage(imagePath, fit: fit);
    }

    return defaultPlaceholder;
  }

  /// Check if an image exists (either as URL or local file)
  static bool imageExists(String? imagePath) {
    if (imagePath == null) return false;

    // URLs are assumed to exist (network check would be async)
    if (StorageHelper.isUrl(imagePath)) return true;

    // Check local file
    return file_helper.fileExists(imagePath);
  }
}
