/// Calendar arithmetic for the app, deliberately timezone-naive.
///
/// Notion delivers an event's date as a plain `YYYY-MM-DD` string, optionally
/// with a time. The Expo app parsed those with `new Date(string)`, which reads
/// them as midnight **UTC** — in UTC-3 that lands on 21:00 of the previous day.
/// Two user-visible bugs came out of that: events happening today were dropped
/// from the week view, and the home card showed the day before the one the
/// detail sheet showed for the same event.
///
/// So: every date here is built as a *local* date, and events are compared by
/// calendar day only. Day arithmetic goes through UTC internally so a DST
/// transition can never make a day 23 or 25 hours long.
library;

/// Today's local calendar day, with the time stripped.
///
/// The single source of "now" for every filter, so tests can compare against a
/// fixed day by passing their own instead.
DateTime today() => dateOnly(DateTime.now());

/// Strips the time from [value], keeping the local calendar day.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Whether [a] and [b] fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Whole calendar days from [from] to [to]. Negative when [to] is earlier.
///
/// Uses UTC internally: `difference().inDays` on local dates truncates to 0
/// across a 23-hour DST day, which would silently shift a filter boundary.
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

/// [value] shifted by [days] calendar days, preserving the local midnight.
DateTime addDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

/// Parses a Notion date string — `2025-09-10` or `2025-09-10T20:30:00.000-03:00`
/// — into a local date and, when present, the wall-clock time written in it.
///
/// The time is read from the string as authored rather than converted through a
/// zone: an event marked 20:00 in the Notion database is a 20:00 event, and
/// must not become 23:00 because the record carried an offset.
({DateTime day, ({int hour, int minute})? time})? parseNotionDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;

  final datePart = raw.split('T').first;
  final segments = datePart.split('-');
  if (segments.length != 3) return null;

  final year = int.tryParse(segments[0]);
  final month = int.tryParse(segments[1]);
  final day = int.tryParse(segments[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  ({int hour, int minute})? time;
  if (raw.contains('T')) {
    final clock = raw.split('T')[1];
    final parts = clock.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final rawMinute = parts[1];
      final minute = int.tryParse(
        rawMinute.length >= 2 ? rawMinute.substring(0, 2) : rawMinute,
      );
      if (hour != null && minute != null && hour < 24 && minute < 60) {
        time = (hour: hour, minute: minute);
      }
    }
  }

  return (day: DateTime(year, month, day), time: time);
}
