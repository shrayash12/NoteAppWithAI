import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/document_category.dart';
import '../models/note.dart';
import '../providers/document_scanner_provider.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/document_note_modal.dart';

/// Entry point — call this from main_screen.dart.
/// When [autoSave] is true (the SmartScan entry point), the note is saved
/// automatically using the detected category/title/folder with no manual
/// review step — straight to the results screen, per "Capture. Understand.
/// Organize." When false (the plain "Scan Doc" entry), the existing manual
/// review screen (title field, folder chips, Save button) is shown.
Future<void> launchDocumentScanner(BuildContext context, {bool autoSave = false}) async {
  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document scanning is not supported on web.'),
      ),
    );
    return;
  }
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => DocumentScannerProvider(),
        child: _DocumentScannerEntry(autoSave: autoSave),
      ),
    ),
  );
}

/// Builds the Note to save from the current scanner provider state.
Note _buildNoteFromScannerProvider(DocumentScannerProvider provider, {String? folderId}) {
  final now = DateTime.now();
  final pageCount = provider.displayPaths.length;
  final previewImagePath = provider.displayPaths.isNotEmpty ? provider.displayPaths.first : null;
  final originalImagePath =
      provider.scannedImagePaths.isNotEmpty ? provider.scannedImagePaths.first : null;

  return Note(
    id: const Uuid().v4(),
    title: provider.title.isNotEmpty ? provider.title : 'Scanned Document',
    content: 'Scanned document – $pageCount page(s)',
    type: NoteType.document,
    pdfPath: provider.uploadedPdfUrl,
    imagePath: previewImagePath,
    originalImagePath: originalImagePath,
    folderId: folderId,
    ocrText: provider.ocrText,
    tags: provider.classification?.tags ?? const [],
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Entry widget — runs scan + enhance in initState
// ---------------------------------------------------------------------------
class _DocumentScannerEntry extends StatefulWidget {
  final bool autoSave;
  const _DocumentScannerEntry({this.autoSave = false});

  @override
  State<_DocumentScannerEntry> createState() => _DocumentScannerEntryState();
}

class _DocumentScannerEntryState extends State<_DocumentScannerEntry> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final provider = context.read<DocumentScannerProvider>();
    final now = DateTime.now();
    provider.setTitle('Document ${DateFormat('d MMM yyyy').format(now)}');

    final scanned = await provider.scan();
    if (!scanned) {
      if (mounted) {
        if (provider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.errorMessage!)),
          );
        }
        Navigator.pop(context);
      }
      return;
    }

    if (provider.enhanceEnabled) {
      await provider.enhance();
    }

    if (!kIsWeb) {
      await provider.analyzeDocument();
    }

    if (widget.autoSave && !kIsWeb) {
      await _autoSaveAndShowResult(provider);
      return;
    }

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  Future<void> _autoSaveAndShowResult(DocumentScannerProvider provider) async {
    final notesProvider = context.read<NotesProvider>();
    final folderId = provider.classification?.category.folderId;
    final note = _buildNoteFromScannerProvider(provider, folderId: folderId);

    try {
      await notesProvider.addNote(note);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SmartScanResultScreen(note: note)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save note: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return _LoadingScreen(isSmartScan: widget.autoSave);
    }
    return const DocumentScannerScreen();
  }
}

// ---------------------------------------------------------------------------
// Loading screen shown while scanning/enhancing
// ---------------------------------------------------------------------------
class _LoadingScreen extends StatelessWidget {
  final bool isSmartScan;
  const _LoadingScreen({this.isSmartScan = false});

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentScannerProvider>(
      builder: (context, provider, _) {
        String message;
        switch (provider.state) {
          case DocumentScannerState.scanning:
            message = 'Scanning document…';
            break;
          case DocumentScannerState.enhancing:
            message = 'Enhancing image quality…';
            break;
          case DocumentScannerState.analyzing:
            message = 'Reading text & detecting document type…';
            break;
          default:
            message = 'Please wait…';
        }
        return Scaffold(
          backgroundColor: AppTheme.getBackgroundColor(context),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    isSmartScan ? Icons.receipt_long : Icons.document_scanner,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Main scanner screen
// ---------------------------------------------------------------------------
class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({super.key});

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  int _currentPage = 0;
  String? _selectedFolderId;
  final TextEditingController _titleController = TextEditingController();

  static const _folderOptions = [
    ('receipts', 'Receipts'),
    ('bills', 'Bills'),
    ('bank_statements', 'Bank Statements'),
    ('medical', 'Medical'),
    ('identity', 'Identity'),
    ('work', 'Work'),
    ('personal', 'Personal'),
    ('ideas', 'Ideas'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DocumentScannerProvider>();
      _titleController.text = provider.title;
      final category = provider.classification?.category;
      if (category != null && category.id != DocumentCategory.miscellaneous.id) {
        setState(() => _selectedFolderId = category.folderId);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _shareCurrentPdf() async {
    final provider = context.read<DocumentScannerProvider>();
    final url = provider.uploadedPdfUrl;
    if (url == null) return;

    try {
      // Share the Firebase URL directly as text if file not local
      if (provider.localPdfPath != null &&
          File(provider.localPdfPath!).existsSync()) {
        await Share.shareXFiles(
          [XFile(provider.localPdfPath!, mimeType: 'application/pdf')],
          subject: provider.title,
        );
      } else {
        await Share.share(url, subject: provider.title);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  Future<void> _openPdf() async {
    final provider = context.read<DocumentScannerProvider>();
    if (provider.localPdfPath != null) {
      await OpenFilex.open(provider.localPdfPath!);
    }
  }

  Future<void> _generatePdf() async {
    final provider = context.read<DocumentScannerProvider>();
    await provider.generateAndUpload();
  }

  Future<void> _saveNote() async {
    final provider = context.read<DocumentScannerProvider>();
    final notesProvider = context.read<NotesProvider>();
    final note = _buildNoteFromScannerProvider(provider, folderId: _selectedFolderId);

    try {
      await notesProvider.addNote(note);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SmartScanResultScreen(note: note),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save note: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentScannerProvider>(
      builder: (context, provider, _) {
        final pages = provider.displayPaths;
        final isDone = provider.state == DocumentScannerState.done;
        final isGenerating =
            provider.state == DocumentScannerState.generatingPdf ||
                provider.state == DocumentScannerState.uploading;
        final isError = provider.state == DocumentScannerState.error;

        return Scaffold(
          backgroundColor: AppTheme.getBackgroundColor(context),
          appBar: AppBar(
            backgroundColor: AppTheme.getCardColor(context),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppTheme.getTextPrimaryColor(context)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Scan Document',
              style: TextStyle(
                color: AppTheme.getTextPrimaryColor(context),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            actions: [
              if (isDone)
                IconButton(
                  icon: Icon(Icons.share_outlined,
                      color: AppTheme.getTextPrimaryColor(context)),
                  onPressed: _shareCurrentPdf,
                ),
            ],
          ),
          body: Column(
            children: [
              // Page preview
              Expanded(
                child: pages.isEmpty
                    ? const Center(
                        child: Icon(Icons.image_not_supported,
                            size: 80, color: Colors.grey),
                      )
                    : InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.file(
                          File(pages[_currentPage]),
                          fit: BoxFit.contain,
                          width: double.infinity,
                        ),
                      ),
              ),

              // Thumbnail strip (multi-page)
              if (pages.length > 1)
                Container(
                  height: 80,
                  color: AppTheme.getSurfaceColor(context),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: pages.length,
                    itemBuilder: (context, i) {
                      final isSelected = i == _currentPage;
                      return GestureDetector(
                        onTap: () => setState(() => _currentPage = i),
                        child: Container(
                          width: 56,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF10B981)
                                  : AppTheme.getDividerColor(context),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              File(pages[i]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Bottom controls panel
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SmartScan detected category badge
                    if (provider.classification != null &&
                        provider.classification!.category.id != DocumentCategory.miscellaneous.id) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: provider.classification!.category.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(provider.classification!.category.icon,
                                size: 14, color: provider.classification!.category.color),
                            const SizedBox(width: 6),
                            Text(
                              'SmartScan detected: ${provider.classification!.category.displayName}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: provider.classification!.category.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Title field
                    TextField(
                      controller: _titleController,
                      onChanged: provider.setTitle,
                      decoration: InputDecoration(
                        labelText: 'Document Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Enhance quality toggle
                    Row(
                      children: [
                        Text('Enhance Quality',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.getTextPrimaryColor(context),
                                fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Switch(
                          value: provider.enhanceEnabled,
                          onChanged: provider.setEnhanceEnabled,
                          activeColor: const Color(0xFF10B981),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Folder selector
                    Text(
                      'Save to Folder',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.getTextSecondaryColor(context)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _folderOptions.map((f) {
                        final isSelected = _selectedFolderId == f.$1;
                        return ChoiceChip(
                          label: Text(f.$2),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedFolderId =
                                  isSelected ? null : f.$1;
                            });
                          },
                          selectedColor:
                              const Color(0xFF10B981).withOpacity(0.15),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? const Color(0xFF059669)
                                : AppTheme.getTextPrimaryColor(context),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Error message
                    if (isError) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade600, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                provider.errorMessage ?? 'An error occurred.',
                                style:
                                    TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Progress indicator
                    if (isGenerating) ...[
                      Text(
                        provider.state == DocumentScannerState.generatingPdf
                            ? 'Generating PDF…'
                            : 'Uploading to cloud…',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.getTextSecondaryColor(context)),
                      ),
                      const SizedBox(height: 6),
                      const LinearProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF10B981)),
                        backgroundColor: Color(0xFFD1FAE5),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Generate PDF / Open PDF buttons
                    Row(
                      children: [
                        if (!isDone)
                          Expanded(
                            child: GestureDetector(
                              onTap: isGenerating ? null : _generatePdf,
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: isGenerating
                                      ? const LinearGradient(colors: [
                                          Colors.grey,
                                          Colors.grey
                                        ])
                                      : const LinearGradient(
                                          colors: [
                                            Color(0xFF10B981),
                                            Color(0xFF059669)
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.picture_as_pdf,
                                          color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Generate PDF',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (isDone) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openPdf,
                              icon: const Icon(Icons.open_in_new,
                                  color: Color(0xFF10B981)),
                              label: const Text('Open PDF',
                                  style:
                                      TextStyle(color: Color(0xFF10B981))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Color(0xFF10B981)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (isError) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _generatePdf,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Retry',
                              style: TextStyle(color: Color(0xFF10B981))),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Save Document button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saveNote,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save Document',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// SmartScan results screen — shown after saving, matches the spec's
// "Capture. Understand. Organize." success step.
// ---------------------------------------------------------------------------
class SmartScanResultScreen extends StatelessWidget {
  final Note note;
  const SmartScanResultScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final matchingFolders = note.folderId == null
        ? const <Folder>[]
        : Folder.defaultFolders.where((f) => f.id == note.folderId).toList();
    final folderName = matchingFolders.isEmpty ? null : matchingFolders.first.name;
    final category = note.tags.isNotEmpty ? note.tags.first : 'Document';

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getCardColor(context),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'SmartScan Complete',
          style: TextStyle(
            color: AppTheme.getTextPrimaryColor(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Captured, understood & organized',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _InfoRow(icon: Icons.label_outline, label: 'Category', value: category),
            if (folderName != null)
              _InfoRow(icon: Icons.folder_outlined, label: 'Folder', value: folderName),
            _InfoRow(icon: Icons.title, label: 'Title', value: note.title),

            if (note.imagePath != null && File(note.imagePath!).existsSync()) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(note.imagePath!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],

            if (note.ocrText != null && note.ocrText!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Extracted Text',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    note.ocrText!,
                    style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondaryColor(context)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showDocumentNoteModal(context, note),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryPurple),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Edit', style: TextStyle(color: AppTheme.primaryPurple)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.getTextSecondaryColor(context)),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 14, color: AppTheme.getTextSecondaryColor(context)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.getTextPrimaryColor(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
