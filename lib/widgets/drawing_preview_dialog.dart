import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../utils/image_helper.dart';
import '../l10n/app_localizations.dart';
import 'fullscreen_image_viewer.dart';

void showDrawingPreview(BuildContext context, Note note) {
  if (note.imagePath == null) return;
  showDialog(
    context: context,
    builder: (context) => DrawingPreviewDialog(note: note),
  );
}

class DrawingPreviewDialog extends StatefulWidget {
  final Note note;
  const DrawingPreviewDialog({super.key, required this.note});

  @override
  State<DrawingPreviewDialog> createState() => _DrawingPreviewDialogState();
}

class _DrawingPreviewDialogState extends State<DrawingPreviewDialog> {
  DateTime? _reminderDateTime;

  @override
  void initState() {
    super.initState();
    _reminderDateTime = widget.note.reminderDateTime;
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
    await notesProvider.updateNote(widget.note.copyWith(reminderDateTime: newReminder, updatedAt: DateTime.now()));
  }

  Future<void> _removeReminder() async {
    setState(() => _reminderDateTime = null);
    final notesProvider = context.read<NotesProvider>();
    await notesProvider.updateNote(widget.note.copyWith(clearReminder: true, updatedAt: DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.brush, color: AppTheme.primaryPurple, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        note.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Image
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.getDividerColor(context)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ImageHelper.imageExists(note.imagePath)
                    ? GestureDetector(
                        onTap: () => showFullScreenImage(context, note.imagePath),
                        child: ImageHelper.buildImage(note.imagePath, fit: BoxFit.contain),
                      )
                    : Center(child: Icon(Icons.broken_image, size: 60, color: AppTheme.getIconColor(context))),
              ),
            ),
            // Reminder row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.notifications_outlined, size: 16, color: AppTheme.getTextSecondaryColor(context)),
                  const SizedBox(width: 6),
                  if (_reminderDateTime == null)
                    TextButton.icon(
                      onPressed: _pickReminder,
                      icon: const Icon(Icons.add_alarm, size: 14),
                      label: Text(AppLocalizations.of(context).addReminder, style: const TextStyle(fontSize: 12)),
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
                      deleteIcon: Icon(Icons.close, size: 14, color: AppTheme.getTextSecondaryColor(context)),
                      onDeleted: _removeReminder,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _pickReminder,
                      icon: Icon(Icons.edit, size: 14, color: AppTheme.getTextSecondaryColor(context)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
            ),
            // Date
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '${AppLocalizations.of(context).createdOn} ${DateFormat('MMM d, yyyy').format(note.createdAt)}',
                style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondaryColor(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
