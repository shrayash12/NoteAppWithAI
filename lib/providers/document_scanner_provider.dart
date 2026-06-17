import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';
import '../services/document_scanner_service.dart';
import '../utils/storage_helper.dart';

enum DocumentScannerState {
  idle,
  scanning,
  enhancing,
  generatingPdf,
  uploading,
  done,
  error,
}

class DocumentScannerProvider extends ChangeNotifier {
  DocumentScannerState _state = DocumentScannerState.idle;
  List<String> _scannedImagePaths = [];
  List<String> _enhancedImagePaths = [];
  String? _localPdfPath;
  String? _uploadedPdfUrl;
  String? _errorMessage;
  bool _enhanceEnabled = true;
  String _title = '';

  final _service = const DocumentScannerService();

  DocumentScannerState get state => _state;
  List<String> get scannedImagePaths => _scannedImagePaths;
  List<String> get enhancedImagePaths => _enhancedImagePaths;
  String? get localPdfPath => _localPdfPath;
  String? get uploadedPdfUrl => _uploadedPdfUrl;
  String? get errorMessage => _errorMessage;
  bool get enhanceEnabled => _enhanceEnabled;
  String get title => _title;

  List<String> get displayPaths =>
      _enhancedImagePaths.isNotEmpty ? _enhancedImagePaths : _scannedImagePaths;

  void setTitle(String t) {
    _title = t;
    notifyListeners();
  }

  void setEnhanceEnabled(bool v) {
    _enhanceEnabled = v;
    notifyListeners();
  }

  /// Launch the document scanner and return true if pages were captured.
  Future<bool> scan() async {
    _state = DocumentScannerState.scanning;
    notifyListeners();

    try {
      final List<String>? pics = await CunningDocumentScanner.getPictures();
      if (pics == null || pics.isEmpty) {
        _state = DocumentScannerState.idle;
        notifyListeners();
        return false;
      }
      _scannedImagePaths = List<String>.from(pics);
      _state = DocumentScannerState.idle;
      notifyListeners();
      return true;
    } catch (e) {
      _state = DocumentScannerState.error;
      _errorMessage = 'Failed to scan document: $e';
      notifyListeners();
      return false;
    }
  }

  /// Enhance all scanned images in parallel using compute().
  Future<void> enhance() async {
    if (_scannedImagePaths.isEmpty) return;
    _state = DocumentScannerState.enhancing;
    notifyListeners();

    try {
      final futures = _scannedImagePaths
          .map((p) => compute(enhanceImageIsolate, p))
          .toList();
      _enhancedImagePaths = await Future.wait(futures);
      _state = DocumentScannerState.idle;
      notifyListeners();
    } catch (e) {
      // Fallback: use originals
      _enhancedImagePaths = List<String>.from(_scannedImagePaths);
      _state = DocumentScannerState.idle;
      notifyListeners();
    }
  }

  /// Generate PDF and upload to Firebase Storage.
  Future<void> generateAndUpload() async {
    final paths = displayPaths;
    if (paths.isEmpty) return;

    try {
      // Generate PDF
      _state = DocumentScannerState.generatingPdf;
      notifyListeners();

      _localPdfPath = await _service.generatePdf(paths, _title);

      // Upload to Firebase Storage
      _state = DocumentScannerState.uploading;
      notifyListeners();

      final pdfBytes = await File(_localPdfPath!).readAsBytes();
      final fileName = 'pdfs/${_localPdfPath!.split('/').last}';
      _uploadedPdfUrl = await StorageHelper.uploadToFirebase(
        pdfBytes,
        fileName,
        'application/pdf',
      );

      _state = DocumentScannerState.done;
      notifyListeners();
    } catch (e) {
      _state = DocumentScannerState.error;
      _errorMessage = 'Failed to generate or upload PDF: $e';
      notifyListeners();
    }
  }

  void reset() {
    _state = DocumentScannerState.idle;
    _scannedImagePaths = [];
    _enhancedImagePaths = [];
    _localPdfPath = null;
    _uploadedPdfUrl = null;
    _errorMessage = null;
    _enhanceEnabled = true;
    _title = '';
    notifyListeners();
  }
}
