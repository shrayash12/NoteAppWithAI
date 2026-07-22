import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_header.dart';
import '../widgets/filter_bottom_sheet.dart';
import 'text_note_screen.dart';
import 'drawing_screen.dart';
import '../widgets/photo_preview_modal.dart';
import '../widgets/animated_notification.dart';
import '../widgets/shimmer_widgets.dart';
import '../widgets/document_note_modal.dart';
import 'checklist_screen.dart';
import '../utils/storage_helper.dart';
import '../utils/image_helper.dart';
import '../utils/share_helper.dart';
import '../widgets/lock_bottom_sheet.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedFilterIndex = 0;
  int _pressedFilterIndex = -1;
  int _filterVersion = 0;

  static const int _pageSize = 20;
  int _visibleCount = 20;
  List<Note> _allCurrentNotes = [];
  final ScrollController _scrollController = ScrollController();
  final List<IconData> _filterIcons = [
    Icons.grid_view,
    Icons.push_pin_outlined,
    Icons.mic_none,
    Icons.star_outline,
    Icons.lock_outline,
  ];

  List<String> _getFilters(AppLocalizations l10n) => [
    l10n.filterAll,
    l10n.filterPinned,
    l10n.navVoice,
    l10n.filterFavorites,
    l10n.filterLocked,
  ];

  // Audio player for voice notes
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  bool _isPlaying = false;
  String? _loadingNoteId;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _currentlyPlayingId = null;
        _isPlaying = false;
      });
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        if (_visibleCount < _allCurrentNotes.length) {
          setState(() {
            _visibleCount = (_visibleCount + _pageSize)
                .clamp(0, _allCurrentNotes.length);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _playPause(Note note) async {
    if (_currentlyPlayingId == note.id && _isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else if (_currentlyPlayingId == note.id && !_isPlaying) {
      await _audioPlayer.resume();
      setState(() {
        _isPlaying = true;
      });
    } else {
      if (note.voicePath != null) {
        try {
          await _audioPlayer.stop();
          String playPath = note.voicePath!;
          if (StorageHelper.isUrl(note.voicePath)) {
            setState(() => _loadingNoteId = note.id);
            // Download to temp file first — Android MediaPlayer struggles with Firebase URLs directly
            final dir = await getTemporaryDirectory();
            final tempFile = File('${dir.path}/voice_${note.id}.m4a');
            if (!tempFile.existsSync()) {
              final response = await http.get(Uri.parse(note.voicePath!));
              await tempFile.writeAsBytes(response.bodyBytes);
            }
            playPath = tempFile.path;
          }
          await _audioPlayer.play(DeviceFileSource(playPath));
          setState(() {
            _loadingNoteId = null;
            _currentlyPlayingId = note.id;
            _isPlaying = true;
          });
        } catch (e) {
          setState(() => _loadingNoteId = null);
          debugPrint('Error playing voice note: $e');
        }
      }
    }
  }

  void _openNote(BuildContext context, Note note) {
    if (note.type == NoteType.drawing) {
      _showDrawingPreview(context, note);
    } else if (note.type == NoteType.photo) {
      showPhotoPreviewModal(context, note);
    } else if (note.type == NoteType.checklist) {
      showChecklistModal(context, note: note);
    } else if (note.type == NoteType.document) {
      showDocumentNoteModal(context, note);
    } else if (note.type == NoteType.voice) {
      _showVoiceNoteModal(context, note);
    } else {
      showTextNoteModal(context, note: note);
    }
  }

  void _showVoiceNoteModal(BuildContext context, Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VoiceNoteDetailSheet(
        note: note,
        audioPlayer: _audioPlayer,
        isPlaying: _currentlyPlayingId == note.id && _isPlaying,
        onPlayPause: () => _playPause(note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filters = _getFilters(l10n);
    return Consumer<NotesProvider>(
      builder: (context, notesProvider, child) {
        return Column(
          children: [
            GradientHeader(
              title: l10n.appTitle,
              searchBar: SearchBarWidget(
                onNoteSelected: (note) => _openNote(context, note),
              ),
              isGridView: notesProvider.isGridView,
              onViewToggle: () => notesProvider.toggleGridView(),
              onFilterTap: () => showFilterBottomSheet(context),
              hasActiveFilters: notesProvider.hasActiveFilters,
            ),
            // Filter Tabs
            if (!notesProvider.isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filters.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedFilterIndex == index;
                      final isPressed = _pressedFilterIndex == index;
                      final grad = AppTheme.accentGradient(notesProvider.themeColorIndex);
                      return GestureDetector(
                        onTapDown: (_) => setState(() => _pressedFilterIndex = index),
                        onTapUp: (_) {
                          setState(() {
                            _pressedFilterIndex = -1;
                            if (_selectedFilterIndex != index) {
                              _selectedFilterIndex = index;
                              _filterVersion++;
                              _visibleCount = _pageSize;
                            }
                          });
                        },
                        onTapCancel: () => setState(() => _pressedFilterIndex = -1),
                        child: AnimatedScale(
                          scale: isPressed ? 0.92 : 1.0,
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeOut,
                          child: AnimatedOpacity(
                            opacity: isSelected ? 1.0 : 0.55,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [grad[0], grad[1]]),
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 2.0)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: grad[0].withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(_filterIcons[index], size: 16, color: Colors.white),
                                  const SizedBox(width: 6),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                    child: Text(filters[index]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Note list — takes remaining space and scrolls independently
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(_filterVersion),
                child: _buildContent(context, notesProvider),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stagger(Widget child, int index) => _StaggerItem(
        key: ValueKey('stagger_${_filterVersion}_$index'),
        index: index,
        child: child,
      );

  Widget _buildPaginationFooter(int total, int showing) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      child: Center(
        child: Text(
          'Showing $showing of $total notes',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.getTextSecondaryColor(context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, NotesProvider notesProvider) {
    if (notesProvider.isLoading) {
      return HomeShimmerLayout(isGridView: notesProvider.isGridView);
    }

    List<Note> notes;
    switch (_selectedFilterIndex) {
      case 1: notes = notesProvider.pinnedNotesList; break;
      case 2: notes = notesProvider.voiceNotesList; break;
      case 3: notes = notesProvider.favoriteNotesList; break;
      case 4: notes = notesProvider.lockedNotesList; break;
      default: notes = notesProvider.allNotes;
    }
    if (_selectedFilterIndex != 0) {
      notes = notesProvider.applyFilters(notes);
    } else {
      // For "All Notes", preserve drag-and-drop order but still float pinned notes to top
      notes = notes.toList();
      notes.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return 0;
      });
    }
    _allCurrentNotes = notes;

    if (notes.isEmpty) return _EmptyState();

    final visibleNotes = notes.take(_visibleCount).toList();
    final hasMore = _visibleCount < notes.length;

    // Grid view
    if (notesProvider.isGridView) {
      return Column(
        children: [
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12,
                mainAxisSpacing: 12, childAspectRatio: 0.85,
              ),
              itemCount: visibleNotes.length,
              itemBuilder: (context, index) {
                final note = visibleNotes[index];
                return _stagger(_GridNoteCard(
                  key: ValueKey(note.id),
                  note: note,
                  colorIndex: index % 2 == 0
                    ? (index ~/ 2) % AppTheme.noteCardColors.length
                    : ((index ~/ 2) + AppTheme.noteCardColors.length ~/ 2) % AppTheme.noteCardColors.length,
                  onTap: () async {
                    if (note.isLocked) {
                      final provider = context.read<NotesProvider>();
                      if (provider.appLockEnabled) {
                        final unlocked = await showModalBottomSheet<bool>(
                          context: context, isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => LockBottomSheet(biometricEnabled: provider.biometricEnabled),
                        );
                        if (unlocked != true) return;
                      }
                    }
                    if (!context.mounted) return;
                    if (note.type == NoteType.drawing) _showDrawingPreview(context, note);
                    else if (note.type == NoteType.photo) showPhotoPreviewModal(context, note);
                    else if (note.type == NoteType.checklist) showChecklistModal(context, note: note);
                    else if (note.type == NoteType.document) showDocumentNoteModal(context, note);
                    else if (note.type == NoteType.voice) _showVoiceNoteModal(context, note);
                    else showTextNoteModal(context, note: note);
                  },
                  onMenuTap: () => _showNoteOptionsMenu(context, note, notesProvider),
                ), index);
              },
            ),
          ),
          if (hasMore) _buildPaginationFooter(notes.length, visibleNotes.length),
        ],
      );
    }

    // Reorderable list (All filter, list view)
    if (_selectedFilterIndex == 0) {
      return ReorderableListView.builder(
        scrollController: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        buildDefaultDragHandles: true,
        onReorder: (oldIndex, newIndex) => notesProvider.reorderNotes(oldIndex, newIndex),
        proxyDecorator: (child, index, animation) => AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(animation.value);
            return Transform.scale(
              scale: lerpDouble(1.0, 1.03, t)!,
              child: Material(
                elevation: lerpDouble(0, 16, t)!,
                color: Colors.transparent,
                shadowColor: Colors.black38,
                borderRadius: BorderRadius.circular(16),
                child: child,
              ),
            );
          },
          child: child,
        ),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          final isVoicePlaying = note.type == NoteType.voice &&
              _currentlyPlayingId == note.id && _isPlaying;
          return KeyedSubtree(
            key: ValueKey(note.id),
            child: _NoteCard(
              note: note,
              colorIndex: index % 2 == 0
                    ? (index ~/ 2) % AppTheme.noteCardColors.length
                    : ((index ~/ 2) + AppTheme.noteCardColors.length ~/ 2) % AppTheme.noteCardColors.length,
              isPlaying: isVoicePlaying,
              isLoadingAudio: _loadingNoteId == note.id,
              reorderIndex: index,
              onPlayPause: note.type == NoteType.voice ? () => _playPause(note) : null,
              onDrawingEdit: note.type == NoteType.drawing
                  ? () => _showDrawingEditOptions(context, note, notesProvider) : null,
              onTap: () async {
                if (note.isLocked) {
                  final provider = context.read<NotesProvider>();
                  if (provider.appLockEnabled) {
                    final unlocked = await showModalBottomSheet<bool>(
                      context: context, isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => LockBottomSheet(biometricEnabled: provider.biometricEnabled),
                    );
                    if (unlocked != true) return;
                  }
                }
                if (!context.mounted) return;
                if (note.type == NoteType.drawing) _showDrawingPreview(context, note);
                else if (note.type == NoteType.photo) showPhotoPreviewModal(context, note);
                else if (note.type == NoteType.checklist) showChecklistModal(context, note: note);
                else if (note.type == NoteType.document) showDocumentNoteModal(context, note);
                else if (note.type == NoteType.voice) _showVoiceNoteModal(context, note);
                else showTextNoteModal(context, note: note);
              },
              onMenuTap: () => _showNoteOptionsMenu(context, note, notesProvider),
            ),
          );
        },
      );
    }

    // Filtered lists with pagination
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: visibleNotes.length,
            itemBuilder: (context, index) {
              final note = visibleNotes[index];
              final isVoicePlaying = note.type == NoteType.voice &&
                  _currentlyPlayingId == note.id && _isPlaying;
              return _stagger(_NoteCard(
                key: ValueKey(note.id),
                note: note,
                colorIndex: index % 2 == 0
                    ? (index ~/ 2) % AppTheme.noteCardColors.length
                    : ((index ~/ 2) + AppTheme.noteCardColors.length ~/ 2) % AppTheme.noteCardColors.length,
                isPlaying: isVoicePlaying,
                isLoadingAudio: _loadingNoteId == note.id,
                onPlayPause: note.type == NoteType.voice ? () => _playPause(note) : null,
                onDrawingEdit: note.type == NoteType.drawing
                    ? () => _showDrawingEditOptions(context, note, notesProvider) : null,
                onTap: () async {
                  if (note.isLocked) {
                    final provider = context.read<NotesProvider>();
                    if (provider.appLockEnabled) {
                      final unlocked = await showModalBottomSheet<bool>(
                        context: context, isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => LockBottomSheet(biometricEnabled: provider.biometricEnabled),
                      );
                      if (unlocked != true) return;
                    }
                  }
                  if (!context.mounted) return;
                  if (note.type == NoteType.drawing) _showDrawingPreview(context, note);
                  else if (note.type == NoteType.photo) showPhotoPreviewModal(context, note);
                  else if (note.type == NoteType.checklist) showChecklistModal(context, note: note);
                  else if (note.type == NoteType.document) showDocumentNoteModal(context, note);
                  else if (note.type == NoteType.voice) _showVoiceNoteModal(context, note);
                  else showTextNoteModal(context, note: note);
                },
                onMenuTap: () => _showNoteOptionsMenu(context, note, notesProvider),
              ), index);
            },
          ),
        ),
        if (hasMore) _buildPaginationFooter(notes.length, visibleNotes.length),
      ],
    );
  }


  void _showDrawingEditOptions(BuildContext context, Note note, NotesProvider notesProvider) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.getDividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              l10n.drawingOptions,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // View Drawing
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.visibility,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              title: Text(
                l10n.viewDrawing,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l10n.openFullScreen),
              onTap: () {
                Navigator.pop(context);
                _showDrawingPreview(context, note);
              },
            ),
            const SizedBox(height: 8),
            // Edit/Redraw
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
                  Icons.edit,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              title: Text(
                l10n.createNewDrawing,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l10n.openSketchPad),
              onTap: () {
                Navigator.pop(context);
                showDrawingScreen(context);
              },
            ),
            const SizedBox(height: 8),
            // Delete
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade600,
                  size: 22,
                ),
              ),
              title: Text(
                l10n.deleteDrawing,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
              subtitle: Text(l10n.removeDrawing),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, note, notesProvider);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _showNoteOptionsMenu(BuildContext context, Note note, NotesProvider notesProvider) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.getDividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: note.isPinned ? AppTheme.primaryPurple : null,
              ),
              title: Text(note.isPinned ? l10n.unpinAction : l10n.pinAction),
              onTap: () {
                final type = note.isPinned ? NotificationType.unpinned : NotificationType.pinned;
                notesProvider.togglePin(note.id);
                Navigator.pop(context);
                AnimatedNotification.show(context, type: type);
              },
            ),
            ListTile(
              leading: Icon(
                note.isFavorite ? Icons.star : Icons.star_outline,
                color: note.isFavorite ? Colors.amber : null,
              ),
              title: Text(note.isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites),
              onTap: () {
                final type = note.isFavorite ? NotificationType.unfavorite : NotificationType.favorite;
                notesProvider.toggleFavorite(note.id);
                Navigator.pop(context);
                AnimatedNotification.show(context, type: type);
              },
            ),
            ListTile(
              leading: Icon(
                note.isLocked ? Icons.lock : Icons.lock_outline,
                color: note.isLocked ? AppTheme.primaryPurple : null,
              ),
              title: Text(note.isLocked ? l10n.unlockAction : l10n.lockAction),
              onTap: () {
                final type = note.isLocked ? NotificationType.unlocked : NotificationType.locked;
                notesProvider.toggleLock(note.id);
                Navigator.pop(context);
                AnimatedNotification.show(context, type: type);
              },
            ),
            ListTile(
              leading: Icon(Icons.share_outlined, color: AppTheme.getIconColor(context)),
              title: Text(l10n.shareNote),
              onTap: () {
                Navigator.pop(context);
                ShareHelper.shareNote(context, note);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, note, notesProvider);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Note note, NotesProvider notesProvider) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteNote),
        content: Text(l10n.deleteNoteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              notesProvider.deleteNote(note.id);
              Navigator.pop(context);
              AnimatedNotification.show(context, type: NotificationType.deleted);
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDrawingPreview(BuildContext context, Note note) {
    if (note.imagePath == null) return;
    showDialog(
      context: context,
      builder: (context) => _DrawingPreviewDialog(note: note),
    );
  }
}

class _DrawingPreviewDialog extends StatefulWidget {
  final Note note;
  const _DrawingPreviewDialog({required this.note});

  @override
  State<_DrawingPreviewDialog> createState() => _DrawingPreviewDialogState();
}

class _DrawingPreviewDialogState extends State<_DrawingPreviewDialog> {
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
                    ? ImageHelper.buildImage(note.imagePath, fit: BoxFit.contain)
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

/// Tap animation: press to 0.96 → easeOutBack pop to ~1.02 → settle 1.0 → navigate
/// Total duration: 250ms. Navigation happens AFTER animation completes.
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    // 250ms total: 40% press-down, 60% easeOutBack pop (naturally overshoots ~1.02)
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.96)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.96, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
    ]).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _onTap() async {
    if (_animating) return;
    _animating = true;
    await _ctrl.forward();
    _ctrl.reset();
    _animating = false;
    if (mounted) widget.onTap(); // navigate after animation completes
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;
  final bool isPlaying;
  final bool isLoadingAudio;
  final VoidCallback? onPlayPause;
  final VoidCallback? onDrawingEdit;
  final int colorIndex;
  final int? reorderIndex;

  const _NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onMenuTap,
    required this.colorIndex,
    this.isPlaying = false,
    this.isLoadingAudio = false,
    this.onPlayPause,
    this.onDrawingEdit,
    this.reorderIndex,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('M/d/yyyy');
    final isDrawing = note.type == NoteType.drawing;
    final isVoice = note.type == NoteType.voice;
    final themeColorIndex = context.watch<NotesProvider>().themeColorIndex;
    final themeGrad = AppTheme.accentGradient(themeColorIndex);
    final cardHash = colorIndex;
    final cardAccent = AppTheme.noteCardAccentColors[cardHash];
    final cardTextPrimary = AppTheme.noteCardText(context);
    final cardTextSecondary = AppTheme.noteCardSubText(context);

    // Voice note card - same style as voice tab
    if (isVoice) {
      return _TapScale(
        onTap: onTap,
        child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.noteCardBg(context, cardHash),
          borderRadius: BorderRadius.circular(16),
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
            // Waveform thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 50,
                width: double.infinity,
                color: cardAccent,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildWaveformBars(),
                    const Positioned(
                      bottom: 6,
                      right: 10,
                      child: Icon(Icons.mic, color: Colors.white54, size: 14),
                    ),
                  ],
                ),
              ),
            ),
            // Play button row
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Play button
                  GestureDetector(
                    onTap: isLoadingAudio ? null : onPlayPause,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cardAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: isLoadingAudio
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Note info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: cardTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: cardTextSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateFormat.format(note.createdAt),
                              style: TextStyle(
                                fontSize: 13,
                                color: cardTextSecondary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.mic,
                              size: 14,
                              color: cardTextSecondary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Voice recording',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cardTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Drag handle + menu
                  Row(
                    children: [
                      Icon(Icons.drag_indicator, color: cardTextSecondary, size: 20),
                      IconButton(
                        icon: Icon(Icons.more_vert, color: cardTextSecondary),
                        onPressed: onMenuTap,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      );
    }

    // Document note card
    if (note.type == NoteType.document) {
      return _TapScale(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.noteCardBg(context, cardHash),
            borderRadius: BorderRadius.circular(16),
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
              // PDF thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  height: 50,
                  width: double.infinity,
                  color: AppTheme.isDarkMode(context)
                      ? cardAccent.withOpacity(0.7)
                      : cardAccent,
                  child: const Center(
                    child: Icon(Icons.picture_as_pdf, color: Colors.white, size: 26),
                  ),
                ),
              ),
              // Info row
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cardAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: cardTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 14, color: cardTextSecondary),
                              const SizedBox(width: 4),
                              Text(
                                dateFormat.format(note.createdAt),
                                style: TextStyle(
                                    fontSize: 13, color: cardTextSecondary),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.description,
                                  size: 14, color: cardTextSecondary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  note.content.isNotEmpty
                                      ? note.content
                                      : 'Scanned document',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13, color: cardTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.drag_indicator, color: cardTextSecondary, size: 20),
                        IconButton(
                          icon: Icon(Icons.more_vert, color: cardTextSecondary),
                          onPressed: onMenuTap,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Photo note card - shows image thumbnail
    if (note.type == NoteType.photo && note.imagePath != null) {
      return _TapScale(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(16),
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
              // Image thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 100,
                      width: double.infinity,
                      child: ImageHelper.imageExists(note.imagePath)
                          ? ImageHelper.buildImage(
                              note.imagePath,
                              fit: BoxFit.cover,
                              height: 100,
                            )
                          : Container(
                              color: AppTheme.getDividerColor(context),
                              child: Icon(
                                Icons.broken_image,
                                size: 50,
                                color: cardTextSecondary,
                              ),
                            ),
                    ),
                    // Photo badge
                    Positioned(
                      top: 12,
                      left: 12,
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
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Photo',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // OCR badge
                    if (note.ocrText != null)
                      Positioned(
                        bottom: 10,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.text_fields,
                                  size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'OCR',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Menu button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: onMenuTap,
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                            size: 20,
                          ),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Details section
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: cardTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: cardTextSecondary),
                              const SizedBox(width: 4),
                              Text(dateFormat.format(note.createdAt),
                                  style: TextStyle(fontSize: 13, color: cardTextSecondary)),
                              if (note.isPinned) ...[
                                const SizedBox(width: 12),
                                Icon(Icons.push_pin, size: 14, color: cardTextSecondary),
                              ],
                              if (note.isFavorite) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.drag_indicator, color: cardTextSecondary, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _TapScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDrawing
              ? AppTheme.getCardColor(context)
              : AppTheme.noteCardBg(context, cardHash),

          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.getDividerColor(context),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section with menu
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status icons and type indicator
                  Row(
                    children: [
                      if (isDrawing)
                        GestureDetector(
                          onTap: onDrawingEdit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.brush,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Drawing',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.edit,
                                  size: 12,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (note.type == NoteType.voice) ...[
                        // Play/Pause button for voice notes
                        if (onPlayPause != null)
                          GestureDetector(
                            onTap: isLoadingAudio ? null : onPlayPause,
                            child: Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isPlaying
                                      ? [AppTheme.primaryMagenta, AppTheme.primaryPurple]
                                      : [const Color(0xFF22C55E), const Color(0xFF10B981)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: isLoadingAudio
                                  ? const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Icon(
                                      isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.mic,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Voice',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Text note badge
                      if (note.type == NoteType.text)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.description,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Text',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Checklist note badge
                      if (note.type == NoteType.checklist)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.checklist,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Checklist',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (note.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.push_pin,
                            size: 16,
                            color: cardTextSecondary,
                          ),
                        ),
                      if (note.isFavorite)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber.shade600,
                          ),
                        ),
                      if (note.isLocked)
                        Icon(
                          Icons.lock,
                          size: 16,
                          color: cardTextSecondary,
                        ),
                      if (note.reminderDateTime != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.notifications_active,
                          size: 16,
                          color: Colors.orange.shade400,
                        ),
                      ],
                    ],
                  ),
                  // Drag handle and Menu button
                  Row(
                    children: [
                      // Drag handle
                      Icon(
                          Icons.drag_indicator,
                          color: cardTextSecondary,
                          size: 20,
                        ),
                      const SizedBox(width: 4),
                      // Menu button
                      IconButton(
                        onPressed: onMenuTap,
                        icon: Icon(
                          Icons.more_vert,
                          color: cardTextSecondary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Drawing thumbnail
            if (isDrawing && note.imagePath != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 65,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _buildDrawingThumbnail(note.imagePath!),
                  ),
                ),
              ),
            ],

            // Text preview
            if (note.type == NoteType.text && note.content.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                child: Text(
                  note.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ),
            ],

            // Checklist preview
            if (note.type == NoteType.checklist &&
                (note.checklistItems?.isNotEmpty ?? false)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: note.checklistItems!.take(2).map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Icon(
                            item.isChecked
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 13,
                            color: item.isChecked
                                ? Colors.green.shade600
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.text,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                decoration: item.isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Content section
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    note.title.isNotEmpty ? note.title : 'Untitled Note',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: cardTextPrimary,
                    ),
                  ),

                  // Tags
                  if (note.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: note.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryPurple,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Bottom row with type indicator and date
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Type indicator
                      Row(
                        children: [
                          Icon(
                            isDrawing ? Icons.brush : Icons.language,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isDrawing ? 'Sketch' : 'EN',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      // Date
                      Text(
                        dateFormat.format(note.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<double> _waveHeights = [
    18.0, 30.0, 22.0, 42.0, 28.0, 48.0, 20.0, 38.0, 24.0, 32.0, 44.0, 28.0, 18.0, 36.0, 24.0
  ];

  Widget _buildWaveformBars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: _waveHeights.map((h) {
        return Container(
          width: 4,
          height: h,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDrawingThumbnail(String imagePath) {
    if (ImageHelper.imageExists(imagePath)) {
      return ImageHelper.buildImage(
        imagePath,
        fit: BoxFit.cover,
        placeholder: _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.brush,
            size: 40,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'Drawing',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: accentColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Create Your First Note',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _QuickActionChip(
                icon: Icons.note_alt_outlined,
                label: 'Text',
                color: accentColor,
                filled: false,
              ),
              const SizedBox(width: 12),
              _QuickActionChip(
                icon: Icons.mic,
                label: 'Voice',
                color: accentColor,
                filled: true,
              ),
              const SizedBox(width: 12),
              _QuickActionChip(
                icon: Icons.brush,
                label: 'Draw',
                color: accentColor,
                filled: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: filled ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: filled ? Colors.white : color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridNoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;
  final int colorIndex;

  const _GridNoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onMenuTap,
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

  static const List<double> _waveHeights = [
    18.0, 26.0, 20.0, 36.0, 24.0, 40.0, 18.0, 32.0, 22.0, 28.0, 38.0, 24.0, 16.0, 30.0, 20.0
  ];

  Widget _buildWaveformBars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: _waveHeights.map((h) {
        return Container(
          width: 3,
          height: h,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGridThumbnail(BuildContext context) {
    final cardHash = colorIndex;
    final cardAccent = AppTheme.noteCardAccentColors[cardHash];
    final cardTextSecondary = AppTheme.noteCardSubText(context);
    switch (note.type) {
      case NoteType.photo:
      case NoteType.drawing:
        return SizedBox(
          height: 90,
          width: double.infinity,
          child: note.imagePath != null && ImageHelper.imageExists(note.imagePath)
              ? ImageHelper.buildImage(note.imagePath, fit: BoxFit.cover, height: 90)
              : Container(
                  color: AppTheme.getSurfaceColor(context),
                  child: Icon(
                    note.type == NoteType.photo ? Icons.photo_camera : Icons.brush,
                    size: 36,
                    color: cardTextSecondary,
                  ),
                ),
        );
      case NoteType.voice:
        return Container(
          height: 90,
          width: double.infinity,
          color: cardAccent,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildWaveformBars(),
              const Positioned(
                bottom: 8,
                right: 10,
                child: Icon(Icons.mic, color: Colors.white54, size: 16),
              ),
            ],
          ),
        );
      case NoteType.text:
        return Container(
          height: 90,
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          color: AppTheme.noteCardBg(context, cardHash),
          child: note.content.isNotEmpty
              ? Text(
                  note.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: cardTextSecondary,
                    height: 1.3,
                  ),
                )
              : Icon(Icons.description, size: 36, color: cardTextSecondary),
        );
      case NoteType.checklist:
        final items = note.checklistItems?.take(3).toList() ?? [];
        return Container(
          height: 90,
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: AppTheme.noteCardBg(context, cardHash),
          child: items.isEmpty
              ? Icon(Icons.checklist, size: 36, color: Colors.amber.shade300)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            item.isChecked
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 13,
                            color: item.isChecked
                                ? Colors.green.shade400
                                : cardTextSecondary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.text,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: cardTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        );
      case NoteType.document:
        return Container(
          height: 90,
          width: double.infinity,
          color: cardAccent,
          child: const Center(
            child: Icon(Icons.picture_as_pdf, color: Colors.white, size: 44),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('M/d');
    final cardHash = colorIndex;
    final cardTextPrimary = AppTheme.noteCardText(context);
    final cardTextSecondary = AppTheme.noteCardSubText(context);
    return _TapScale(
      onTap: onTap,
      child: Container(
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
            // Thumbnail at the top
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: _buildGridThumbnail(context),
            ),

            // Header with type badge and menu
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: _getNoteTypeGradient()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getNoteTypeIcon(),
                          size: 12,
                          color: Colors.white,
                        ),
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
                  // Menu button
                  GestureDetector(
                    onTap: onMenuTap,
                    child: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: cardTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Content area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Text(
                  note.title.isNotEmpty ? note.title : 'Untitled',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: cardTextPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Bottom row with status icons and date
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status icons
                  Row(
                    children: [
                      if (note.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.push_pin,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      if (note.isFavorite)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber.shade600,
                          ),
                        ),
                      if (note.isLocked)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.lock,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      if (note.reminderDateTime != null)
                        Icon(
                          Icons.notifications_active,
                          size: 14,
                          color: Colors.orange.shade400,
                        ),
                    ],
                  ),
                  // Date
                  Text(
                    dateFormat.format(note.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: cardTextSecondary,
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

class _VoiceNoteDetailSheet extends StatefulWidget {
  final Note note;
  final AudioPlayer audioPlayer;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  const _VoiceNoteDetailSheet({
    required this.note,
    required this.audioPlayer,
    required this.isPlaying,
    required this.onPlayPause,
  });

  @override
  State<_VoiceNoteDetailSheet> createState() => _VoiceNoteDetailSheetState();
}

class _VoiceNoteDetailSheetState extends State<_VoiceNoteDetailSheet> {
  late bool _isPlaying;
  DateTime? _reminderDateTime;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.isPlaying;
    _reminderDateTime = widget.note.reminderDateTime;
    widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    widget.audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
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
    final newReminder = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _reminderDateTime = newReminder);
    final notesProvider = context.read<NotesProvider>();
    final updated = widget.note.copyWith(reminderDateTime: newReminder, updatedAt: DateTime.now());
    await notesProvider.updateNote(updated);
  }

  Future<void> _removeReminder() async {
    setState(() => _reminderDateTime = null);
    final notesProvider = context.read<NotesProvider>();
    final updated = widget.note.copyWith(clearReminder: true, updatedAt: DateTime.now());
    await notesProvider.updateNote(updated);
  }

  String _parseDuration(String content) {
    final lines = content.split('\n');
    if (lines.isNotEmpty && lines[0].startsWith('Duration:')) {
      return lines[0].replaceFirst('Duration: ', '');
    }
    return '';
  }

  static const List<double> _waveHeights = [
    18.0, 30.0, 22.0, 42.0, 28.0, 48.0, 20.0, 38.0, 24.0, 32.0,
    44.0, 28.0, 18.0, 36.0, 24.0, 20.0, 34.0, 26.0, 40.0, 22.0,
  ];

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final duration = _parseDuration(note.content);
    final dateFormat = DateFormat('MMMM d, yyyy');
    final colorIndex = context.watch<NotesProvider>().themeColorIndex;
    final themeGrad = AppTheme.accentGradient(colorIndex);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.getDividerColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Waveform
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [themeGrad[0], themeGrad[1]],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: _waveHeights.map((h) {
                return Container(
                  width: 4,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          // Title
          Text(
            note.title.isNotEmpty ? note.title : 'Voice Note',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Date & duration
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today, size: 14, color: AppTheme.getTextSecondaryColor(context)),
              const SizedBox(width: 4),
              Text(
                dateFormat.format(note.createdAt),
                style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondaryColor(context)),
              ),
              if (duration.isNotEmpty) ...[
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 14, color: AppTheme.getTextSecondaryColor(context)),
                const SizedBox(width: 4),
                Text(
                  duration,
                  style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondaryColor(context)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          // Play/Pause button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPlayPause,
              borderRadius: BorderRadius.circular(36),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isPlaying
                        ? [themeGrad[1], themeGrad[0]]
                        : [themeGrad[0], themeGrad[1]],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: themeGrad[0].withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isPlaying ? 'Playing...' : 'Tap to play',
            style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondaryColor(context)),
          ),
          const SizedBox(height: 20),
          // Reminder row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_outlined, size: 16, color: AppTheme.getTextSecondaryColor(context)),
              const SizedBox(width: 8),
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
        ],
      ),
    );
  }
}

class _StaggerItem extends StatefulWidget {
  final Widget child;
  final int index;

  const _StaggerItem({super.key, required this.child, required this.index});

  @override
  State<_StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<_StaggerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    // Stagger: each note starts 50ms after the previous
    final delay = Duration(milliseconds: widget.index * 50);
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _fade, child: widget.child);
}
