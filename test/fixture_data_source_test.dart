import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletop_events/data/events_data_source.dart';
import 'package:tabletop_events/data/fixture_data_source.dart';
import 'package:tabletop_events/data/proxy_data_source.dart';
import 'package:tabletop_events/domain/calendar_date.dart';
import 'package:tabletop_events/domain/event.dart';
import 'package:tabletop_events/domain/event_category.dart';
import 'package:tabletop_events/domain/event_filters.dart';

/// Serves a string as if it were a bundled asset.
class StringBundle extends CachingAssetBundle {
  StringBundle(this.contents);

  final Map<String, String> contents;

  @override
  Future<ByteData> load(String key) async {
    final value = contents[key];
    if (value == null) {
      throw FlutterError('asset ausente: $key');
    }
    return ByteData.sublistView(utf8.encode(value));
  }
}

void main() {
  group('the bundled fixture', () {
    late List<Event> events;

    setUpAll(() async {
      // Reads the real file from disk, so a change to it that breaks the format
      // fails here instead of shipping. It is also the proxy backend's payload
      // format, which makes this a contract test for that too.
      final raw =
          await File('assets/fixtures/events.json').readAsString();
      final source = FixtureDataSource(
        delay: Duration.zero,
        bundle: StringBundle({'assets/fixtures/events.json': raw}),
      );
      events = await source.fetchEvents();
    });

    test('parses every record', () {
      expect(events, hasLength(12));
    });

    test('resolves day offsets against today', () {
      final byId = {for (final event in events) event.id: event};

      expect(byId['fx-hoje-pokemon']!.day, today());
      expect(byId['fx-amanha-magic']!.day, addDays(today(), 1));
      expect(byId['fx-ontem-passado']!.day, addDays(today(), -2));
    });

    test('the week view is never empty', () {
      // Which is the point of writing the fixture in offsets: a sample agenda
      // with fixed dates goes stale and every screen renders empty.
      expect(events.withinDays(7, from: today()), isNotEmpty);
    });

    test('the past event is excluded from what is upcoming', () {
      final upcoming = events.upcomingFrom(today());

      expect(upcoming, hasLength(11));
      expect(upcoming.map((e) => e.id), isNot(contains('fx-ontem-passado')));
    });

    test('reads rich text as inline runs', () {
      final event = events.firstWhere((e) => e.id == 'fx-hoje-pokemon');

      expect(event.description.length, greaterThan(1));
      expect(event.description.any((run) => run.bold), isTrue);
      expect(event.description.any((run) => run.code), isTrue);
      expect(
        event.plainDescription,
        startsWith('Etapa válida para o ranking regional.'),
      );
    });

    test('accepts a plain-string description too', () {
      final event = events.firstWhere((e) => e.id == 'fx-hoje-boardgame');

      expect(event.description, hasLength(1));
      expect(event.description.single.bold, isFalse);
      expect(event.plainDescription, contains('Mesa livre'));
    });

    test('covers every price state', () {
      final byId = {for (final event in events) event.id: event};

      expect(byId['fx-hoje-boardgame']!.isFree, isTrue);
      expect(byId['fx-hoje-pokemon']!.price, 35.5);
      // No "price" key at all — not free, just not set.
      expect(byId['fx-4-digimon']!.hasPrice, isFalse);
      expect(byId['fx-4-digimon']!.isFree, isFalse);
    });

    test('covers every status', () {
      final byStatus = <EventStatus, int>{};
      for (final event in events) {
        byStatus.update(event.status, (n) => n + 1, ifAbsent: () => 1);
      }

      expect(byStatus[EventStatus.available], greaterThan(0));
      expect(byStatus[EventStatus.soldOut], 1);
      expect(byStatus[EventStatus.postponed], 1);
    });

    test('detects a range of categories', () {
      final categories = events.map((e) => e.category).toSet();

      expect(categories, contains(EventCategory.pokemon));
      expect(categories, contains(EventCategory.magic));
      expect(categories, contains(EventCategory.rpg));
      expect(categories, contains(EventCategory.boardGames));
      expect(categories.length, greaterThanOrEqualTo(5));
    });

    test('an event with no time gets none, not a fake 20:00', () {
      final byId = {for (final event in events) event.id: event};

      expect(byId['fx-hoje-pokemon']!.time, (hour: 19, minute: 30));
      expect(byId['fx-4-digimon']!.time, (hour: 19, minute: 0));
    });
  });

  group('FixtureDataSource failures', () {
    test('reports a missing asset as a failure', () {
      final source = FixtureDataSource(
        delay: Duration.zero,
        bundle: StringBundle(const {}),
      );

      expect(source.fetchEvents(), throwsA(isA<EventsFailure>()));
    });

    test('reports a malformed file as a failure', () {
      final source = FixtureDataSource(
        delay: Duration.zero,
        bundle: StringBundle({'assets/fixtures/events.json': '{"nada": 1}'}),
      );

      expect(source.fetchEvents(), throwsA(isA<EventsFailure>()));
    });
  });

  group('the proxy payload format', () {
    test('reads a full record', () {
      final event = eventFromJson({
        'id': 'p1',
        'name': 'Draft Semanal',
        'date': '2025-09-12',
        'time': '19:00',
        'price': 45,
        'location': 'TableTop Sorocaba',
        'status': 'available',
        'organizer': 'Bruno Salles',
        'tags': ['Draft', 'Magic'],
        'imageUrl': 'https://cdn.example.com/capa.png',
        'pageUrl': 'https://example.com/evento',
        'description': [
          {'text': 'Três boosters. '},
          {'text': 'Premiação', 'bold': true},
        ],
      })!;

      expect(event.name, 'Draft Semanal');
      expect(event.day, DateTime(2025, 9, 12));
      expect(event.time, (hour: 19, minute: 0));
      expect(event.price, 45);
      expect(event.status, EventStatus.available);
      expect(event.tags, ['Draft', 'Magic']);
      expect(event.description[1].bold, isTrue);
    });

    test('rejects a record with no id or no date', () {
      expect(eventFromJson({'date': '2025-09-12'}), isNull);
      expect(eventFromJson({'id': 'p1'}), isNull);
      expect(eventFromJson({'id': 'p1', 'date': 'em breve'}), isNull);
    });

    test('accepts the Notion status labels as a fallback', () {
      Event? build(String status) => eventFromJson({
            'id': 'p1',
            'date': '2025-09-12',
            'status': status,
          });

      expect(build('sold_out')!.status, EventStatus.soldOut);
      expect(build('Esgotado')!.status, EventStatus.soldOut);
      expect(build('cancelled')!.status, EventStatus.cancelled);
      expect(build('Adiado')!.status, EventStatus.postponed);
    });

    test('falls back on every optional field', () {
      final event = eventFromJson({'id': 'p1', 'date': '2025-09-12'})!;

      expect(event.name, 'Evento sem nome');
      expect(event.location, 'Local não definido');
      expect(event.organizer, 'Organizador não definido');
      expect(event.tags, isEmpty);
      expect(event.description, isEmpty);
      expect(event.price, isNull);
      expect(event.time, isNull);
    });
  });
}
