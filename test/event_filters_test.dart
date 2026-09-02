import 'package:flutter_test/flutter_test.dart';
import 'package:tabletop_events/domain/event.dart';
import 'package:tabletop_events/domain/event_filters.dart';

Event eventOn(DateTime day, {String? name, int hour = 20}) => Event(
      id: '${day.toIso8601String()}-${name ?? ''}-$hour',
      name: name ?? 'Evento ${day.day}/${day.month}',
      day: day,
      time: (hour: hour, minute: 0),
      price: 0,
      location: 'Sede',
      status: EventStatus.available,
      description: const [],
      tags: const [],
      organizer: 'Organizador',
    );

void main() {
  // A fixed "today" so the assertions do not depend on when the suite runs.
  final today = DateTime(2025, 9, 10);

  group('upcomingFrom', () {
    test("keeps today's events", () {
      final events = [eventOn(today)];

      expect(events.upcomingFrom(today), hasLength(1));
    });

    test("keeps an event that started earlier today", () {
      // The Expo week filter compared a UTC-parsed date against local midnight,
      // so an event happening today was always in the past. It is not: the
      // agenda works in whole days.
      final events = [eventOn(today, hour: 9)];

      expect(events.upcomingFrom(DateTime(2025, 9, 10, 22, 0)), hasLength(1));
    });

    test('drops yesterday and keeps tomorrow', () {
      final events = [
        eventOn(DateTime(2025, 9, 9), name: 'ontem'),
        eventOn(DateTime(2025, 9, 11), name: 'amanha'),
      ];

      final upcoming = events.upcomingFrom(today);

      expect(upcoming.map((e) => e.name), ['amanha']);
    });

    test('returns them soonest first', () {
      final events = [
        eventOn(DateTime(2025, 9, 20), name: 'depois'),
        eventOn(DateTime(2025, 9, 12), name: 'antes'),
        eventOn(DateTime(2025, 9, 12), name: 'antes-cedo', hour: 9),
      ];

      expect(
        events.upcomingFrom(today).map((e) => e.name),
        ['antes-cedo', 'antes', 'depois'],
      );
    });
  });

  group('withinDays', () {
    test('a 7-day window spans exactly 7 days, not 8', () {
      final events = [
        for (var offset = 0; offset < 10; offset++)
          eventOn(DateTime(2025, 9, 10 + offset), name: 'dia+$offset'),
      ];

      final week = events.withinDays(7, from: today);

      expect(week, hasLength(7));
      expect(week.first.name, 'dia+0', reason: 'hoje entra na semana');
      expect(week.last.name, 'dia+6');
      expect(
        week.map((e) => e.name),
        isNot(contains('dia+7')),
        reason: 'o oitavo dia fica fora — era o bug do filtro semanal',
      );
    });

    test('excludes the past even inside the window length', () {
      final events = [
        eventOn(DateTime(2025, 9, 8), name: 'passado'),
        eventOn(DateTime(2025, 9, 11), name: 'futuro'),
      ];

      expect(events.withinDays(7, from: today).map((e) => e.name), ['futuro']);
    });

    test('crosses a month boundary', () {
      final events = [
        eventOn(DateTime(2025, 10, 2), name: 'outubro'),
      ];

      expect(
        events.withinDays(7, from: DateTime(2025, 9, 28)),
        hasLength(1),
      );
    });
  });

  group('onDay', () {
    test('matches by calendar day, ignoring the time', () {
      final events = [
        eventOn(today, name: 'manha', hour: 9),
        eventOn(today, name: 'noite', hour: 21),
        eventOn(DateTime(2025, 9, 11), name: 'outro dia'),
      ];

      expect(
        events.onDay(DateTime(2025, 9, 10, 15, 30)).map((e) => e.name),
        ['manha', 'noite'],
      );
    });

    test('returns empty for a day with nothing on it', () {
      expect([eventOn(today)].onDay(DateTime(2025, 9, 11)), isEmpty);
    });
  });

  group('groupedByDay', () {
    test('buckets events under their own day', () {
      final events = [
        eventOn(today, name: 'a'),
        eventOn(today, name: 'b', hour: 9),
        eventOn(DateTime(2025, 9, 12), name: 'c'),
      ];

      final grouped = events.groupedByDay();

      expect(grouped.keys, hasLength(2));
      expect(grouped[today]!.map((e) => e.name), ['b', 'a']);
      expect(grouped[DateTime(2025, 9, 12)]!.map((e) => e.name), ['c']);
    });
  });
}
