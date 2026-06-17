import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_header.dart';
import '../widgets/voice_recording_modal.dart';
import '../utils/storage_helper.dart';
import '../utils/share_helper.dart';
import '../l10n/app_localizations.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  bool _isPlaying = false;
  String? _loadingNoteId;

  static const int _pageSize = 20;
  int _visibleCount = 20;
  int _totalCount = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _currentlyPlayingId = null;
        _isPlaying = false;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _playPause(Note note) async {
    if (_loadingNoteId != null) return; // prevent double-tap during load
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
        await _audioPlayer.stop();
        setState(() {
          _loadingNoteId = note.id;
          _currentlyPlayingId = note.id;
          _isPlaying = false;
        });
        try {
          if (StorageHelper.isUrl(note.voicePath)) {
            await _audioPlayer.play(UrlSource(note.voicePath!));
          } else {
            await _audioPlayer.play(DeviceFileSource(note.voicePath!));
          }
        } finally {
          if (mounted) {
            setState(() {
              _loadingNoteId = null;
              _isPlaying = true;
            });
          }
        }
      }
    }
  }

  void _startRecording() async {
    final result = await showVoiceRecordingModal(context);
    if (result == true) {
      // Recording was saved
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(
      builder: (context, notesProvider, child) {
        final voiceNotes = notesProvider.voiceNotesList;
        final themeGrad = AppTheme.accentGradient(notesProvider.themeColorIndex);

        final l10n = AppLocalizations.of(context);
        return Column(
          children: [
            GradientHeader(
              title: l10n.voiceNotesTitle,
              subtitle: l10n.voiceRecordingsCount(voiceNotes.length),
              searchBar: const SearchBarWidget(),
              showFilter: false,
            ),
            Expanded(
              child: voiceNotes.isEmpty
                  ? _EmptyVoiceState(onStartRecording: _startRecording)
                  : Builder(builder: (context) {
                      _totalCount = voiceNotes.length;
                      final visibleNotes =
                          voiceNotes.take(_visibleCount).toList();
                      final hasMore = _visibleCount < voiceNotes.length;
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: visibleNotes.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == visibleNotes.length) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Showing $index of ${voiceNotes.length} recordings',
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
                          final isPlaying =
                              _currentlyPlayingId == note.id && _isPlaying;
                          final isLoading = _loadingNoteId == note.id;
                          return _VoiceNoteCard(
                            note: note,
                            isPlaying: isPlaying,
                            isLoading: isLoading,
                            onPlayPause: () => _playPause(note),
                            onDelete: () =>
                                _showDeleteConfirmation(note, notesProvider),
                            onShare: () => ShareHelper.shareNote(context, note),
                          );
                        },
                      );
                    }),
            ),
            // Floating record button when there are notes
            if (voiceNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: _startRecording,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [themeGrad[0], themeGrad[1]],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: themeGrad[0].withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mic, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.newRecording,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(Note note, NotesProvider notesProvider) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteVoiceNote),
        content: Text(l10n.deleteVoiceConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              notesProvider.deleteNote(note.id);
              Navigator.pop(context);
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _VoiceNoteCard extends StatelessWidget {
  final Note note;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlayPause;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _VoiceNoteCard({
    required this.note,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlayPause,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('M/d/yyyy');
    final colorIndex = context.watch<NotesProvider>().themeColorIndex;
    final themeGrad = AppTheme.accentGradient(colorIndex);

    return GestureDetector(
      onTap: onPlayPause,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          // Play/pause/loading button
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPlaying
                    ? [themeGrad[1], themeGrad[0]]
                    : [themeGrad[0], themeGrad[1]],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 16),
          // Note info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(note.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.getTextSecondaryColor(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.mic,
                      size: 14,
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        AppLocalizations.of(context).voiceRecordingLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Menu button — stop tap from bubbling to card
          GestureDetector(
            onTap: () {}, // absorb tap so card doesn't trigger play
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppTheme.getIconColor(context)),
              onSelected: (value) {
                if (value == 'share') {
                  onShare();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 20, color: AppTheme.getIconColor(context)),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).shareNote),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).delete, style: const TextStyle(color: Colors.red)),
                    ],
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

class _EmptyVoiceState extends StatelessWidget {
  final VoidCallback onStartRecording;

  const _EmptyVoiceState({required this.onStartRecording});

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none,
            size: 80,
            color: accentColor.withOpacity(0.7),
          ),
          const SizedBox(height: 24),
          Text(
            'No Voice Notes Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start recording your thoughts with voice',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.getTextSecondaryColor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onStartRecording,
            child: Container(
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'Start Recording',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
