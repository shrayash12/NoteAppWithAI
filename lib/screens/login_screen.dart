import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../utils/google_signin_web_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _bgController;    // slow rotating gradient
  late final AnimationController _entryController; // stagger entry
  late final AnimationController _floatController; // floating orbs
  late final AnimationController _pulseController; // button pulse
  late final AnimationController _logoController;  // logo spin+scale

  // ── Entry animations ──────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _buttonSlide;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _footerSlide;
  late final Animation<double> _footerFade;

  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();

    // Background gradient rotation — very slow
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Logo spinning on entry
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Floating orbs
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Button pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Stagger entry controller — 1200ms total
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Logo: scale + fade (0–50%)
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Tagline: slide up + fade (25–60%)
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.25, 0.6, curve: Curves.easeOutCubic),
    ));
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
      ),
    );

    // Button: slide up + fade (50–85%)
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.50, 0.85, curve: Curves.easeOutCubic),
    ));
    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.50, 0.80, curve: Curves.easeOut),
      ),
    );

    // Footer: fade (75–100%)
    _footerSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    ));
    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start logo spin then entry
    _logoController.forward().then((_) => _entryController.forward());
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    try {
      await GoogleSignIn.instance.authenticate();
      // The global authenticationEvents listener in main.dart signs into
      // Firebase; AuthWrapper then handles navigation.
    } on GoogleSignInException catch (e) {
      if (mounted) {
        setState(() => _isSigningIn = false);
        if (e.code != GoogleSignInExceptionCode.canceled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign-in failed: ${e.description ?? e.code}'),
              backgroundColor: Colors.red.shade400,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSigningIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  static bool get _supportsAppleSignIn => !kIsWeb && Platform.isIOS;

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = math.Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  Future<void> _signInWithApple() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );

      await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      // AuthWrapper will handle navigation
    } on SignInWithAppleAuthorizationException catch (e) {
      if (mounted) {
        setState(() => _isSigningIn = false);
        if (e.code != AuthorizationErrorCode.canceled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign-in failed: ${e.message}'),
              backgroundColor: Colors.red.shade400,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSigningIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    final colorIndex = notesProvider.themeColorIndex;
    final grad = AppTheme.accentGradient(colorIndex);
    final accent = AppTheme.accentColor(colorIndex);
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          final t = _bgController.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(
                  math.cos(t * 2 * math.pi) * 0.6,
                  math.sin(t * 2 * math.pi) * 0.6,
                ),
                end: Alignment(
                  -math.cos(t * 2 * math.pi) * 0.6,
                  -math.sin(t * 2 * math.pi) * 0.6,
                ),
                colors: [
                  grad[0].withOpacity(0.95),
                  grad[1].withOpacity(0.85),
                  isDark
                      ? const Color(0xFF0F172A)
                      : Colors.white.withOpacity(0.9),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            // ── Floating orbs background ────────────────────────────────
            _FloatingOrbs(
              floatAnim: _floatController,
              accent: accent,
              grad: grad,
            ),

            // ── Main content ────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Logo + App name
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Column(
                          children: [
                            // Animated logo container
                            AnimatedBuilder(
                              animation: _logoController,
                              builder: (context, child) => Transform.rotate(
                                angle: (1 - _logoController.value) * 2 * math.pi,
                                child: child,
                              ),
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.3),
                                      Colors.white.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withOpacity(0.4),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 52,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'SmartNotes',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tagline
                    FadeTransition(
                      opacity: _taglineFade,
                      child: SlideTransition(
                        position: _taglineSlide,
                        child: Column(
                          children: [
                            Text(
                              'Your AI-powered notes,',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w300,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              'beautifully organized.',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w300,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Feature pills
                    FadeTransition(
                      opacity: _buttonFade,
                      child: SlideTransition(
                        position: _buttonSlide,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _FeaturePill(icon: Icons.mic, label: 'Voice Notes'),
                            _FeaturePill(icon: Icons.brush, label: 'Drawing'),
                            _FeaturePill(icon: Icons.camera_alt, label: 'Photos'),
                            _FeaturePill(icon: Icons.check_box, label: 'Checklists'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Google Sign-In button
                    FadeTransition(
                      opacity: _buttonFade,
                      child: SlideTransition(
                        position: _buttonSlide,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) => Transform.scale(
                            scale: _isSigningIn
                                ? 1.0
                                : 1.0 + _pulseController.value * 0.012,
                            child: child,
                          ),
                          child: kIsWeb
                              ? SizedBox(
                                  width: double.infinity,
                                  height: 58,
                                  child: Center(child: renderGoogleSignInButton()),
                                )
                              : _GoogleSignInButton(
                                  onPressed: _signInWithGoogle,
                                  isLoading: _isSigningIn,
                                  accent: accent,
                                ),
                        ),
                      ),
                    ),

                    if (_supportsAppleSignIn) ...[
                      const SizedBox(height: 14),
                      FadeTransition(
                        opacity: _buttonFade,
                        child: SlideTransition(
                          position: _buttonSlide,
                          child: SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: SignInWithAppleButton(
                              onPressed: _isSigningIn ? null : _signInWithApple,
                              height: 58,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Footer
                    FadeTransition(
                      opacity: _footerFade,
                      child: SlideTransition(
                        position: _footerSlide,
                        child: Text(
                          'By signing in, you agree to our Terms & Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Floating orbs ─────────────────────────────────────────────────────────────

class _FloatingOrbs extends StatelessWidget {
  final Animation<double> floatAnim;
  final Color accent;
  final List<Color> grad;

  const _FloatingOrbs({
    required this.floatAnim,
    required this.accent,
    required this.grad,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: floatAnim,
      builder: (context, _) {
        final t = floatAnim.value;
        return Stack(
          children: [
            // Top-right large orb
            Positioned(
              top: -60 + t * 30,
              right: -80 + t * 20,
              child: _Orb(size: 220, color: grad[1], opacity: 0.25),
            ),
            // Bottom-left orb
            Positioned(
              bottom: 80 - t * 40,
              left: -60 + t * 15,
              child: _Orb(size: 180, color: grad[0], opacity: 0.2),
            ),
            // Mid-right small orb
            Positioned(
              top: 200 + t * 50,
              right: 20 - t * 10,
              child: _Orb(size: 80, color: Colors.white, opacity: 0.12),
            ),
            // Mid-left tiny orb
            Positioned(
              top: 350 - t * 30,
              left: 10 + t * 20,
              child: _Orb(size: 50, color: Colors.white, opacity: 0.1),
            ),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _Orb({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }
}

// ── Feature pill ──────────────────────────────────────────────────────────────

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Google Sign-In button ─────────────────────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final Color accent;

  const _GoogleSignInButton({
    required this.onPressed,
    required this.isLoading,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: accent.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google 'G' logo
                  _GoogleLogo(),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Blue arc (top-right + right)
    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.17
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.78),
      -0.52,
      1.65,
      false,
      paintBlue,
    );

    // Red arc (top-left)
    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.17
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.78),
      -2.82,
      1.13,
      false,
      paintRed,
    );

    // Yellow arc (bottom-left)
    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.17
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.78),
      2.17,
      0.97,
      false,
      paintYellow,
    );

    // Green arc (bottom-right)
    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.17
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.78),
      1.13,
      1.04,
      false,
      paintGreen,
    );

    // Horizontal bar (Google's right-side bar)
    final paintBar = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.17
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(c.dx, c.dy),
      Offset(c.dx + r * 0.78, c.dy),
      paintBar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
