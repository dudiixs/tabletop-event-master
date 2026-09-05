import 'dart:async';

import 'package:tabletop_events/notifications/announcement_presenter.dart';
import 'package:tabletop_events/notifications/push_announcement.dart';
import 'package:tabletop_events/notifications/push_gateway.dart';

/// A push gateway that records what it was asked to do instead of talking to
/// Firebase.
///
/// Lets the tests drive the whole push flow — topic reconciliation, a partial
/// failure, a tap from cold start — on a VM with no Firebase and no network.
class FakePushGateway implements PushGateway {
  FakePushGateway({
    this.isSupported = true,
    this.notificationsEnabled = true,
    this.permissionWillBeGranted = true,
  });

  @override
  bool isSupported;

  bool notificationsEnabled;
  bool permissionWillBeGranted;

  /// The topics this device currently holds.
  final subscribed = <String>{};

  /// Every call made, in order, as `'subscribe:game_rpg'`. Asserting on this
  /// is how a test proves the reconciler sent only the difference.
  final calls = <String>[];

  /// Topics whose next call throws, standing in for being offline or for iOS
  /// refusing before APNs has handed over a token.
  final failing = <String>{};

  int initializeCalls = 0;
  int permissionRequests = 0;

  final _messages = StreamController<PushAnnouncement>.broadcast();
  final _opened = StreamController<PushAnnouncement>.broadcast();

  /// What a cold launch from a tap will report, once.
  PushAnnouncement? launchMessage;
  int initialMessageReads = 0;

  /// Delivers a push as if the app were in the foreground.
  void deliver(PushAnnouncement announcement) => _messages.add(announcement);

  /// Delivers a tap as if the app were in the background.
  void tap(PushAnnouncement announcement) => _opened.add(announcement);

  Future<void> dispose() async {
    await _messages.close();
    await _opened.close();
  }

  @override
  Future<void> initialize() async => initializeCalls++;

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
  Future<void> subscribeToTopic(String topic) async {
    calls.add('subscribe:$topic');
    if (failing.contains(topic)) throw StateError('offline');
    subscribed.add(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    calls.add('unsubscribe:$topic');
    if (failing.contains(topic)) throw StateError('offline');
    subscribed.remove(topic);
  }

  @override
  Stream<PushAnnouncement> get onMessage => _messages.stream;

  @override
  Stream<PushAnnouncement> get onOpened => _opened.stream;

  @override
  Future<PushAnnouncement?> initialMessage() async {
    initialMessageReads++;
    final message = launchMessage;
    launchMessage = null;
    return message;
  }

  @override
  Future<String?> token() async => isSupported ? 'fake-token' : null;
}

/// A presenter that keeps what it was asked to draw.
class FakePresenter implements AnnouncementPresenter {
  final presented = <PushAnnouncement>[];

  @override
  Future<void> present(PushAnnouncement announcement) async =>
      presented.add(announcement);
}
