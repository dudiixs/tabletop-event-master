/// What a push is telling the app.
///
/// The server puts this in the message's `data` map. It is deliberately a
/// small closed set: the app has to decide what to do without the server
/// being able to make it do anything, so an unrecognised kind is shown as a
/// plain announcement rather than dispatched somewhere.
enum AnnouncementKind {
  /// An event was added to the agenda.
  newEvent('new_event'),

  /// An event the user may have marked was cancelled.
  cancelled('event_cancelled'),

  /// Date, time or venue moved.
  updated('event_updated'),

  /// Anything else the server sends. Displayed, never acted on.
  unknown('unknown');

  const AnnouncementKind(this.wireName);

  /// The string the server puts in `data.type`.
  final String wireName;

  static AnnouncementKind parse(Object? value) {
    for (final kind in values) {
      if (kind != unknown && kind.wireName == value) return kind;
    }
    return unknown;
  }
}

/// One push message, decoded.
///
/// A plain Dart class with no Firebase types in it. That boundary is the whole
/// point: [PushGateway] maps the platform's `RemoteMessage` into this, so every
/// rule about what a push *means* — which ones open an event, what shows in the
/// tray, what is ignored — is exercised by tests on a VM that has no Firebase.
class PushAnnouncement {
  const PushAnnouncement({
    required this.kind,
    required this.title,
    required this.body,
    this.eventId,
    this.category,
    this.sentAt,
  });

  final AnnouncementKind kind;
  final String title;
  final String body;

  /// The event this is about, when it is about one.
  ///
  /// Null is normal: a general announcement has no event, and so does a
  /// malformed one. Anything that navigates has to handle null rather than
  /// assume the server got it right.
  final String? eventId;

  /// The `EventCategory.name` the server filed this under, when it sent one.
  final String? category;

  final DateTime? sentAt;

  /// Whether tapping this should try to open an event.
  bool get opensEvent => eventId != null && eventId!.isNotEmpty;

  /// Reads the `data` map of a push.
  ///
  /// [title] and [body] come from the message's notification block when the
  /// server sent one; the `data` map can override them, which is what lets a
  /// data-only push still render something in the tray.
  ///
  /// Everything is read defensively. A push arrives from the network into a
  /// code path that can run with no UI on screen, so a missing or wrongly typed
  /// field has to produce a dull announcement, never an exception.
  factory PushAnnouncement.fromData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
    DateTime? sentAt,
  }) {
    String? text(String key) {
      final value = data[key];
      if (value == null) return null;
      final str = value.toString().trim();
      return str.isEmpty ? null : str;
    }

    return PushAnnouncement(
      kind: AnnouncementKind.parse(text('type')),
      title: text('title') ?? title?.trim() ?? 'TableTop Events',
      body: text('body') ?? body?.trim() ?? '',
      eventId: text('eventId'),
      category: text('category'),
      sentAt: sentAt,
    );
  }
}
