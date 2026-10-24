import 'package:flutter/material.dart';

/// Central Design System & Theme Manager for Meeqat (المیقات)
/// Supports seamless live switching between obsidian Dark and minimalist Light themes.
class AppTheme {
  static final ValueNotifier<bool> isDarkNotifier = ValueNotifier<bool>(true);

  static bool get isDark => isDarkNotifier.value;
  static set isDark(bool val) => isDarkNotifier.value = val;

  static void toggle() {
    isDarkNotifier.value = !isDarkNotifier.value;
  }

  // --- Dynamic Color Tokens ---
  static Color get background => isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC);
  static Color get surface => isDark ? const Color(0xFF131D31) : Colors.white;
  static Color get surfaceElevated => isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  static Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  static Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  static Color get textMuted => isDark ? Colors.white54 : const Color(0xFF94A3B8);
  static Color get border => isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
  static Color get borderLight => isDark ? Colors.white12 : const Color(0xFFCBD5E1);
  static Color get cardBorder => isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
  static Color get cardHighlight => isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

  // Brand Accent Colors
  static Color get gold => isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
  static Color get emerald => isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
  static Color get sky => isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
  static Color get red => isDark ? Colors.redAccent : const Color(0xFFDC2626);

  // Navigation & Bottom Bar
  static Color get navBackground => isDark ? const Color(0xFF0F172A) : Colors.white;
  static Color get navBorder => isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);

  // Shadows
  static List<BoxShadow> get cardShadow => isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ]
      : [
          const BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          )
        ];

  static List<BoxShadow> get elevatedShadow => isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ]
      : [
          const BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          )
        ];

  // ThemeData Generators
  static ThemeData getTheme({required bool isUrdu, required bool isDarkMode}) {
    final font = isUrdu ? 'Jameel Noori Nastaleeq' : 'Segoe UI';
    if (isDarkMode) {
      return ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0F1D),
        primaryColor: const Color(0xFF10B981),
        fontFamily: font,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFFF59E0B),
          surface: Color(0xFF131D31),
          error: Colors.redAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      );
    } else {
      return ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        primaryColor: const Color(0xFF059669),
        fontFamily: font,
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF059669),
          secondary: Color(0xFFD97706),
          surface: Colors.white,
          error: Color(0xFFDC2626),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        ),
      );
    }
  }
}
