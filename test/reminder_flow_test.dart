import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletop_events/data/events_providers.dart';
import 'package:tabletop_events/features/weekly/weekly_screen.dart';
import 'package:tabletop_events/notifications/reminder_tier.dart';
import 'package:tabletop_events/notifications/subscription_controller.dart';

import 'app_harness.dart';
import 'fake_scheduler.dart';

void main() {
  group('marking from the contact button', () {
    testWidgets('schedules all three tiers when notifications are on',
        (tester) async {
      final scheduler = FakeScheduler();
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', dayOffset: 3),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);

      final result = await container
          .read(subscriptionsProvider.notifier)
          .markGoing(source.events.single);

      expect(result, SubscriptionResult.subscribed);
      expect(scheduler.scheduled['evento-a'], ReminderTier.values);
    });

    testWidgets('never prompts for permission on the way to WhatsApp',
        (tester) async {
      // The whole reason markGoing exists: tapping "Entrar em contato" has to
      // open WhatsApp, not a permission dialog.
      final scheduler = FakeScheduler(notificationsEnabled: false);
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', dayOffset: 3),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);

      final result = await container
          .read(subscriptionsProvider.notifier)
          .markGoing(source.events.single);

      expect(result, SubscriptionResult.subscribedNeedsPermission);
      expect(scheduler.permissionRequests, 0,
          reason: 'nenhum diálogo antes de abrir o WhatsApp');
      // The presence is recorded regardless — it is the intent, and it is what
      // the organizer counts.
      expect(container.read(subscriptionsProvider), contains('evento-a'));
      expect(scheduler.scheduled, isEmpty);
    });

    testWidgets('enabling later schedules what was waiting', (tester) async {
      final scheduler = FakeScheduler(notificationsEnabled: false);
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', dayOffset: 3),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);

      final controller = container.read(subscriptionsProvider.notifier);
      await controller.markGoing(source.events.single);
      expect(scheduler.scheduled, isEmpty);

      final granted = await controller.enableReminders();

      expect(granted, isTrue);
      expect(scheduler.permissionRequests, 1);
      expect(scheduler.scheduled['evento-a'], ReminderTier.values);
    });

    testWidgets('a refused permission leaves the presence but no reminders',
        (tester) async {
      final scheduler = FakeScheduler(
        notificationsEnabled: false,
        permissionWillBeGranted: false,
      );
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', dayOffset: 3),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);

      final controller = container.read(subscriptionsProvider.notifier);
      await controller.markGoing(source.events.single);

      expect(await controller.enableReminders(), isFalse);
      expect(scheduler.scheduled, isEmpty);
      expect(container.read(subscriptionsProvider), contains('evento-a'));
    });

    testWidgets('an event too close to warn about is still marked',
        (tester) async {
      final scheduler = FakeScheduler();
      final source = FakeDataSource(events: [
        // Starts today, already past every tier's fire time.
        testEvent(id: 'agora', dayOffset: 0, hour: 0, minute: 1),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);

      final result = await container
          .read(subscriptionsProvider.notifier)
          .markGoing(source.events.single);

      expect(
        result,
        anyOf(
          SubscriptionResult.subscribedTooLate,
          SubscriptionResult.subscribedQueued,
        ),
      );
      expect(container.read(subscriptionsProvider), contains('agora'));
      expect(scheduler.scheduled, isEmpty);
    });
  });

  group('the budget', () {
    testWidgets('the nearest events get the reminders', (tester) async {
      final scheduler = FakeScheduler(eventBudget: 2);
      final source = FakeDataSource(events: [
        testEvent(id: 'perto', dayOffset: 1),
        testEvent(id: 'medio', dayOffset: 4),
        testEvent(id: 'longe', dayOffset: 20),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);

      final controller = container.read(subscriptionsProvider.notifier);
      for (final event in source.events) {
        await controller.markGoing(event);
      }

      expect(container.read(subscriptionsProvider), hasLength(3),
          reason: 'as três presenças ficam marcadas');
      expect(scheduler.scheduled.keys, {'perto', 'medio'},
          reason: 'só os dois mais próximos cabem no orçamento do iOS');
    });

    testWidgets('unmarking a near event lets a far one in', (tester) async {
      final scheduler = FakeScheduler(eventBudget: 1);
      final source = FakeDataSource(events: [
        testEvent(id: 'perto', dayOffset: 1),
        testEvent(id: 'longe', dayOffset: 20),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);

      final controller = container.read(subscriptionsProvider.notifier);
      await controller.markGoing(source.events[0]);
      await controller.markGoing(source.events[1]);
      expect(scheduler.scheduled.keys, {'perto'});

      await controller.toggle(source.events[0]);

      expect(scheduler.scheduled.keys, {'longe'},
          reason: 'o slot liberado passa para o próximo da fila');
    });
  });

  group('reconciliation', () {
    testWidgets('clears everything before rescheduling', (tester) async {
      // A date that moved in Notion must not leave a stale alarm behind.
      final scheduler = FakeScheduler();
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', dayOffset: 3),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);

      final controller = container.read(subscriptionsProvider.notifier);
      await controller.markGoing(source.events.single);
      final before = scheduler.cancelAllCalls;

      await controller.reconcile();

      expect(scheduler.cancelAllCalls, greaterThan(before));
      expect(scheduler.scheduled['evento-a'], ReminderTier.values);
    });

    testWidgets('drops a mark for an event that left the agenda',
        (tester) async {
      final scheduler = FakeScheduler();
      final source = FakeDataSource(events: [
        testEvent(id: 'fica', dayOffset: 2),
        testEvent(id: 'sai', dayOffset: 3),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);

      final controller = container.read(subscriptionsProvider.notifier);
      for (final event in source.events) {
        await controller.markGoing(event);
      }
      expect(container.read(subscriptionsProvider), hasLength(2));

      // The event is deleted in Notion.
      source.events = [testEvent(id: 'fica', dayOffset: 2)];
      container.read(eventsRepositoryProvider).invalidate();
      container.invalidate(agendaProvider);
      await container.read(agendaProvider.future);
      await settle(tester);

      await controller.reconcile();

      expect(container.read(subscriptionsProvider), {'fica'});
      expect(scheduler.scheduled.keys, {'fica'});
    });
  });

  group('the footer', () {
    testWidgets('offers to enable notifications when they are off',
        (tester) async {
      final scheduler = FakeScheduler(notificationsEnabled: false);
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', name: 'Draft Semanal', dayOffset: 3),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);

      await container
          .read(subscriptionsProvider.notifier)
          .markGoing(source.events.single);

      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);

      expect(find.text('Você vai neste evento'), findsOne);
      expect(
        find.textContaining('Ative as notificações'),
        findsOne,
        reason: 'não pode prometer avisos que não vão chegar',
      );
      expect(find.text('Ativar'), findsOne);
    });

    testWidgets('confirms the tiers when notifications are on',
        (tester) async {
      final scheduler = FakeScheduler();
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', name: 'Draft Semanal', dayOffset: 3),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);

      await container
          .read(subscriptionsProvider.notifier)
          .markGoing(source.events.single);

      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);

      expect(find.text('Você vai neste evento'), findsOne);
      expect(find.textContaining('1 hora, 30 minutos, 5 minutos'), findsOne);
      expect(
        find.descendant(
          of: find.byKey(const Key('going-strip')),
          matching: find.byTooltip('Não vou mais'),
        ),
        findsOne,
      );
    });

    testWidgets('the "Ativar" button turns notifications on', (tester) async {
      final scheduler = FakeScheduler(notificationsEnabled: false);
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', name: 'Draft Semanal', dayOffset: 3),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);
      await container
          .read(subscriptionsProvider.notifier)
          .markGoing(source.events.single);

      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);
      await tester.tap(find.text('Ativar'));
      await settle(tester);

      expect(scheduler.permissionRequests, 1);
      expect(scheduler.scheduled['evento-a'], ReminderTier.values);
      expect(find.textContaining('1 hora, 30 minutos, 5 minutos'), findsOne);
    });

    testWidgets('discloses the consequence before the tap', (tester) async {
      // A button that quietly subscribes you to notifications is a trick, so
      // the consequence has to be on screen before the tap.
      final scheduler = FakeScheduler();
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', name: 'Draft Semanal', dayOffset: 3),
      ]);

      await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);
      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);

      expect(find.text('Entrar em contato'), findsOne);
      expect(find.textContaining('fica marcado neste evento'), findsOne);
      expect(find.textContaining('passa a receber os avisos'), findsOne);
      expect(find.byKey(const Key('going-strip')), findsNothing);
    });

    testWidgets('the disclosure gives way to the confirmation strip',
        (tester) async {
      final scheduler = FakeScheduler();
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', name: 'Draft Semanal', dayOffset: 3),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);
      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);

      expect(find.textContaining('fica marcado neste evento'), findsOne);

      await container
          .read(subscriptionsProvider.notifier)
          .markGoing(source.events.single);
      await settle(tester);

      // The strip says it better than the caption did — and unlike a snackbar
      // it is still there when they come back from WhatsApp.
      expect(find.byKey(const Key('going-strip')), findsOne);
      expect(find.textContaining('fica marcado neste evento'), findsNothing);
    });

    testWidgets('the contact button stays available after marking',
        (tester) async {
      // Sign-up happens in the conversation, so they may need to go back to it.
      final scheduler = FakeScheduler();
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', name: 'Draft Semanal', dayOffset: 3),
      ]);

      final container = await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);
      await container
          .read(subscriptionsProvider.notifier)
          .markGoing(source.events.single);
      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);

      expect(find.text('Entrar em contato'), findsOne);
    });

    testWidgets('hides the reminder UI where it cannot work', (tester) async {
      // Web. The WhatsApp button, which works everywhere, stays.
      final scheduler = FakeScheduler(isSupported: false);
      final source = FakeDataSource(events: [
        testEvent(id: 'evento-a', name: 'Draft Semanal', dayOffset: 3),
      ]);

      await pumpScreen(
        tester,
        const WeeklyScreen(),
        dataSource: source,
        overrides: [reminderServiceProvider.overrideWithValue(scheduler)],
      );
      await settle(tester);
      await tester.tap(find.text('Draft Semanal'));
      await settle(tester);

      expect(find.text('Entrar em contato'), findsOne);
      expect(find.textContaining('fica marcado neste evento'), findsNothing);
      expect(find.byKey(const Key('going-strip')), findsNothing);
    });
  });
}
