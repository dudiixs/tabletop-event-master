import '../domain/event.dart';
import 'reminder_tier.dart';

/// What happened when reminders were scheduled for an event.
class ReminderOutcome {
  const ReminderOutcome({
    required this.scheduled,
    required this.skippedTooLate,
    required this.exactTiming,
  });

  const ReminderOutcome.none()
      : scheduled = const [],
        skippedTooLate = const [],
        exactTiming = false;

  /// The tiers that actually got scheduled.
  final List<ReminderTier> scheduled;

  /// Tiers whose fire time had already passed — an event starting in 20 minutes
  /// cannot be announced an hour ahead.
  final List<ReminderTier> skippedTooLate;

  /// Whether the OS will fire these at the exact minute. False means Android
  /// denied the exact-alarm permission and the five-minute warning may drift.
  final bool exactTiming;

  bool get isEmpty => scheduled.isEmpty;
}

/// The boundary between the app and the operating system's alarm clock.
///
/// An interface rather than a concrete class for two reasons. It names exactly
/// what the app needs from the platform, which is a short list. And it makes
/// the notification behaviour testable: the test VM is neither Android nor iOS,
/// so against the real implementation every one of these answers "not
/// supported" and nothing above it can be exercised.
abstract interface class ReminderScheduler {
  /// Whether this platform can schedule local reminders at all. False on web.
  bool get isSupported;

  /// How many events can hold a full set of reminders at once.
  ///
  /// iOS keeps only the 64 soonest pending local notifications per app and
  /// drops the rest silently, so this is a real ceiling and not a guess.
  int get eventBudget;

  /// Whether notifications are allowed, **without prompting**.
  Future<bool> areNotificationsEnabled();

  /// Asks the OS for permission to post notifications.
  Future<bool> requestPermission();

  /// Whether the OS will fire alarms at the exact minute requested.
  Future<bool> canScheduleExactly();

  /// Sends the user to the system screen that grants exact alarms.
  Future<bool> requestExactAlarms();

  /// Schedules every tier of [event] that is still in the future.
  Future<ReminderOutcome> scheduleFor(Event event);

  /// Drops every tier for [event].
  Future<void> cancelFor(Event event);

  /// Drops everything this app has scheduled.
  Future<void> cancelAll();
}
