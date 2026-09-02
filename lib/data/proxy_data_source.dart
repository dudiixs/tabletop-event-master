import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import '../domain/calendar_date.dart';
import '../domain/event.dart';
import 'events_data_source.dart';

/// Reads the agenda from a backend that owns the Notion token.
///
/// This is the production path, and the one that closes the leak the Expo build
/// shipped with. The app never sees a Notion credential; the backend does the
/// paginated query and hands back a flat array.
///
/// ## The contract
///
/// `GET {PROXY_BASE_URL}/events` returns `200` with:
///
/// ```json
/// { "events": [
///   { "id": "…",
///     "name": "Torneio de Pokémon TCG",
///     "date": "2025-09-10",
///     "time": "19:30",
///     "price": 35.5,
///     "location": "TableTop Sorocaba",
///     "status": "available",
///     "organizer": "Eduardo Martins",
///     "tags": ["Competitivo", "Pokémon"],
///     "imageUrl": "https://cdn…/capa.png",
///     "pageUrl": "https://…",
///     "description": [
///       { "text": "Traga seu ", "bold": false },
///       { "text": "deck", "bold": true, "code": true }
///     ] } ] }
/// ```
///
/// `date` is a plain `YYYY-MM-DD` with no zone — the day as written in Notion.
/// `time` is optional wall-clock `HH:mm`. `price` may be null, meaning "not
/// set", which is not the same as free. Every other field is optional.
///
/// Two things the backend should do that the app cannot: re-host the event
/// images somewhere stable, because Notion's file URLs expire in about an hour,
/// and cache the Notion response so the API quota is not spent per device.
class ProxyDataSource implements EventsDataSource {
  ProxyDataSource({required AppConfig config, Dio? client})
      : _client = client ??
            Dio(BaseOptions(
              baseUrl: config.proxyBaseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
            ));

  final Dio _client;

  @override
  Future<List<Event>> fetchEvents() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/events');
      final payload = response.data?['events'];
      if (payload is! List) {
        throw const EventsFailure('A resposta do servidor veio incompleta.');
      }
      return payload
          .whereType<Map<String, dynamic>>()
          .map(eventFromJson)
          .whereType<Event>()
          .toList();
    } on DioException catch (error) {
      final offline = error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout;
      throw EventsFailure(
        offline
            ? 'Sem conexão com a internet.'
            : 'Não foi possível carregar a agenda agora.',
        isOffline: offline,
        cause: error,
      );
    }
  }
}

/// Reads one event from the proxy's flat JSON shape.
///
/// Shared with the fixture source so the bundled sample data and the production
/// payload are the same format — which means the fixtures are a real contract
/// test, not a separate parallel model.
Event? eventFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  if (id is! String || id.isEmpty) return null;

  final parsedDay = parseNotionDate(json['date'] as String?);
  if (parsedDay == null) return null;

  return Event(
    id: id,
    name: (json['name'] as String?)?.trim().isNotEmpty == true
        ? (json['name'] as String).trim()
        : 'Evento sem nome',
    day: parsedDay.day,
    time: _time(json['time']) ?? parsedDay.time,
    price: (json['price'] as num?)?.toDouble(),
    location: (json['location'] as String?)?.trim().isNotEmpty == true
        ? (json['location'] as String).trim()
        : 'Local não definido',
    status: _status(json['status']),
    description: _description(json['description']),
    tags: (json['tags'] as List?)
            ?.whereType<String>()
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList() ??
        const [],
    organizer: (json['organizer'] as String?)?.trim().isNotEmpty == true
        ? (json['organizer'] as String).trim()
        : 'Organizador não definido',
    imageUrl: _nonEmpty(json['imageUrl']),
    pageUrl: _nonEmpty(json['pageUrl']),
  );
}

String? _nonEmpty(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

({int hour, int minute})? _time(Object? raw) {
  if (raw is! String) return null;
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour > 23 || minute > 59) return null;
  return (hour: hour, minute: minute);
}

EventStatus _status(Object? raw) {
  if (raw is! String) return EventStatus.available;
  return switch (raw.trim().toLowerCase()) {
    'available' => EventStatus.available,
    'sold_out' || 'soldout' => EventStatus.soldOut,
    'cancelled' || 'canceled' => EventStatus.cancelled,
    'postponed' => EventStatus.postponed,
    'unknown' => EventStatus.unknown,
    // Fall through to the Notion labels so a backend that passes the raw
    // select value through still maps correctly.
    final other => EventStatus.fromNotion(other),
  };
}

List<RichRun> _description(Object? raw) {
  // A plain string is accepted so a simpler backend can skip the formatting.
  if (raw is String) {
    final text = raw.trim();
    return text.isEmpty ? const [] : [RichRun(text: text)];
  }
  if (raw is! List) return const [];

  return raw
      .whereType<Map<String, dynamic>>()
      .map((run) {
        final text = run['text'] as String? ?? '';
        if (text.isEmpty) return null;
        return RichRun(
          text: text,
          bold: run['bold'] == true,
          italic: run['italic'] == true,
          strikethrough: run['strikethrough'] == true,
          underline: run['underline'] == true,
          code: run['code'] == true,
          href: _nonEmpty(run['href']),
        );
      })
      .whereType<RichRun>()
      .toList();
}
