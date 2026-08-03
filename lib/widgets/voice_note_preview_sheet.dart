import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../utils/storage_helper.dart';

/// Self-contained voice-note preview — owns its own [AudioPlayer] rather
/// than sharing one with a parent screen's inline-list playback, so it can
/// be dropped into any screen without coordinating "currently playing" state.
void showVoiceNotePreview(BuildContext context, Note note) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => VoiceNotePreviewSheet(note: note),
  );
}

class VoiceNotePreviewSheet extends StatefulWidget {
  final Note note;
  const VoiceNotePreviewSheet({super.key, required this.note});

  @override
  State<VoiceNotePreviewSheet> createState() => _VoiceNotePreviewSheetState();
}

class _VoiceNotePreviewSheetState extends State<VoiceNotePreviewSheet> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  DateTime? _reminderDateTime;

  @override
  void initState() {
    super.initState();
    _reminderDateTime = widget.note.reminderDateTime;
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      return;
    }
    if (_audioPlayer.state == PlayerState.paused) {
      await _audioPlayer.resume();
      return;
    }
    final path = widget.note.voicePath;
    if (path == null) return;
    setState(() => _isLoading = true);
    try {
      String playPath = path;
      if (StorageHelper.isUrl(path)) {
        final dir = await getTemporaryDirectory();
        final tempFile = File('${dir.path}/voice_${widget.note.id}.m4a');
        if (!tempFile.existsSync()) {
          final response = await http.get(Uri.parse(path));
          await tempFile.writeAsBytes(response.bodyBytes);
        }
        playPath = tempFile.path;
      }
      await _audioPlayer.play(DeviceFileSource(playPath));
    } catch (e) {
      debugPrint('VoiceNotePreviewSheet: error playing voice note: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.getDividerColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [themeGrad[0], themeGrad[1]]),
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _playPause,
              borderRadius: BorderRadius.circular(36),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isPlaying ? [themeGrad[1], themeGrad[0]] : [themeGrad[0], themeGrad[1]],
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
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(22),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isLoading ? 'Loading...' : (_isPlaying ? 'Playing...' : 'Tap to play'),
            style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondaryColor(context)),
          ),
          const SizedBox(height: 20),
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
