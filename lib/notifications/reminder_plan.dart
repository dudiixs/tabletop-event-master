import '../domain/calendar_date.dart';
import '../domain/event.dart';
import '../domain/event_filters.dart';
import 'reminder_tier.dart';

/// What a device should have scheduled right now.
///
/// The interesting decisions here are pure on purpose: which events win the
/// limited notification slots, and which tiers of each are still in the future.
/// Both are easy to get subtly wrong in a way nobody notices until a reminder
/// does not arrive, and neither needs a device to be tested.
class ReminderPlan {
  const ReminderPlan({required this.entries, required this.queued});

  /// The events that get reminders, soonest first, with their live tiers.
  final List<ReminderPlanEntry> entries;

  /// Marked events that did not fit in the budget. Their reminders start once
  /// a nearer event has passed and freed the slots.
  final List<Event> queued;

  bool holdsRemindersFor(String eventId) =>
      entries.any((entry) => entry.event.id == eventId);

  /// How many notifications this plan asks the OS to hold.
  int get notificationCount =>
      entries.fold(0, (total, entry) => total + entry.tiers.length);
}

class ReminderPlanEntry {
  const ReminderPlanEntry({required this.event, required this.tiers});

  final Event event;

  /// The tiers whose fire time is still ahead. Empty is possible for an event
  /// that starts in under five minutes.
  final List<ReminderTier> tiers;

  /// Tiers whose moment already passed — an event in 20 minutes cannot be
  /// announced an hour ahead.
  List<ReminderTier> get missed =>
      ReminderTier.values.where((tier) => !tiers.contains(tier)).toList();
}

/// Builds the plan for [subscribed].
///
/// [subscribed] should already be filtered to upcoming events and sorted
/// soonest first. [eventBudget] is the platform ceiling: iOS keeps only the 64
/// soonest pending local notifications and drops the rest without a word, so
/// the nearest events have to win.
ReminderPlan buildReminderPlan(
  List<Event> subscribed, {
  required int eventBudget,
  required DateTime now,
}) {
  final entries = <ReminderPlanEntry>[];
  final queued = <Event>[];

  for (final event in subscribed) {
    final tiers = liveTiersFor(event, now: now);

    // An event with nothing left to announce takes no slot: spending one on it
    // would push a later event out of the budget for nothing.
    if (tiers.isEmpty) continue;

    if (entries.length < eventBudget) {
      entries.add(ReminderPlanEntry(event: event, tiers: tiers));
    } else {
      queued.add(event);
    }
  }

  return ReminderPlan(entries: entries, queued: queued);
}

/// The tiers of [event] whose fire time is still in the future.
List<ReminderTier> liveTiersFor(Event event, {required DateTime now}) {
  final startsAt = event.startsAt();
  return ReminderTier.values
      .where((tier) => tier.fireTimeFor(startsAt).isAfter(now))
      .toList();
}

/// The marked events that still point at something live, soonest first.
///
/// A mark can go stale in three ways: the event was deleted in Notion, its date
/// moved into the past, or it simply happened. Pruning keeps the bells lit in
/// the UI honest — and pure, so the rule is tested rather than only observed on
/// a device.
List<Event> liveSubscriptions(
  Set<String> marked,
  List<Event> agenda, {
  required DateTime now,
}) {
  final byId = {for (final event in agenda) event.id: event};
  return marked
      .map((id) => byId[id])
      .whereType<Event>()
      .toList()
      .upcomingFrom(dateOnly(now));
}
