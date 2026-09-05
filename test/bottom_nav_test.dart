import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletop_events/core/config/app_config.dart';
import 'package:tabletop_events/core/format/formatters.dart';
import 'package:tabletop_events/core/router/app_router.dart';
import 'package:tabletop_events/core/theme/app_theme.dart';
import 'package:tabletop_events/core/theme/theme_controller.dart';
import 'package:tabletop_events/data/events_providers.dart';
import 'package:tabletop_events/features/calendar/calendar_screen.dart';
import 'package:tabletop_events/features/play/ui/play_screen.dart';
import 'package:tabletop_events/features/profile/profile_screen.dart';
import 'package:tabletop_events/features/rentals/rentals_screen.dart';
import 'package:tabletop_events/features/weekly/weekly_screen.dart';

import 'app_harness.dart';

/// The tab bar has to know where it is.
///
/// The shell used to build its header as `const AppHeader()`, so Flutter reused
/// the identical widget across navigations and the header never noticed it had
/// moved — the back arrow stayed hidden off the home screen. A `const` tab bar
/// would have inherited exactly that bug and stayed lit on the first tab
/// forever, so the shell hands the location down to both.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    initializeDateFormatting(Fmt.locale);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    tester.view
      ..physicalSize = const Size(420, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        appConfigProvider.overrideWithValue(
          const AppConfig(backend: EventsBackend.fixtures),
        ),
        eventsDataSourceProvider.overrideWithValue(FakeDataSource()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: buildRouter(),
          theme: AppTheme.light(),
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every destination is on the bar', (tester) async {
    await pumpApp(tester);

    for (final label in ['Início', 'Eventos', 'PLAY', 'Locação', 'Perfil']) {
      expect(find.text(label), findsOne, reason: label);
    }
  });

  testWidgets('the PLAY tab opens the counter setup', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayScreen), findsOne);
    expect(find.text('Commander'), findsOne);
  });

  testWidgets('the Locação tab opens the shelf', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Locação'));
    await tester.pumpAndSettle();

    expect(find.byType(RentalsScreen), findsOne);
  });

  testWidgets('leaving home reveals the back arrow', (tester) async {
    await pumpApp(tester);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    await tester.tap(find.text('Eventos'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOne);
  });

  testWidgets('Eventos opens the week, which reaches the calendar', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Eventos'));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyScreen), findsOne);

    // The calendar lost its own tab, so the week has to carry the way in.
    await tester.tap(find.text('Calendário'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen), findsOne);
  });

  testWidgets('Perfil is a tab, and offers the login when logged out', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOne);
  });
}
