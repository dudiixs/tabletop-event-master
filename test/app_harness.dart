import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletop_events/core/config/app_config.dart';
import 'package:tabletop_events/core/format/formatters.dart';
import 'package:tabletop_events/core/theme/app_theme.dart';
import 'package:tabletop_events/core/theme/theme_controller.dart';
import 'package:tabletop_events/data/events_data_source.dart';
import 'package:tabletop_events/data/events_providers.dart';
import 'package:tabletop_events/domain/calendar_date.dart';
import 'package:tabletop_events/domain/event.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Serves a fixed agenda, or fails on demand.
class FakeDataSource implements EventsDataSource {
  FakeDataSource({this.events = const [], this.failure});

  List<Event> events;
  EventsFailure? failure;
  int calls = 0;

  @override
  Future<List<Event>> fetchEvents() async {
    calls++;
    final failure = this.failure;
    if (failure != null) throw failure;
    return events;
  }
}

/// An event `dayOffset` days from today.
Event testEvent({
  required String id,
  String name = 'Torneio de Pokémon TCG',
  int dayOffset = 1,
  int hour = 19,
  int minute = 30,
  double? price = 35,
  String location = 'TableTop Sorocaba',
  EventStatus status = EventStatus.available,
  List<RichRun> description = const [
    RichRun(text: 'Traga seu '),
    RichRun(text: 'deck', bold: true),
    RichRun(text: ' completo.'),
  ],
  List<String> tags = const ['Competitivo', 'Pokémon'],
  String organizer = 'Eduardo Martins',
  String? imageUrl,
  String? pageUrl,
}) =>
    Event(
      id: id,
      name: name,
      day: addDays(today(), dayOffset),
      time: (hour: hour, minute: minute),
      price: price,
      location: location,
      status: status,
      description: description,
      tags: tags,
      organizer: organizer,
      imageUrl: imageUrl,
      pageUrl: pageUrl,
    );

/// Mounts [child] with the app's theme, locale and providers.
///
/// Not `TableTopApp` itself, so a test can mount one screen instead of the
/// whole router — but the same theme and localizations, so what the test sees
/// is what the app renders.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  FakeDataSource? dataSource,
  Size size = const Size(420, 1400),
  List<Override> overrides = const [],
}) async {
  initializeDateFormatting(Fmt.locale);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();

  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        appConfigProvider.overrideWithValue(
          const AppConfig(backend: EventsBackend.fixtures),
        ),
        if (dataSource != null)
          eventsDataSourceProvider.overrideWithValue(dataSource),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    ),
  );
}

/// Lets the agenda future resolve and the screen settle.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}
