import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onFabPressed;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onFabPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final bgColor = AppTheme.getCardColor(context);
    final accent = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            // 5 equal slots: Home | Folders | FAB | Voice | Settings
            final slotW = w / 5;
            // nav index → row slot (skip slot 2 = FAB)
            final slot = currentIndex < 2 ? currentIndex : currentIndex + 1;
            const indicatorW = 32.0;
            final indicatorLeft = slotW * slot + (slotW - indicatorW) / 2;

            return SizedBox(
              height: 62,
              child: Stack(
                children: [
                  // ── Nav row ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavItem(
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home,
                            label: l10n.navHome,
                            isSelected: currentIndex == 0,
                            onTap: () => onTap(0),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.folder_outlined,
                            activeIcon: Icons.folder,
                            label: l10n.navFolders,
                            isSelected: currentIndex == 1,
                            onTap: () => onTap(1),
                          ),
                        ),
                        SizedBox(
                          width: slotW,
                          child: Center(child: _FabButton(onPressed: onFabPressed)),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.mic_none,
                            activeIcon: Icons.mic,
                            label: l10n.navVoice,
                            isSelected: currentIndex == 2,
                            onTap: () => onTap(2),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.settings_outlined,
                            activeIcon: Icons.settings,
                            label: l10n.navSettings,
                            isSelected: currentIndex == 3,
                            onTap: () => onTap(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Sliding indicator bar ────────────────────────────────
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.fastOutSlowIn,
                    left: indicatorLeft,
                    bottom: 2,
                    child: Container(
                      width: indicatorW,
                      height: 3,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Nav Item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final inactive = AppTheme.getTextSecondaryColor(context);
    final color = widget.isSelected ? accent : inactive;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                widget.isSelected ? widget.activeIcon : widget.icon,
                key: ValueKey(widget.isSelected),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight:
                    widget.isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(widget.label),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FAB Button (unchanged) ──────────────────────────────────────────────────

class _FabButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _FabButton({required this.onPressed});

  @override
  State<_FabButton> createState() => _FabButtonState();
}

class _FabButtonState extends State<_FabButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.80)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.80, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_controller);

    _rotateAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.375)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.375, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    _controller.forward(from: 0).then((_) => widget.onPressed());
  }

  @override
  Widget build(BuildContext context) {
    final colorIndex = context.watch<NotesProvider>().themeColorIndex;
    final gradColors = AppTheme.accentGradient(colorIndex);
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: Transform.rotate(
            angle: _rotateAnim.value * 2 * 3.14159265,
            child: child,
          ),
        ),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gradColors[1], gradColors[0]],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: gradColors[0].withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
