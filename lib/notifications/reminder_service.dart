import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/event.dart';

/// Schedules the local reminder for an event.
///
/// The Expo app asked for notification permission on every launch and created
/// an Android channel called "Eventos", then never scheduled or received a
/// single notification. This is that feature, actually built: the user marks an
/// event and gets one local notification a few hours before it starts. No
/// server, no push token, nothing to deploy.
class ReminderService {
  ReminderService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'event_reminders';
  static const _channelName = 'Lembretes de eventos';
  static const _channelDescription =
      'Avisa algumas horas antes de um evento que você marcou.';

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;

  /// Whether reminders can work on this platform at all.
  ///
  /// Scheduling needs a device clock and a notification service; the web build
  /// has neither, so the UI hides the bell instead of offering something that
  /// silently does nothing.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Loads the timezone database and registers the channel.
  ///
  /// Safe to call more than once. Does **not** ask for permission — that is
  /// [requestPermission], called the first time someone actually sets a
  /// reminder rather than on launch, so the prompt arrives with a reason
  /// attached.
  Future<void> initialize() async {
    if (_ready || !isSupported) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await _deviceTimeZone()));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Permission is requested on demand, not at startup.
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
  ///
  /// Returns whether reminders can now be delivered.
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

  /// Schedules the reminder for [event], [leadTime] before it starts.
  ///
  /// Returns false when the reminder would land in the past — an event starting
  /// in an hour cannot be announced three hours ahead, and the caller needs to
  /// say so rather than pretend it was set.
  Future<bool> schedule(Event event, {required Duration leadTime}) async {
    if (!isSupported) return false;
    await initialize();

    final fireAt = event.startsAt().subtract(leadTime);
    if (!fireAt.isAfter(DateTime.now())) return false;

    await _plugin.zonedSchedule(
      id: _idFor(event),
      title: event.name,
      body: _body(event, leadTime),
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
      // Inexact scheduling needs no special permission on Android 12+, and a
      // reminder that lands a few minutes off is fine. Exact alarms would make
      // the user grant SCHEDULE_EXACT_ALARM for no real gain.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: event.id,
    );

    return true;
  }

  /// Drops the reminder for [event].
  Future<void> cancel(Event event) async {
    if (!isSupported) return;
    await _plugin.cancel(id: _idFor(event));
  }

  /// The ids the OS currently has scheduled, used to reconcile on launch.
  Future<Set<int>> pendingIds() async {
    if (!isSupported) return const {};
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((request) => request.id).toSet();
  }

  /// A stable 31-bit id derived from the event id.
  ///
  /// The scheduling APIs key on an int, so the same event must always produce
  /// the same one: that is what makes setting a reminder twice replace it
  /// instead of stacking up duplicates.
  int idFor(Event event) => _idFor(event);

  static int _idFor(Event event) => event.id.hashCode & 0x7FFFFFFF;

  String _body(Event event, Duration leadTime) {
    final hours = leadTime.inHours;
    final when = hours >= 1
        ? 'Começa em ${hours}h'
        : 'Começa em ${leadTime.inMinutes} min';
    return '$when · ${event.location}';
  }

  /// The device's IANA zone name, falling back to São Paulo.
  ///
  /// Every event in this database happens in Brazil, so that fallback keeps a
  /// reminder roughly right even if the lookup fails.
  Future<String> _deviceTimeZone() async {
    try {
      final offset = DateTime.now().timeZoneOffset;
      // A precise lookup needs a platform channel; matching the current offset
      // is enough for scheduling a same-zone reminder.
      for (final name in tz.timeZoneDatabase.locations.keys) {
        final location = tz.getLocation(name);
        final now = tz.TZDateTime.now(location);
        if (now.timeZoneOffset == offset && name.startsWith('America/')) {
          return name;
        }
      }
    } on Object {
      // Fall through to the default below.
    }
    return 'America/Sao_Paulo';
  }
}
