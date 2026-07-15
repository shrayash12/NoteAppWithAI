import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';

class ImportNotesSheet extends StatefulWidget {
  const ImportNotesSheet({super.key});

  @override
  State<ImportNotesSheet> createState() => _ImportNotesSheetState();
}

class _ImportNotesSheetState extends State<ImportNotesSheet> {
  bool _importing = false;
  String _statusMessage = '';

  // ── Google Keep JSON import ───────────────────────────────────────────────

  Future<void> _importGoogleKeep() async {
    // Use FileType.any + withData:true for Android compatibility.
    // FileType.custom with allowedExtensions fails silently on Android 9
    // because the SAF file picker doesn't handle JSON MIME filtering well.
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file picker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (result == null || result.files.isEmpty) return;

    // Filter to .json files after picking
    final jsonFiles = result.files
        .where((f) => f.name.toLowerCase().endsWith('.json'))
        .toList();

    if (jsonFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select .json files exported from Google Keep'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _importing = true;
      _statusMessage = 'Reading Google Keep files…';
    });

    final notes = <Note>[];
    for (final file in jsonFiles) {
      try {
        String raw;
        if (file.bytes != null) {
          raw = String.fromCharCodes(file.bytes!);
        } else if (file.path != null) {
          raw = File(file.path!).readAsStringSync();
        } else {
          continue;
        }
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final note = _parseGoogleKeepJson(json);
        if (note != null) notes.add(note);
      } catch (_) {}
    }

    await _uploadNotes(notes, jsonFiles.length);
  }

  // ── Text / Markdown import ────────────────────────────────────────────────

  Future<void> _importTextFiles() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file picker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (result == null || result.files.isEmpty) return;

    // Filter to .txt and .md files after picking
    final textFiles = result.files.where((f) {
      final name = f.name.toLowerCase();
      return name.endsWith('.txt') || name.endsWith('.md');
    }).toList();

    if (textFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select .txt or .md files'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _importing = true;
      _statusMessage = 'Parsing files…';
    });

    final notes = <Note>[];
    for (final file in textFiles) {
      final note = _parseTextFile(file.bytes, file.path, file.name);
      if (note != null) notes.add(note);
    }

    await _uploadNotes(notes, textFiles.length);
  }

  // ── Save parsed notes to Firestore ───────────────────────────────────────

  Future<void> _uploadNotes(List<Note> notes, int totalFiles) async {
    if (notes.isEmpty) {
      setState(() => _importing = false);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No notes could be read from the selected files.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _statusMessage = 'Importing ${notes.length} notes…');

    final provider = context.read<NotesProvider>();
    int imported = 0;
    for (final note in notes) {
      try {
        await provider.addNote(note);
        imported++;
      } catch (_) {}
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            imported == notes.length
                ? 'Imported $imported note${imported == 1 ? '' : 's'} successfully'
                : 'Imported $imported of ${notes.length} notes',
          ),
          backgroundColor: AppTheme.primaryPurple,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Parsers ───────────────────────────────────────────────────────────────

  Note? _parseTextFile(Uint8List? bytes, String? path, String filename) {
    try {
      String content;
      if (bytes != null) {
        content = String.fromCharCodes(bytes);
      } else if (path != null) {
        content = File(path).readAsStringSync();
      } else {
        return null;
      }
      if (content.trim().isEmpty) return null;

      final lines = content.split('\n');
      String title =
          filename.replaceAll(RegExp(r'\.(txt|md)$', caseSensitive: false), '');
      String body = content;

      // Use first # heading as title for markdown files
      if (filename.toLowerCase().endsWith('.md') && lines.isNotEmpty) {
        final firstLine = lines.first.trim();
        if (firstLine.startsWith('#')) {
          title = firstLine.replaceAll(RegExp(r'^#+\s*'), '').trim();
          body = lines.skip(1).join('\n').trim();
        }
      }

      final now = DateTime.now();
      return Note(
        id: const Uuid().v4(),
        title: title.isEmpty ? 'Imported Note' : title,
        content: body,
        type: NoteType.text,
        createdAt: now,
        updatedAt: now,
      );
    } catch (_) {
      return null;
    }
  }

  Note? _parseGoogleKeepJson(Map<String, dynamic> json) {
    try {
      // Skip trashed notes
      if (json['isTrashed'] == true) return null;

      final title = json['title'] as String? ?? '';
      final textContent = json['textContent'] as String? ?? '';
      final isPinned = json['isPinned'] as bool? ?? false;

      // Timestamps are microseconds since epoch
      final createdMicros = json['createdTimestampUsec'] as int? ?? 0;
      final editedMicros = json['userEditedTimestampUsec'] as int? ?? 0;
      final createdAt = createdMicros > 0
          ? DateTime.fromMicrosecondsSinceEpoch(createdMicros)
          : DateTime.now();
      final updatedAt = editedMicros > 0
          ? DateTime.fromMicrosecondsSinceEpoch(editedMicros)
          : DateTime.now();

      // Labels → tags
      final labels = json['labels'] as List<dynamic>? ?? [];
      final tags = labels
          .map((l) => l['name'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      // Checklist note
      final listContent = json['listContent'] as List<dynamic>?;
      if (listContent != null && listContent.isNotEmpty) {
        final items = listContent
            .map((item) => ChecklistItem(
                  id: const Uuid().v4(),
                  text: item['text'] as String? ?? '',
                  isChecked: item['isChecked'] as bool? ?? false,
                ))
            .where((item) => item.text.isNotEmpty)
            .toList();

        return Note(
          id: const Uuid().v4(),
          title: title.isEmpty ? 'Imported Note' : title,
          content: textContent,
          type: NoteType.checklist,
          checklistItems: items,
          createdAt: createdAt,
          updatedAt: updatedAt,
          isPinned: isPinned,
          tags: tags,
        );
      }

      // Text note — derive title from content if missing
      final noteTitle = title.isNotEmpty
          ? title
          : textContent.length > 50
              ? '${textContent.substring(0, 50)}…'
              : textContent;

      return Note(
        id: const Uuid().v4(),
        title: noteTitle.isEmpty ? 'Imported Note' : noteTitle,
        content: textContent,
        type: NoteType.text,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isPinned: isPinned,
        tags: tags,
      );
    } catch (_) {
      return null;
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBg =
        isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F3FF);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppTheme.primaryPurple,
                      AppTheme.primaryMagenta,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.file_download_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Notes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Bring your notes from other apps',
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_importing) ...[
            const SizedBox(height: 8),
            const CircularProgressIndicator(
              color: AppTheme.primaryPurple,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: TextStyle(color: textColor.withOpacity(0.7)),
            ),
            const SizedBox(height: 24),
          ] else ...[
            // ── Google Keep card ──────────────────────────────────────────
            _ImportOptionCard(
              bg: cardBg,
              textColor: textColor,
              icon: Icons.cloud_download_outlined,
              iconColor: const Color(0xFF34A853),
              title: 'Google Keep',
              subtitle: 'Import .json files from Google Takeout',
              hints: const [
                'Go to takeout.google.com',
                'Export "Keep" → extract the ZIP',
                'Select one or more .json note files',
              ],
              onTap: _importGoogleKeep,
            ),
            const SizedBox(height: 12),

            // ── Text / Markdown card ──────────────────────────────────────
            _ImportOptionCard(
              bg: cardBg,
              textColor: textColor,
              icon: Icons.description_outlined,
              iconColor: AppTheme.primaryPurple,
              title: 'Text / Markdown files',
              subtitle: 'Import .txt or .md files from any app',
              hints: const [
                'Apple Notes (export as text)',
                'Obsidian, Notion, Bear .md exports',
                'Any plain-text file',
              ],
              onTap: _importTextFiles,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ── Import option card ────────────────────────────────────────────────────────

class _ImportOptionCard extends StatelessWidget {
  final Color bg;
  final Color textColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<String> hints;
  final VoidCallback onTap;

  const _ImportOptionCard({
    required this.bg,
    required this.textColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.hints,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: iconColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...hints.map(
                    (hint) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              hint,
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withOpacity(0.55),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: textColor.withOpacity(0.35),
            ),
          ],
        ),
      ),
    );
  }
}
