import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletop_events/core/format/formatters.dart';
import 'package:tabletop_events/core/theme/app_palette.dart';
import 'package:tabletop_events/core/theme/app_theme.dart';
import 'package:tabletop_events/core/theme/theme_controller.dart';
import 'package:tabletop_events/domain/event.dart';

import 'app_harness.dart';

/// Builds a container with the given stored preferences.
Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(preferences),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(() => initializeDateFormatting(Fmt.locale));

  group('theme mode', () {
    test('follows the device when nothing was ever chosen', () async {
      // The Expo theme context started in light and ignored the system setting
      // entirely, despite its own config asking for `automatic`.
      final container = await containerWith({});

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('restores an explicit choice', () async {
      final container = await containerWith({'theme_mode': 'dark'});

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('migrates the Expo preference key', () async {
      // Someone updating in place keeps the theme they had.
      final container = await containerWith({'app_theme': 'dark'});

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('the new key wins over the legacy one', () async {
      final container = await containerWith({
        'app_theme': 'dark',
        'theme_mode': 'light',
      });

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('toggling from system commits to the opposite of the device',
        () async {
      final container = await containerWith({});
      final controller = container.read(themeModeProvider.notifier);

      await controller.toggle(Brightness.dark);
      expect(container.read(themeModeProvider), ThemeMode.light);

      await controller.toggle(Brightness.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('a choice is written to disk so it survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ]);
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).select(ThemeMode.dark);

      // What a fresh launch would read back.
      expect(preferences.getString('theme_mode'), 'dark');

      final relaunched = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ]);
      addTearDown(relaunched.dispose);
      expect(relaunched.read(themeModeProvider), ThemeMode.dark);
    });

    test('resolves system against the platform brightness', () async {
      final container = await containerWith({});
      final controller = container.read(themeModeProvider.notifier);

      expect(controller.isDark(Brightness.dark), isTrue);
      expect(controller.isDark(Brightness.light), isFalse);

      await controller.select(ThemeMode.dark);
      expect(controller.isDark(Brightness.light), isTrue,
          reason: 'uma escolha explicita ganha do sistema');
    });
  });

  group('palette', () {
    test('light and dark define the same tokens', () {
      // A ThemeExtension makes this structural: both are the same class, so a
      // token can never exist in one theme and be missing in the other.
      expect(AppPalette.light.primary, AppPalette.dark.primary,
          reason: 'a cor da marca e a identidade, igual nos dois temas');
      expect(AppPalette.light.background, isNot(AppPalette.dark.background));
      expect(AppPalette.light.brand, const Color(0xFF5166C6));
      expect(AppPalette.dark.brand, const Color(0xFF1E1E1E));
    });

    test('interpolates every token on a theme change', () {
      final middle = AppPalette.light.lerp(AppPalette.dark, 0.5);

      expect(middle.background, isNot(AppPalette.light.background));
      expect(middle.card, isNot(AppPalette.light.card));
    });

    test('is attached to both ThemeData objects', () {
      expect(AppTheme.light().extension<AppPalette>(), AppPalette.light);
      expect(AppTheme.dark().extension<AppPalette>(), AppPalette.dark);
    });

    testWidgets('context.palette reads the active theme', (tester) async {
      late AppPalette seen;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(builder: (context) {
          seen = context.palette;
          return const SizedBox();
        }),
      ));

      expect(seen.background, AppPalette.dark.background);
    });
  });

  group('formatters', () {
    test('prices distinguish free, priced and unset', () {
      expect(Fmt.price(testEvent(id: 'a', price: 0)), 'Gratuito');
      expect(Fmt.price(testEvent(id: 'b', price: null)), 'A definir');
      expect(Fmt.price(testEvent(id: 'c', price: 35.5)), contains('35,50'));
      expect(Fmt.price(testEvent(id: 'd', price: 35.5)), startsWith(r'R$'));
    });

    test('times pad and fall back', () {
      final event = testEvent(id: 'a', hour: 9, minute: 5);
      expect(Fmt.time(event), '09:05');

      final noTime = Event(
        id: 'b',
        name: 'Sem hora',
        day: DateTime(2025, 9, 10),
        location: 'Sede',
        status: EventStatus.available,
        description: const [],
        tags: const [],
        organizer: 'Alguém',
      );
      expect(Fmt.time(noTime), 'Horário a confirmar');
    });

    test('dates read in Portuguese', () {
      final day = DateTime(2025, 9, 10);

      expect(Fmt.fullDate(day), 'Quarta-feira, 10 de setembro de 2025');
      expect(Fmt.longDate(day), '10 de setembro de 2025');
      expect(Fmt.dayMonthWeekday(day), 'Qua., 10 de set.');
      expect(Fmt.monthBadge(day), 'SET');
      expect(Fmt.monthYear(day), 'Setembro de 2025');
    });

    test('relative days read naturally', () {
      expect(Fmt.relativeDay(0), 'Hoje');
      expect(Fmt.relativeDay(1), 'Amanhã');
      expect(Fmt.relativeDay(3), 'Em 3 dias');
      expect(Fmt.relativeDay(9), 'Semana que vem');
      expect(Fmt.relativeDay(-1), 'Já aconteceu');
    });

    test('event counts agree in number', () {
      expect(Fmt.eventCount(0), 'Nenhum evento');
      expect(Fmt.eventCount(1), '1 evento');
      expect(Fmt.eventCount(4), '4 eventos');
    });
  });
}
