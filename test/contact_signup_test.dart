import 'package:flutter_test/flutter_test.dart';
import 'package:tabletop_events/domain/event.dart';
import 'package:tabletop_events/notifications/reminder_plan.dart';
import 'package:tabletop_events/features/weekly/weekly_screen.dart';
import 'package:tabletop_events/notifications/subscription_controller.dart';

import 'app_harness.dart';

/// Opens the detail sheet for the single event in [source].
Future<void> openSheet(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await settle(tester);
}

void main() {
  group('the contact button carries the sign-up', () {
    testWidgets('records the presence even where nothing can be scheduled',
        (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', name: 'Draft Semanal', dayOffset: 1),
      ]);
      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
      );
      await settle(tester);

      final event = source.events.single;
      final result =
          await container.read(subscriptionsProvider.notifier).markGoing(event);

      // No local notifications on this platform, so the presence is recorded
      // and nothing is scheduled — which is exactly the web behaviour.
      expect(result, SubscriptionResult.unsupported);
      expect(container.read(subscriptionsProvider), contains('evento-a'));
    });

    testWidgets('marking twice does not double up', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', dayOffset: 1),
      ]);
      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
      );
      await settle(tester);

      final event = source.events.single;
      final controller = container.read(subscriptionsProvider.notifier);

      await controller.markGoing(event);
      final again = await controller.markGoing(event);

      expect(again, SubscriptionResult.alreadySubscribed);
      expect(container.read(subscriptionsProvider), hasLength(1));
    });

    testWidgets('the mark survives closing and reopening the sheet',
        (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', name: 'Draft Semanal', dayOffset: 1),
      ]);
      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
      );
      await settle(tester);

      await container
          .read(subscriptionsProvider.notifier)
          .markGoing(source.events.single);
      await settle(tester);

      await openSheet(tester, 'Draft Semanal');

      expect(container.read(subscriptionsProvider), contains('evento-a'));
    });

    testWidgets('the bell in the card reflects the mark', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', name: 'Draft Semanal', dayOffset: 1),
      ]);
      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
      );
      await settle(tester);

      expect(container.read(subscriptionsProvider), isEmpty);

      await container
          .read(subscriptionsProvider.notifier)
          .markGoing(source.events.single);
      await settle(tester);

      expect(container.read(subscriptionsProvider), contains('evento-a'));
    });
  });

  group('undoing', () {
    testWidgets('unmarking clears the presence', (tester) async {
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', dayOffset: 1),
      ]);
      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
      );
      await settle(tester);

      final event = source.events.single;
      final controller = container.read(subscriptionsProvider.notifier);

      await controller.markGoing(event);
      final undo = await controller.toggle(event);

      expect(undo, SubscriptionResult.unsubscribed);
      expect(container.read(subscriptionsProvider), isEmpty);
    });
  });

  group('liveSubscriptions', () {
    final now = DateTime(2025, 9, 10, 12, 0);

    Event at(String id, int dayOffset) => Event(
          id: id,
          name: 'Evento $id',
          day: DateTime(2025, 9, 10 + dayOffset),
          time: (hour: 20, minute: 0),
          location: 'Sede',
          status: EventStatus.available,
          description: const [],
          tags: const [],
          organizer: 'Organizador',
        );

    test('keeps a mark that still points at an upcoming event', () {
      final live = liveSubscriptions({'a'}, [at('a', 2)], now: now);

      expect(live.map((e) => e.id), ['a']);
    });

    test('drops a mark for an event deleted from the agenda', () {
      // Deleted in Notion. The bell must not stay lit for something gone.
      final live = liveSubscriptions({'a', 'sumiu'}, [at('a', 2)], now: now);

      expect(live.map((e) => e.id), ['a']);
    });

    test('drops a mark for an event that already happened', () {
      final live = liveSubscriptions(
        {'passou', 'vem'},
        [at('passou', -3), at('vem', 3)],
        now: now,
      );

      expect(live.map((e) => e.id), ['vem']);
    });

    test('keeps an event happening today', () {
      // The regression the Expo app shipped: an event today read as past.
      final live = liveSubscriptions({'hoje'}, [at('hoje', 0)], now: now);

      expect(live.map((e) => e.id), ['hoje']);
    });

    test('returns them soonest first, for the budget to cut the far ones', () {
      final live = liveSubscriptions(
        {'longe', 'perto', 'medio'},
        [at('longe', 20), at('perto', 1), at('medio', 5)],
        now: now,
      );

      expect(live.map((e) => e.id), ['perto', 'medio', 'longe']);
    });

    test('an empty mark set yields nothing', () {
      expect(liveSubscriptions(const {}, [at('a', 1)], now: now), isEmpty);
    });
  });

  group('messages', () {
    test('every outcome, including the new ones, has a sentence', () {
      for (final result in SubscriptionResult.values) {
        expect(
          subscriptionMessage(result).length,
          greaterThan(15),
          reason: '$result precisa de uma frase',
        );
      }
    });

    test('the needs-permission message does not claim the avisos are on', () {
      final message =
          subscriptionMessage(SubscriptionResult.subscribedNeedsPermission);

      expect(message, contains('Presença anotada'));
      expect(message, contains('Ative'));
    });
  });
}
