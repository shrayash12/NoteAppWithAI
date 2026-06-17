import 'package:flutter/material.dart';
import '../utils/app_lock_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class LockBottomSheet extends StatefulWidget {
  final bool biometricEnabled;

  const LockBottomSheet({super.key, this.biometricEnabled = false});

  @override
  State<LockBottomSheet> createState() => _LockBottomSheetState();
}

class _LockBottomSheetState extends State<LockBottomSheet>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _shaking = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    if (widget.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final ok = await AppLockService.authenticateWithBiometric();
    if (ok && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _onDigit(String digit) async {
    if (_pin.length >= 4) return;
    final newPin = _pin + digit;
    setState(() => _pin = newPin);

    if (newPin.length == 4) {
      await Future.delayed(const Duration(milliseconds: 100));
      final correct = await AppLockService.verifyPin(newPin);
      if (correct && mounted) {
        Navigator.pop(context, true);
      } else if (mounted) {
        setState(() {
          _shaking = true;
          _pin = '';
        });
        await _shakeController.forward(from: 0);
        if (mounted) setState(() => _shaking = false);
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = AppTheme.isDarkMode(context);
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Lock icon + title
          const Icon(Icons.lock_outline, size: 40, color: AppTheme.primaryPurple),
          const SizedBox(height: 12),
          Text(
            l10n.noteLocked,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.enterPinContinue,
            style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.6)),
          ),
          const SizedBox(height: 28),

          // 4-dot indicator with shake
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shaking ? _shakeAnimation.value : 0, 0),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? (_shaking ? Colors.red : AppTheme.primaryPurple)
                        : Colors.transparent,
                    border: Border.all(
                      color: _shaking
                          ? Colors.red
                          : filled
                              ? AppTheme.primaryPurple
                              : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 28),

          // Number pad
          _buildPad(textColor),

          // Biometric button
          if (widget.biometricEnabled) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _tryBiometric,
              icon: const Icon(Icons.fingerprint, color: AppTheme.primaryPurple),
              label: const Text(
                'Use Fingerprint',
                style: TextStyle(color: AppTheme.primaryPurple),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPad(Color textColor) {
    const digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      children: [
        ...digits.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row
                    .map((d) => _PadButton(
                          label: d,
                          textColor: textColor,
                          onTap: () => _onDigit(d),
                        ))
                    .toList(),
              ),
            )),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PadButton(
              label: '⌫',
              textColor: textColor,
              onTap: _onBackspace,
            ),
            _PadButton(
              label: '0',
              textColor: textColor,
              onTap: () => _onDigit('0'),
            ),
            const SizedBox(width: 72), // spacer to match backspace
          ],
        ),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  final String label;
  final Color textColor;
  final VoidCallback onTap;

  const _PadButton({
    required this.label,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryPurple.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: label.length == 1 ? 22 : 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
