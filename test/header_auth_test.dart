import 'dart:async';

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
import 'package:tabletop_events/features/auth/auth_controller.dart';

import 'app_harness.dart';

/// The session has one door, and it is the Perfil tab.
///
/// The profile used to be an avatar in the header as well. Two doors to the
/// same room is one too many, so the header now carries only identity and the
/// theme toggle — and the session has to show through the tab instead.
void main() {
  testWidgets('the profile lives in the tab bar, not in the header', (
    tester,
  ) async {
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
    await settle(tester);

    // Nothing about the account up top any more, in either state.
    expect(find.byTooltip('Entrar'), findsNothing);
    expect(find.byTooltip('Meu Perfil'), findsNothing);
    expect(find.text('Perfil'), findsOne, reason: 'a aba é o caminho');

    // Not awaited: the controller sleeps to fake network latency, and under
    // the test binding's clock that future only completes while the tester
    // pumps. Awaiting it here would hang the test instead of failing it.
    unawaited(
      container.read(authProvider.notifier).loginWithEmail(
        email: 'jogador@tabletop.com.br',
        password: 'uma-senha-qualquer',
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    await tester.tap(find.text('Perfil'));
    await settle(tester);

    expect(
      find.textContaining('jogador@tabletop.com.br'),
      findsWidgets,
      reason: 'a aba mostra a sessão aberta',
    );

    unawaited(container.read(authProvider.notifier).logout());
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(
      find.textContaining('jogador@tabletop.com.br'),
      findsNothing,
      reason: 'e some assim que a sessão acaba',
    );
  });
}
