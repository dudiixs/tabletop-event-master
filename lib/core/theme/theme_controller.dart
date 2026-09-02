import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The [SharedPreferences] instance, read once during startup.
///
/// Overridden in `main` with the already-loaded instance, so nothing in the
/// widget tree ever awaits disk. That is what removes the white flash the Expo
/// app showed on every launch: its theme context started in light and only
/// then read the saved preference, and it exposed an `isLoading` flag that no
/// widget ever consumed.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('sharedPreferencesProvider precisa de override'),
);

/// The chosen theme, persisted across launches.
final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  /// Kept as the Expo key so an app updating in place keeps the user's choice.
  static const _legacyKey = 'app_theme';
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    final stored = prefs.getString(_key);
    if (stored != null) {
      return switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    }

    // Migrate the Expo preference, which only ever held 'light' or 'dark'.
    return switch (prefs.getString(_legacyKey)) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      // Follow the device by default. The Expo app ignored the system setting
      // even though its own config asked for `userInterfaceStyle: automatic`.
      _ => ThemeMode.system,
    };
  }

  /// Whether the app is currently rendering dark, resolving [ThemeMode.system]
  /// against [platformBrightness].
  bool isDark(Brightness platformBrightness) => switch (state) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system => platformBrightness == Brightness.dark,
      };

  /// Flips between light and dark, which is what the header button does.
  ///
  /// Starting from [ThemeMode.system] it commits to the opposite of whatever
  /// the device is showing, so the first tap always visibly changes something.
  Future<void> toggle(Brightness platformBrightness) =>
      select(isDark(platformBrightness) ? ThemeMode.light : ThemeMode.dark);

  /// Sets the mode explicitly, including back to [ThemeMode.system].
  Future<void> select(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}
