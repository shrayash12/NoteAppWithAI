import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_notification.dart';
import '../services/ai_service.dart';
import '../l10n/app_localizations.dart';

class TextNoteModal extends StatefulWidget {
  final Note? note;

  const TextNoteModal({super.key, this.note});

  @override
  State<TextNoteModal> createState() => _TextNoteModalState();
}

class _TextNoteModalState extends State<TextNoteModal> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagController;

  bool _isFavorite = false;
  bool _isLocked = false;
  List<String> _tags = [];
  bool _isEditing = false;
  String? _selectedFolderId;
  DateTime? _reminderDateTime;
  bool _aiEnhanceLoading = false;

  // Folders that users can assign notes to
  static final List<Folder> _assignableFolders = Folder.defaultFolders
      .where((f) => ['work', 'personal', 'ideas'].contains(f.id))
      .toList();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.note != null;
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _tagController = TextEditingController();

    if (widget.note != null) {
      _isFavorite = widget.note!.isFavorite;
      _isLocked = widget.note!.isLocked;
      _tags = List.from(widget.note!.tags);
      _selectedFolderId = widget.note!.folderId;
      _reminderDateTime = widget.note!.reminderDateTime;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }



  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
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
    setState(() {
      _reminderDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _saveNote() {
    if (_titleController.text.isEmpty && _contentController.text.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final l10n = AppLocalizations.of(context);
    final notesProvider = context.read<NotesProvider>();
    final now = DateTime.now();

    if (_isEditing && widget.note != null) {
      final updatedNote = widget.note!.copyWith(
        title: _titleController.text.isEmpty ? l10n.untitledNote : _titleController.text,
        content: _contentController.text,
        updatedAt: now,
        isFavorite: _isFavorite,
        isLocked: _isLocked,
        tags: _tags,
        folderId: _selectedFolderId,
        reminderDateTime: _reminderDateTime,
        clearReminder: _reminderDateTime == null,
      );
      notesProvider.updateNote(updatedNote);

      Navigator.pop(context);
      AnimatedNotification.show(context, type: NotificationType.updated);
    } else {
      final newNote = notesProvider.createNote(
        title: _titleController.text.isEmpty ? l10n.untitledNote : _titleController.text,
        content: _contentController.text,
        type: NoteType.text,
        folderId: _selectedFolderId,
      );
      final noteWithExtras = newNote.copyWith(
        isFavorite: _isFavorite,
        isLocked: _isLocked,
        tags: _tags,
        reminderDateTime: _reminderDateTime,
      );
      notesProvider.addNote(noteWithExtras);

      Navigator.pop(context);
      AnimatedNotification.show(context, type: NotificationType.created);
    }
  }

  Future<void> _aiEnhance() async {
    final l10n = AppLocalizations.of(context);
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.aiErrorEmptyInput)),
      );
      return;
    }

    setState(() => _aiEnhanceLoading = true);
    try {
      final enhanced = await AIService.enhanceWriting(_contentController.text);
      if (!mounted) return;
      setState(() => _aiEnhanceLoading = false);
      _showEnhancedPreview(enhanced);
    } on AIServiceException catch (e) {
      if (!mounted) return;
      setState(() => _aiEnhanceLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _aiEnhanceLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.aiErrorGeneric)));
    }
  }

  void _showEnhancedPreview(String enhanced) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.aiResult),
        content: SingleChildScrollView(child: Text(enhanced)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.aiDiscard),
          ),
          TextButton(
            onPressed: () {
              setState(() => _contentController.text = enhanced);
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.aiApply),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                children: [
                  // Favorite button
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isFavorite = !_isFavorite;
                      });
                    },
                    icon: Icon(
                      _isFavorite ? Icons.star : Icons.star_outline,
                      color: _isFavorite ? Colors.amber : AppTheme.getIconColor(context),
                    ),
                  ),
                  // Lock button
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isLocked = !_isLocked;
                      });
                    },
                    icon: Icon(
                      _isLocked ? Icons.lock : Icons.lock_outline,
                      color: _isLocked ? AppTheme.primaryPurple : AppTheme.getIconColor(context),
                    ),
                  ),
                  const Spacer(),
                  // Close button
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppTheme.getIconColor(context)),
                  ),
                ],
              ),
            ),

            // Note content area
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    TextField(
                      controller: _titleController,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getTextPrimaryColor(context),
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.noteTitleHint,
                        hintStyle: TextStyle(
                          color: AppTheme.getTextSecondaryColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                      ),
                    ),

                    // Content area with colored background
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.getTextPrimaryColor(context),
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.startTypingHint,
                          hintStyle: TextStyle(
                            color: AppTheme.getTextSecondaryColor(context),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // AI Enhance button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _aiEnhanceLoading ? null : _aiEnhance,
                        icon: _aiEnhanceLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(l10n.aiEnhance),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.getIconColor(context),
                          side: BorderSide(color: AppTheme.getDividerColor(context)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Folder section
                    Row(
                      children: [
                        Icon(Icons.folder_outlined,
                            size: 20, color: AppTheme.getIconColor(context)),
                        const SizedBox(width: 8),
                        Text(
                          l10n.folderLabel,
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
                          // No folder option
                          _FolderOption(
                            name: l10n.none,
                            icon: Icons.folder_off_outlined,
                            color: Colors.grey,
                            isSelected: _selectedFolderId == null,
                            onTap: () {
                              setState(() {
                                _selectedFolderId = null;
                              });
                            },
                          ),
                          // Assignable folders
                          ..._assignableFolders.map((folder) {
                            return _FolderOption(
                              name: folder.name,
                              icon: folder.icon,
                              color: folder.color,
                              isSelected: _selectedFolderId == folder.id,
                              onTap: () {
                                setState(() {
                                  _selectedFolderId = folder.id;
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tags section
                    Row(
                      children: [
                        Icon(Icons.label_outline,
                            size: 20, color: AppTheme.getIconColor(context)),
                        const SizedBox(width: 8),
                        Text(
                          'Tags',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.getIconColor(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tag chips
                    if (_tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => _removeTag(tag),
                            backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                            labelStyle: const TextStyle(
                              color: AppTheme.primaryPurple,
                              fontSize: 12,
                            ),
                            deleteIconColor: AppTheme.primaryPurple,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          );
                        }).toList(),
                      ),

                    if (_tags.isNotEmpty) const SizedBox(height: 8),

                    // Add tag input
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.getSurfaceColor(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: _tagController,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Add tag...',
                                hintStyle: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onSubmitted: (_) => _addTag(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _addTag,
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Reminder section
                    Row(
                      children: [
                        Icon(Icons.notifications_outlined,
                            size: 20, color: AppTheme.getIconColor(context)),
                        const SizedBox(width: 8),
                        Text(
                          'Reminder',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.getIconColor(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_reminderDateTime == null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pickReminder,
                          icon: const Icon(Icons.add_alarm, size: 18),
                          label: Text(l10n.addReminder),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.getTextSecondaryColor(context),
                            side: BorderSide(color: AppTheme.getDividerColor(context)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Chip(
                            avatar: const Icon(Icons.notifications_active,
                                size: 16, color: Colors.orange),
                            label: Text(
                              DateFormat('MMM d, y h:mm a').format(_reminderDateTime!),
                              style: const TextStyle(fontSize: 13),
                            ),
                            backgroundColor: Colors.orange.withOpacity(0.1),
                            side: BorderSide(color: Colors.orange.withOpacity(0.3)),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _pickReminder,
                            icon: Icon(Icons.edit, size: 18, color: AppTheme.getIconColor(context)),
                            tooltip: 'Edit reminder',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => setState(() => _reminderDateTime = null),
                            icon: Icon(Icons.close, size: 18, color: AppTheme.getIconColor(context)),
                            tooltip: 'Remove reminder',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.getTextSecondaryColor(context),
                        side: BorderSide(color: AppTheme.getDividerColor(context)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.fabGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _saveNote,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Save Note'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderOption extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FolderOption({
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
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.getDividerColor(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : AppTheme.getIconColor(context),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : AppTheme.getIconColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Function to show the text note modal
void showTextNoteModal(BuildContext context, {Note? note}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => TextNoteModal(note: note),
  );
}

// Keep the old TextNoteScreen for backwards compatibility but redirect to modal
class TextNoteScreen extends StatelessWidget {
  final Note? note;

  const TextNoteScreen({super.key, this.note});

  @override
  Widget build(BuildContext context) {
    // Show the modal and pop this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pop(context);
      showTextNoteModal(context, note: note);
    });

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
