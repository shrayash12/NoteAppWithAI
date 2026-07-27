import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/document_category.dart';
import '../services/document_classifier_service.dart';
import '../services/document_scanner_service.dart';
import '../services/ocr_service.dart';
import '../utils/storage_helper.dart';

enum DocumentScannerState {
  idle,
  scanning,
  enhancing,
  analyzing,
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
  String? _ocrText;
  DocumentClassification? _classification;

  final _service = const DocumentScannerService();

  DocumentScannerState get state => _state;
  List<String> get scannedImagePaths => _scannedImagePaths;
  List<String> get enhancedImagePaths => _enhancedImagePaths;
  String? get localPdfPath => _localPdfPath;
  String? get uploadedPdfUrl => _uploadedPdfUrl;
  String? get errorMessage => _errorMessage;
  bool get enhanceEnabled => _enhanceEnabled;
  String get title => _title;
  String? get ocrText => _ocrText;
  DocumentClassification? get classification => _classification;

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

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _state = DocumentScannerState.error;
      _errorMessage = status.isPermanentlyDenied
          ? 'Camera access is disabled. Enable it in Settings to scan documents.'
          : 'Camera permission is required to scan documents.';
      notifyListeners();
      return false;
    }

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

  /// Runs OCR + offline SmartScan classification on the scanned pages.
  /// Populates [ocrText] and [classification], and auto-fills [title]
  /// with the detected smart title when a real category is found.
  Future<void> analyzeDocument() async {
    final paths = displayPaths;
    if (paths.isEmpty) return;
    _state = DocumentScannerState.analyzing;
    notifyListeners();

    try {
      final ocrText = await compute(extractOcrFromPaths, paths);
      if (ocrText != null && ocrText.isNotEmpty) {
        _ocrText = ocrText;
        _classification = const DocumentClassifierService().classify(ocrText);
        if (_classification!.category.id != DocumentCategory.miscellaneous.id) {
          _title = _classification!.title;
        }
      }
    } catch (e) {
      debugPrint('DocumentScannerProvider: analyzeDocument error: $e');
    } finally {
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
    _ocrText = null;
    _classification = null;
    notifyListeners();
  }
}
