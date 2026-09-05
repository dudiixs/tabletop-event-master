import 'push_announcement.dart';

/// The boundary between the app and the push service.
///
/// An interface for the same reason [ReminderScheduler] is one: it names the
/// short list of things the app actually needs from FCM, and it makes the
/// behaviour testable. Against the real implementation on the test VM every
/// answer is "not supported", so nothing above it could be exercised.
///
/// Note what is **not** here. There is no "send" — this app only ever receives.
/// Sending requires the service account key, which lives on the server.
abstract interface class PushGateway {
  /// Whether this platform can receive push at all.
  ///
  /// False on web: no web app is registered in the Firebase project, and the
  /// web build reads fixtures anyway.
  bool get isSupported;

  /// Brings up Firebase and the message listeners. Safe to call twice.
  ///
  /// Does **not** ask for permission, matching [ReminderService.initialize]:
  /// the prompt should arrive with a visible reason, not at launch.
  Future<void> initialize();

  /// Whether push is already allowed, without prompting.
  Future<bool> areNotificationsEnabled();

  /// Asks the OS for permission to post notifications.
  Future<bool> requestPermission();

  /// Starts receiving [topic].
  Future<void> subscribeToTopic(String topic);

  /// Stops receiving [topic].
  Future<void> unsubscribeFromTopic(String topic);

  /// Messages that arrive while the app is in the foreground.
  ///
  /// The OS does not draw these — an app in front is expected to decide for
  /// itself — so something has to present them.
  Stream<PushAnnouncement> get onMessage;

  /// Messages whose tray notification the user tapped, with the app already
  /// running in the background.
  Stream<PushAnnouncement> get onOpened;

  /// The message whose tap launched the app from cold, if that is why it
  /// started. Returns null on an ordinary launch, and only once.
  Future<PushAnnouncement?> initialMessage();

  /// This device's registration token.
  ///
  /// Unused while targeting is by topic, and kept because it is what a "remind
  /// only me" feature would need. Null when push is unavailable.
  Future<String?> token();
}
