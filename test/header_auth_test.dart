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

/// The header's profile button has to follow the session.
///
/// It watched `authProvider.notifier` instead of `authProvider`, and the
/// notifier is a stable object: the state could change all it liked and this
/// header never rebuilt. Because `AppShell` builds it as `const AppHeader()`,
/// a parent rebuild did not save it either, so the avatar stayed on whatever
/// the first frame showed until something else in the header changed.
void main() {
  testWidgets('the header follows the session in and out', (tester) async {
    initializeDateFormatting(Fmt.locale);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    tester.view
      ..physicalSize = const Size(420, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      appConfigProvider.overrideWithValue(
        const AppConfig(backend: EventsBackend.fixtures),
      ),
      eventsDataSourceProvider.overrideWithValue(FakeDataSource()),
    ]);
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

    expect(find.byTooltip('Entrar'), findsOne);
    expect(find.byTooltip('Meu Perfil'), findsNothing);

    // Not awaited: the controller sleeps to fake network latency, and under
    // the test binding's clock that future only completes while the tester
    // pumps. Awaiting it here would hang the test instead of failing it.
    unawaited(container.read(authProvider.notifier).loginWithEmail(
          email: 'jogador@tabletop.com.br',
          password: 'uma-senha-qualquer',
        ));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(find.byTooltip('Meu Perfil'), findsOne,
        reason: 'o avatar aparece assim que a sessão existe');
    expect(find.text('J'), findsWidgets, reason: 'a inicial do nome');

    unawaited(container.read(authProvider.notifier).logout());
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(find.byTooltip('Entrar'), findsOne,
        reason: 'e some assim que a sessão acaba');
  });
}
