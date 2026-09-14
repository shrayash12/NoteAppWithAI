import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';

const _kAiDisclosureAcceptedKey = 'ai_disclosure_accepted';

/// Shows a one-time consent sheet before the first AI action (Enhance,
/// Summarize, Translate) explaining that the submitted note text is sent
/// to Google's Gemini API. Returns true if the user may proceed — either
/// because they've already accepted before, or they just accepted now.
/// Returns false if they declined, in which case the caller must not
/// send anything to the AI service.
Future<bool> ensureAiDisclosureAccepted(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kAiDisclosureAcceptedKey) ?? false) {
    return true;
  }

  if (!context.mounted) return false;
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AiDisclosureSheet(),
  );

  if (accepted == true) {
    await prefs.setBool(_kAiDisclosureAcceptedKey, true);
    return true;
  }
  return false;
}

class _AiDisclosureSheet extends StatelessWidget {
  const _AiDisclosureSheet();

  @override
  Widget build(BuildContext context) {
    final colorIndex = context.watch<NotesProvider>().themeColorIndex;
    final gradient = AppTheme.accentGradient(colorIndex);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Before you use AI features',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Enhance, Summarize, and Translate send the text you submit to '
            "Google's Gemini API to generate the result. Only that text is "
            'sent — not your other notes, account details, or files — and '
            "it isn't used to train Google's models by us.",
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppTheme.getTextSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You can keep using SmartNotes fully without ever turning this on — '
            'these AI actions are entirely optional. See our Privacy Policy for details.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppTheme.getTextSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Not Now'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Allow & Continue',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
