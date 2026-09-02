import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/format/formatters.dart';
import '../domain/event.dart';
import 'reminder_plan.dart';
import 'reminder_tier.dart';

/// What happened when reminders were scheduled for an event.
class ReminderOutcome {
  const ReminderOutcome({
    required this.scheduled,
    required this.skippedTooLate,
    required this.exactTiming,
  });

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

/// Schedules the local reminders for an event.
///
/// The Expo app requested notification permission on every launch, created an
/// Android channel called "Eventos", and never scheduled a single notification.
/// This is that feature built for real.
///
/// Deliberately local rather than push: the phone already knows when the event
/// starts, so a scheduled notification fires offline, at the exact minute, with
/// no dependency on FCM delivery latency. Push is the wrong tool for "starts in
/// five minutes" — it is the right tool for things the phone cannot know, which
/// is why a new event or a cancellation goes over FCM instead.
class ReminderService {
  ReminderService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'event_reminders';
  static const _channelName = 'Lembretes de eventos';
  static const _channelDescription =
      'Avisa 1 hora, 30 minutos e 5 minutos antes de um evento que você marcou.';

  /// iOS keeps only the **64 soonest** pending local notifications per app and
  /// silently drops the rest. At three tiers per event that is 21 events, so
  /// the schedule is budgeted and refilled as near events pass.
  static const iosPendingBudget = 60;

  /// Android has no comparable low ceiling; the budget here only stops an
  /// absurd number of alarms from piling up.
  static const androidPendingBudget = 300;

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;
  bool? _exactAllowed;

  /// Whether reminders can work on this platform at all.
  ///
  /// Scheduling needs a device clock and a notification service; the web build
  /// has neither, so the UI hides the control instead of offering something
  /// that silently does nothing.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// How many pending notifications this platform tolerates.
  static int get pendingBudget {
    if (!isSupported) return 0;
    return Platform.isIOS ? iosPendingBudget : androidPendingBudget;
  }

  /// How many events can hold a full set of reminders at once.
  static int get eventBudget => pendingBudget ~/ ReminderTier.values.length;

  /// Loads the timezone database and registers the channel.
  ///
  /// Does **not** ask for permission — that is [requestPermission], called the
  /// first time someone marks an event rather than on launch, so the prompt
  /// arrives with a visible reason attached.
  Future<void> initialize() async {
    if (_ready || !isSupported) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_deviceTimeZone()));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ));

    _ready = true;
  }

  /// Asks the OS for permission to post notifications.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await initialize();

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  /// Whether the OS will fire alarms at the exact minute requested.
  ///
  /// Android 12 put exact alarms behind `SCHEDULE_EXACT_ALARM`. Without it the
  /// system batches alarms for battery, which can push a notification minutes
  /// late — fatal for the five-minute warning and harmless for the other two.
  Future<bool> canScheduleExactly() async {
    if (!isSupported) return false;
    if (Platform.isIOS) return true;
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    _exactAllowed = await android?.canScheduleExactNotifications() ?? false;
    return _exactAllowed!;
  }

  /// Sends the user to the system screen that grants exact alarms.
  ///
  /// Only meaningful on Android 12+ and only when [canScheduleExactly] is
  /// false. On Android 13+ an app in the alarm-and-calendar category can hold
  /// `USE_EXACT_ALARM` instead, which is granted at install and needs no prompt.
  Future<bool> requestExactAlarms() async {
    if (!isSupported || Platform.isIOS) return true;
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestExactAlarmsPermission() ?? false;
    _exactAllowed = granted;
    return granted;
  }

  /// Schedules every tier that is still in the future for [event].
  Future<ReminderOutcome> scheduleFor(Event event) async {
    if (!isSupported) {
      return const ReminderOutcome(
        scheduled: [],
        skippedTooLate: [],
        exactTiming: false,
      );
    }
    await initialize();

    final exact = _exactAllowed ?? await canScheduleExactly();
    final startsAt = event.startsAt();

    // Which tiers are still ahead is decided by the pure planner, so the rule
    // is covered by tests rather than only by running the app at the right
    // moment.
    final live = liveTiersFor(event, now: DateTime.now());
    final entry = ReminderPlanEntry(event: event, tiers: live);

    for (final tier in live) {
      await _schedule(event, tier, tier.fireTimeFor(startsAt), exact: exact);
    }

    return ReminderOutcome(
      scheduled: live,
      skippedTooLate: entry.missed,
      exactTiming: exact,
    );
  }

  Future<void> _schedule(
    Event event,
    ReminderTier tier,
    DateTime fireAt, {
    required bool exact,
  }) async {
    // Only the five-minute tier is worth spending the exact-alarm budget on.
    final useExact = exact && tier.needsExactTiming;

    await _plugin.zonedSchedule(
      id: notificationId(event, tier),
      title: tier.headline,
      body: '${event.name} · ${Fmt.time(event)} · ${event.location}',
      scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: useExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: event.id,
    );
  }

  /// Drops every tier for [event].
  Future<void> cancelFor(Event event) async {
    if (!isSupported) return;
    await initialize();
    for (final tier in ReminderTier.values) {
      await _plugin.cancel(id: notificationId(event, tier));
    }
  }

  /// Drops everything this app has scheduled.
  Future<void> cancelAll() async {
    if (!isSupported) return;
    await initialize();
    await _plugin.cancelAll();
  }

  /// The ids currently pending with the OS, for reconciling on launch.
  Future<Set<int>> pendingIds() async {
    if (!isSupported) return const {};
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((request) => request.id).toSet();
  }

  /// A stable id for one tier of one event.
  ///
  /// The scheduling APIs key on an int, so the same event and tier must always
  /// produce the same one — that is what makes re-scheduling replace instead of
  /// stacking duplicates. Three low bits carry the tier so the ids of an
  /// event's tiers never collide with another event's.
  static int notificationId(Event event, ReminderTier tier) {
    final base = event.id.hashCode & 0x0FFFFFFF;
    return (base << 2) | tier.slot;
  }

  /// The device's IANA zone name.
  ///
  /// Every event in this database happens in Brazil, so São Paulo is the
  /// fallback and keeps a reminder right for the audience that actually has
  /// the app even if the lookup finds nothing.
  String _deviceTimeZone() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      for (final name in tz.timeZoneDatabase.locations.keys) {
        if (!name.startsWith('America/')) continue;
        if (tz.TZDateTime.now(tz.getLocation(name)).timeZoneOffset == offset) {
          return name;
        }
      }
    } on Object {
      // Fall through to the default.
    }
    return 'America/Sao_Paulo';
  }
}
