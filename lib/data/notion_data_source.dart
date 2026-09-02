import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import '../domain/event.dart';
import 'events_data_source.dart';
import 'notion_mapper.dart';

/// Reads the agenda straight from the Notion API.
///
/// **Development only.** The token this needs is embedded in the built binary,
/// which is how the Expo release ended up publishing its integration token.
/// Browsers also cannot reach the Notion API at all: it sends no CORS headers.
/// [ProxyDataSource] is the production path.
class NotionDataSource implements EventsDataSource {
  NotionDataSource({
    required AppConfig config,
    Dio? client,
    this.mapper = const NotionMapper(),
  })  : _config = config,
        _client = client ??
            Dio(BaseOptions(
              baseUrl: 'https://api.notion.com/v1',
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'Authorization': 'Bearer ${config.notionToken}',
                'Notion-Version': _apiVersion,
                'Content-Type': 'application/json',
              },
            ));

  static const _apiVersion = '2022-06-28';

  /// Notion caps a response at 100 records regardless of what is asked for.
  static const _pageSize = 100;

  /// A stop so a pagination bug cannot loop forever. 50 pages is 5,000 events.
  static const _maxPages = 50;

  final AppConfig _config;
  final NotionMapper mapper;
  final Dio _client;

  @override
  Future<List<Event>> fetchEvents() async {
    final events = <Event>[];
    String? cursor;
    var pagesRead = 0;

    do {
      final body = await _queryPage(cursor);
      events.addAll(mapper.mapResults(body));
      cursor = NotionMapper.nextCursor(body);
      pagesRead++;
    } while (cursor != null && pagesRead < _maxPages);

    return events;
  }

  /// Fetches one page of the database query.
  ///
  /// Sorting is left to the client: the filter layer orders by start time, and
  /// asking Notion to sort by a property that has been renamed makes the whole
  /// query fail rather than one field come back empty.
  Future<Map<String, dynamic>> _queryPage(String? cursor) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/databases/${_config.notionDatabaseId}/query',
        data: {
          'page_size': _pageSize,
          'start_cursor': ?cursor,
        },
      );

      final body = response.data;
      if (body == null) {
        throw const EventsFailure('O Notion respondeu sem conteúdo.');
      }
      return body;
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  EventsFailure _translate(DioException error) {
    final status = error.response?.statusCode;

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return EventsFailure(
        'Sem conexão com a internet.',
        isOffline: true,
        cause: error,
      );
    }

    return EventsFailure(
      switch (status) {
        401 => 'O token do Notion foi recusado.',
        403 => 'A integração não tem acesso a esta base do Notion.',
        404 => 'A base de eventos não foi encontrada no Notion.',
        429 => 'Muitas requisições ao Notion. Tente em instantes.',
        _ => 'O Notion não respondeu como esperado${status == null ? '' : ' ($status)'}.',
      },
      cause: error,
    );
  }
}
