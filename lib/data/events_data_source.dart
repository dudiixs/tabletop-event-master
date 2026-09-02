import '../domain/event.dart';

/// Something went wrong fetching the agenda.
///
/// The Expo data layer swallowed every failure and returned an empty list, so a
/// dropped connection looked exactly like an agenda with no events. Failures
/// travel as exceptions here, and the UI renders them as errors with a retry.
class EventsFailure implements Exception {
  const EventsFailure(this.message, {this.isOffline = false, this.cause});

  /// Text written for the person holding the phone, not for a log.
  final String message;

  /// Whether this looks like a connectivity problem rather than a server one.
  final bool isOffline;

  final Object? cause;

  @override
  String toString() => 'EventsFailure($message)';
}

/// Reads events from somewhere.
///
/// Three implementations exist — bundled fixtures, the Notion API directly, and
/// a backend proxy — and swapping between them is a single line in
/// `events_providers.dart`.
abstract interface class EventsDataSource {
  /// Every event in the database, in no guaranteed order.
  ///
  /// Implementations must fetch *all* of them, following pagination where the
  /// transport has any. Filtering to what a screen shows happens above this
  /// layer, so the cache holds one complete agenda.
  Future<List<Event>> fetchEvents();
}
