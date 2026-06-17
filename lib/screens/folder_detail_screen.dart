import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_notification.dart';
import '../widgets/photo_preview_modal.dart';
import 'text_note_screen.dart';
import 'drawing_screen.dart';
import '../utils/storage_helper.dart';
import '../utils/image_helper.dart';
import '../utils/share_helper.dart';
import '../l10n/app_localizations.dart';

class FolderDetailScreen extends StatefulWidget {
  final Folder folder;

  const FolderDetailScreen({super.key, required this.folder});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  bool _isPlaying = false;

  static const int _pageSize = 20;
  int _visibleCount = 20;
  int _totalCount = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _currentlyPlayingId = null;
        _isPlaying = false;
      });
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        if (_visibleCount < _totalCount && mounted) {
          setState(() {
            _visibleCount =
                (_visibleCount + _pageSize).clamp(0, _totalCount);
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
        // Use UrlSource for Firebase URLs, DeviceFileSource for local files
        if (StorageHelper.isUrl(note.voicePath)) {
          await _audioPlayer.play(UrlSource(note.voicePath!));
        } else {
          await _audioPlayer.play(DeviceFileSource(note.voicePath!));
        }
        setState(() {
          _currentlyPlayingId = note.id;
          _isPlaying = true;
        });
      }
    }
  }

  void _showDrawingEditOptions(BuildContext context, Note note) {
    final l10n = AppLocalizations.of(context);
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
            Text(
              l10n.drawingOptions,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
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
                l10n.editDrawing,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l10n.continueEditingDrawing),
              onTap: () {
                Navigator.pop(context);
                showDrawingScreen(context);
              },
            ),
            const SizedBox(height: 8),
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
                  Icons.brush,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              title: Text(
                l10n.createNewDrawing,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l10n.startFreshCanvas),
              onTap: () {
                Navigator.pop(context);
                showDrawingScreen(context);
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Consumer<NotesProvider>(
        builder: (context, notesProvider, child) {
          final notes = notesProvider.getNotesByFolder(widget.folder.id);

          return Column(
            children: [
              // Custom Header
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  right: 16,
                  bottom: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppTheme.isDarkMode(context)
                        ? [
                            Color.alphaBlend(
                                Colors.black.withOpacity(0.45), widget.folder.color),
                            Color.alphaBlend(
                                Colors.black.withOpacity(0.55), widget.folder.color),
                          ]
                        : [
                            widget.folder.color,
                            widget.folder.color.withOpacity(0.8),
                          ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            widget.folder.icon,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.folder.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.notesCount(notes.length),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Notes List
              Expanded(
                child: notes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.folder.icon,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.noNotesInFolder,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Builder(builder: (context) {
                        _totalCount = notes.length;
                        final visibleNotes =
                            notes.take(_visibleCount).toList();
                        final hasMore = _visibleCount < notes.length;
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: visibleNotes.length + (hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == visibleNotes.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Text(
                                    'Showing $index of ${notes.length} notes',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.getTextSecondaryColor(
                                          context),
                                    ),
                                  ),
                                ),
                              );
                            }
                            final note = visibleNotes[index];
                            final cardHash =
                                index % AppTheme.noteCardColors.length;
                            return _buildNoteCard(
                                context, note, notesProvider, cardHash);
                          },
                        );
                      }),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, Note note, NotesProvider notesProvider, int cardHash) {
    final dateFormat = DateFormat('MMM d, yyyy');

    switch (note.type) {
      case NoteType.voice:
        return _buildVoiceNoteCard(context, note, notesProvider, dateFormat, cardHash);
      case NoteType.photo:
        return _buildPhotoNoteCard(context, note, notesProvider, dateFormat, cardHash);
      case NoteType.drawing:
        return _buildDrawingNoteCard(context, note, notesProvider, dateFormat, cardHash);
      default:
        return _buildTextNoteCard(context, note, notesProvider, dateFormat, cardHash);
    }
  }

  Widget _buildTextNoteCard(BuildContext context, Note note, NotesProvider notesProvider, DateFormat dateFormat, int cardHash) {
    final cardTextPrimary = AppTheme.noteCardText(context);
    final cardTextSecondary = AppTheme.noteCardSubText(context);
    return GestureDetector(
      onTap: () => showTextNoteModal(context, note: note),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.noteCardBg(context, cardHash),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.text_fields, size: 14, color: AppTheme.primaryPurple),
                      SizedBox(width: 4),
                      Text(
                        'Text',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (note.isFavorite)
                  Icon(Icons.star, size: 18, color: Colors.amber.shade600),
                if (note.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.push_pin, size: 18, color: cardTextSecondary),
                  ),
                _buildPopupMenu(context, note, notesProvider),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              note.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cardTextPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (note.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                note.content,
                style: TextStyle(
                  fontSize: 14,
                  color: cardTextSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              dateFormat.format(note.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: cardTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceNoteCard(BuildContext context, Note note, NotesProvider notesProvider, DateFormat dateFormat, int cardHash) {
    final isCurrentlyPlaying = _currentlyPlayingId == note.id && _isPlaying;
    final cardAccent = AppTheme.noteCardAccentColors[cardHash];
    final cardTextPrimary = AppTheme.noteCardText(context);
    final cardTextSecondary = AppTheme.noteCardSubText(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.noteCardBg(context, cardHash),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Voice',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (note.isFavorite)
                Icon(Icons.star, size: 18, color: Colors.amber.shade600),
              if (note.isPinned)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.push_pin, size: 18, color: cardTextSecondary),
                ),
              _buildPopupMenu(context, note, notesProvider),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () => _playPause(note),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cardAccent,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: cardAccent.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: TextStyle(
                        fontSize: 16,
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
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Voice recording',
                            style: TextStyle(
                              fontSize: 12,
                              color: cardTextSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoNoteCard(BuildContext context, Note note, NotesProvider notesProvider, DateFormat dateFormat, int cardHash) {
    final cardTextPrimary = AppTheme.noteCardText(context);
    final cardTextSecondary = AppTheme.noteCardSubText(context);
    return GestureDetector(
      onTap: () => showPhotoPreviewModal(context, note),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.noteCardBg(context, cardHash),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: ImageHelper.imageExists(note.imagePath)
                  ? ImageHelper.buildImage(
                      note.imagePath,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.broken_image,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_camera, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Photo',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (note.isFavorite)
                        Icon(Icons.star, size: 18, color: Colors.amber.shade600),
                      if (note.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.push_pin, size: 18, color: cardTextSecondary),
                        ),
                      _buildPopupMenu(context, note, notesProvider),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cardTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(note.createdAt),
                    style: TextStyle(
                      fontSize: 12,
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

  Widget _buildDrawingNoteCard(BuildContext context, Note note, NotesProvider notesProvider, DateFormat dateFormat, int cardHash) {
    final cardTextPrimary = AppTheme.noteCardText(context);
    final cardTextSecondary = AppTheme.noteCardSubText(context);
    return GestureDetector(
      onTap: () => showDrawingScreen(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.noteCardBg(context, cardHash),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: ImageHelper.imageExists(note.imagePath)
                  ? ImageHelper.buildImage(
                      note.imagePath,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      child: Icon(
                        Icons.brush,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showDrawingEditOptions(context, note),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.brush, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Drawing',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.edit, size: 12, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (note.isFavorite)
                        Icon(Icons.star, size: 18, color: Colors.amber.shade600),
                      if (note.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.push_pin, size: 18, color: cardTextSecondary),
                        ),
                      _buildPopupMenu(context, note, notesProvider),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cardTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(note.createdAt),
                    style: TextStyle(
                      fontSize: 12,
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

  Widget _buildPopupMenu(BuildContext context, Note note, NotesProvider notesProvider) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey.shade600, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'pin':
            notesProvider.togglePin(note.id);
            AnimatedNotification.show(
              context,
              type: note.isPinned ? NotificationType.unpinned : NotificationType.pinned,
            );
            break;
          case 'favorite':
            notesProvider.toggleFavorite(note.id);
            AnimatedNotification.show(
              context,
              type: note.isFavorite ? NotificationType.unfavorite : NotificationType.favorite,
            );
            break;
          case 'lock':
            notesProvider.toggleLock(note.id);
            AnimatedNotification.show(
              context,
              type: note.isLocked ? NotificationType.unlocked : NotificationType.locked,
            );
            break;
          case 'share':
            ShareHelper.shareNote(context, note);
            break;
          case 'delete':
            _showDeleteConfirmation(context, note, notesProvider);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(
                note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 20,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 12),
              Text(note.isPinned ? l10n.unpinAction : l10n.pinAction),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'favorite',
          child: Row(
            children: [
              Icon(
                note.isFavorite ? Icons.star : Icons.star_outline,
                size: 20,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 12),
              Text(note.isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'lock',
          child: Row(
            children: [
              Icon(
                note.isLocked ? Icons.lock_open : Icons.lock_outline,
                size: 20,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 12),
              Text(note.isLocked ? l10n.unlockAction : l10n.lockAction),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share_outlined, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Text(l10n.shareNote),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
              const SizedBox(width: 12),
              Text(l10n.delete, style: TextStyle(color: Colors.red.shade400)),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context, Note note, NotesProvider notesProvider) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.deleteNote),
        content: Text(l10n.deleteNoteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              notesProvider.deleteNote(note.id);
              AnimatedNotification.show(context, type: NotificationType.deleted);
            },
            child: Text(l10n.delete, style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
  }
}
