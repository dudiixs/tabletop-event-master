import 'package:tabletop_events/domain/event.dart';
import 'package:tabletop_events/notifications/reminder_plan.dart';
import 'package:tabletop_events/notifications/reminder_scheduler.dart';
import 'package:tabletop_events/notifications/reminder_tier.dart';

/// A scheduler that records what it was asked to do instead of talking to the
/// operating system.
///
/// Lets the tests exercise the whole reminder flow — permission states, the
/// budget, cancellation — on a VM that is neither Android nor iOS.
class FakeScheduler implements ReminderScheduler {
  FakeScheduler({
    this.isSupported = true,
    this.notificationsEnabled = true,
    this.exactAllowed = true,
    this.permissionWillBeGranted = true,
    this.eventBudget = 20,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  @override
  bool isSupported;

  @override
  int eventBudget;

  bool notificationsEnabled;
  bool exactAllowed;

  /// What [requestPermission] will answer.
  bool permissionWillBeGranted;

  final DateTime Function() _clock;

  /// Every event id currently holding reminders, with the tiers scheduled.
  final scheduled = <String, List<ReminderTier>>{};

  /// Call counts, for asserting that WhatsApp was not blocked by a prompt.
  int permissionRequests = 0;
  int exactAlarmRequests = 0;
  int cancelAllCalls = 0;

  @override
  Future<bool> areNotificationsEnabled() async =>
      isSupported && notificationsEnabled;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (!isSupported) return false;
    notificationsEnabled = permissionWillBeGranted;
    return notificationsEnabled;
  }

  @override
  Future<bool> canScheduleExactly() async => isSupported && exactAllowed;

  @override
  Future<bool> requestExactAlarms() async {
    exactAlarmRequests++;
    exactAllowed = true;
    return true;
  }

  @override
  Future<ReminderOutcome> scheduleFor(Event event) async {
    if (!isSupported || !notificationsEnabled) {
      return const ReminderOutcome.none();
    }

    final tiers = liveTiersFor(event, now: _clock());
    if (tiers.isEmpty) {
      return ReminderOutcome(
        scheduled: const [],
        skippedTooLate: ReminderTier.values,
        exactTiming: exactAllowed,
      );
    }

    scheduled[event.id] = tiers;
    return ReminderOutcome(
      scheduled: tiers,
      skippedTooLate:
          ReminderTier.values.where((t) => !tiers.contains(t)).toList(),
      exactTiming: exactAllowed,
    );
  }

  @override
  Future<void> cancelFor(Event event) async => scheduled.remove(event.id);

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    scheduled.clear();
  }
}
