import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/config/firebase_options.dart';
import 'push_announcement.dart';
import 'push_gateway.dart';

/// Handles a push that arrived with the app not running in the foreground.
///
/// Must be a top-level function with this pragma: the OS spawns a **separate
/// Dart isolate** to run it, so it cannot close over anything and the tree
/// shaker would otherwise drop it from a release build.
///
/// It deliberately does almost nothing. A message carrying a `notification`
/// block is drawn by the OS itself before this runs, so presenting it here
/// would show the same announcement twice. This exists so a data-only push is
/// still a valid thing for the server to send, and as the place where anything
/// that must happen without the app open would go.
@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

/// Receives push through Firebase Cloud Messaging.
///
/// Every `RemoteMessage` is mapped to a [PushAnnouncement] at this edge, so no
/// Firebase type gets past it into the rest of the app.
class PushService implements PushGateway {
  /// [messaging] is injectable so a test can hand in a double; in the app
  /// it is left out and the singleton is read lazily on first use.
  PushService([this._messaging]);

  FirebaseMessaging? _messaging;
  bool _ready = false;
  bool _initialMessageConsumed = false;

  FirebaseMessaging get _fcm => _messaging ??= FirebaseMessaging.instance;

  /// Push needs a notification service and a registration token, which the web
  /// build has neither of in this project.
  @override
  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<void> initialize() async {
    if (_ready || !isSupported) return;

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);

    // Stop iOS from drawing foreground messages itself. The app presents them
    // on its own channel instead, so an announcement looks the same whichever
    // platform it lands on and can be silenced separately from the reminders.
    if (Platform.isIOS) {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );
    }

    _ready = true;
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    if (!isSupported) return false;
    await initialize();
    final settings = await _fcm.getNotificationSettings();
    return _granted(settings);
  }

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await initialize();
    final settings = await _fcm.requestPermission();
    return _granted(settings);
  }

  /// Provisional counts as granted: on iOS it means the notification is
  /// delivered quietly to the notification centre rather than not at all.
  static bool _granted(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  @override
  Future<void> subscribeToTopic(String topic) async {
    if (!isSupported) return;
    await initialize();
    // A topic call is a network call and it can fail offline. A failure here
    // must not take down whatever asked for it: the reconciler stores what it
    // actually confirmed, so a dropped call is simply retried next launch.
    try {
      await _fcm.subscribeToTopic(topic);
    } catch (error) {
      debugPrint('Falha ao assinar o tópico $topic: $error');
      rethrow;
    }
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!isSupported) return;
    await initialize();
    try {
      await _fcm.unsubscribeFromTopic(topic);
    } catch (error) {
      debugPrint('Falha ao cancelar o tópico $topic: $error');
      rethrow;
    }
  }

  @override
  Stream<PushAnnouncement> get onMessage => isSupported
      ? FirebaseMessaging.onMessage.map(announcementFrom)
      : const Stream.empty();

  @override
  Stream<PushAnnouncement> get onOpened => isSupported
      ? FirebaseMessaging.onMessageOpenedApp.map(announcementFrom)
      : const Stream.empty();

  @override
  Future<PushAnnouncement?> initialMessage() async {
    if (!isSupported || _initialMessageConsumed) return null;
    await initialize();

    // Once only: the platform keeps answering with the same message, and
    // re-reading it would reopen the event every time the app resumed.
    _initialMessageConsumed = true;

    final message = await _fcm.getInitialMessage();
    return message == null ? null : announcementFrom(message);
  }

  @override
  Future<String?> token() async {
    if (!isSupported) return null;
    await initialize();
    try {
      return await _fcm.getToken();
    } catch (error) {
      debugPrint('Falha ao ler o token de push: $error');
      return null;
    }
  }

  /// Maps the platform's message onto the app's own type.
  ///
  /// Top-level fields are only a display hint; `data` wins, because it is the
  /// part that survives every delivery mode intact.
  static PushAnnouncement announcementFrom(RemoteMessage message) {
    return PushAnnouncement.fromData(
      message.data,
      title: message.notification?.title,
      body: message.notification?.body,
      sentAt: message.sentTime,
    );
  }
}
