import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../services/voice_classifier_service.dart';
import '../theme/app_theme.dart';
import '../utils/storage_helper.dart';
import '../utils/file_helper.dart' as file_helper;

void showSmartVoiceNoteModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => const SmartVoiceNoteModal(),
  );
}

enum _RecState { selectingLanguage, starting, recording, processing, error }

/// Matches AppLocalizations.supportedLocales — the same 11 languages the
/// app's own settings support.
const List<Map<String, String>> _kVoiceNoteLanguages = [
  {'code': 'en', 'name': 'English', 'flag': '🇬🇧', 'locale': 'en_US'},
  {'code': 'es', 'name': 'Español', 'flag': '🇪🇸', 'locale': 'es_ES'},
  {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷', 'locale': 'fr_FR'},
  {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪', 'locale': 'de_DE'},
  {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦', 'locale': 'ar_SA'},
  {'code': 'hi', 'name': 'हिन्दी', 'flag': '🇮🇳', 'locale': 'hi_IN'},
  {'code': 'zh', 'name': '中文', 'flag': '🇨🇳', 'locale': 'zh_CN'},
  {'code': 'ja', 'name': '日本語', 'flag': '🇯🇵', 'locale': 'ja_JP'},
  {'code': 'pt', 'name': 'Português', 'flag': '🇵🇹', 'locale': 'pt_PT'},
  {'code': 'it', 'name': 'Italiano', 'flag': '🇮🇹', 'locale': 'it_IT'},
  {'code': 'ko', 'name': '한국어', 'flag': '🇰🇷', 'locale': 'ko_KR'},
];

class SmartVoiceNoteModal extends StatefulWidget {
  const SmartVoiceNoteModal({super.key});

  @override
  State<SmartVoiceNoteModal> createState() => _SmartVoiceNoteModalState();
}

class _SmartVoiceNoteModalState extends State<SmartVoiceNoteModal> {
  final AudioRecorder _recorder = AudioRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();

  _RecState _state = _RecState.selectingLanguage;
  String? _recordingPath;
  String _transcript = '';
  int _duration = 0;
  Timer? _timer;
  String? _errorMessage;
  String _selectedLanguageCode = 'en';

  String get _selectedLocaleId => _kVoiceNoteLanguages
      .firstWhere((l) => l['code'] == _selectedLanguageCode)['locale']!;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _speech.stop();
    super.dispose();
  }

  String get _formattedDuration {
    final m = (_duration ~/ 60).toString().padLeft(2, '0');
    final s = (_duration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _start() async {
    setState(() => _state = _RecState.starting);

    final hasAudioPermission = await _recorder.hasPermission();
    if (!hasAudioPermission) {
      setState(() {
        _state = _RecState.error;
        _errorMessage = 'Microphone permission is required to record.';
      });
      return;
    }

    final speechAvailable = await _speech.initialize(
      onStatus: (_) {},
      onError: (e) => debugPrint('SmartVoiceNote speech error: $e'),
    );

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'voice_note_${const Uuid().v4()}.m4a';
      _recordingPath = '${directory.path}/$fileName';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
        path: _recordingPath!,
      );

      if (speechAvailable) {
        await _speech.listen(
          onResult: (result) {
            if (mounted) setState(() => _transcript = result.recognizedWords);
          },
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            listenFor: const Duration(minutes: 10),
            pauseFor: const Duration(seconds: 30),
            localeId: _selectedLocaleId,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _state = _RecState.recording;
        _duration = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _duration++);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _RecState.error;
          _errorMessage = 'Failed to start recording: $e';
        });
      }
    }
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    setState(() => _state = _RecState.processing);

    try {
      await _speech.stop();
      final path = await _recorder.stop();

      if (path == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final classification = const VoiceClassifierService().classify(_transcript);

      String? uploadedVoicePath;
      try {
        final bytes = await file_helper.getFileBytes(path);
        if (bytes != null) {
          final fileName = 'voice_notes/${const Uuid().v4()}.m4a';
          uploadedVoicePath = await StorageHelper.uploadToFirebase(bytes, fileName, 'audio/mp4');
        }
      } catch (e) {
        debugPrint('SmartVoiceNote upload error: $e');
      }

      final now = DateTime.now();
      final note = Note(
        id: const Uuid().v4(),
        title: classification.title,
        content: _transcript.isNotEmpty ? _transcript : 'Duration: $_formattedDuration',
        type: NoteType.voice,
        createdAt: now,
        updatedAt: now,
        voicePath: uploadedVoicePath ?? path,
        folderId: classification.category.folderId,
        ocrText: _transcript.isNotEmpty ? _transcript : null,
        tags: classification.tags,
      );

      if (!mounted) return;
      final notesProvider = context.read<NotesProvider>();
      await notesProvider.addNote(note);

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SmartVoiceNoteResultScreen(note: note)),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _RecState.error;
          _errorMessage = 'Failed to save recording: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.getDividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                'Smart Voice Note',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_state == _RecState.selectingLanguage) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Speak in:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextSecondaryColor(context),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kVoiceNoteLanguages.map((lang) {
                final isSelected = _selectedLanguageCode == lang['code'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedLanguageCode = lang['code']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryPurple.withOpacity(0.15)
                          : AppTheme.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryPurple : AppTheme.getDividerColor(context),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '${lang['flag']} ${lang['name']}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                        color: isSelected ? AppTheme.primaryPurple : AppTheme.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.mic, color: Colors.white),
                label: const Text('Start Recording', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ] else if (_state == _RecState.error) ...[
            Text(
              _errorMessage ?? 'Something went wrong.',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ] else ...[
            Text(
              _formattedDuration,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _state == _RecState.recording
                  ? 'Listening…'
                  : _state == _RecState.processing
                      ? 'Saving…'
                      : 'Starting…',
              style: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
            ),
            const SizedBox(height: 16),
            if (_transcript.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    _transcript,
                    style: TextStyle(fontSize: 14, color: AppTheme.getTextSecondaryColor(context)),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _state == _RecState.recording ? _stopAndSave : null,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _state == _RecState.recording ? Colors.red : Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: _state == _RecState.processing
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : const Icon(Icons.stop, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to stop & save',
              style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondaryColor(context)),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Smart Voice Note results screen — shown after saving.
// ---------------------------------------------------------------------------
class SmartVoiceNoteResultScreen extends StatelessWidget {
  final Note note;
  const SmartVoiceNoteResultScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final matchingFolders = note.folderId == null
        ? const <Folder>[]
        : Folder.defaultFolders.where((f) => f.id == note.folderId).toList();
    final folderName = matchingFolders.isEmpty ? null : matchingFolders.first.name;
    final category = note.tags.isNotEmpty ? note.tags.first : 'Quick Note';

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getCardColor(context),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Smart Voice Note Saved',
          style: TextStyle(
            color: AppTheme.getTextPrimaryColor(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Recorded, transcribed & organized',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _InfoRow(icon: Icons.label_outline, label: 'Category', value: category),
            if (folderName != null)
              _InfoRow(icon: Icons.folder_outlined, label: 'Folder', value: folderName),
            _InfoRow(icon: Icons.title, label: 'Title', value: note.title),

            if (note.ocrText != null && note.ocrText!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Transcript',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    note.ocrText!,
                    style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondaryColor(context)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.getTextSecondaryColor(context)),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 14, color: AppTheme.getTextSecondaryColor(context)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.getTextPrimaryColor(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
