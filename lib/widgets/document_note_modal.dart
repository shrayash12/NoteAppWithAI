import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import 'animated_notification.dart';

void showDocumentNoteModal(BuildContext context, Note note) {
  showDialog(
    context: context,
    builder: (context) => DocumentNoteModal(note: note),
  );
}

class DocumentNoteModal extends StatefulWidget {
  final Note note;

  const DocumentNoteModal({super.key, required this.note});

  @override
  State<DocumentNoteModal> createState() => _DocumentNoteModalState();
}

class _DocumentNoteModalState extends State<DocumentNoteModal> {
  late Note _currentNote;
  bool _isEditing = false;
  late TextEditingController _titleController;
  bool _isLoadingPdf = false;
  bool _showOcrText = false;
  DateTime? _reminderDateTime;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _titleController = TextEditingController(text: _currentNote.title);
    _reminderDateTime = widget.note.reminderDateTime;
    // Auto-expand if OCR text already exists
    if (_currentNote.ocrText != null) {
      _showOcrText = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
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
    final notesProvider = context.read<NotesProvider>();
    final updated = _currentNote.copyWith(reminderDateTime: newReminder, updatedAt: DateTime.now());
    await notesProvider.updateNote(updated);
    setState(() => _currentNote = updated);
  }

  Future<void> _removeReminder() async {
    setState(() => _reminderDateTime = null);
    final notesProvider = context.read<NotesProvider>();
    final updated = _currentNote.copyWith(clearReminder: true, updatedAt: DateTime.now());
    await notesProvider.updateNote(updated);
    setState(() => _currentNote = updated);
  }

  Future<void> _renameNote(String newTitle) async {
    if (newTitle.trim().isEmpty || newTitle == _currentNote.title) return;
    final notesProvider = context.read<NotesProvider>();
    final updated = _currentNote.copyWith(
      title: newTitle.trim(),
      updatedAt: DateTime.now(),
    );
    await notesProvider.updateNote(updated);
    setState(() {
      _currentNote = updated;
      _isEditing = false;
    });
    if (mounted) {
      AnimatedNotification.show(
        context,
        type: NotificationType.updated,
        customMessage: 'Title Updated',
      );
    }
  }

  /// Download the PDF from Firebase URL to temp dir and return local path.
  Future<String?> _downloadToTemp() async {
    final url = _currentNote.pdfPath;
    if (url == null) return null;

    setState(() => _isLoadingPdf = true);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final tempDir = await getTemporaryDirectory();
      final fileName = 'doc_${const Uuid().v4()}.pdf';
      final filePath = '${tempDir.path}/$fileName';
      await File(filePath).writeAsBytes(response.bodyBytes);
      return filePath;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download PDF: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isLoadingPdf = false);
    }
  }

  Future<void> _openPdf() async {
    final localPath = await _downloadToTemp();
    if (localPath != null) {
      await OpenFilex.open(localPath);
    }
  }

  Future<void> _sharePdf() async {
    final localPath = await _downloadToTemp();
    if (localPath != null) {
      await Share.shareXFiles(
        [XFile(localPath, mimeType: 'application/pdf')],
        subject: _currentNote.title,
      );
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

  Widget _buildPdfCard() {
    final hasPdf = _currentNote.pdfPath != null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.picture_as_pdf,
                color: Colors.red.shade600, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPdf
                      ? (_currentNote.pdfPath!.split('/').last.split('?').first)
                      : 'No PDF attached',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPdf ? 'PDF Document' : 'PDF not available',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.document_scanner,
                            size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Document',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

            // Title — tappable to rename
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _isEditing
                  ? TextField(
                      controller: _titleController,
                      autofocus: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check,
                                  color: Color(0xFF10B981)),
                              onPressed: () =>
                                  _renameNote(_titleController.text),
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: Colors.grey.shade500),
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _titleController.text = _currentNote.title;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      onSubmitted: _renameNote,
                    )
                  : GestureDetector(
                      onTap: () => setState(() => _isEditing = true),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _currentNote.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Icon(Icons.edit,
                              size: 18, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),

            // PDF card
            _buildPdfCard(),

            // Open PDF button
            if (_currentNote.pdfPath != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingPdf ? null : _openPdf,
                    icon: _isLoadingPdf
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                        : const Icon(Icons.open_in_new, size: 18),
                    label: Text(
                        _isLoadingPdf ? 'Opening…' : 'Open PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Content
            if (_currentNote.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _currentNote.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // OCR text panel
            if (_currentNote.ocrText != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showOcrText = !_showOcrText),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.text_fields,
                                size: 16, color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Extracted Text Available',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ),
                            Icon(
                              _showOcrText
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                              color: const Color(0xFF059669),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: _copyOcrText,
                              child: const Icon(Icons.copy,
                                  size: 16, color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showOcrText) ...[
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.2)),
                        ),
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
                  ],
                ),
              ),

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

            const SizedBox(height: 8),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    dateFormat.format(_currentNote.createdAt),
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  if (_currentNote.pdfPath != null)
                    IconButton(
                      icon: Icon(Icons.share,
                          color: Colors.grey.shade600, size: 22),
                      onPressed: _isLoadingPdf ? null : _sharePdf,
                    ),
                  if (_currentNote.isFavorite)
                    Icon(Icons.star,
                        size: 22, color: Colors.amber.shade600),
                  if (_currentNote.isPinned) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.push_pin,
                        size: 20, color: Colors.grey.shade600),
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
