import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Builds the two [ThemeData]s from the app's palettes.
///
/// Material components are wired to the same tokens the custom widgets use, so
/// a dialog, a bottom sheet, a snack bar or a FAB ripple comes out on-brand
/// without each call site restyling it.
abstract final class AppTheme {
  static ThemeData light() => _build(AppPalette.light, Brightness.light);
  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
    ).copyWith(
      primary: palette.primary,
      onPrimary: Colors.white,
      surface: palette.background,
      onSurface: palette.text,
      error: palette.error,
      onError: Colors.white,
      outlineVariant: palette.border,
    );

    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: palette.surface,
      // The system font on every platform. The Expo app named 'System'
      // explicitly for the calendar; here it is simply the default.
      fontFamily: null,
    );

    return base.copyWith(
      extensions: [palette],
      textTheme: _textTheme(base.textTheme, palette),
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: palette.textSecondary),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: 0.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: palette.textSecondary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: palette.text,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: palette.textSecondary,
          fontSize: 15,
          height: 1.45,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? palette.card : const Color(0xFF2D4150),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.primary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.primary.withValues(alpha: 0.12),
        side: BorderSide(color: palette.primary.withValues(alpha: 0.25)),
        labelStyle: TextStyle(
          color: palette.primary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
      ),
      // 48dp minimum on every tap target. The Expo cards relied on padding
      // and some of the icon buttons came out under the accessible minimum.
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  static TextTheme _textTheme(TextTheme base, AppPalette palette) {
    return base
        .copyWith(
          headlineLarge: base.headlineLarge?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: base.bodyLarge?.copyWith(fontSize: 15.5, height: 1.5),
          bodyMedium: base.bodyMedium?.copyWith(fontSize: 14.5, height: 1.45),
          bodySmall: base.bodySmall?.copyWith(fontSize: 13, height: 1.4),
          labelLarge: base.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        )
        .apply(bodyColor: palette.text, displayColor: palette.text);
  }
}
