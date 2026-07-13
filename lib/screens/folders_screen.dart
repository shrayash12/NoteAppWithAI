import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_header.dart';
import '../widgets/filter_bottom_sheet.dart';
import 'folder_detail_screen.dart';
import '../l10n/app_localizations.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  String? _draggingNoteId;
  String? _hoveredFolderId;

  final List<String> _droppableFolderIds = ['work', 'personal', 'ideas'];

  void _onNoteDropped(Note note, String folderId) {
    final notesProvider = context.read<NotesProvider>();
    final updatedNote = note.copyWith(folderId: folderId);
    notesProvider.updateNote(updatedNote);

    final folderName = Folder.defaultFolders.firstWhere((f) => f.id == folderId).name;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.movedToFolder(note.title, folderName)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(
      builder: (context, notesProvider, child) {
        final allNotes = notesProvider.applyFilters(notesProvider.allNotes);
        final droppableFolders = Folder.defaultFolders
            .where((f) => _droppableFolderIds.contains(f.id))
            .toList();
        final otherFolders = Folder.defaultFolders
            .where((f) => !_droppableFolderIds.contains(f.id))
            .toList();

        final l10n = AppLocalizations.of(context);
        return Column(
          children: [
            GradientHeader(
              title: l10n.navFolders,
              subtitle: l10n.foldersSubtitle,
              isGridView: notesProvider.isGridView,
              onViewToggle: () => notesProvider.toggleGridView(),
              onFilterTap: () => showFilterBottomSheet(context),
              hasActiveFilters: notesProvider.hasActiveFilters,
            ),

            // Drop target folders - always visible
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              color: AppTheme.getBackgroundColor(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dropNotesHere,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: droppableFolders.map((folder) {
                      final noteCount = notesProvider.getNoteCountByFolder(folder.id);
                      final isHovered = _hoveredFolderId == folder.id;

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: folder.id != 'ideas' ? 8 : 0,
                          ),
                          child: DragTarget<Note>(
                            onWillAcceptWithDetails: (details) {
                              final willAccept = details.data.folderId != folder.id;
                              if (willAccept) {
                                setState(() => _hoveredFolderId = folder.id);
                              }
                              return willAccept;
                            },
                            onLeave: (_) {
                              setState(() => _hoveredFolderId = null);
                            },
                            onAcceptWithDetails: (details) {
                              setState(() => _hoveredFolderId = null);
                              _onNoteDropped(details.data, folder.id);
                            },
                            builder: (context, candidateData, rejectedData) {
                              return _DropTargetFolder(
                                folder: folder,
                                noteCount: noteCount,
                                isHighlighted: isHovered,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, _) =>
                                          FolderDetailScreen(folder: folder),
                                      transitionsBuilder: (context, animation, _, child) {
                                        return SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(1, 0),
                                            end: Offset.zero,
                                          ).animate(CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeInOutCubic,
                                          )),
                                          child: child,
                                        );
                                      },
                                      transitionDuration: const Duration(milliseconds: 300),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Other folders
                    ...otherFolders.map((folder) {
                      final noteCount = notesProvider.getNoteCountByFolder(folder.id);
                      return _FolderCard(
                        folder: folder,
                        noteCount: noteCount,
                      );
                    }),

                    const SizedBox(height: 24),

                    // All Notes section header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.allNotes,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimaryColor(context),
                          ),
                        ),
                        Text(
                          l10n.longPressDrag,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.getTextSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Draggable notes list/grid
                    if (allNotes.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            l10n.noNotesYet,
                            style: TextStyle(
                              color: AppTheme.getTextSecondaryColor(context),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else if (notesProvider.isGridView)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: allNotes.length,
                        itemBuilder: (context, index) {
                          final note = allNotes[index];
                          return _DraggableGridNoteCard(
                            note: note,
                            colorIndex: index % AppTheme.noteCardColors.length,
                            isDragging: _draggingNoteId == note.id,
                            onDragStarted: () {
                              setState(() => _draggingNoteId = note.id);
                            },
                            onDragEnd: () {
                              setState(() {
                                _draggingNoteId = null;
                                _hoveredFolderId = null;
                              });
                            },
                          );
                        },
                      )
                    else
                      ...allNotes.asMap().entries.map((entry) => _DraggableNoteCard(
                        note: entry.value,
                        colorIndex: entry.key % AppTheme.noteCardColors.length,
                        isDragging: _draggingNoteId == entry.value.id,
                        onDragStarted: () {
                          setState(() => _draggingNoteId = entry.value.id);
                        },
                        onDragEnd: () {
                          setState(() {
                            _draggingNoteId = null;
                            _hoveredFolderId = null;
                          });
                        },
                      )),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DropTargetFolder extends StatefulWidget {
  final Folder folder;
  final int noteCount;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _DropTargetFolder({
    required this.folder,
    required this.noteCount,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  State<_DropTargetFolder> createState() => _DropTargetFolderState();
}

class _DropTargetFolderState extends State<_DropTargetFolder>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    _flipController.reset();
    await _flipController.forward();
    if (!mounted) return;
    widget.onTap();
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _flipController.reset();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isHighlighted
              ? widget.folder.color.withOpacity(0.15)
              : AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isHighlighted
                ? widget.folder.color
                : AppTheme.getDividerColor(context),
            width: widget.isHighlighted ? 2 : 1,
          ),
          boxShadow: widget.isHighlighted
              ? [
                  BoxShadow(
                    color: widget.folder.color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, child) {
                final isFirstHalf = _flipAnimation.value <= 0.5;
                final scaleX = isFirstHalf
                    ? 1.0 - (_flipAnimation.value * 2)
                    : (_flipAnimation.value - 0.5) * 2;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..scale(scaleX.abs(), 1.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.folder.color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.isHighlighted
                          ? Icons.add
                          : (isFirstHalf
                              ? widget.folder.icon
                              : Icons.arrow_forward_rounded),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              widget.folder.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.isHighlighted
                    ? widget.folder.color
                    : AppTheme.getTextPrimaryColor(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.isHighlighted ? 'Drop here' : '${widget.noteCount} notes',
              style: TextStyle(
                fontSize: 10,
                color: widget.isHighlighted
                    ? widget.folder.color
                    : AppTheme.getTextSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final Folder folder;
  final int noteCount;
  final bool isHighlighted;

  const _FolderCard({
    required this.folder,
    required this.noteCount,
    this.isHighlighted = false,
  });

  void _navigate(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => FolderDetailScreen(folder: folder),
        transitionsBuilder: (context, animation, _, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigate(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: isHighlighted
              ? Border.all(color: folder.color, width: 2)
              : null,
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              isHighlighted ? folder.color.withOpacity(0.1) : AppTheme.getCardColor(context),
              folder.color.withOpacity(isHighlighted ? 0.25 : 0.05),
            ],
          ),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: folder.color.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: folder.color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isHighlighted
                    ? [
                        BoxShadow(
                          color: folder.color.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isHighlighted ? Icons.add : folder.icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        folder.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isHighlighted ? folder.color : AppTheme.getTextPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isHighlighted ? 'Drop here to move' : '$noteCount notes',
                    style: TextStyle(
                      fontSize: 14,
                      color: isHighlighted ? folder.color : AppTheme.getTextSecondaryColor(context),
                      fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isHighlighted ? Icons.arrow_downward : Icons.chevron_right,
              color: isHighlighted ? folder.color : AppTheme.getIconColor(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggableGridNoteCard extends StatelessWidget {
  final Note note;
  final bool isDragging;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final int colorIndex;

  const _DraggableGridNoteCard({
    required this.note,
    required this.isDragging,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.colorIndex,
  });

  IconData _getNoteTypeIcon() {
    switch (note.type) {
      case NoteType.text:
        return Icons.description;
      case NoteType.voice:
        return Icons.mic;
      case NoteType.drawing:
        return Icons.brush;
      case NoteType.photo:
        return Icons.photo_camera;
      case NoteType.checklist:
        return Icons.checklist;
      case NoteType.document:
        return Icons.picture_as_pdf;
    }
  }

  List<Color> _getNoteTypeGradient() {
    switch (note.type) {
      case NoteType.text:
        return [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];
      case NoteType.voice:
        return [const Color(0xFF06B6D4), const Color(0xFF3B82F6)];
      case NoteType.drawing:
        return [const Color(0xFF8B5CF6), const Color(0xFFA855F7)];
      case NoteType.photo:
        return [const Color(0xFFEC4899), const Color(0xFFF43F5E)];
      case NoteType.checklist:
        return [const Color(0xFFFBBF24), const Color(0xFFF59E0B)];
      case NoteType.document:
        return [const Color(0xFF10B981), const Color(0xFF059669)];
    }
  }

  String _getNoteTypeLabel() {
    switch (note.type) {
      case NoteType.text:
        return 'Text';
      case NoteType.voice:
        return 'Voice';
      case NoteType.drawing:
        return 'Drawing';
      case NoteType.photo:
        return 'Photo';
      case NoteType.checklist:
        return 'Checklist';
      case NoteType.document:
        return 'Document';
    }
  }

  Color _getNoteTypeColor() {
    switch (note.type) {
      case NoteType.text:
        return const Color(0xFF3B82F6);
      case NoteType.voice:
        return const Color(0xFF06B6D4);
      case NoteType.drawing:
        return const Color(0xFF8B5CF6);
      case NoteType.photo:
        return const Color(0xFFEC4899);
      case NoteType.checklist:
        return const Color(0xFFF59E0B);
      case NoteType.document:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('M/d');

    return LongPressDraggable<Note>(
      data: note,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd(),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.4,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getNoteTypeColor(), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _getNoteTypeGradient()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getNoteTypeIcon(), size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _getNoteTypeLabel(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                note.title.isNotEmpty ? note.title : 'Untitled',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildGridCard(context, dateFormat),
      ),
      child: _buildGridCard(context, dateFormat),
    );
  }

  Widget _buildGridCard(BuildContext context, DateFormat dateFormat) {
    final cardHash = colorIndex;
    final cardTextPrimary = AppTheme.noteCardText(context);
    final cardTextSecondary = AppTheme.noteCardSubText(context);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.noteCardBg(context, cardHash),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getDividerColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with type badge and drag indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _getNoteTypeGradient()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getNoteTypeIcon(), size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        _getNoteTypeLabel(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: cardTextSecondary,
                ),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isNotEmpty ? note.title : 'Untitled',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: cardTextPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      note.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: cardTextSecondary,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom row with status icons and date
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (note.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.push_pin, size: 14, color: cardTextSecondary),
                      ),
                    if (note.isFavorite)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                      ),
                    if (note.isLocked)
                      Icon(Icons.lock, size: 14, color: cardTextSecondary),
                  ],
                ),
                Text(
                  dateFormat.format(note.createdAt),
                  style: TextStyle(fontSize: 11, color: cardTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableNoteCard extends StatelessWidget {
  final Note note;
  final bool isDragging;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final int colorIndex;

  const _DraggableNoteCard({
    required this.note,
    required this.isDragging,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.colorIndex,
  });

  IconData _getNoteTypeIcon() {
    switch (note.type) {
      case NoteType.text:
        return Icons.description;
      case NoteType.voice:
        return Icons.mic;
      case NoteType.drawing:
        return Icons.brush;
      case NoteType.photo:
        return Icons.photo_camera;
      case NoteType.checklist:
        return Icons.checklist;
      case NoteType.document:
        return Icons.picture_as_pdf;
    }
  }

  Color _getNoteTypeColor() {
    switch (note.type) {
      case NoteType.text:
        return const Color(0xFF3B82F6);
      case NoteType.voice:
        return const Color(0xFF06B6D4);
      case NoteType.drawing:
        return const Color(0xFF8B5CF6);
      case NoteType.photo:
        return const Color(0xFFEC4899);
      case NoteType.checklist:
        return const Color(0xFFF59E0B);
      case NoteType.document:
        return const Color(0xFF10B981);
    }
  }

  String? _getFolderName() {
    if (note.folderId == null) return null;
    final folder = Folder.defaultFolders.where((f) => f.id == note.folderId).firstOrNull;
    return folder?.name;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('M/d/yyyy');
    final folderName = _getFolderName();

    return LongPressDraggable<Note>(
      data: note,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd(),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getNoteTypeColor(), width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getNoteTypeColor(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getNoteTypeIcon(),
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      note.title.isNotEmpty ? note.title : 'Untitled',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getTextPrimaryColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Drag to folder',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getNoteTypeColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildCard(context, dateFormat, folderName),
      ),
      child: _buildCard(context, dateFormat, folderName),
    );
  }

  Widget _buildCard(BuildContext context, DateFormat dateFormat, String? folderName) {
    final cardTextPrimary = AppTheme.noteCardText(context);
    final cardTextSecondary = AppTheme.noteCardSubText(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.noteCardBg(context, colorIndex),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getDividerColor(context)),
      ),
      child: Row(
        children: [
          // Type icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _getNoteTypeColor().withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getNoteTypeIcon(),
              color: _getNoteTypeColor(),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Note info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title.isNotEmpty ? note.title : 'Untitled',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cardTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      dateFormat.format(note.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: cardTextSecondary,
                      ),
                    ),
                    if (folderName != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          folderName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: cardTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Drag indicator
          Icon(
            Icons.drag_indicator,
            color: cardTextSecondary,
            size: 22,
          ),
        ],
      ),
    );
  }
}
