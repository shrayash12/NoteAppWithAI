import 'package:flutter/material.dart';
import '../models/note.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class CreateNoteModal extends StatefulWidget {
  final Function(NoteType) onNoteTypeSelected;

  const CreateNoteModal({
    super.key,
    required this.onNoteTypeSelected,
  });

  @override
  State<CreateNoteModal> createState() => _CreateNoteModalState();
}

class _CreateNoteModalState extends State<CreateNoteModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: _buildContent(bottomPadding),
      ),
    );
  }

  Widget _buildContent(double bottomPadding) {
    final l10n = AppLocalizations.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding + 16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.createNew,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimaryColor(context),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _NoteTypeCard(
                  icon: Icons.edit,
                  label: l10n.typeTextNote,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD946EF), Color(0xFF8B5CF6)],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNoteTypeSelected(NoteType.text);
                  },
                ),
                _NoteTypeCard(
                  icon: Icons.mic,
                  label: l10n.typeVoiceNote,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNoteTypeSelected(NoteType.voice);
                  },
                ),
                _NoteTypeCard(
                  icon: Icons.chat_bubble,
                  label: l10n.typeDrawSketch,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFEF4444)],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNoteTypeSelected(NoteType.drawing);
                  },
                ),
                _NoteTypeCard(
                  icon: Icons.camera_alt,
                  label: l10n.typePhotoNote,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF10B981)],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNoteTypeSelected(NoteType.photo);
                  },
                ),
                _NoteTypeCard(
                  icon: Icons.check_box,
                  label: l10n.typeChecklist,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNoteTypeSelected(NoteType.checklist);
                  },
                ),
                _NoteTypeCard(
                  icon: Icons.document_scanner,
                  label: l10n.typeScanDoc,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNoteTypeSelected(NoteType.document);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _NoteTypeCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.getDividerColor(context),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.getTextPrimaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showCreateNoteModal(BuildContext context, Function(NoteType) onNoteTypeSelected) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 380),
    ),
    builder: (context) => CreateNoteModal(onNoteTypeSelected: onNoteTypeSelected),
  );
}
