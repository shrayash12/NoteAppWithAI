import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

class DocumentScannerService {
  const DocumentScannerService();

  /// Enhances a scanned image with improved contrast and brightness.
  /// Runs synchronously — call via compute() from UI code.
  Future<String> enhanceImage(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return imagePath;

      final enhanced = img.adjustColor(
        original,
        contrast: 1.4,
        brightness: 1.05,
        saturation: 0.0,
      );

      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/enhanced_${const Uuid().v4()}.jpg';
      await File(outPath).writeAsBytes(img.encodeJpg(enhanced, quality: 90));
      return outPath;
    } catch (e) {
      debugPrint('DocumentScannerService: enhanceImage error: $e');
      return imagePath; // Fallback to original on error
    }
  }

  /// Generates a PDF from a list of image paths. Each image = one A4 page.
  /// Returns the local PDF file path.
  Future<String> generatePdf(List<String> imagePaths, String title) async {
    final pdf = pw.Document();

    for (final path in imagePaths) {
      try {
        final bytes = await File(path).readAsBytes();
        final image = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      } catch (e) {
        debugPrint('DocumentScannerService: error adding page $path: $e');
      }
    }

    final tempDir = await getTemporaryDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final fileName = '${safeTitle.isNotEmpty ? safeTitle : 'document'}_${const Uuid().v4()}.pdf';
    final outPath = '${tempDir.path}/$fileName';
    final file = File(outPath);
    await file.writeAsBytes(await pdf.save());
    return outPath;
  }

  Future<void> deleteLocalFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('DocumentScannerService: deleteLocalFile error: $e');
    }
  }
}

/// Top-level function for use with compute().
Future<String> enhanceImageIsolate(String path) async {
  return const DocumentScannerService().enhanceImage(path);
}
