import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';
import 'animated_notification.dart';
import '../utils/storage_helper.dart';
import '../utils/image_helper.dart';
import '../utils/file_helper.dart' as file_helper;

void showPhotoPreviewModal(BuildContext context, Note note) {
  showDialog(
    context: context,
    builder: (context) => PhotoPreviewModal(note: note),
  );
}

class PhotoPreviewModal extends StatefulWidget {
  final Note note;

  const PhotoPreviewModal({super.key, required this.note});

  @override
  State<PhotoPreviewModal> createState() => _PhotoPreviewModalState();
}

class _PhotoPreviewModalState extends State<PhotoPreviewModal> {
  late Note _currentNote;
  bool _isExtractingOcr = false;
  bool _showOcrText = false;
  DateTime? _reminderDateTime;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _reminderDateTime = widget.note.reminderDateTime;
    // Auto-expand OCR panel if text already exists
    if (_currentNote.ocrText != null) {
      _showOcrText = true;
    }
  }

  Future<void> _pickReminder() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _reminderDateTime ?? DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_reminderDateTime ?? DateTime.now()),
    );
    if (time == null) return;
    final newReminder = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _reminderDateTime = newReminder);
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final updated = _currentNote.copyWith(reminderDateTime: newReminder, updatedAt: DateTime.now());
    await notesProvider.updateNote(updated);
    setState(() => _currentNote = updated);
  }

  Future<void> _removeReminder() async {
    setState(() => _reminderDateTime = null);
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final updated = _currentNote.copyWith(clearReminder: true, updatedAt: DateTime.now());
    await notesProvider.updateNote(updated);
    setState(() => _currentNote = updated);
  }

  Future<void> _retakePhoto(ImageSource source) async {
    final picker = ImagePicker();

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        // Delete old image file (only for local files, not URLs)
        if (_currentNote.imagePath != null &&
            !StorageHelper.isUrl(_currentNote.imagePath)) {
          file_helper.deleteFile(_currentNote.imagePath!);
        }

        String savedPath;
        final fileName = 'photo_note_${const Uuid().v4()}.jpg';

        // Upload to Firebase Storage on all platforms
        final bytes = await pickedFile.readAsBytes();
        savedPath = await StorageHelper.uploadToFirebase(
          bytes,
          'photos/$fileName',
          'image/jpeg',
        );
        if (!kIsWeb) {
          // Also save locally for offline access
          final appDir = await getApplicationDocumentsDirectory();
          final localPath = '${appDir.path}/$fileName';
          await file_helper.copyFile(pickedFile.path, localPath);
        }

        // Update the note
        final notesProvider = Provider.of<NotesProvider>(context, listen: false);
        final updatedNote = _currentNote.copyWith(
          imagePath: savedPath,
          updatedAt: DateTime.now(),
        );

        await notesProvider.updateNote(updatedNote);

        setState(() {
          _currentNote = updatedNote;
        });

        if (mounted) {
          AnimatedNotification.show(
            context,
            type: NotificationType.updated,
            customMessage: 'Photo Updated',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AnimatedNotification.show(
          context,
          type: NotificationType.error,
          customMessage: 'Failed to update photo',
        );
      }
    }
  }

  Future<void> _scanDocument() async {
    try {
      final List<String>? scannedPaths =
          await CunningDocumentScanner.getPictures(noOfPages: 1);

      if (scannedPaths != null && scannedPaths.isNotEmpty && mounted) {
        // Delete old image (only for local files)
        if (_currentNote.imagePath != null &&
            !StorageHelper.isUrl(_currentNote.imagePath)) {
          file_helper.deleteFile(_currentNote.imagePath!);
        }

        final fileName = 'photo_note_${const Uuid().v4()}.jpg';
        final bytes = await file_helper.getFileBytes(scannedPaths.first);
        final savedPath = bytes != null
            ? await StorageHelper.uploadToFirebase(
                bytes, 'photos/$fileName', 'image/jpeg')
            : scannedPaths.first;

        final notesProvider = Provider.of<NotesProvider>(context, listen: false);
        final updatedNote = _currentNote.copyWith(
          imagePath: savedPath,
          updatedAt: DateTime.now(),
        );

        await notesProvider.updateNote(updatedNote);

        setState(() {
          _currentNote = updatedNote;
        });

        if (mounted) {
          AnimatedNotification.show(
            context,
            type: NotificationType.updated,
            customMessage: 'Document Scanned',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AnimatedNotification.show(
          context,
          type: NotificationType.error,
          customMessage: 'Failed to scan document',
        );
      }
    }
  }

  Future<void> _extractOcrText() async {
    final imagePath = _currentNote.imagePath;
    if (imagePath == null || kIsWeb) return;
    setState(() => _isExtractingOcr = true);
    try {
      final text = await compute(extractOcrFromPath, imagePath);
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
      await notesProvider.updateNoteOcrText(_currentNote.id, text);
      setState(() {
        _currentNote = _currentNote.copyWith(
          ocrText: text,
          clearOcrText: text == null,
        );
        _showOcrText = text != null;
      });
      if (mounted) {
        AnimatedNotification.show(
          context,
          type: text != null ? NotificationType.updated : NotificationType.error,
          customMessage: text != null ? 'Text Extracted' : 'No text found',
        );
      }
    } catch (e) {
      if (mounted) {
        AnimatedNotification.show(
          context,
          type: NotificationType.error,
          customMessage: 'OCR failed',
        );
      }
    } finally {
      if (mounted) setState(() => _isExtractingOcr = false);
    }
  }

  void _copyOcrText() {
    final text = _currentNote.ocrText;
    if (text == null) return;
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Photo Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            // Retake from Camera
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              title: const Text(
                'Retake Photo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Take a new photo with camera'),
              onTap: () {
                Navigator.pop(context);
                _retakePhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
            // Choose from Gallery
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Select a different photo'),
              onTap: () {
                Navigator.pop(context);
                _retakePhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
            // Scan Document (CamScanner-style)
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.document_scanner,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              title: const Text(
                'Scan Document',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Scan with auto edge detection'),
              onTap: () {
                Navigator.pop(context);
                _scanDocument();
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM d, yyyy');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Row(
                children: [
                  // Tappable Photo badge with edit options
                  GestureDetector(
                    onTap: _showPhotoOptions,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_camera,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Photo',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            size: 14,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _currentNote.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Image
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ImageHelper.imageExists(_currentNote.imagePath)
                      ? InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: ImageHelper.buildImage(
                            _currentNote.imagePath,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Container(
                          height: 200,
                          color: Colors.grey.shade100,
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 60,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            // OCR action row (native only)
            if (!kIsWeb) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isExtractingOcr ? null : _extractOcrText,
                      icon: _isExtractingOcr
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF8B5CF6)),
                              ),
                            )
                          : const Icon(Icons.text_fields,
                              size: 16, color: Color(0xFF8B5CF6)),
                      label: Text(
                        _currentNote.ocrText != null
                            ? 'Re-extract Text'
                            : 'Extract Text',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF8B5CF6)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF8B5CF6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const Spacer(),
                    if (_currentNote.ocrText != null) ...[
                      IconButton(
                        onPressed: () =>
                            setState(() => _showOcrText = !_showOcrText),
                        icon: Icon(
                          _showOcrText
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: Colors.grey.shade600,
                        ),
                        tooltip: _showOcrText ? 'Collapse' : 'Expand',
                      ),
                      IconButton(
                        onPressed: _copyOcrText,
                        icon: const Icon(Icons.copy,
                            color: Color(0xFF8B5CF6), size: 20),
                        tooltip: 'Copy text',
                      ),
                    ],
                  ],
                ),
              ),
              // Expandable OCR text panel
              if (_currentNote.ocrText != null && _showOcrText)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.text_fields,
                                size: 14, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 6),
                            const Text(
                              'Extracted Text',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _currentNote.ocrText!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            // Reminder row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.notifications_outlined, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  if (_reminderDateTime == null)
                    TextButton.icon(
                      onPressed: _pickReminder,
                      icon: const Icon(Icons.add_alarm, size: 14),
                      label: const Text('Add Reminder', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else ...[
                    Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      avatar: Icon(Icons.notifications_active, size: 14, color: Colors.orange.shade600),
                      label: Text(
                        DateFormat('MMM d, h:mm a').format(_reminderDateTime!),
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: Colors.orange.shade50,
                      side: BorderSide(color: Colors.orange.shade200),
                      deleteIcon: Icon(Icons.close, size: 14, color: Colors.grey.shade500),
                      onDeleted: _removeReminder,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _pickReminder,
                      icon: Icon(Icons.edit, size: 14, color: Colors.grey.shade500),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
            ),
            // Footer with date
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateFormat.format(_currentNote.createdAt),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  if (_currentNote.isFavorite)
                    Icon(
                      Icons.star,
                      size: 20,
                      color: Colors.amber.shade600,
                    ),
                  if (_currentNote.isPinned) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.push_pin,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
