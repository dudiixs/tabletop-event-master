import 'calendar_date.dart';
import 'event.dart';

/// The date filters behind the three screens.
///
/// Every function takes an explicit [from] day so the behaviour is testable
/// without waiting for a particular date to come around — the ambiguity that
/// let the Expo app ship a week filter that silently dropped today's events.
extension EventFilters on List<Event> {
  /// Events happening today or later, soonest first.
  ///
  /// Today counts. An event at 20:00 tonight is still upcoming at 21:00 —
  /// the agenda works in whole days, not instants.
  List<Event> upcomingFrom(DateTime from) {
    final start = dateOnly(from);
    return where((event) => !event.day.isBefore(start)).toList()..sortByDay();
  }

  /// Events inside a window of exactly [days] calendar days starting today.
  ///
  /// `withinDays(7, from: today)` covers today plus the next six days. The
  /// Expo version compared against `today + 7` at 23:59, which quietly made
  /// "próximos 7 dias" span eight.
  List<Event> withinDays(int days, {required DateTime from}) {
    assert(days > 0, 'a janela precisa de pelo menos um dia');
    final start = dateOnly(from);
    return where((event) {
      final offset = daysBetween(start, event.day);
      return offset >= 0 && offset < days;
    }).toList()
      ..sortByDay();
  }

  /// Events on one specific calendar day.
  List<Event> onDay(DateTime day) =>
      where((event) => event.occursOn(day)).toList()..sortByDay();

  /// The set of days that carry at least one event, for the calendar's dots.
  Map<DateTime, List<Event>> groupedByDay() {
    final grouped = <DateTime, List<Event>>{};
    for (final event in this) {
      grouped.putIfAbsent(event.day, () => <Event>[]).add(event);
    }
    for (final entry in grouped.entries) {
      entry.value.sortByDay();
    }
    return grouped;
  }
}

extension _SortByDay on List<Event> {
  /// Chronological, and stable on name so two events on the same day keep a
  /// predictable order between rebuilds.
  void sortByDay() => sort((a, b) {
        final byStart = a.startsAt().compareTo(b.startsAt());
        return byStart != 0 ? byStart : a.name.compareTo(b.name);
      });
}
