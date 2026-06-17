import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../utils/storage_helper.dart';
import '../utils/file_helper.dart' as file_helper;
import '../l10n/app_localizations.dart';

class VoiceRecordingModal extends StatefulWidget {
  const VoiceRecordingModal({super.key});

  @override
  State<VoiceRecordingModal> createState() => _VoiceRecordingModalState();
}

class _VoiceRecordingModalState extends State<VoiceRecordingModal> {
  final AudioRecorder _recorder = AudioRecorder();

  RecordingState _state = RecordingState.ready;
  String? _recordingPath;
  int _recordingDuration = 0;
  Timer? _timer;
  String _selectedLanguage = 'English';
  String? _selectedFolderId;

  bool _isSaving = false;

  // Simulated waveform data
  List<double> _waveformData = List.generate(25, (i) => 0.3);

  // Folders that users can assign notes to
  static final List<Folder> _assignableFolders = Folder.defaultFolders
      .where((f) => ['work', 'personal', 'ideas'].contains(f.id))
      .toList();

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'es', 'name': 'Spanish', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'French', 'flag': '🇫🇷'},
    {'code': 'de', 'name': 'German', 'flag': '🇩🇪'},
    {'code': 'it', 'name': 'Italian', 'flag': '🇮🇹'},
    {'code': 'pt', 'name': 'Portuguese', 'flag': '🇵🇹'},
    {'code': 'zh', 'name': 'Chinese', 'flag': '🇨🇳'},
    {'code': 'ja', 'name': 'Japanese', 'flag': '🇯🇵'},
    {'code': 'ko', 'name': 'Korean', 'flag': '🇰🇷'},
    {'code': 'ar', 'name': 'Arabic', 'flag': '🇸🇦'},
    {'code': 'hi', 'name': 'Hindi', 'flag': '🇮🇳'},
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String get _formattedDuration {
    final minutes = (_recordingDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingDuration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _getStatusText(AppLocalizations l10n) {
    switch (_state) {
      case RecordingState.ready:
        return l10n.recordingReady;
      case RecordingState.recording:
        return l10n.recordingActive;
      case RecordingState.paused:
        return l10n.recordingPaused;
      case RecordingState.stopped:
        return l10n.recordingComplete;
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final fileName = 'voice_note_${const Uuid().v4()}';

        if (kIsWeb) {
          // On web, record to blob URL (webm format)
          await _recorder.start(
            const RecordConfig(
              encoder: AudioEncoder.opus,
              bitRate: 128000,
              sampleRate: 44100,
            ),
            path: '', // Empty path for web blob recording
          );
          _recordingPath = fileName; // Store just the filename for later use
        } else {
          // On native, record to local file
          final directory = await getApplicationDocumentsDirectory();
          _recordingPath = '${directory.path}/$fileName.m4a';

          await _recorder.start(
            const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 128000,
              sampleRate: 44100,
            ),
            path: _recordingPath!,
          );
        }

        setState(() {
          _state = RecordingState.recording;
          _recordingDuration = 0;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration++;
            // Simulate waveform animation
            _waveformData = List.generate(25, (i) =>
              0.2 + (0.8 * (i % 3 == 0 ? 0.9 : (i % 2 == 0 ? 0.5 : 0.3)))
            );
          });
        });
      } else {
        _showPermissionDeniedDialog();
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      _timer?.cancel();
      final path = await _recorder.stop();

      if (kIsWeb && path != null) {
        // On web, path is a blob URL - we need to upload to Firebase
        setState(() {
          _state = RecordingState.stopped;
          _webBlobUrl = path;
        });
      } else {
        setState(() {
          _state = RecordingState.stopped;
          _recordingPath = path;
        });
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  String? _webBlobUrl;

  Future<void> _saveRecording() async {
    if (_recordingPath == null && _webBlobUrl == null) return;
    setState(() => _isSaving = true);

    String? finalVoicePath;

    if (kIsWeb && _webBlobUrl != null) {
      try {
        // Fetch blob URL and upload to Firebase Storage
        final response = await http.get(Uri.parse(_webBlobUrl!));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final fileName = 'voice_notes/${_recordingPath ?? const Uuid().v4()}.webm';
          finalVoicePath = await StorageHelper.uploadToFirebase(
            Uint8List.fromList(bytes),
            fileName,
            'audio/webm',
          );
        }
      } catch (e) {
        debugPrint('Error uploading voice note: $e');
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving recording: $e')),
          );
        }
        return;
      }
    } else if (_recordingPath != null) {
      try {
        // On native, upload to Firebase Storage for cross-device sync
        final bytes = await file_helper.getFileBytes(_recordingPath!);
        if (bytes != null) {
          final fileName = 'voice_notes/${const Uuid().v4()}.m4a';
          finalVoicePath = await StorageHelper.uploadToFirebase(
            bytes,
            fileName,
            'audio/mp4',
          );
        } else {
          finalVoicePath = _recordingPath;
        }
      } catch (e) {
        debugPrint('Error uploading voice note to Firebase: $e');
        // Fall back to local path if upload fails
        finalVoicePath = _recordingPath;
      }
    }

    if (finalVoicePath == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    final notesProvider = context.read<NotesProvider>();
    final now = DateTime.now();

    final note = Note(
      id: const Uuid().v4(),
      title: 'Voice Note ${now.day}/${now.month}/${now.year}',
      content: 'Duration: $_formattedDuration\nLanguage: $_selectedLanguage',
      type: NoteType.voice,
      createdAt: now,
      updatedAt: now,
      voicePath: finalVoicePath,
      folderId: _selectedFolderId,
    );

    await notesProvider.addNote(note);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget _buildFolderChip({
    required String name,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppTheme.getDividerColor(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : AppTheme.getIconColor(context)),
            const SizedBox(width: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : AppTheme.getTextSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.micPermissionTitle),
        content: Text(l10n.micPermissionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.getDividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context).languageSelect,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  final isSelected = lang['name'] == _selectedLanguage;
                  return ListTile(
                    leading: Text(
                      lang['flag']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(lang['name']!),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppTheme.primaryPurple)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedLanguage = lang['name']!;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
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
    final colorIndex = context.watch<NotesProvider>().themeColorIndex;
    final themeGrad = AppTheme.accentGradient(colorIndex);
    final accentColor = AppTheme.accentColor(colorIndex);
    final currentLang = _languages.firstWhere(
      (l) => l['name'] == _selectedLanguage,
      orElse: () => _languages.first,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                // Mic icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTheme.fabGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Title and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.typeVoiceNote,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.getTextPrimaryColor(context),
                        ),
                      ),
                      Text(
                        _getStatusText(l10n),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // Language selector
                GestureDetector(
                  onTap: _showLanguageSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.getDividerColor(context)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentLang['flag']!,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedLanguage,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppTheme.getIconColor(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Folder selection
            Row(
              children: [
                Icon(Icons.folder_outlined, size: 16, color: AppTheme.getIconColor(context)),
                const SizedBox(width: 6),
                Text(
                  l10n.saveTo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.getIconColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFolderChip(
                    name: l10n.none,
                    icon: Icons.folder_off_outlined,
                    color: Colors.grey,
                    isSelected: _selectedFolderId == null,
                    onTap: () => setState(() => _selectedFolderId = null),
                  ),
                  ..._assignableFolders.map((folder) => _buildFolderChip(
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

            // Waveform visualization
            SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(25, (index) {
                  final height = _state == RecordingState.recording
                      ? _waveformData[index] * 50
                      : 20.0;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 3,
                    height: height,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [themeGrad[1], themeGrad[0]],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 32),

            // Timer
            Text(
              _formattedDuration,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimaryColor(context),
                letterSpacing: 4,
              ),
            ),

            const SizedBox(height: 40),

            // Record button / saving indicator
            if (_isSaving)
              Column(
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        ),
                        Icon(
                          Icons.cloud_upload_outlined,
                          color: accentColor,
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Saving...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: accentColor,
                    ),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: () {
                  if (_state == RecordingState.ready) {
                    _startRecording();
                  } else if (_state == RecordingState.recording) {
                    _stopRecording();
                  } else if (_state == RecordingState.stopped) {
                    _saveRecording();
                  }
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [themeGrad[1], themeGrad[0]],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    _state == RecordingState.recording
                        ? Icons.stop
                        : _state == RecordingState.stopped
                            ? Icons.check
                            : Icons.mic,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Cancel button
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      _timer?.cancel();
                      if (_state == RecordingState.recording) {
                        _recorder.stop();
                      }
                      // Delete the recording file if cancelled (native only)
                      if (!kIsWeb && _recordingPath != null && _state != RecordingState.ready) {
                        try {
                          file_helper.deleteFile(_recordingPath!);
                        } catch (e) {
                          debugPrint('Error deleting file: $e');
                        }
                      }
                      Navigator.pop(context);
                    },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  color: _isSaving ? AppTheme.getDividerColor(context) : AppTheme.getTextSecondaryColor(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum RecordingState {
  ready,
  recording,
  paused,
  stopped,
}

// Function to show the voice recording modal
Future<bool?> showVoiceRecordingModal(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const VoiceRecordingModal(),
  );
}
