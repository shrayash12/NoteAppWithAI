import 'package:intl/intl.dart';
import '../models/voice_note_category.dart';

/// Result of classifying a voice note's transcript.
class VoiceNoteClassification {
  final VoiceNoteCategory category;
  final String title;
  final List<String> tags;

  const VoiceNoteClassification({
    required this.category,
    required this.title,
    required this.tags,
  });
}

/// Offline, rule-based voice note classifier. Runs entirely on-device via
/// keyword matching against the live transcript — no AI calls, no cost.
class VoiceClassifierService {
  const VoiceClassifierService();

  VoiceNoteClassification classify(String transcript) {
    final category = _bestCategory(transcript);
    final title = _generateTitle(category, transcript);
    final tags = <String>{category.displayName}.toList();
    return VoiceNoteClassification(category: category, title: title, tags: tags);
  }

  VoiceNoteCategory _bestCategory(String transcript) {
    final lower = transcript.toLowerCase();
    VoiceNoteCategory best = VoiceNoteCategory.quickNote;
    int bestScore = 0;

    for (final category in VoiceNoteCategory.all) {
      var score = 0;
      for (final keyword in category.keywords) {
        if (lower.contains(keyword)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = category;
      }
    }

    return bestScore > 0 ? best : VoiceNoteCategory.quickNote;
  }

  /// Uses the first meaningful sentence/phrase of the transcript as the
  /// title, falling back to "<Category> - <date>" when the transcript is
  /// too short or empty.
  String _generateTitle(VoiceNoteCategory category, String transcript) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return '${category.displayName} - ${DateFormat('MMM d, yyyy').format(DateTime.now())}';
    }

    final firstSentence = trimmed.split(RegExp(r'[.!?\n]')).first.trim();
    final words = firstSentence.split(RegExp(r'\s+'));
    final snippet = words.take(8).join(' ');
    final title = snippet.isEmpty ? trimmed : snippet;

    if (title.isEmpty) {
      return '${category.displayName} - ${DateFormat('MMM d, yyyy').format(DateTime.now())}';
    }
    return title[0].toUpperCase() + title.substring(1);
  }
}
