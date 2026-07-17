import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/note.dart';
import '../models/subscription.dart';
import '../providers/notes_provider.dart';
import '../providers/usage_provider.dart';
import '../screens/upgrade_screen.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

enum AIActionType { enhance, summarize, translate }

const _translateLanguages = [
  'Spanish', 'French', 'German', 'Hindi', 'Chinese', 'Japanese', 'Korean',
  'Portuguese', 'Italian', 'Arabic', 'English',
];

/// Standalone AI Assistant sheet: takes pasted text, runs the chosen action
/// against Gemini, and lets the user copy the result or save it as a new note.
Future<void> showAIActionSheet(BuildContext context, AIActionType type) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AIActionSheet(type: type),
  );
}

class _AIActionSheet extends StatefulWidget {
  final AIActionType type;
  const _AIActionSheet({required this.type});

  @override
  State<_AIActionSheet> createState() => _AIActionSheetState();
}

class _AIActionSheetState extends State<_AIActionSheet> {
  final _inputController = TextEditingController();
  String _targetLanguage = 'Spanish';
  bool _loading = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  String _titleFor(AppLocalizations l10n) {
    switch (widget.type) {
      case AIActionType.enhance:
        return l10n.aiEnhance;
      case AIActionType.summarize:
        return l10n.aiSummarize;
      case AIActionType.translate:
        return l10n.aiTranslate;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case AIActionType.enhance:
        return Icons.auto_fix_high;
      case AIActionType.summarize:
        return Icons.summarize;
      case AIActionType.translate:
        return Icons.translate;
    }
  }

  AIFeature get _feature {
    switch (widget.type) {
      case AIActionType.enhance:
        return AIFeature.enhance;
      case AIActionType.summarize:
        return AIFeature.summarize;
      case AIActionType.translate:
        return AIFeature.translate;
    }
  }

  Future<void> _run() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final text = _inputController.text;
      late final String output;
      switch (widget.type) {
        case AIActionType.enhance:
          output = await AIService.enhanceWriting(text);
          break;
        case AIActionType.summarize:
          output = await AIService.summarize(text);
          break;
        case AIActionType.translate:
          output = await AIService.translate(text, _targetLanguage);
          break;
      }
      if (!mounted) return;
      setState(() {
        _result = output;
        _loading = false;
      });
      context.read<UsageProvider>().refresh();
    } on AIServiceException catch (e) {
      if (!mounted) return;
      if (e.isQuotaExceeded) {
        setState(() => _loading = false);
        context.read<UsageProvider>().refresh();
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UpgradeScreen()),
        );
        return;
      }
      setState(() {
        _loading = false;
        _error = e.code == 'empty_input' ? l10n.aiErrorEmptyInput : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = l10n.aiErrorGeneric;
      });
    }
  }

  void _saveAsNote() {
    final l10n = AppLocalizations.of(context);
    final notesProvider = context.read<NotesProvider>();
    final note = notesProvider.createNote(
      title: _titleFor(l10n),
      content: _result ?? '',
      type: NoteType.text,
    );
    notesProvider.addNote(note);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.aiInsertAsNote)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorIndex = context.watch<NotesProvider>().themeColorIndex;
    final gradient = AppTheme.accentGradient(colorIndex);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
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
                    child: Icon(_icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titleFor(l10n),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimaryColor(context),
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final usage = context.watch<UsageProvider>().usageFor(_feature);
                            if (usage == null) return const SizedBox.shrink();
                            return Text(
                              '${usage.remaining} of ${usage.limit} left this period',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.getTextSecondaryColor(context),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _inputController,
                maxLines: 6,
                minLines: 3,
                style: TextStyle(color: AppTheme.getTextPrimaryColor(context)),
                decoration: InputDecoration(
                  hintText: l10n.aiInputHint,
                  hintStyle: TextStyle(color: AppTheme.getTextSecondaryColor(context)),
                  filled: true,
                  fillColor: AppTheme.getSurfaceColor(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (widget.type == AIActionType.translate) ...[
                const SizedBox(height: 14),
                Text(
                  l10n.aiTranslateTargetLabel,
                  style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondaryColor(context)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _translateLanguages.map((lang) {
                    final selected = lang == _targetLanguage;
                    return ChoiceChip(
                      label: Text(lang),
                      selected: selected,
                      onSelected: (_) => setState(() => _targetLanguage = lang),
                      selectedColor: gradient[0].withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: selected ? gradient[0] : AppTheme.getTextPrimaryColor(context),
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: _loading ? null : _run,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.aiRun,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              if (_result != null) ...[
                const SizedBox(height: 20),
                Text(
                  l10n.aiResult,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getTextSecondaryColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(
                    _result!,
                    style: TextStyle(color: AppTheme.getTextPrimaryColor(context), height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _result!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.aiCopied)),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(l10n.aiCopy),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveAsNote,
                        icon: const Icon(Icons.note_add, size: 16),
                        label: Text(l10n.aiInsertAsNote),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gradient[0],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
