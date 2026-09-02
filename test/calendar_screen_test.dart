import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart' hide isSameDay;
import 'package:tabletop_events/data/events_data_source.dart';
import 'package:tabletop_events/domain/calendar_date.dart';
import 'package:tabletop_events/domain/event.dart';
import 'package:tabletop_events/features/calendar/calendar_screen.dart';

import 'app_harness.dart';

void main() {
  group('CalendarScreen', () {
    testWidgets('renders the month with the agenda underneath', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'a', name: 'Liga Pokémon', dayOffset: 2),
      ]);

      await pumpScreen(
        tester,
        const CalendarScreen(),
        dataSource: source,
        size: const Size(420, 2000),
      );
      await settle(tester);

      expect(find.byType(TableCalendar<Event>), findsOne);
      expect(find.text('Todos os Eventos'), findsOne);
      expect(find.text('Liga Pokémon'), findsOne);
    });

    testWidgets('starts the week on Monday, in Portuguese', (tester) async {
      await pumpScreen(
        tester,
        const CalendarScreen(),
        dataSource: FakeDataSource(events: [testEvent(id: 'a', dayOffset: 1)]),
        size: const Size(420, 2000),
      );
      await settle(tester);

      final calendar =
          tester.widget<TableCalendar<Event>>(find.byType(TableCalendar<Event>));

      expect(calendar.startingDayOfWeek, StartingDayOfWeek.monday);
      expect(calendar.locale, 'pt_BR');
      expect(calendar.calendarStyle.outsideDaysVisible, isFalse);
    });

    testWidgets('selecting a day filters the list to that day',
        (tester) async {
      final target = addDays(today(), 3);
      final source = FakeDataSource(events: [
        testEvent(id: 'alvo', name: 'No dia escolhido', dayOffset: 3),
        testEvent(id: 'outro', name: 'Em outro dia', dayOffset: 5),
      ]);

      await pumpScreen(
        tester,
        const CalendarScreen(),
        dataSource: source,
        size: const Size(420, 2000),
      );
      await settle(tester);

      expect(find.text('No dia escolhido'), findsOne);
      expect(find.text('Em outro dia'), findsOne);

      // Tap the target day's number inside the calendar grid.
      await tester.tap(
        find.descendant(
          of: find.byType(TableCalendar<Event>),
          matching: find.text('${target.day}'),
        ).first,
      );
      await settle(tester);

      expect(find.text('No dia escolhido'), findsOne);
      expect(find.text('Em outro dia'), findsNothing);
      expect(find.textContaining('Eventos de'), findsOne);
    });

    testWidgets('tapping the selected day again clears the filter',
        (tester) async {
      // The Expo calendar had no way back to the full list without leaving the
      // screen: once a day was selected it stayed selected.
      final target = addDays(today(), 3);
      final source = FakeDataSource(events: [
        testEvent(id: 'alvo', name: 'No dia escolhido', dayOffset: 3),
        testEvent(id: 'outro', name: 'Em outro dia', dayOffset: 5),
      ]);

      await pumpScreen(
        tester,
        const CalendarScreen(),
        dataSource: source,
        size: const Size(420, 2000),
      );
      await settle(tester);

      final dayFinder = find.descendant(
        of: find.byType(TableCalendar<Event>),
        matching: find.text('${target.day}'),
      ).first;

      await tester.tap(dayFinder);
      await settle(tester);
      expect(find.text('Em outro dia'), findsNothing);

      await tester.tap(dayFinder);
      await settle(tester);

      expect(find.text('Todos os Eventos'), findsOne);
      expect(find.text('Em outro dia'), findsOne);
    });

    testWidgets('a day with nothing on it says so', (tester) async {
      final empty = addDays(today(), 4);
      final source = FakeDataSource(events: [
        testEvent(id: 'a', name: 'Único evento', dayOffset: 2),
      ]);

      await pumpScreen(
        tester,
        const CalendarScreen(),
        dataSource: source,
        size: const Size(420, 2000),
      );
      await settle(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(TableCalendar<Event>),
          matching: find.text('${empty.day}'),
        ).first,
      );
      await settle(tester);

      expect(find.text('Nada marcado neste dia'), findsOne);
    });

    testWidgets('marks the days that carry events', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'a', dayOffset: 1),
        testEvent(id: 'b', dayOffset: 1),
        testEvent(id: 'c', dayOffset: 4),
      ]);

      await pumpScreen(
        tester,
        const CalendarScreen(),
        dataSource: source,
        size: const Size(420, 2000),
      );
      await settle(tester);

      final calendar =
          tester.widget<TableCalendar<Event>>(find.byType(TableCalendar<Event>));

      expect(calendar.eventLoader!(addDays(today(), 1)), hasLength(2));
      expect(calendar.eventLoader!(addDays(today(), 4)), hasLength(1));
      expect(calendar.eventLoader!(addDays(today(), 2)), isEmpty);
      // A past day carries no marker: the agenda only holds what is upcoming.
      expect(calendar.eventLoader!(addDays(today(), -1)), isEmpty);
    });

    testWidgets('shows an error with a retry when the fetch fails',
        (tester) async {
      await pumpScreen(
        tester,
        const CalendarScreen(),
        dataSource: FakeDataSource(
          failure: const EventsFailure('Sem conexão com a internet.'),
        ),
        size: const Size(420, 2000),
      );
      await settle(tester);

      expect(find.text('Tentar novamente'), findsOne);
      expect(find.byType(TableCalendar<Event>), findsNothing);
    });
  });
}
