import 'package:flutter/material.dart';

/// Every icon the app uses, in one place.
///
/// The Expo app drew Ionicons. The Dart `ionicons` package cannot build against
/// Flutter 3.44 — it extends `IconData`, which is now a `final class` — and the
/// version that fixes it needs a newer Dart than this SDK ships. So these are
/// Material icons, which come bundled with the framework: one fewer dependency,
/// one fewer font to download, and consistent with the Material 3 theme the
/// rest of the app is built on.
///
/// Naming each one here rather than scattering `Icons.*` through the widgets
/// keeps the mapping from the original reviewable in a single file.
abstract final class AppIcons {
  // Navigation and chrome
  static const back = Icons.arrow_back;
  static const forward = Icons.arrow_forward;
  static const chevron = Icons.chevron_right;
  static const close = Icons.close;
  static const refresh = Icons.refresh;
  static const shuffle = Icons.shuffle;
  static const openExternal = Icons.open_in_new;

  // Theme toggle
  static const themeLight = Icons.light_mode;
  static const themeDark = Icons.dark_mode;

  // Event metadata
  static const calendar = Icons.calendar_month;
  static const calendarOutline = Icons.calendar_month_outlined;
  static const today = Icons.today_outlined;
  static const time = Icons.schedule_outlined;
  static const place = Icons.place_outlined;
  static const person = Icons.person_outline;
  static const price = Icons.payments_outlined;
  static const image = Icons.image_outlined;

  // Reminders
  static const bellOn = Icons.notifications;
  static const bellOff = Icons.notifications_outlined;

  /// The contact button.
  ///
  /// Material carries no WhatsApp mark, so this is a generic chat glyph. The
  /// button keeps the WhatsApp green and every label naming it says WhatsApp,
  /// which is what makes it recognisable.
  static const whatsapp = Icons.chat_bubble;

  // States
  static const offline = Icons.cloud_off_outlined;
  static const failure = Icons.error_outline;
  static const emptyCalendar = Icons.event_busy_outlined;
  static const brandFallback = Icons.casino_outlined;

  // "Por que jogar com a gente"
  static const community = Icons.groups_outlined;
  static const quality = Icons.emoji_events_outlined;
  static const upToDate = Icons.update;
  static const fun = Icons.favorite_outline;
}
