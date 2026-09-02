import 'package:flutter/material.dart';

/// The app's own colour tokens, carried on the [ThemeData] itself.
///
/// These are the thirteen tokens the Expo theme context defined, plus the two
/// values it computed inline in the header and hero. Putting them on a
/// [ThemeExtension] means a widget reads `context.palette.card` instead of
/// reaching into a global — so there is exactly one source of truth for colour,
/// and the light and dark sets are guaranteed to have the same shape.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.background,
    required this.surface,
    required this.card,
    required this.text,
    required this.textSecondary,
    required this.border,
    required this.success,
    required this.warning,
    required this.error,
    required this.shadow,
    required this.brand,
    required this.onBrand,
    required this.onBrandMuted,
  });

  /// The brand indigo. The same value in both themes — it is the identity.
  final Color primary;

  /// The window behind everything.
  final Color background;

  /// The ground a screen's content sits on.
  final Color surface;

  /// A raised card.
  final Color card;

  final Color text;
  final Color textSecondary;
  final Color border;

  /// Semantic colours, kept apart from [primary] so a price chip and a primary
  /// button never collapse into the same hue.
  final Color success;
  final Color warning;
  final Color error;

  final Color shadow;

  /// The header and hero ground: brand indigo in light, near-black in dark.
  /// The Expo app recomputed this inline in two components; it is one token now.
  final Color brand;

  /// Content on top of [brand].
  final Color onBrand;

  /// Secondary content on top of [brand].
  final Color onBrandMuted;

  /// The app's light palette, matching the Expo theme value for value.
  static const light = AppPalette(
    primary: Color(0xFF5166C6),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF8F9FA),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF2D4150),
    textSecondary: Color(0xFF666666),
    border: Color(0xFFE0E0E0),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    shadow: Color(0x1A000000),
    brand: Color(0xFF5166C6),
    onBrand: Color(0xFFFFFFFF),
    onBrandMuted: Color(0xE6FFFFFF),
  );

  /// The app's dark palette. Pure black ground with raised `#1E1E1E` cards, as
  /// the Expo theme had it.
  static const dark = AppPalette(
    primary: Color(0xFF5166C6),
    background: Color(0xFF000000),
    surface: Color(0xFF000000),
    card: Color(0xFF1E1E1E),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA0A0A0),
    border: Color(0xFF333333),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    shadow: Color(0x1AFFFFFF),
    brand: Color(0xFF1E1E1E),
    onBrand: Color(0xFFFFFFFF),
    onBrandMuted: Color(0xE6FFFFFF),
  );

  /// The colour that reads a given [EventStatus]-ish state.
  Color statusColor({required bool isOpen, required bool isCancelled}) {
    if (isCancelled) return error;
    return isOpen ? success : warning;
  }

  @override
  AppPalette copyWith({
    Color? primary,
    Color? background,
    Color? surface,
    Color? card,
    Color? text,
    Color? textSecondary,
    Color? border,
    Color? success,
    Color? warning,
    Color? error,
    Color? shadow,
    Color? brand,
    Color? onBrand,
    Color? onBrandMuted,
  }) =>
      AppPalette(
        primary: primary ?? this.primary,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        card: card ?? this.card,
        text: text ?? this.text,
        textSecondary: textSecondary ?? this.textSecondary,
        border: border ?? this.border,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        error: error ?? this.error,
        shadow: shadow ?? this.shadow,
        brand: brand ?? this.brand,
        onBrand: onBrand ?? this.onBrand,
        onBrandMuted: onBrandMuted ?? this.onBrandMuted,
      );

  /// Interpolates every token, so switching themes animates instead of
  /// snapping — the calendar in the Expo app had to be force-remounted with a
  /// changing key to pick up a theme change at all.
  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      onBrandMuted: Color.lerp(onBrandMuted, other.onBrandMuted, t)!,
    );
  }
}

/// Reads the app's tokens off the nearest theme.
extension PaletteAccess on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  /// A tint of [color] at [opacity], replacing the `color + '20'` hex-suffix
  /// trick the Expo styles used in dozens of places.
  Color tint(Color color, [double opacity = 0.12]) =>
      color.withValues(alpha: opacity);
}
