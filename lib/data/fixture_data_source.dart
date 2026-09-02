import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/calendar_date.dart';
import '../domain/event.dart';
import 'events_data_source.dart';
import 'proxy_data_source.dart' show eventFromJson;

/// Reads the agenda from the bundled sample file.
///
/// Three jobs: it drives the widget tests, it lets the web build show a working
/// app despite the Notion API refusing browser requests, and it makes the whole
/// UI reviewable without a token. It parses the same JSON shape the proxy
/// returns, so the fixture doubles as a contract test for that format.
///
/// Dates in the file are written as day offsets (`+0`, `+3`, `-2`) rather than
/// fixed dates, so the sample agenda is always relative to today and the week
/// view is never empty.
class FixtureDataSource implements EventsDataSource {
  const FixtureDataSource({
    this.assetPath = 'assets/fixtures/events.json',
    this.delay = const Duration(milliseconds: 350),
    this.bundle,
  });

  final String assetPath;

  /// A small pause so loading states are actually visible while developing.
  /// Nothing like the 500–1000 ms the Expo screens added on every load.
  final Duration delay;

  /// Overridden in tests to serve the fixture from memory.
  final AssetBundle? bundle;

  @override
  Future<List<Event>> fetchEvents() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final String raw;
    try {
      raw = await (bundle ?? rootBundle).loadString(assetPath);
    } on FlutterError catch (error) {
      throw EventsFailure(
        'Os eventos de exemplo não foram encontrados.',
        cause: error,
      );
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const EventsFailure('O arquivo de exemplo está mal formado.');
    }

    final payload = decoded['events'];
    if (payload is! List) {
      throw const EventsFailure('O arquivo de exemplo não tem eventos.');
    }

    final reference = today();
    return payload
        .whereType<Map<String, dynamic>>()
        .map((json) => _resolveOffsets(json, reference))
        .map(eventFromJson)
        .whereType<Event>()
        .toList();
  }

  /// Rewrites a `dayOffset` field into a concrete `date` relative to today.
  Map<String, dynamic> _resolveOffsets(
    Map<String, dynamic> json,
    DateTime reference,
  ) {
    final offset = json['dayOffset'];
    if (offset is! num) return json;

    final day = addDays(reference, offset.toInt());
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');

    return {
      ...json,
      'date': '${day.year}-$month-$dayOfMonth',
    };
  }
}
