import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../providers/notes_provider.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_header.dart';
import '../utils/notification_service.dart';
import '../utils/app_lock_service.dart';
import '../utils/storage_helper.dart';
import '../widgets/lock_bottom_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _pickReminderTime(BuildContext context, NotesProvider notesProvider) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: notesProvider.reminderTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryPurple),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      await notesProvider.setReminderTime(picked);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.settingsDailyReminderSet} ${picked.format(context)}'),
            backgroundColor: AppTheme.primaryPurple,
          ),
        );
      }
    }
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LanguagePickerSheet(),
    );
  }

  void _showThemeColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ThemeColorPickerSheet(),
    );
  }

  Future<void> _handleAppLockToggle(
      BuildContext context, bool value, NotesProvider notesProvider) async {
    if (value) {
      // Turning ON: require PIN setup
      final pinSet = await _showPinSetupSheet(context);
      if (pinSet == true && context.mounted) {
        await notesProvider.setAppLock(true);
      }
      // If cancelled, toggle stays off (notesProvider.appLockEnabled remains false)
    } else {
      // Turning OFF: require verification first
      if (!context.mounted) return;
      final unlocked = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => LockBottomSheet(
          biometricEnabled: notesProvider.biometricEnabled,
        ),
      );
      if (unlocked == true && context.mounted) {
        await notesProvider.setAppLock(false);
        await AppLockService.clearPin();
      }
    }
  }

  /// Shows a two-step PIN setup sheet. Returns true when PIN is saved.
  Future<bool?> _showPinSetupSheet(BuildContext context) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PinSetupSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimaryColor(context);
    final textSecondary = AppTheme.getTextSecondaryColor(context);
    final dividerColor = AppTheme.getDividerColor(context);
    final iconColor = AppTheme.getIconColor(context);

    return Consumer<NotesProvider>(
      builder: (context, notesProvider, child) {
        return Column(
          children: [
            GradientHeader(
              title: l10n.settingsTitle,
              showFilter: false,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // ── Account Section ─────────────────────────────────
                    _AccountCard(
                      accent: AppTheme.accentColor(notesProvider.themeColorIndex),
                      grad: AppTheme.accentGradient(notesProvider.themeColorIndex),
                      cardColor: cardColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onSignOut: () async {
                        await GoogleSignIn.instance.signOut();
                        await FirebaseAuth.instance.signOut();
                        // AuthWrapper will navigate to LoginScreen
                      },
                    ),
                    const SizedBox(height: 24),
                    // Preferences Section
                    Text(
                      l10n.settingsPreferences,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.notifications_none,
                            title: l10n.settingsNotifications,
                            subtitle: notesProvider.notificationsEnabled
                                ? l10n.settingsDailyRemindersEnabled
                                : l10n.settingsNotificationsOff,
                            iconColor: iconColor,
                            textColor: textPrimary,
                            trailing: Switch(
                              value: notesProvider.notificationsEnabled,
                              onChanged: (value) {
                                notesProvider.setNotifications(value);
                              },
                              activeColor: AppTheme.accentColor(notesProvider.themeColorIndex),
                            ),
                          ),
                          if (notesProvider.notificationsEnabled) ...[
                            _SettingsDivider(color: dividerColor),
                            _SettingsTile(
                              icon: Icons.access_time,
                              title: l10n.settingsDailyReminderTime,
                              subtitle: l10n.settingsTapChangeTime,
                              iconColor: AppTheme.primaryPurple,
                              textColor: textPrimary,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryPurple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      notesProvider.reminderTime.format(context),
                                      style: const TextStyle(
                                        color: AppTheme.primaryPurple,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right, color: textSecondary),
                                ],
                              ),
                              onTap: () => _pickReminderTime(context, notesProvider),
                            ),
                            _SettingsDivider(color: dividerColor),
                            _SettingsTile(
                              icon: Icons.send,
                              title: l10n.settingsSendTest,
                              subtitle: l10n.settingsCheckNotifications,
                              iconColor: const Color(0xFF06B6D4),
                              textColor: textPrimary,
                              trailing: Icon(Icons.chevron_right, color: textSecondary),
                              onTap: () async {
                                await NotificationService.showInstantNotification(
                                  title: 'SmartNotes',
                                  body: l10n.settingsNotificationsWorking,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.settingsTestNotificationSent),
                                      backgroundColor: const Color(0xFF06B6D4),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                          _SettingsDivider(color: dividerColor),
                          _SettingsTile(
                            icon: Icons.dark_mode_outlined,
                            title: l10n.settingsDarkMode,
                            iconColor: iconColor,
                            textColor: textPrimary,
                            trailing: Switch(
                              value: notesProvider.isDarkMode,
                              onChanged: (value) {
                                notesProvider.setDarkMode(value);
                              },
                              activeColor: AppTheme.accentColor(notesProvider.themeColorIndex),
                            ),
                          ),
                          _SettingsDivider(color: dividerColor),
                          _SettingsTile(
                            icon: Icons.language,
                            title: l10n.settingsLanguage,
                            iconColor: iconColor,
                            textColor: textPrimary,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${l10n.currentLanguageFlag}  ${l10n.currentLanguageName}',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  color: textSecondary,
                                ),
                              ],
                            ),
                            onTap: () => _showLanguagePicker(context),
                          ),
                          _SettingsDivider(color: dividerColor),
                          _SettingsTile(
                            icon: Icons.color_lens_outlined,
                            title: l10n.settingsThemeColor,
                            iconColor: AppTheme.accentColor(notesProvider.themeColorIndex),
                            textColor: textPrimary,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: AppTheme.accentGradient(notesProvider.themeColorIndex),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right, color: textSecondary),
                              ],
                            ),
                            onTap: () => _showThemeColorPicker(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Security Section
                    Text(
                      l10n.settingsSecurity,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.lock_outline,
                            title: l10n.settingsNoteLock,
                            subtitle: notesProvider.appLockEnabled
                                ? l10n.settingsLockedRequirePin
                                : l10n.settingsLockedUnprotected,
                            iconColor: iconColor,
                            textColor: textPrimary,
                            trailing: Switch(
                              value: notesProvider.appLockEnabled,
                              onChanged: (value) =>
                                  _handleAppLockToggle(context, value, notesProvider),
                              activeColor: AppTheme.accentColor(notesProvider.themeColorIndex),
                            ),
                          ),
                          if (notesProvider.appLockEnabled) ...[
                            _SettingsDivider(color: dividerColor),
                            _SettingsTile(
                              icon: Icons.fingerprint,
                              title: l10n.settingsBiometric,
                              subtitle: l10n.settingsBiometricSubtitle,
                              iconColor: iconColor,
                              textColor: textPrimary,
                              trailing: Switch(
                                value: notesProvider.biometricEnabled,
                                onChanged: (value) {
                                  notesProvider.setBiometric(value);
                                },
                                activeColor: AppTheme.accentColor(notesProvider.themeColorIndex),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Theme Color Picker Sheet ────────────────────────────────────────────────

class _ThemeColorPickerSheet extends StatelessWidget {
  const _ThemeColorPickerSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final notesProvider = context.read<NotesProvider>();
    final selectedIndex = notesProvider.themeColorIndex;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.color_lens_outlined, color: AppTheme.primaryPurple, size: 24),
              const SizedBox(width: 12),
              Text(
                'Theme Color',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your accent color',
            style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: AppTheme.themeColors.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 16,
              crossAxisSpacing: 8,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, index) {
              final isSelected = index == selectedIndex;
              final colors = AppTheme.accentGradient(index);
              final name = AppTheme.themeColors[index]['name'] as String;
              return GestureDetector(
                onTap: () {
                  notesProvider.setThemeColor(index);
                  Navigator.pop(context);
                },
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: colors[0], width: 3)
                            : Border.all(color: Colors.transparent, width: 3),
                        boxShadow: isSelected
                            ? [BoxShadow(color: colors[0].withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))]
                            : [],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 22)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? colors[0] : textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Language Picker Sheet ───────────────────────────────────────────────────

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.read<LocaleProvider>();
    final currentCode = localeProvider.locale.languageCode;
    final isDark = AppTheme.isDarkMode(context);
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = AppTheme.getTextSecondaryColor(context);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.language, color: AppTheme.primaryPurple, size: 24),
              const SizedBox(width: 12),
              Text(
                l10n.languageSelect,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...AppLocalizations.supportedLocales.map((locale) {
            final code = locale.languageCode;
            final name = AppLocalizations.languageNameFor(code);
            final flag = AppLocalizations.flagFor(code);
            final isSelected = code == currentCode;

            return InkWell(
              onTap: () async {
                await localeProvider.setLocale(locale);
                if (context.mounted) Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryPurple.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: AppTheme.primaryPurple.withOpacity(0.4), width: 1.5)
                      : null,
                ),
                child: Row(
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected ? AppTheme.primaryPurple : textColor,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          color: AppTheme.primaryPurple, size: 20)
                    else
                      Icon(Icons.circle_outlined, color: textSecondary, size: 20),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── PIN Setup Sheet ────────────────────────────────────────────────────────

class _PinSetupSheet extends StatefulWidget {
  const _PinSetupSheet();

  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _firstPin;
  bool _confirming = false;
  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _shaking = false;

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
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _onDigit(String digit) async {
    if (_pin.length >= 4) return;
    final newPin = _pin + digit;
    setState(() => _pin = newPin);

    if (newPin.length == 4) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_confirming) {
        // Step 1: store first PIN, move to confirm
        setState(() {
          _firstPin = newPin;
          _pin = '';
          _confirming = true;
          _errorMessage = null;
        });
      } else {
        // Step 2: confirm
        if (newPin == _firstPin) {
          await AppLockService.savePin(newPin);
          if (mounted) Navigator.pop(context, true);
        } else {
          setState(() {
            _shaking = true;
            _pin = '';
            _errorMessage = 'PINs do not match. Try again.';
          });
          await _shakeController.forward(from: 0);
          if (mounted) setState(() => _shaking = false);
        }
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Icon(Icons.lock_outline, size: 40, color: AppTheme.primaryPurple),
          const SizedBox(height: 12),
          Text(
            _confirming ? 'Confirm your PIN' : 'Set a 4-digit PIN',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 13, color: Colors.red),
            )
          else
            Text(
              _confirming ? 'Re-enter your PIN to confirm' : 'This PIN protects your locked notes',
              style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.6)),
            ),
          const SizedBox(height: 28),
          // Dots
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) => Transform.translate(
              offset: Offset(_shaking ? _shakeAnimation.value : 0, 0),
              child: child,
            ),
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
          _buildPad(textColor),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: textColor.withOpacity(0.5))),
          ),
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
            _PadButton(label: '⌫', textColor: textColor, onTap: _onBackspace),
            _PadButton(label: '0', textColor: textColor, onTap: () => _onDigit('0')),
            const SizedBox(width: 72),
          ],
        ),
      ],
    );
  }
}

// ─── Shared pad button ───────────────────────────────────────────────────────

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

// ─── Settings tile / divider ─────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.onTap,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, color: textColor),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ─── Account Card ─────────────────────────────────────────────────────────────

class _AccountCard extends StatefulWidget {
  final Color accent;
  final List<Color> grad;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onSignOut;

  const _AccountCard({
    required this.accent,
    required this.grad,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onSignOut,
  });

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _uploadingPhoto = false;

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final bytes = await picked.readAsBytes();
      final url = await StorageHelper.uploadToFirebase(
        bytes,
        'profile_photos/${user.uid}.jpg',
        'image/jpeg',
      );
      await user.updatePhotoURL(url);
      await user.reload();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Tappable avatar with camera overlay
                GestureDetector(
                  onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                  child: Stack(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: widget.grad),
                        ),
                        child: _uploadingPhoto
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : (user.photoURL != null
                                ? ClipOval(
                                    child: Image.network(
                                      user.photoURL!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.person, color: Colors.white, size: 28)),
                      ),
                      if (!_uploadingPhoto)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: widget.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: widget.cardColor, width: 1.5),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 10),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'User',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email ?? '',
                        style: TextStyle(fontSize: 13, color: widget.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Google badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Google',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: widget.textSecondary.withOpacity(0.15), indent: 16, endIndent: 16),
          InkWell(
            onTap: widget.onSignOut,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 22),
                  const SizedBox(width: 14),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.red.shade300, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  final Color color;

  const _SettingsDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: color,
      indent: 56,
    );
  }
}
