import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletop_events/core/theme/app_icons.dart';
import 'package:tabletop_events/data/events_data_source.dart';
import 'package:tabletop_events/features/events/event_details_sheet.dart';
import 'package:tabletop_events/features/events/events_list.dart';
import 'package:tabletop_events/features/home/home_screen.dart';
import 'package:tabletop_events/features/weekly/weekly_screen.dart';
import 'package:tabletop_events/domain/event.dart';

import 'app_harness.dart';

void main() {
  group('WeeklyScreen', () {
    testWidgets("lists today's event", (tester) async {
      // The Expo week filter dropped events happening today. This is that bug
      // as a screen test.
      final source = FakeDataSource(events: [
        testEvent(id: 'hoje', name: 'Liga de hoje', dayOffset: 0),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);

      expect(find.text('Liga de hoje'), findsOne);
      expect(find.textContaining('Hoje'), findsWidgets);
    });

    testWidgets('covers seven days and excludes the eighth', (tester) async {
      final source = FakeDataSource(events: [
        for (var offset = 0; offset < 9; offset++)
          testEvent(id: 'd$offset', name: 'Dia $offset', dayOffset: offset),
      ]);

      await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        size: const Size(420, 4200),
      );
      await settle(tester);

      for (var offset = 0; offset < 7; offset++) {
        expect(find.text('Dia $offset'), findsOne, reason: 'dia $offset entra');
      }
      expect(find.text('Dia 7'), findsNothing, reason: 'o oitavo dia fica fora');
      expect(find.text('Dia 8'), findsNothing);
    });

    testWidgets('excludes a past event', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'ontem', name: 'Já passou', dayOffset: -1),
        testEvent(id: 'amanha', name: 'Vem aí', dayOffset: 1),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);

      expect(find.text('Já passou'), findsNothing);
      expect(find.text('Vem aí'), findsOne);
    });

    testWidgets('shows the empty state, not an error', (tester) async {
      await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: FakeDataSource(events: const []),
      );
      await settle(tester);

      expect(find.text('Nenhum evento nos próximos 7 dias'), findsOne);
    });

    testWidgets('shows an error with a retry when the fetch fails',
        (tester) async {
      // In the Expo app this state rendered as "Nenhum evento encontrado" with
      // no way to try again.
      final source = FakeDataSource(
        failure: const EventsFailure('Sem conexão com a internet.',
            isOffline: true),
      );

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);

      expect(find.text('Sem conexão'), findsOne);
      expect(find.text('Sem conexão com a internet.'), findsOne);
      expect(find.text('Tentar novamente'), findsOne);
      expect(find.text('Nenhum evento nos próximos 7 dias'), findsNothing);
    });

    testWidgets('retry refetches and then renders the agenda', (tester) async {
      final source = FakeDataSource(
        failure: const EventsFailure('Sem conexão com a internet.'),
      );

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);
      expect(source.calls, 1);

      source
        ..failure = null
        ..events = [testEvent(id: 'ok', name: 'Voltou', dayOffset: 1)];

      await tester.tap(find.text('Tentar novamente'));
      await settle(tester);

      expect(source.calls, 2);
      expect(find.text('Voltou'), findsOne);
    });

    testWidgets('offers pull-to-refresh', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'a', dayOffset: 1),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);

      expect(find.byType(RefreshIndicator), findsOne);
    });
  });

  group('HomeScreen', () {
    testWidgets('counts the week and the whole agenda', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'a', dayOffset: 0),
        testEvent(id: 'b', dayOffset: 3),
        testEvent(id: 'c', dayOffset: 20),
        testEvent(id: 'past', dayOffset: -5),
      ]);

      await pumpScreen(
        tester,
        const HomeScreen(),
        dataSource: source,
        size: const Size(420, 2600),
      );
      await settle(tester);

      // Two inside the week, three upcoming, the past one counted nowhere.
      expect(find.text('2 EVENTOS'), findsOne);
      expect(find.text('3 NA AGENDA'), findsOne);
    });

    testWidgets('features an upcoming event', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'a', name: 'Draft Semanal', dayOffset: 2),
      ]);

      await pumpScreen(
        tester,
        const HomeScreen(),
        dataSource: source,
        size: const Size(420, 2600),
      );
      await settle(tester);

      expect(find.textContaining('Draft Semanal'), findsWidgets);
    });

    testWidgets('says so when the agenda is empty', (tester) async {
      await pumpScreen(
        tester,
        const HomeScreen(),
        dataSource: FakeDataSource(events: const []),
        size: const Size(420, 2600),
      );
      await settle(tester);

      expect(find.text('🎲 Nada marcado ainda'), findsOne);
      expect(find.text('NADA ESTA SEMANA'), findsOne);
      expect(find.text('AGENDA VAZIA'), findsOne);
    });

    testWidgets('surfaces a fetch failure in the featured card',
        (tester) async {
      await pumpScreen(
        tester,
        const HomeScreen(),
        dataSource: FakeDataSource(
          failure: const EventsFailure('Sem conexão com a internet.'),
        ),
        size: const Size(420, 2600),
      );
      await settle(tester);

      expect(find.text('Sem conexão com a internet.'), findsOne);
      expect(find.text('Tentar novamente'), findsOne);
    });
  });

  group('event card', () {
    testWidgets('shows price, place, time and category', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'a', dayOffset: 1, price: 35, hour: 19, minute: 30),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);

      expect(find.textContaining('19:30'), findsWidgets);
      expect(find.text('TableTop Sorocaba'), findsOne);
      expect(find.text('Pokémon TCG'), findsOne);
      expect(find.textContaining('35,00'), findsOne);
    });

    testWidgets('a free event reads "Gratuito"', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'a', dayOffset: 1, price: 0),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);

      expect(find.text('Gratuito'), findsOne);
    });

    testWidgets('an unset price reads "A definir", not "Gratuito"',
        (tester) async {
      // The Expo card coerced an empty Notion field to 0 and announced it free.
      final source = FakeDataSource(events: [
        testEvent(id: 'a', dayOffset: 1, price: null),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);

      expect(find.text('A definir'), findsOne);
      expect(find.text('Gratuito'), findsNothing);
    });

    testWidgets('a cancelled event is not labelled available', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'a', dayOffset: 1, status: EventStatus.cancelled),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);

      expect(find.text('Cancelado'), findsOne);
      expect(find.text('Disponível'), findsNothing);
    });

    testWidgets('an unmapped status asks for confirmation', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'a', dayOffset: 1, status: EventStatus.unknown),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);

      expect(find.text('Confirmar'), findsOne);
      expect(find.text('Disponível'), findsNothing);
    });

    testWidgets('flattens the rich description into the preview',
        (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'a', dayOffset: 1),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);

      // One run of text, not three stacked blocks.
      expect(find.text('Traga seu deck completo.'), findsOne);
    });
  });

  group('EventDetailsSheet', () {
    testWidgets('opens on tap and shows the event detail', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'a', name: 'Draft Semanal', dayOffset: 1),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);

      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);

      expect(find.byType(EventDetailsSheet), findsOne);
      expect(find.text('Local'), findsOne);
      expect(find.text('Organizador'), findsOne);
      expect(find.text('Eduardo Martins'), findsOne);
      expect(find.text('Valor'), findsOne);
      expect(find.text('Vagas disponíveis'), findsOne);
    });

    testWidgets('shows one description section, not two', (tester) async {
      // The Expo sheet rendered "Resumo" and "Descrição Completa" from the same
      // Notion field, so the text appeared twice.
      final source = FakeDataSource(events: [
        testEvent(id: 'a', name: 'Draft Semanal', dayOffset: 1),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);
      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);

      expect(find.text('Sobre o evento'), findsOne);
      expect(find.text('Resumo'), findsNothing);
      expect(find.text('Descrição Completa'), findsNothing);
    });

    testWidgets('renders each tag as its own chip', (tester) async {
      // Tags stay a real list. The Expo sheet joined them into a string and
      // split it back on commas.
      final source = FakeDataSource(events: [
        testEvent(
          id: 'a',
          name: 'Draft Semanal',
          dayOffset: 1,
          tags: const ['Board Games, Cooperativo', 'Casual'],
        ),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);
      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);

      expect(find.widgetWithText(Chip, 'Board Games, Cooperativo'), findsOne);
      expect(find.widgetWithText(Chip, 'Casual'), findsOne);
    });

    testWidgets('offers the event page link when Notion has one',
        (tester) async {
      final source = FakeDataSource(events: [
        testEvent(
          id: 'a',
          name: 'Draft Semanal',
          dayOffset: 1,
          pageUrl: 'https://example.com/evento',
        ),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);
      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);

      // The Expo mapper read this URL and never showed it anywhere.
      expect(find.text('Abrir a página do evento'), findsOne);
    });

    testWidgets('hides the page link when there is none', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'a', name: 'Draft Semanal', dayOffset: 1),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);
      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);

      expect(find.text('Abrir a página do evento'), findsNothing);
    });

    testWidgets('has a WhatsApp contact button', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'a', name: 'Draft Semanal', dayOffset: 1),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);
      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);

      expect(find.text('Entrar em contato'), findsOne);
      expect(find.byIcon(AppIcons.whatsapp), findsWidgets);
    });
  });

  group('list title', () {
    test('says "Todos os Eventos" with no day selected', () {
      expect(eventsListTitle(null), 'Todos os Eventos');
    });

    test('names the selected day', () {
      expect(
        eventsListTitle(DateTime(2025, 9, 10)),
        'Eventos de Qua., 10 de set.',
      );
    });
  });
}
