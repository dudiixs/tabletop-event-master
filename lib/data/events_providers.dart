import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../domain/calendar_date.dart';
import '../domain/event.dart';
import '../domain/event_filters.dart';
import 'events_data_source.dart';
import 'events_repository.dart';
import 'fixture_data_source.dart';
import 'notion_data_source.dart';
import 'proxy_data_source.dart';

/// This build's configuration. Overridden in tests.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// Where events come from.
///
/// **This is the one line that swaps the backend.** `EVENTS_BACKEND` selects
/// it at build time; nothing above this provider knows which one is in play.
final eventsDataSourceProvider = Provider<EventsDataSource>((ref) {
  final config = ref.watch(appConfigProvider);

  return switch (config.backend) {
    EventsBackend.fixtures => const FixtureDataSource(),
    EventsBackend.notionDirect => NotionDataSource(config: config),
    EventsBackend.proxy => ProxyDataSource(config: config),
  };
});

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return EventsRepository(
    dataSource: ref.watch(eventsDataSourceProvider),
    ttl: config.cacheTtl,
  );
});

/// The full agenda. Every screen derives its own view from this one fetch.
final agendaProvider = FutureProvider<List<Event>>((ref) async {
  final repository = ref.watch(eventsRepositoryProvider);
  return repository.getEvents();
});

/// Refetches the agenda and waits for the result.
///
/// Wired to pull-to-refresh, which the Expo app had no equivalent for — the
/// only way to reload was to leave the screen and come back after the TTL.
Future<void> refreshAgenda(WidgetRef ref) async {
  ref.read(eventsRepositoryProvider).invalidate();
  ref.invalidate(agendaProvider);
  await ref.read(agendaProvider.future);
}

/// The agenda filtered to today and later.
final upcomingEventsProvider = Provider<List<Event>>((ref) {
  final agenda = ref.watch(agendaProvider).valueOrNull ?? const <Event>[];
  return agenda.upcomingFrom(today());
});

/// The next seven calendar days, today included.
final weeklyEventsProvider = Provider<List<Event>>((ref) {
  final agenda = ref.watch(agendaProvider).valueOrNull ?? const <Event>[];
  return agenda.withinDays(7, from: today());
});

/// Every upcoming event bucketed by day, for the calendar's markers.
final eventsByDayProvider = Provider<Map<DateTime, List<Event>>>((ref) {
  return ref.watch(upcomingEventsProvider).groupedByDay();
});

/// The day the calendar has selected, or null for "show everything".
final selectedDayProvider = StateProvider<DateTime?>((ref) => null);

/// What the calendar screen lists: one day's events, or the whole agenda.
final calendarListProvider = Provider<List<Event>>((ref) {
  final selected = ref.watch(selectedDayProvider);
  final upcoming = ref.watch(upcomingEventsProvider);
  return selected == null ? upcoming : upcoming.onDay(selected);
});

/// The event shown in the home screen's "Em Destaque" card.
///
/// Held in state rather than recomputed on build: a random pick inside a build
/// method would draw a different event on every rebuild — a theme toggle would
/// silently change the featured event.
final featuredEventProvider =
    NotifierProvider<FeaturedEventNotifier, Event?>(FeaturedEventNotifier.new);

class FeaturedEventNotifier extends Notifier<Event?> {
  final _random = Random();

  @override
  Event? build() {
    final upcoming = ref.watch(upcomingEventsProvider);
    // Re-picking when the agenda itself changes is intentional; rebuilds that
    // do not change the agenda keep the current pick.
    return _pick(upcoming, avoid: null);
  }

  /// Draws another upcoming event, never repeating the current one when there
  /// is more than one to choose from.
  void shuffle() {
    final upcoming = ref.read(upcomingEventsProvider);
    state = _pick(upcoming, avoid: state);
  }

  Event? _pick(List<Event> events, {required Event? avoid}) {
    if (events.isEmpty) return null;
    if (events.length == 1) return events.first;

    final candidates =
        avoid == null ? events : events.where((e) => e.id != avoid.id).toList();
    if (candidates.isEmpty) return events.first;

    // Weighted toward what is coming up soonest: a card advertising an event
    // three weeks out is less useful than one advertising tomorrow.
    final soonest = candidates.take(6).toList();
    return soonest[_random.nextInt(soonest.length)];
  }
}
