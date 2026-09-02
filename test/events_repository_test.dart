import 'package:flutter_test/flutter_test.dart';
import 'package:tabletop_events/data/events_data_source.dart';
import 'package:tabletop_events/data/events_repository.dart';
import 'package:tabletop_events/domain/event.dart';

class RecordingDataSource implements EventsDataSource {
  RecordingDataSource({this.failWith});

  int calls = 0;
  EventsFailure? failWith;
  List<Event> events = const [];

  @override
  Future<List<Event>> fetchEvents() async {
    calls++;
    final failure = failWith;
    if (failure != null) throw failure;
    return events;
  }
}

Event sampleEvent(String id) => Event(
      id: id,
      name: 'Evento $id',
      day: DateTime(2025, 9, 10),
      location: 'Sede',
      status: EventStatus.available,
      description: const [],
      tags: const [],
      organizer: 'Organizador',
    );

void main() {
  group('cache', () {
    test('fetches once and serves the cache inside the TTL', () async {
      final source = RecordingDataSource()..events = [sampleEvent('a')];
      var now = DateTime(2025, 9, 10, 12, 0);
      final repository = EventsRepository(
        dataSource: source,
        ttl: const Duration(minutes: 5),
        clock: () => now,
      );

      await repository.getEvents();
      now = now.add(const Duration(minutes: 4, seconds: 59));
      await repository.getEvents();

      expect(source.calls, 1, reason: 'a segunda leitura vem do cache');
    });

    test('refetches once the TTL has passed', () async {
      final source = RecordingDataSource()..events = [sampleEvent('a')];
      var now = DateTime(2025, 9, 10, 12, 0);
      final repository = EventsRepository(
        dataSource: source,
        ttl: const Duration(minutes: 5),
        clock: () => now,
      );

      await repository.getEvents();
      now = now.add(const Duration(minutes: 5, seconds: 1));
      await repository.getEvents();

      expect(source.calls, 2);
    });

    test('forceRefresh ignores a fresh cache', () async {
      final source = RecordingDataSource()..events = [sampleEvent('a')];
      final repository = EventsRepository(dataSource: source);

      await repository.getEvents();
      await repository.getEvents(forceRefresh: true);

      expect(source.calls, 2);
    });

    test('two concurrent screens share one request', () async {
      // The Expo app fetched at least twice on every open: the home screen
      // called the API directly while the cache lived in the root screen.
      final source = RecordingDataSource()..events = [sampleEvent('a')];
      final repository = EventsRepository(dataSource: source);

      await Future.wait([
        repository.getEvents(),
        repository.getEvents(),
        repository.getEvents(),
      ]);

      expect(source.calls, 1);
    });

    test('invalidate drops the cache', () async {
      final source = RecordingDataSource()..events = [sampleEvent('a')];
      final repository = EventsRepository(dataSource: source);

      await repository.getEvents();
      repository.invalidate();

      expect(repository.hasFreshCache, isFalse);
      expect(repository.lastKnown, isNull);

      await repository.getEvents();
      expect(source.calls, 2);
    });

    test('records when the agenda was cached', () async {
      final now = DateTime(2025, 9, 10, 12, 0);
      final repository = EventsRepository(
        dataSource: RecordingDataSource()..events = [sampleEvent('a')],
        clock: () => now,
      );

      expect(repository.cachedAt, isNull);
      await repository.getEvents();
      expect(repository.cachedAt, now);
    });
  });

  group('failures', () {
    test('propagates the failure instead of returning an empty agenda', () {
      // The Expo data layer caught every error and returned [], so a dropped
      // connection was indistinguishable from an empty agenda.
      final repository = EventsRepository(
        dataSource: RecordingDataSource(
          failWith: const EventsFailure('sem rede', isOffline: true),
        ),
      );

      expect(
        repository.getEvents(),
        throwsA(isA<EventsFailure>().having((e) => e.isOffline, 'isOffline', isTrue)),
      );
    });

    test('a failed fetch leaves no stale cache behind', () async {
      final source = RecordingDataSource(
        failWith: const EventsFailure('falhou'),
      );
      final repository = EventsRepository(dataSource: source);

      await expectLater(repository.getEvents(), throwsA(isA<EventsFailure>()));

      expect(repository.hasFreshCache, isFalse);
      expect(repository.lastKnown, isNull);
    });

    test('keeps serving the last good agenda after a failed refresh', () async {
      final source = RecordingDataSource()..events = [sampleEvent('a')];
      final repository = EventsRepository(dataSource: source);

      await repository.getEvents();
      source.failWith = const EventsFailure('caiu');

      await expectLater(
        repository.getEvents(forceRefresh: true),
        throwsA(isA<EventsFailure>()),
      );

      // The screen can still show what it had rather than going blank.
      expect(repository.lastKnown, hasLength(1));
    });

    test('recovers on the retry after a failure', () async {
      final source = RecordingDataSource(failWith: const EventsFailure('x'));
      final repository = EventsRepository(dataSource: source);

      await expectLater(repository.getEvents(), throwsA(isA<EventsFailure>()));

      source
        ..failWith = null
        ..events = [sampleEvent('a')];

      expect(await repository.getEvents(), hasLength(1));
    });
  });
}
