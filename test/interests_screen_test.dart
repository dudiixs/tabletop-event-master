import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletop_events/domain/event_category.dart';
import 'package:tabletop_events/features/preferences/interests_screen.dart';
import 'package:tabletop_events/features/weekly/weekly_screen.dart';
import 'package:tabletop_events/notifications/interests_controller.dart';
import 'package:tabletop_events/notifications/subscription_controller.dart';

import 'app_harness.dart';

void main() {
  group('InterestsScreen', () {
    testWidgets('lists every selectable game, all on by default',
        (tester) async {
      await pumpScreen(
        tester,
        const InterestsScreen(),
        size: const Size(420, 2400),
      );
      await settle(tester);

      expect(find.text('Avise-me sobre'), findsOne);
      for (final category in InterestsController.selectable) {
        expect(
          find.textContaining(category.label),
          findsWidgets,
          reason: '${category.label} deveria aparecer na lista',
        );
      }

      final switches =
          tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
      expect(switches, hasLength(InterestsController.selectable.length));
      expect(switches.every((tile) => tile.value), isTrue);
    });

    testWidgets('does not offer the catch-all category', (tester) async {
      await pumpScreen(
        tester,
        const InterestsScreen(),
        size: const Size(420, 2400),
      );
      await settle(tester);

      expect(find.textContaining(EventCategory.other.label), findsNothing);
    });

    testWidgets('turning a game off updates the switch', (tester) async {
      await pumpScreen(
        tester,
        const InterestsScreen(),
        size: const Size(420, 2400),
      );
      await settle(tester);

      final target = find.ancestor(
        of: find.textContaining(EventCategory.digimon.label),
        matching: find.byType(SwitchListTile),
      );

      await tester.tap(target);
      await settle(tester);

      expect(tester.widget<SwitchListTile>(target).value, isFalse);
    });

    testWidgets('warns when nothing is followed', (tester) async {
      await pumpScreen(
        tester,
        const InterestsScreen(),
        size: const Size(420, 2400),
      );
      await settle(tester);

      await tester.tap(find.text('Desmarcar todos'));
      await settle(tester);

      expect(
        find.textContaining('não recebe aviso de evento novo'),
        findsOne,
      );
      // And says the per-event reminders keep working, so turning topics off
      // does not read as turning notifications off entirely.
      expect(find.textContaining('continuam funcionando'), findsOne);
    });

    testWidgets('"Marcar todos" restores everything', (tester) async {
      await pumpScreen(
        tester,
        const InterestsScreen(),
        size: const Size(420, 2400),
      );
      await settle(tester);

      await tester.tap(find.text('Desmarcar todos'));
      await settle(tester);
      await tester.tap(find.text('Marcar todos'));
      await settle(tester);

      final switches =
          tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
      expect(switches.every((tile) => tile.value), isTrue);
    });

    testWidgets('explains the three reminder tiers', (tester) async {
      await pumpScreen(
        tester,
        const InterestsScreen(),
        size: const Size(420, 2400),
      );
      await settle(tester);

      expect(find.text('Lembretes'), findsOne);
      // The tier list is generated from the enum, so this catches a tier being
      // added or renamed without the copy following.
      expect(reminderTiersDescription, '1 hora, 30 minutos, 5 minutos');
    });
  });

  group('InterestsSummaryCard', () {
    testWidgets('summarises the selection and is tappable', (tester) async {
      var tapped = false;

      await pumpScreen(
        tester,
        InterestsSummaryCard(onTap: () => tapped = true),
      );
      await settle(tester);

      expect(find.text('Avise-me sobre'), findsOne);
      expect(find.text('Todos os jogos'), findsOne);

      await tester.tap(find.byType(InterestsSummaryCard));
      expect(tapped, isTrue);
    });
  });

  group('"vou nesse evento"', () {
    testWidgets('the WhatsApp button is the only footer action',
        (tester) async {
      // Signing up happens in the WhatsApp conversation, so the contact button
      // carries it — there is no second "vou nesse" button competing with it.
      final source = FakeDataSource(events: [
        testEvent(id: 'a', name: 'Draft Semanal', dayOffset: 1),
      ]);

      await pumpScreen(tester, const WeeklyScreen(), dataSource: source);
      await settle(tester);
      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);

      expect(find.text('Entrar em contato'), findsOne);
      expect(find.text('Vou nesse evento'), findsNothing);
    });

    testWidgets('marking still records the interest where it cannot notify',
        (tester) async {
      // The mark is what the organizer counts, so it is kept even on a
      // platform that cannot schedule — it syncs to a phone that can.
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
      final result =
          await container.read(subscriptionsProvider.notifier).toggle(event);

      expect(result, SubscriptionResult.unsupported);
      expect(container.read(subscriptionsProvider), contains('evento-a'));

      final undo =
          await container.read(subscriptionsProvider.notifier).toggle(event);

      expect(undo, SubscriptionResult.unsubscribed);
      expect(container.read(subscriptionsProvider), isEmpty);
    });
  });

  group('subscription messages', () {
    test('every outcome has words for the user', () {
      for (final result in SubscriptionResult.values) {
        final message = subscriptionMessage(result);
        expect(message, isNotEmpty);
        expect(message.length, greaterThan(15),
            reason: '$result precisa de uma frase, não de um rótulo');
      }
    });

    test('the tier list comes from the enum, not from prose', () {
      expect(
        subscriptionMessage(SubscriptionResult.subscribed),
        contains('1 hora'),
      );
    });
  });
}
