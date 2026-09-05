import 'package:flutter/foundation.dart';

import '../core/format/formatters.dart';
import 'rental_game.dart';

/// A rental someone is about to ask for: which games, and for how long.
///
/// The whole thing is a pure value that can price itself and write its own
/// WhatsApp message. That keeps the arithmetic — the part a customer will
/// check against what the shop charges — out of the widgets and under test.
@immutable
class RentalQuote {
  const RentalQuote({
    required this.games,
    required this.pickup,
    required this.dropoff,
  });

  final List<RentalGame> games;
  final DateTime pickup;
  final DateTime dropoff;

  /// Billed days, never fewer than one: taking a game out and back the same
  /// afternoon is still a daily rate.
  int get days {
    final from = DateTime(pickup.year, pickup.month, pickup.day);
    final to = DateTime(dropoff.year, dropoff.month, dropoff.day);
    // Hours over 24 rather than `inDays`, so a daylight-saving change in the
    // middle of the period cannot swallow a day.
    final span = (to.difference(from).inHours / 24).round();
    return span < 1 ? 1 : span;
  }

  double get dailyTotal =>
      games.fold(0, (total, game) => total + game.dailyPrice);

  double get total => dailyTotal * days;

  /// Held while the games are out and returned with them.
  double get deposit => games.fold(0, (total, game) => total + game.deposit);

  bool get isEmpty => games.isEmpty;

  bool get isValid => games.isNotEmpty && !dropoff.isBefore(pickup);

  RentalQuote copyWith({
    List<RentalGame>? games,
    DateTime? pickup,
    DateTime? dropoff,
  }) => RentalQuote(
    games: games ?? this.games,
    pickup: pickup ?? this.pickup,
    dropoff: dropoff ?? this.dropoff,
  );

  /// The message that lands in the shop's WhatsApp.
  ///
  /// Written so whoever reads it on the other side can answer with a yes: the
  /// dates, the exact games, the price the customer was shown, and the fact
  /// that it is an estimate rather than a booking.
  String whatsappMessage() {
    final lines = <String>[
      'Olá! Quero alugar board games na TableTop 🎲',
      '',
      '📅 Retirada: ${Fmt.fullDate(pickup)}',
      '📦 Devolução: ${Fmt.fullDate(dropoff)}',
      '⏳ $days ${days == 1 ? 'diária' : 'diárias'}',
      '',
      'Jogos:',
      for (final game in games)
        '• ${game.title} — ${Fmt.money(game.dailyPrice)}/dia',
      '',
      'Total estimado: ${Fmt.money(total)}',
      if (deposit > 0) 'Caução: ${Fmt.money(deposit)}',
      '',
      'Confere pra mim se está tudo disponível?',
    ];

    return lines.join('\n');
  }
}
