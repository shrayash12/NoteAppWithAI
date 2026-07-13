import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/create_note_modal.dart';
import '../widgets/photo_note_modal.dart';
import '../widgets/ai_action_dialog.dart';
import 'home_screen.dart';
import 'folders_screen.dart';
import 'voice_screen.dart';
import 'settings_screen.dart';
import 'text_note_screen.dart';
import 'drawing_screen.dart';
import 'checklist_screen.dart';
import 'document_scanner_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  bool _isAnimating = false;
  bool _isForward = true;

  late final AnimationController _controller;
  late Animation<Offset> _incomingSlide;
  late Animation<Offset> _outgoingSlide;
  late final Animation<double> _incomingFade;
  late final Animation<double> _outgoingFade;

  final List<Widget> _screens = const [
    RepaintBoundary(child: HomeScreen()),
    RepaintBoundary(child: FoldersScreen()),
    RepaintBoundary(child: VoiceScreen()),
    RepaintBoundary(child: SettingsScreen()),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..value = 1.0;

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _isAnimating = false);
      }
    });

    _incomingSlide = _controller.drive(
      Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeInOutCubic)),
    );

    _outgoingSlide = _controller.drive(
      Tween<Offset>(begin: Offset.zero, end: const Offset(-1.0, 0))
          .chain(CurveTween(curve: Curves.easeInOutCubic)),
    );

    // Fade: incoming 0→1, outgoing 1→0
    _incomingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
      ),
    );
    _outgoingFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigate(int index) {
    if (index == _currentIndex || _isAnimating) return;
    final isForward = index > _currentIndex;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
      _isAnimating = true;
      _isForward = isForward;
    });

    // Flip directions when going backwards
    _incomingSlide = _controller.drive(
      Tween<Offset>(
        begin: Offset(isForward ? 1.0 : -1.0, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
    );

    _outgoingSlide = _controller.drive(
      Tween<Offset>(
        begin: Offset.zero,
        end: Offset(isForward ? -1.0 : 1.0, 0),
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
    );

    _controller.forward(from: 0);
  }

  void _onFabPressed() {
    showCreateNoteModal(context, _onNoteTypeSelected);
  }

  void _onNoteTypeSelected(NoteType type) {
    switch (type) {
      case NoteType.text:
        showTextNoteModal(context);
        break;
      case NoteType.voice:
        _navigate(2);
        break;
      case NoteType.drawing:
        showDrawingScreen(context);
        break;
      case NoteType.photo:
        showPhotoNoteModal(context);
        break;
      case NoteType.checklist:
        showChecklistModal(context);
        break;
      case NoteType.document:
        launchDocumentScanner(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final outgoing = _isAnimating
                ? FadeTransition(
                    opacity: _outgoingFade,
                    child: SlideTransition(
                      position: _outgoingSlide,
                      child: _screens[_previousIndex],
                    ),
                  )
                : null;
            final incoming = FadeTransition(
              opacity: _incomingFade,
              child: SlideTransition(
                position: _incomingSlide,
                child: _screens[_currentIndex],
              ),
            );
            return Stack(
              fit: StackFit.expand,
              children: _isForward
                  ? [if (outgoing != null) outgoing, incoming]
                  : [incoming, if (outgoing != null) outgoing],
            );
          },
        ),
      ),
      floatingActionButton: _AIFloatingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _navigate,
        onFabPressed: _onFabPressed,
      ),
    );
  }
}

class _AIFloatingButton extends StatefulWidget {
  @override
  State<_AIFloatingButton> createState() => _AIFloatingButtonState();
}

class _AIFloatingButtonState extends State<_AIFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showAIPanel(BuildContext context) {
    final colorIndex = context.read<NotesProvider>().themeColorIndex;
    final gradient = AppTheme.accentGradient(colorIndex);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Assistant',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimaryColor(context),
                      ),
                    ),
                    Text(
                      'Smart features for your notes',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.getTextSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _AIFeatureTile(
              icon: Icons.auto_fix_high,
              label: 'Enhance Writing',
              description: 'Improve grammar & style',
              gradient: gradient,
              onTap: () {
                Navigator.pop(context);
                showAIActionSheet(context, AIActionType.enhance);
              },
            ),
            const SizedBox(height: 10),
            _AIFeatureTile(
              icon: Icons.summarize,
              label: 'Summarize',
              description: 'Get a quick summary',
              gradient: gradient,
              onTap: () {
                Navigator.pop(context);
                showAIActionSheet(context, AIActionType.summarize);
              },
            ),
            const SizedBox(height: 10),
            _AIFeatureTile(
              icon: Icons.translate,
              label: 'Translate',
              description: 'Translate to any language',
              gradient: gradient,
              onTap: () {
                Navigator.pop(context);
                showAIActionSheet(context, AIActionType.translate);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorIndex = context.watch<NotesProvider>().themeColorIndex;
    final gradient = AppTheme.accentGradient(colorIndex);

    return ScaleTransition(
      scale: _pulseAnimation,
      child: GestureDetector(
        onTap: () => _showAIPanel(context),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _AIFeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _AIFeatureTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getTextSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.getIconColor(context)),
          ],
        ),
      ),
    );
  }
}

