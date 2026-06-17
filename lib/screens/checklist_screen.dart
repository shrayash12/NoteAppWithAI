import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_notification.dart';

class ChecklistModal extends StatefulWidget {
  final Note? note;

  const ChecklistModal({super.key, this.note});

  @override
  State<ChecklistModal> createState() => _ChecklistModalState();
}

class _ChecklistModalState extends State<ChecklistModal> {
  late TextEditingController _titleController;
  late TextEditingController _newItemController;
  late List<ChecklistItem> _items;
  bool _isFavorite = false;
  bool _isLocked = false;
  bool _isEditing = false;
  String? _selectedFolderId;
  DateTime? _reminderDateTime;

  // Folders that users can assign notes to
  static final List<Folder> _assignableFolders = Folder.defaultFolders
      .where((f) => ['work', 'personal', 'ideas'].contains(f.id))
      .toList();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.note != null;
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _newItemController = TextEditingController();
    _items = widget.note?.checklistItems != null
        ? List.from(widget.note!.checklistItems!)
        : [];

    if (widget.note != null) {
      _isFavorite = widget.note!.isFavorite;
      _isLocked = widget.note!.isLocked;
      _selectedFolderId = widget.note!.folderId;
      _reminderDateTime = widget.note!.reminderDateTime;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _newItemController.dispose();
    super.dispose();
  }

  void _addItem() {
    final text = _newItemController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _items.add(ChecklistItem(
          id: const Uuid().v4(),
          text: text,
          isChecked: false,
        ));
        _newItemController.clear();
      });
    }
  }

  void _toggleItem(int index) {
    setState(() {
      final item = _items[index];
      _items[index] = ChecklistItem(
        id: item.id,
        text: item.text,
        isChecked: !item.isChecked,
      );
    });
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
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

  void _saveChecklist() {
    if (_titleController.text.isEmpty && _items.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final notesProvider = context.read<NotesProvider>();
    final now = DateTime.now();

    if (_isEditing && widget.note != null) {
      final updatedNote = widget.note!.copyWith(
        title: _titleController.text.isEmpty ? 'Untitled Checklist' : _titleController.text,
        content: '${_items.where((i) => i.isChecked).length}/${_items.length} completed',
        updatedAt: now,
        isFavorite: _isFavorite,
        isLocked: _isLocked,
        checklistItems: _items,
        folderId: _selectedFolderId,
        reminderDateTime: _reminderDateTime,
        clearReminder: _reminderDateTime == null,
      );
      notesProvider.updateNote(updatedNote);

      Navigator.pop(context);
      AnimatedNotification.show(context, type: NotificationType.updated);
    } else {
      final newNote = Note(
        id: const Uuid().v4(),
        title: _titleController.text.isEmpty ? 'Untitled Checklist' : _titleController.text,
        content: '${_items.where((i) => i.isChecked).length}/${_items.length} completed',
        type: NoteType.checklist,
        createdAt: now,
        updatedAt: now,
        isFavorite: _isFavorite,
        isLocked: _isLocked,
        checklistItems: _items,
        folderId: _selectedFolderId,
        reminderDateTime: _reminderDateTime,
      );
      notesProvider.addNote(newNote);

      Navigator.pop(context);
      AnimatedNotification.show(context, type: NotificationType.created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _items.where((i) => i.isChecked).length;
    final progress = _items.isEmpty ? 0.0 : completedCount / _items.length;

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
                  // Checklist badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_box, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Checklist',
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
                  // Favorite button
                  IconButton(
                    onPressed: () => setState(() => _isFavorite = !_isFavorite),
                    icon: Icon(
                      _isFavorite ? Icons.star : Icons.star_outline,
                      color: _isFavorite ? Colors.amber : AppTheme.getIconColor(context),
                    ),
                  ),
                  // Lock button
                  IconButton(
                    onPressed: () => setState(() => _isLocked = !_isLocked),
                    icon: Icon(
                      _isLocked ? Icons.lock : Icons.lock_outline,
                      color: _isLocked ? AppTheme.primaryPurple : AppTheme.getIconColor(context),
                    ),
                  ),
                  // Close button
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppTheme.getIconColor(context)),
                  ),
                ],
              ),
            ),

            // Content area
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
                        hintText: 'Checklist title...',
                        hintStyle: TextStyle(
                          color: AppTheme.getTextSecondaryColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                      ),
                    ),

                    // Progress bar
                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: AppTheme.getDividerColor(context),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress == 1.0 ? Colors.green : const Color(0xFFF59E0B),
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$completedCount/${_items.length}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getTextSecondaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Checklist items
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // Existing items
                          ..._items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return _ChecklistItemTile(
                              item: item,
                              onToggle: () => _toggleItem(index),
                              onDelete: () => _deleteItem(index),
                            );
                          }),

                          // Add new item
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  color: AppTheme.getIconColor(context),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _newItemController,
                                    style: const TextStyle(fontSize: 16),
                                    decoration: InputDecoration(
                                      hintText: 'Add new item...',
                                      hintStyle: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (_) => _addItem(),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _addItem,
                                  child: const Text(
                                    'Add',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Folder selection
                    Row(
                      children: [
                        Icon(Icons.folder_outlined, size: 20, color: AppTheme.getIconColor(context)),
                        const SizedBox(width: 8),
                        Text(
                          'Folder',
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
                          _FolderOption(
                            name: 'None',
                            icon: Icons.folder_off_outlined,
                            color: Colors.grey,
                            isSelected: _selectedFolderId == null,
                            onTap: () => setState(() => _selectedFolderId = null),
                          ),
                          ..._assignableFolders.map((folder) => _FolderOption(
                            name: folder.name,
                            icon: folder.icon,
                            color: folder.color,
                            isSelected: _selectedFolderId == folder.id,
                            onTap: () => setState(() => _selectedFolderId = folder.id),
                          )),
                        ],
                      ),
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
                          label: const Text('Add Reminder'),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _saveChecklist,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Save'),
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

class _ChecklistItemTile extends StatelessWidget {
  final ChecklistItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ChecklistItemTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: item.isChecked,
            onChanged: (_) => onToggle(),
            activeColor: const Color(0xFFF59E0B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Text(
              item.text,
              style: TextStyle(
                fontSize: 16,
                color: item.isChecked ? AppTheme.getTextSecondaryColor(context) : AppTheme.getTextPrimaryColor(context),
                decoration: item.isChecked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.close, size: 20, color: AppTheme.getIconColor(context)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
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
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? color : AppTheme.getIconColor(context)),
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

// Function to show the checklist modal
void showChecklistModal(BuildContext context, {Note? note}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ChecklistModal(note: note),
  );
}
