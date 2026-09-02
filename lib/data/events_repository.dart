import '../domain/event.dart';
import 'events_data_source.dart';

/// The agenda, fetched once and shared by every screen.
///
/// The Expo app built its cache in the root screen and threaded it down as a
/// prop — and then the home screen called the API directly anyway, so opening
/// the app always cost at least two full fetches. Here every screen reads
/// through this one object, so the agenda is fetched once per TTL no matter
/// which screen asks.
class EventsRepository {
  EventsRepository({
    required this.dataSource,
    this.ttl = const Duration(minutes: 5),
    this.clock = DateTime.now,
  });

  final EventsDataSource dataSource;

  /// How long a fetched agenda stays fresh.
  final Duration ttl;

  /// Injectable "now", so the TTL is testable without waiting.
  final DateTime Function() clock;

  List<Event>? _cache;
  DateTime? _cachedAt;

  /// An in-flight fetch, so two screens opening at once share one request
  /// instead of racing.
  Future<List<Event>>? _inFlight;

  /// Whether the cached agenda is still within its TTL.
  bool get hasFreshCache {
    final cachedAt = _cachedAt;
    if (_cache == null || cachedAt == null) return false;
    return clock().difference(cachedAt) < ttl;
  }

  /// The cached agenda regardless of age, or null if nothing was ever fetched.
  ///
  /// Used to keep showing the last known agenda underneath a failed refresh
  /// rather than dropping the screen to an error state.
  List<Event>? get lastKnown => _cache;

  /// When the cached agenda was fetched.
  DateTime? get cachedAt => _cachedAt;

  /// The full agenda, from cache when fresh.
  ///
  /// Pass [forceRefresh] for pull-to-refresh. Throws [EventsFailure] when the
  /// fetch fails and there is nothing cached to fall back on.
  Future<List<Event>> getEvents({bool forceRefresh = false}) {
    if (!forceRefresh && hasFreshCache) {
      return Future.value(_cache);
    }

    // Coalesce concurrent callers onto one request.
    final pending = _inFlight;
    if (pending != null && !forceRefresh) return pending;

    final request = _fetch();
    _inFlight = request;
    return request;
  }

  Future<List<Event>> _fetch() async {
    try {
      final events = await dataSource.fetchEvents();
      _cache = events;
      _cachedAt = clock();
      return events;
    } finally {
      _inFlight = null;
    }
  }

  /// Forgets the cached agenda.
  void invalidate() {
    _cache = null;
    _cachedAt = null;
  }
}
