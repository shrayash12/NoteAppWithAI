import 'package:flutter/material.dart';

class AppTheme {
  // Theme accent color options
  static const List<Map<String, dynamic>> themeColors = [
    // — Vibrant —
    {'name': 'Purple',      'color': Color(0xFF8B5CF6), 'gradient': [Color(0xFF8B5CF6), Color(0xFFD946EF)]},
    {'name': 'Blue',        'color': Color(0xFF3B82F6), 'gradient': [Color(0xFF3B82F6), Color(0xFF60A5FA)]},
    {'name': 'Indigo',      'color': Color(0xFF6366F1), 'gradient': [Color(0xFF6366F1), Color(0xFF8B5CF6)]},
    {'name': 'Teal',        'color': Color(0xFF14B8A6), 'gradient': [Color(0xFF14B8A6), Color(0xFF06B6D4)]},
    {'name': 'Cyan',        'color': Color(0xFF06B6D4), 'gradient': [Color(0xFF06B6D4), Color(0xFF3B82F6)]},
    {'name': 'Green',       'color': Color(0xFF10B981), 'gradient': [Color(0xFF10B981), Color(0xFF22C55E)]},
    {'name': 'Lt Green',    'color': Color(0xFF4ADE80), 'gradient': [Color(0xFF4ADE80), Color(0xFF10B981)]},
    {'name': 'Lime',        'color': Color(0xFF84CC16), 'gradient': [Color(0xFF84CC16), Color(0xFF4ADE80)]},
    {'name': 'Yellow',      'color': Color(0xFFEAB308), 'gradient': [Color(0xFFEAB308), Color(0xFFFBBF24)]},
    {'name': 'Amber',       'color': Color(0xFFF59E0B), 'gradient': [Color(0xFFF59E0B), Color(0xFFFBBF24)]},
    {'name': 'Orange',      'color': Color(0xFFF97316), 'gradient': [Color(0xFFF97316), Color(0xFFFB923C)]},
    {'name': 'Rose',        'color': Color(0xFFEC4899), 'gradient': [Color(0xFFEC4899), Color(0xFFF43F5E)]},
    {'name': 'Brown',       'color': Color(0xFF92400E), 'gradient': [Color(0xFF92400E), Color(0xFFB45309)]},
    {'name': 'Gray',        'color': Color(0xFF6B7280), 'gradient': [Color(0xFF6B7280), Color(0xFF9CA3AF)]},
    // — Professional Light —
    {'name': 'Sky',         'color': Color(0xFF0EA5E9), 'gradient': [Color(0xFF0EA5E9), Color(0xFF38BDF8)]},
    {'name': 'Slate Blue',  'color': Color(0xFF475569), 'gradient': [Color(0xFF475569), Color(0xFF64748B)]},
    {'name': 'Steel',       'color': Color(0xFF4A90A4), 'gradient': [Color(0xFF4A90A4), Color(0xFF6BB8CC)]},
    {'name': 'Sage',        'color': Color(0xFF7C9A7E), 'gradient': [Color(0xFF7C9A7E), Color(0xFF9BB89D)]},
    {'name': 'Dusty Rose',  'color': Color(0xFFB07A8A), 'gradient': [Color(0xFFB07A8A), Color(0xFFC9909E)]},
    {'name': 'Mauve',       'color': Color(0xFF9B7FA6), 'gradient': [Color(0xFF9B7FA6), Color(0xFFB89DC0)]},
    {'name': 'Warm Tan',    'color': Color(0xFFA0846C), 'gradient': [Color(0xFFA0846C), Color(0xFFBFA08A)]},
    {'name': 'Midnight',    'color': Color(0xFF2D3561), 'gradient': [Color(0xFF2D3561), Color(0xFF4A5299)]},
    {'name': 'Forest',      'color': Color(0xFF2D6A4F), 'gradient': [Color(0xFF2D6A4F), Color(0xFF40916C)]},
    {'name': 'Burgundy',    'color': Color(0xFF8B2252), 'gradient': [Color(0xFF8B2252), Color(0xFFB5446E)]},
  ];

  static Color accentColor(int index) =>
      themeColors[index.clamp(0, themeColors.length - 1)]['color'] as Color;

  static List<Color> accentGradient(int index) =>
      List<Color>.from(themeColors[index.clamp(0, themeColors.length - 1)]['gradient'] as List);

  // Note card background colors — 6 pastel shades
  static const List<Color> noteCardColors = [
    Color(0xFFEDE9FE), // lavender
    Color(0xFFD1FAE5), // mint green
    Color(0xFFFFEDD5), // peach
    Color(0xFFF3F4F6), // soft gray
    Color(0xFFBEBF5C), // lime light (top shade)
    Color(0xFFDDE1FF), // midnight-100
  ];

  // Dark mode tinted card backgrounds (accent color at low opacity on dark base)
  static const List<Color> noteCardDarkColors = [
    Color(0xFF1D1A35), // dark purple  (lavender family)
    Color(0xFF0E1F18), // dark green   (mint family)
    Color(0xFF261812), // dark orange  (peach family)
    Color(0xFF161920), // dark slate   (gray family)
    Color(0xFF1A1E10), // dark olive   (lime family)
    Color(0xFF0E1120), // dark indigo  (midnight family)
  ];

  // Fixed dark text for pastel note cards — light mode only
  static const Color noteCardTextPrimary = Color(0xFF1F2937);
  static const Color noteCardTextSecondary = Color(0xFF6B7280);

  // Dynamic helpers — call these in build methods
  static Color noteCardBg(BuildContext context, int hash) =>
      isDarkMode(context)
          ? noteCardDarkColors[hash]
          : noteCardColors[hash];

  static Color noteCardText(BuildContext context) =>
      isDarkMode(context) ? _darkTextPrimary : noteCardTextPrimary;

  static Color noteCardSubText(BuildContext context) =>
      isDarkMode(context) ? _darkTextSecondary : noteCardTextSecondary;

  // Darker shades of the same family — used for thumbnails on each card
  static const List<Color> noteCardAccentColors = [
    Color(0xFF8B5CF6), // violet-500   (lavender cards)
    Color(0xFF10B981), // emerald-500  (mint green cards)
    Color(0xFFF97316), // orange-500   (peach cards)
    Color(0xFF6B7280), // gray-500     (soft gray cards)
    Color(0xFF787020), // lime dark (bottom shade, for lime cards)
    Color(0xFF3730A3), // indigo-800   (midnight cards)
  ];

  // Primary gradient colors
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color primaryMagenta = Color(0xFFD946EF);
  static const Color primaryPink = Color(0xFFEC4899);

  // Light mode colors
  static const Color _lightBackground = Color(0xFFF5F5F5);
  static const Color _lightCardBackground = Colors.white;
  static const Color _lightTextPrimary = Color(0xFF1F2937);
  static const Color _lightTextSecondary = Color(0xFF6B7280);

  // Dark mode colors
  static const Color _darkBackground = Color(0xFF0F172A);
  static const Color _darkCardBackground = Color(0xFF1E293B);
  static const Color _darkSurface = Color(0xFF334155);
  static const Color _darkTextPrimary = Color(0xFFF1F5F9);
  static const Color _darkTextSecondary = Color(0xFF94A3B8);

  // Legacy static colors (for backwards compatibility)
  static const Color backgroundColor = _lightBackground;
  static const Color cardBackground = _lightCardBackground;
  static const Color textPrimary = _lightTextPrimary;
  static const Color textSecondary = _lightTextSecondary;
  static const Color textLight = Colors.white;

  // Folder icon colors
  static const Color folderPurple = Color(0xFF8B5CF6);
  static const Color folderBlue = Color(0xFF3B82F6);
  static const Color folderPink = Color(0xFFEC4899);
  static const Color folderYellow = Color(0xFFEAB308);
  static const Color folderGreen = Color(0xFF22C55E);
  static const Color folderOrange = Color(0xFFF97316);

  // Gradient for header
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF8B5CF6),
      Color(0xFFD946EF),
      Color(0xFFEC4899),
    ],
  );

  // Gradient for FAB
  static const LinearGradient fabGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD946EF),
      Color(0xFF8B5CF6),
    ],
  );

  // Stats card gradients
  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
  );

  static const LinearGradient pinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
  );

  // Helper methods to get colors based on theme
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkBackground
        : _lightBackground;
  }

  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkCardBackground
        : _lightCardBackground;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkSurface
        : Colors.grey.shade100;
  }

  static Color getTextPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkTextPrimary
        : _lightTextPrimary;
  }

  static Color getTextSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkTextSecondary
        : _lightTextSecondary;
  }

  static Color getDividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade200;
  }

  static Color getIconColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkTextSecondary
        : Colors.grey.shade700;
  }

  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static ThemeData lightTheme([Color seedColor = primaryPurple]) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _lightTextPrimary),
        titleTextStyle: TextStyle(
          color: _lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: _lightCardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryPurple,
        unselectedItemColor: _lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _lightCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
      ),
    );
  }

  static ThemeData darkTheme([Color seedColor = primaryPurple]) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
        surface: _darkCardBackground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _darkTextPrimary),
        titleTextStyle: TextStyle(
          color: _darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: _darkCardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkCardBackground,
        selectedItemColor: primaryPurple,
        unselectedItemColor: _darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _darkCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _darkSurface,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.1),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _darkCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryPurple;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryPurple.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.3);
        }),
      ),
    );
  }
}
