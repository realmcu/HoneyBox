import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // Realtek brand blue — used as the app's primary accent and all app-bar
  // backgrounds (with white foreground).
  static const Color primary = Color(0xFF0072BC);
  static const Color onPrimary = Colors.white;
  static const Color primaryContainer = Color(0xFFD3E3FD);
  static const Color secondary = Color(0xFF34A853);
  static const Color onSecondary = Colors.white;
  static const Color secondaryContainer = Color(0xFFCEEAD6);
  static const Color error = Color(0xFFEA4335);
  static const Color surface = Colors.white;
  static const Color surfaceContainerHighest = Color(0xFFF0F0F3);
  static const Color background = Color(0xFFF5F5F7);
  static const Color outline = Color(0xFFDADCE0);
  static const Color textPrimary = Color(0xFF1F1F1F);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color textTertiary = Color(0xFF9AA0A6);

  // Watch 应用的专属 accent（青绿）——与 app_catalog 中 AppId.watch 的 accent
  // 同值，用于 Watch 主页的状态摘要卡渐变。dark 为其加深版，作渐变终点。
  static const Color watchAccent = Color(0xFF2E7D6B);
  static const Color watchAccentDark = Color(0xFF256355);

  static const _lightColorScheme = ColorScheme.light(
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    error: error,
    surface: surface,
    surfaceContainerHighest: surfaceContainerHighest,
    outline: outline,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightColorScheme,
      scaffoldBackgroundColor: background,

      // ── AppBar ── (Realtek blue with white title/icons)
      appBarTheme: const AppBarTheme(
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: primary,
        foregroundColor: onPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: onPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outline.withValues(alpha: 0.3)),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── ElevatedButton ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── FilledButton ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Icon ──
      iconTheme: const IconThemeData(color: textSecondary, size: 24),

      // ── SnackBar ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: outline.withValues(alpha: 0.3),
        thickness: 1,
        space: 1,
      ),

      // ── Text ──
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary),
        displayMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w600, color: textPrimary),
        displaySmall: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
        headlineLarge: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
        headlineMedium: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary),
        titleSmall: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
        bodyLarge: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w400, color: textSecondary),
        bodyMedium: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
        bodySmall: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w400, color: textTertiary),
        labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
        labelMedium: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
        labelSmall: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w400, color: textTertiary),
      ),
    );
  }
}
