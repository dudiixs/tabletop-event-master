import 'package:flutter_test/flutter_test.dart';
import 'package:tabletop_events/domain/event.dart';
import 'package:tabletop_events/notifications/reminder_plan.dart';
import 'package:tabletop_events/notifications/reminder_service.dart';
import 'package:tabletop_events/notifications/reminder_tier.dart';

/// An event starting at [startsAt].
Event eventAt(DateTime startsAt, {String? id}) => Event(
      id: id ?? startsAt.toIso8601String(),
      name: 'Evento ${startsAt.hour}h',
      day: DateTime(startsAt.year, startsAt.month, startsAt.day),
      time: (hour: startsAt.hour, minute: startsAt.minute),
      location: 'Sede',
      status: EventStatus.available,
      description: const [],
      tags: const [],
      organizer: 'Organizador',
    );

void main() {
  final now = DateTime(2025, 9, 10, 12, 0);

  group('ReminderTier', () {
    test('the three tiers are 1h, 30min and 5min', () {
      expect(ReminderTier.oneHour.leadTime, const Duration(hours: 1));
      expect(
        ReminderTier.thirtyMinutes.leadTime,
        const Duration(minutes: 30),
      );
      expect(ReminderTier.fiveMinutes.leadTime, const Duration(minutes: 5));
    });

    test('fire times count back from the start', () {
      final start = DateTime(2025, 9, 10, 20, 0);

      expect(
        ReminderTier.oneHour.fireTimeFor(start),
        DateTime(2025, 9, 10, 19, 0),
      );
      expect(
        ReminderTier.thirtyMinutes.fireTimeFor(start),
        DateTime(2025, 9, 10, 19, 30),
      );
      expect(
        ReminderTier.fiveMinutes.fireTimeFor(start),
        DateTime(2025, 9, 10, 19, 55),
      );
    });

    test('only the five-minute tier needs exact timing', () {
      // Android batches inexact alarms for battery and can delay them by
      // minutes. Nine minutes late is fine for the hour warning and useless
      // for the five-minute one.
      expect(ReminderTier.fiveMinutes.needsExactTiming, isTrue);
      expect(ReminderTier.oneHour.needsExactTiming, isFalse);
      expect(ReminderTier.thirtyMinutes.needsExactTiming, isFalse);
    });
  });

  group('liveTiersFor', () {
    test('an event far out keeps all three', () {
      final event = eventAt(DateTime(2025, 9, 10, 20, 0));

      expect(liveTiersFor(event, now: now), ReminderTier.values);
    });

    test('an event in 45 minutes loses the hour warning', () {
      final event = eventAt(DateTime(2025, 9, 10, 12, 45));

      expect(liveTiersFor(event, now: now), [
        ReminderTier.thirtyMinutes,
        ReminderTier.fiveMinutes,
      ]);
    });

    test('an event in 20 minutes keeps only the five-minute warning', () {
      final event = eventAt(DateTime(2025, 9, 10, 12, 20));

      expect(liveTiersFor(event, now: now), [ReminderTier.fiveMinutes]);
    });

    test('an event in 3 minutes has nothing left to announce', () {
      final event = eventAt(DateTime(2025, 9, 10, 12, 3));

      expect(liveTiersFor(event, now: now), isEmpty);
    });

    test('a tier due exactly now is already past', () {
      // 13:00 minus one hour is 12:00, which is now — not the future.
      final event = eventAt(DateTime(2025, 9, 10, 13, 0));

      expect(liveTiersFor(event, now: now), isNot(contains(ReminderTier.oneHour)));
    });
  });

  group('buildReminderPlan', () {
    test('schedules every marked event when they all fit', () {
      final events = [
        eventAt(DateTime(2025, 9, 11, 20, 0), id: 'a'),
        eventAt(DateTime(2025, 9, 12, 20, 0), id: 'b'),
      ];

      final plan = buildReminderPlan(events, eventBudget: 21, now: now);

      expect(plan.entries, hasLength(2));
      expect(plan.queued, isEmpty);
      expect(plan.notificationCount, 6);
      expect(plan.holdsRemindersFor('a'), isTrue);
    });

    test('the nearest events win the slots when the budget is tight', () {
      // iOS keeps only the 64 soonest pending notifications and silently drops
      // the rest, so this ordering is what makes the limit invisible.
      final events = [
        for (var day = 11; day <= 20; day++)
          eventAt(DateTime(2025, 9, day, 20, 0), id: 'dia$day'),
      ];

      final plan = buildReminderPlan(events, eventBudget: 3, now: now);

      expect(plan.entries.map((e) => e.event.id), ['dia11', 'dia12', 'dia13']);
      expect(plan.queued, hasLength(7));
      expect(plan.queued.first.id, 'dia14');
      expect(plan.holdsRemindersFor('dia14'), isFalse);
    });

    test('an event with nothing left to announce takes no slot', () {
      // Spending a slot on an event that cannot notify would push a later one
      // out of the budget for nothing.
      final events = [
        eventAt(DateTime(2025, 9, 10, 12, 2), id: 'agora'),
        eventAt(DateTime(2025, 9, 11, 20, 0), id: 'amanha'),
      ];

      final plan = buildReminderPlan(events, eventBudget: 1, now: now);

      expect(plan.entries.map((e) => e.event.id), ['amanha']);
      expect(plan.queued, isEmpty);
    });

    test('reports which tiers an event missed', () {
      final events = [eventAt(DateTime(2025, 9, 10, 12, 20), id: 'perto')];

      final plan = buildReminderPlan(events, eventBudget: 21, now: now);
      final entry = plan.entries.single;

      expect(entry.tiers, [ReminderTier.fiveMinutes]);
      expect(entry.missed, [
        ReminderTier.oneHour,
        ReminderTier.thirtyMinutes,
      ]);
    });

    test('an empty agenda plans nothing', () {
      final plan = buildReminderPlan(const [], eventBudget: 21, now: now);

      expect(plan.entries, isEmpty);
      expect(plan.queued, isEmpty);
      expect(plan.notificationCount, 0);
    });

    test('a budget of zero queues everything', () {
      final events = [eventAt(DateTime(2025, 9, 11, 20, 0), id: 'a')];

      final plan = buildReminderPlan(events, eventBudget: 0, now: now);

      expect(plan.entries, isEmpty);
      expect(plan.queued, hasLength(1));
    });
  });

  group('notification ids', () {
    final event = eventAt(DateTime(2025, 9, 11, 20, 0), id: 'evento-1');
    final other = eventAt(DateTime(2025, 9, 12, 20, 0), id: 'evento-2');

    test('are stable for the same event and tier', () {
      // Which is what makes marking an event twice replace the reminders
      // instead of stacking duplicates.
      expect(
        ReminderService.notificationId(event, ReminderTier.oneHour),
        ReminderService.notificationId(event, ReminderTier.oneHour),
      );
    });

    test('differ between the tiers of one event', () {
      final ids = ReminderTier.values
          .map((tier) => ReminderService.notificationId(event, tier))
          .toSet();

      expect(ids, hasLength(3));
    });

    test('never collide across events', () {
      final mine = ReminderTier.values
          .map((tier) => ReminderService.notificationId(event, tier))
          .toSet();
      final theirs = ReminderTier.values
          .map((tier) => ReminderService.notificationId(other, tier))
          .toSet();

      expect(mine.intersection(theirs), isEmpty);
    });

    test('stay inside the 32-bit signed range the OS accepts', () {
      for (final tier in ReminderTier.values) {
        final id = ReminderService.notificationId(event, tier);
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThan(1 << 31));
      }
    });
  });

  group('platform budget', () {
    test('the event budget divides the notification budget by the tiers', () {
      expect(
        ReminderService.iosPendingBudget ~/ ReminderTier.values.length,
        20,
        reason: 'iOS guarda 64 pendentes; 3 por evento cabem 20 eventos',
      );
      expect(ReminderService.iosPendingBudget, lessThan(64),
          reason: 'deixa folga abaixo do teto do iOS');
    });
  });
}
