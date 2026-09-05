import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_announcement.dart';

/// Draws an announcement in the notification tray.
///
/// Only foreground messages need this. When the app is in the background the
/// OS draws the notification block itself, and doing it twice would show the
/// same message twice.
abstract interface class AnnouncementPresenter {
  Future<void> present(PushAnnouncement announcement);
}

/// Presents announcements through the same plugin the reminders use.
///
/// On its own channel, not the reminders' one. They are different promises —
/// "an event you marked starts in an hour" versus "a new event was added" —
/// and Android channels are what let someone keep the first and silence the
/// second. Folding them together would mean the only way to stop the
/// advertising is to lose the reminder.
class LocalAnnouncementPresenter implements AnnouncementPresenter {
  LocalAnnouncementPresenter({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'event_announcements';
  static const channelName = 'Novidades da agenda';
  static const channelDescription =
      'Avisa quando um evento novo entra na agenda ou quando um evento que '
      'você acompanha muda de data ou é cancelado.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _ensureChannel() async {
    if (_ready || !_supported) return;

    // The plugin is already initialized by ReminderService; creating a channel
    // is idempotent, so doing it here keeps this class independent of whether
    // a reminder happened to be scheduled first.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.defaultImportance,
        ));

    _ready = true;
  }

  @override
  Future<void> present(PushAnnouncement announcement) async {
    if (!_supported) return;
    if (announcement.title.isEmpty && announcement.body.isEmpty) return;
    await _ensureChannel();

    await _plugin.show(
      // Keyed on the event so a correction replaces the announcement it
      // corrects instead of stacking a second copy under it. The high bit is
      // set so these ids can never collide with a reminder's, which are built
      // from the same hash shifted left by two.
      id: notificationId(announcement),
      title: announcement.title,
      body: announcement.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: announcement.eventId,
    );
  }

  /// A stable id per announced event.
  static int notificationId(PushAnnouncement announcement) {
    final source = announcement.eventId ?? announcement.title;
    return (source.hashCode & 0x0FFFFFFF) | 0x40000000;
  }
}
