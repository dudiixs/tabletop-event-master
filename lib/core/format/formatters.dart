import 'package:intl/intl.dart';

import '../../domain/event.dart';

/// Every user-facing string built from a number or a date.
///
/// All of it in one place and all of it pt-BR, so the same event never reads
/// one way on the home screen and another in the detail sheet — the mismatch
/// that had the Expo home card showing the day before the detail sheet's date.
abstract final class Fmt {
  static const locale = 'pt_BR';

  static final _currency = NumberFormat.currency(
    locale: locale,
    symbol: r'R$',
    decimalDigits: 2,
  );

  static final _dayMonthWeekday = DateFormat("EEE, d 'de' MMM", locale);
  static final _fullDate = DateFormat("EEEE, d 'de' MMMM 'de' y", locale);
  static final _longDate = DateFormat("d 'de' MMMM 'de' y", locale);
  static final _monthShort = DateFormat('MMM', locale);
  static final _monthYear = DateFormat("MMMM 'de' y", locale);

  /// A price for a chip or a label.
  ///
  /// Three distinct states, where the Expo app had two: a real zero is free, a
  /// price is money, and an empty Notion field is neither.
  static String price(Event event) {
    if (!event.hasPrice) return 'A definir';
    if (event.isFree) return 'Gratuito';
    return _currency.format(event.price);
  }

  /// `R$ 35,50`
  static String money(double value) => _currency.format(value);

  /// `qua., 10 de set.`
  static String dayMonthWeekday(DateTime day) =>
      _capitalize(_dayMonthWeekday.format(day));

  /// `quarta-feira, 10 de setembro de 2025`
  static String fullDate(DateTime day) => _capitalize(_fullDate.format(day));

  /// `10 de setembro de 2025`
  static String longDate(DateTime day) => _longDate.format(day);

  /// `SET` — the month badge on an event card.
  static String monthBadge(DateTime day) =>
      _monthShort.format(day).replaceAll('.', '').toUpperCase();

  /// `Setembro de 2025` — the calendar's header.
  static String monthYear(DateTime day) => _capitalize(_monthYear.format(day));

  /// `19:30`, or a dash when the record carries only a date.
  static String time(Event event) {
    final time = event.time;
    if (time == null) return 'Horário a confirmar';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// How far off an event is, in words: `Hoje`, `Amanhã`, `Em 3 dias`.
  static String relativeDay(int daysAway) => switch (daysAway) {
        0 => 'Hoje',
        1 => 'Amanhã',
        _ when daysAway < 0 => 'Já aconteceu',
        _ when daysAway < 7 => 'Em $daysAway dias',
        _ when daysAway < 14 => 'Semana que vem',
        _ => 'Em $daysAway dias',
      };

  /// `3 eventos`, `1 evento`, `Nenhum evento`.
  static String eventCount(int count) => switch (count) {
        0 => 'Nenhum evento',
        1 => '1 evento',
        _ => '$count eventos',
      };

  /// Portuguese month and weekday names come out lowercase from [DateFormat];
  /// a label at the start of a line reads better capitalised.
  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
