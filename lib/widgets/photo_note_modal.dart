import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, compute;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';
import '../utils/storage_helper.dart';
import '../utils/file_helper.dart' as file_helper;

Future<bool?> showPhotoNoteModal(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const PhotoNoteModal(),
  );
}

class PhotoNoteModal extends StatefulWidget {
  const PhotoNoteModal({super.key});

  @override
  State<PhotoNoteModal> createState() => _PhotoNoteModalState();
}

class _PhotoNoteModalState extends State<PhotoNoteModal> {
  String? _selectedFolderId;
  bool _isLoading = false;

  // Folders that users can assign notes to
  static final List<Folder> _assignableFolders = Folder.defaultFolders
      .where((f) => ['work', 'personal', 'ideas'].contains(f.id))
      .toList();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: AppTheme.getDividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Saving photo note...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.getDividerColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Text(
            'Add Photo Note',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how you want to add your photo',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.getTextSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 24),

          // Folder selection
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 18, color: AppTheme.getIconColor(context)),
              const SizedBox(width: 8),
              Text(
                'Save to folder:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.getIconColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FolderChip(
                  name: 'None',
                  icon: Icons.folder_off_outlined,
                  color: Colors.grey,
                  isSelected: _selectedFolderId == null,
                  onTap: () => setState(() => _selectedFolderId = null),
                ),
                ..._assignableFolders.map((folder) => _FolderChip(
                  name: folder.name,
                  icon: folder.icon,
                  color: folder.color,
                  isSelected: _selectedFolderId == folder.id,
                  onTap: () => setState(() => _selectedFolderId = folder.id),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Options
          Row(
            children: [
              Expanded(
                child: _PhotoOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  description: 'Take a photo',
                  gradient: const [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                  onTap: () => _pickImage(context, ImageSource.camera),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _PhotoOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  description: 'Choose existing',
                  gradient: const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                  onTap: () => _pickImage(context, ImageSource.gallery),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();

    try {
      debugPrint('PhotoNoteModal: Picking image from ${source.name}...');

      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      debugPrint('PhotoNoteModal: pickedFile = $pickedFile');

      if (pickedFile != null && context.mounted) {
        setState(() => _isLoading = true);
        String savedPath;
        final fileName = 'photo_note_${const Uuid().v4()}.jpg';

        // Upload to Firebase Storage on all platforms for reliable sync
        debugPrint('PhotoNoteModal: Reading bytes from picked file...');
        final bytes = await pickedFile.readAsBytes();
        debugPrint('PhotoNoteModal: Got ${bytes.length} bytes, uploading to Firebase...');
        savedPath = await StorageHelper.uploadToFirebase(
          bytes,
          'photos/$fileName',
          'image/jpeg',
        );
        debugPrint('PhotoNoteModal: Upload complete, savedPath = $savedPath');

        if (!kIsWeb) {
          // Also save locally for offline access
          final appDir = await getApplicationDocumentsDirectory();
          final localPath = '${appDir.path}/$fileName';
          await file_helper.copyFile(pickedFile.path, localPath);
        }

        // Create and save the note
        final notesProvider = Provider.of<NotesProvider>(context, listen: false);
        final now = DateTime.now();
        final dateFormat = DateFormat('d/M/yyyy');

        final note = notesProvider.createNote(
          title: 'Photo Note ${dateFormat.format(now)}',
          content: 'Photo captured on ${DateFormat('MMMM d, yyyy').format(now)}',
          type: NoteType.photo,
          imagePath: savedPath,
          folderId: _selectedFolderId,
        );

        debugPrint('PhotoNoteModal: Saving note to Firestore...');
        await notesProvider.addNote(note);
        debugPrint('PhotoNoteModal: Note saved successfully!');

        // Fire-and-forget OCR on native (non-web) after note is saved
        if (!kIsWeb) {
          _runOcrInBackground(savedPath, note.id, notesProvider);
        }

        if (context.mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo note saved successfully!'),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
        }
      } else {
        debugPrint('PhotoNoteModal: No file picked or context not mounted');
      }
    } catch (e, stackTrace) {
      debugPrint('PhotoNoteModal: Error: $e');
      debugPrint('PhotoNoteModal: Stack trace: $stackTrace');
      if (context.mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context, false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

void _runOcrInBackground(
  String imagePath,
  String noteId,
  NotesProvider notesProvider,
) {
  compute(extractOcrFromPath, imagePath).then((ocrText) {
    if (ocrText != null && ocrText.isNotEmpty) {
      notesProvider.updateNoteOcrText(noteId, ocrText);
    }
  }).catchError((e) {
    debugPrint('PhotoNoteModal OCR error: $e');
  });
}

class _FolderChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FolderChip({
    required this.name,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppTheme.getDividerColor(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : AppTheme.getIconColor(context)),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : AppTheme.getTextSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _PhotoOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.getDividerColor(context)),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.getTextSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
