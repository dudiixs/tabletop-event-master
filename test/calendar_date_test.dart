import 'package:flutter_test/flutter_test.dart';
import 'package:tabletop_events/domain/calendar_date.dart';

void main() {
  group('parseNotionDate', () {
    test('reads a date-only record as a local calendar day', () {
      final parsed = parseNotionDate('2025-09-10')!;

      expect(parsed.day, DateTime(2025, 9, 10));
      expect(parsed.time, isNull);
      // The Expo regression: new Date('2025-09-10') is midnight UTC, which in
      // UTC-3 is 2025-09-09T21:00. A local DateTime never drifts like that.
      expect(parsed.day.day, 10, reason: 'nao pode escorregar para o dia 9');
    });

    test('keeps the wall-clock time as authored, offset and all', () {
      final parsed = parseNotionDate('2025-09-10T20:30:00.000-03:00')!;

      expect(parsed.day, DateTime(2025, 9, 10));
      expect(parsed.time, (hour: 20, minute: 30));
    });

    test('reads a UTC-suffixed time without shifting it', () {
      final parsed = parseNotionDate('2025-09-10T14:05:00Z')!;

      expect(parsed.time, (hour: 14, minute: 5));
    });

    test('rejects records with no usable date', () {
      expect(parseNotionDate(null), isNull);
      expect(parseNotionDate(''), isNull);
      expect(parseNotionDate('setembro'), isNull);
      expect(parseNotionDate('2025-13-40'), isNull);
    });
  });

  group('daysBetween', () {
    test('counts whole calendar days in both directions', () {
      expect(daysBetween(DateTime(2025, 9, 10), DateTime(2025, 9, 10)), 0);
      expect(daysBetween(DateTime(2025, 9, 10), DateTime(2025, 9, 17)), 7);
      expect(daysBetween(DateTime(2025, 9, 17), DateTime(2025, 9, 10)), -7);
    });

    test('counts a month boundary', () {
      expect(daysBetween(DateTime(2025, 8, 30), DateTime(2025, 9, 2)), 3);
    });

    test('counts a leap day', () {
      expect(daysBetween(DateTime(2024, 2, 28), DateTime(2024, 3, 1)), 2);
    });

    test('is unaffected by a daylight-saving transition', () {
      // A 23-hour local day makes difference().inDays truncate to one day
      // short. Going through UTC keeps every day exactly one day long.
      expect(daysBetween(DateTime(2018, 11, 3), DateTime(2018, 11, 5)), 2);
      expect(daysBetween(DateTime(2019, 2, 15), DateTime(2019, 2, 18)), 3);
    });
  });

  group('addDays', () {
    test('rolls over month and year ends', () {
      expect(addDays(DateTime(2025, 9, 28), 5), DateTime(2025, 10, 3));
      expect(addDays(DateTime(2025, 12, 30), 3), DateTime(2026, 1, 2));
    });
  });

  test('isSameDay ignores the time of day', () {
    expect(isSameDay(DateTime(2025, 9, 10), DateTime(2025, 9, 10, 23, 59)),
        isTrue);
    expect(isSameDay(DateTime(2025, 9, 10), DateTime(2025, 9, 11)), isFalse);
  });
}
