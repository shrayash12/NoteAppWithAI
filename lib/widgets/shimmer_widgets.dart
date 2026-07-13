import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Base shimmer box — a rounded rectangle placeholder
class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Wraps children in a Shimmer effect that respects dark/light mode
class ShimmerWrapper extends StatelessWidget {
  final Widget child;

  const ShimmerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade300,
      highlightColor: isDark ? const Color(0xFF334155) : Colors.grey.shade100,
      child: child,
    );
  }
}

/// Shimmer for the 3 stat cards at the top of HomeScreen
class ShimmerStatCards extends StatelessWidget {
  const ShimmerStatCards({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: List.generate(3, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Shimmer for a single list-view note card
class ShimmerNoteCard extends StatelessWidget {
  const ShimmerNoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ShimmerBox(width: 32, height: 32, radius: 8),
                const SizedBox(width: 12),
                _ShimmerBox(width: 120, height: 14, radius: 6),
                const Spacer(),
                _ShimmerBox(width: 60, height: 12, radius: 6),
              ],
            ),
            const SizedBox(height: 12),
            _ShimmerBox(width: double.infinity, height: 12, radius: 6),
            const SizedBox(height: 6),
            _ShimmerBox(width: 200, height: 12, radius: 6),
            const SizedBox(height: 12),
            Row(
              children: [
                _ShimmerBox(width: 50, height: 20, radius: 10),
                const SizedBox(width: 8),
                _ShimmerBox(width: 50, height: 20, radius: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer for a single grid-view note card
class ShimmerGridNoteCard extends StatelessWidget {
  const ShimmerGridNoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ShimmerBox(width: 28, height: 28, radius: 8),
                const Spacer(),
                _ShimmerBox(width: 20, height: 20, radius: 10),
              ],
            ),
            const SizedBox(height: 12),
            _ShimmerBox(width: 100, height: 14, radius: 6),
            const SizedBox(height: 8),
            _ShimmerBox(width: double.infinity, height: 11, radius: 6),
            const SizedBox(height: 5),
            _ShimmerBox(width: 80, height: 11, radius: 6),
            const Spacer(),
            _ShimmerBox(width: 55, height: 10, radius: 5),
          ],
        ),
      ),
    );
  }
}

/// Shimmer for the filter tab row
class ShimmerFilterTabs extends StatelessWidget {
  const ShimmerFilterTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(5, (i) {
            return Container(
              margin: EdgeInsets.only(right: i < 4 ? 8 : 0),
              width: 80,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Shimmer for the notes list (filter tabs + note cards).
/// Stat cards are handled separately in the HomeScreen build method.
class HomeShimmerLayout extends StatelessWidget {
  final bool isGridView;

  const HomeShimmerLayout({super.key, required this.isGridView});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const ShimmerFilterTabs(),
        const SizedBox(height: 16),
        isGridView ? _buildGridShimmer() : _buildListShimmer(),
      ],
    );
  }

  Widget _buildListShimmer() {
    return Column(
      children: List.generate(5, (_) => const ShimmerNoteCard()),
    );
  }

  Widget _buildGridShimmer() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const ShimmerGridNoteCard(),
    );
  }
}

/// Shimmer splash screen shown at app launch while Firebase initializes
// ── Original shimmer loading screen (shown while notes load) ─────────────────
class SplashShimmerScreen extends StatelessWidget {
  const SplashShimmerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          ShimmerWrapper(
            child: Container(
              height: 160,
              width: double.infinity,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: const [
                  SizedBox(height: 16),
                  ShimmerStatCards(),
                  SizedBox(height: 16),
                  HomeShimmerLayout(isGridView: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated splash screen (shown during initial auth check) ─────────────────
class SplashAnimationScreen extends StatefulWidget {
  const SplashAnimationScreen({super.key});

  @override
  State<SplashAnimationScreen> createState() => _SplashAnimationScreenState();
}

class _SplashAnimationScreenState extends State<SplashAnimationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _dotCtrl;

  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _floatAnim;
  late final Animation<double> _shimmerAnim;

  static const _bg     = Color(0xFF0D1B2A);
  static const _accent = Color(0xFF4A90D9);
  static const _glow   = Color(0xFF6EB5FF);

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _scaleAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack)
        .drive(Tween(begin: 0.6, end: 1.0));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.5, end: 1.0));

    _floatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _floatAnim = CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut)
        .drive(Tween(begin: -8.0, end: 8.0));

    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _shimmerAnim = _shimmerCtrl.drive(Tween(begin: -1.0, end: 2.0));

    _dotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    _shimmerCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Ambient background
          Positioned.fill(child: CustomPaint(painter: _BgPainter())),

          // Centre content
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_scaleAnim, _floatAnim, _glowAnim]),
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Icon ───────────────────────────────────────────
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing glow halo
                        Opacity(
                          opacity: _glowAnim.value * 0.4,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [_glow.withOpacity(0.35), _glow.withOpacity(0.0)],
                              ),
                            ),
                          ),
                        ),
                        // Icon card
                        Transform.scale(
                          scale: _scaleAnim.value,
                          child: _IconCard(shimmerAnim: _shimmerAnim),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // ── App name ────────────────────────────────────────
                    const Text(
                      'SmartNotes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your AI-powered notebook',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 13.5,
                        letterSpacing: 0.3,
                      ),
                    ),

                    const SizedBox(height: 52),

                    // ── Animated dots ───────────────────────────────────
                    AnimatedBuilder(
                      animation: _dotCtrl,
                      builder: (_, __) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final phase = (_dotCtrl.value - i * 0.22) % 1.0;
                          final scale = 0.6 + math.sin(phase * math.pi).clamp(0.0, 1.0) * 0.8;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _accent.withOpacity(0.4 + scale * 0.4),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCard extends StatelessWidget {
  final Animation<double> shimmerAnim;
  const _IconCard({required this.shimmerAnim});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Card
        Container(
          width: 136,
          height: 136,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A5298), Color(0xFF1A3A6B)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A90D9).withOpacity(0.55),
                blurRadius: 40,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: SizedBox(
              width: 68,
              height: 68,
              child: CustomPaint(painter: _NoteIconPainter()),
            ),
          ),
        ),
        // Shimmer sweep
        AnimatedBuilder(
          animation: shimmerAnim,
          builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: SizedBox(
              width: 136,
              height: 136,
              child: Transform.translate(
                offset: Offset(shimmerAnim.value * 136, 0),
                child: Transform.rotate(
                  angle: -0.4,
                  child: Container(
                    width: 46,
                    height: 220,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter: stacked document pages — matches app launcher icon
class _NoteIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    // Back page (most transparent, offset right+down)
    paint.color = Colors.white.withOpacity(0.22);
    _page(canvas, paint, w * 0.20, h * 0.14, w * 0.66, h * 0.70, 5);

    // Middle page
    paint.color = Colors.white.withOpacity(0.48);
    _page(canvas, paint, w * 0.11, h * 0.08, w * 0.66, h * 0.70, 5);

    // Front page — solid white
    paint.color = Colors.white;
    _page(canvas, paint, w * 0.02, h * 0.02, w * 0.66, h * 0.74, 5);

    // Lines on front page
    paint.color = const Color(0xFF1A3A6B);
    final lx = w * 0.10;
    final rx = w * 0.60;
    for (int i = 0; i < 4; i++) {
      final y = h * (0.20 + i * 0.14);
      final lineW = i == 3 ? (rx - lx) * 0.55 : (rx - lx);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(lx, y, lineW, h * 0.05),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  void _page(Canvas canvas, Paint p, double x, double y, double w, double h, double r) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

/// Soft ambient gradient orbs painted on canvas
class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void orb(Offset center, double radius, Color color, double opacity) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    orb(Offset(size.width * 0.15, size.height * 0.18), size.width * 0.55,
        const Color(0xFF1F3A5F), 0.55);
    orb(Offset(size.width * 0.85, size.height * 0.80), size.width * 0.50,
        const Color(0xFF0F2847), 0.70);
    orb(Offset(size.width * 0.50, size.height * 0.50), size.width * 0.40,
        const Color(0xFF163560), 0.25);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
