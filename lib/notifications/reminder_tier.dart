/// How far ahead of an event a reminder fires.
///
/// Three of them, because one is not enough for an evening event: an hour out
/// is when you decide to leave, half an hour is when you actually leave, and
/// five minutes is the "it is starting" nudge.
enum ReminderTier {
  oneHour(Duration(hours: 1), 'Falta 1 hora', 0),
  thirtyMinutes(Duration(minutes: 30), 'Faltam 30 minutos', 1),
  fiveMinutes(Duration(minutes: 5), 'Começa em 5 minutos', 2);

  const ReminderTier(this.leadTime, this.headline, this.slot);

  final Duration leadTime;

  /// The notification title. Says the time remaining, not the event name — the
  /// event name is the body, so the glanceable part is the urgency.
  final String headline;

  /// A small stable number used to derive this tier's notification id from the
  /// event's, so re-scheduling replaces rather than duplicates.
  final int slot;

  /// Whether this tier needs the OS to fire at the exact minute.
  ///
  /// A five-minute warning delivered nine minutes late is worse than useless.
  /// The hour and half-hour tiers tolerate the drift that Android's
  /// battery-friendly inexact scheduling introduces.
  bool get needsExactTiming => this == ReminderTier.fiveMinutes;

  /// When this tier should fire for an event starting at [startsAt].
  DateTime fireTimeFor(DateTime startsAt) => startsAt.subtract(leadTime);
}
