import 'package:flutter/foundation.dart';

/// The shelf a rental sits on, used for the catalogue's filter row.
enum RentalShelf {
  family('Família'),
  strategy('Estratégia'),
  party('Festa'),
  duo('Dois jogadores'),
  cooperative('Cooperativo'),
  kids('Infantil');

  const RentalShelf(this.label);

  final String label;

  static RentalShelf parse(String? raw) =>
      RentalShelf.values.where((shelf) => shelf.name == raw).firstOrNull ??
      RentalShelf.family;
}

/// A board game the shop rents out.
///
/// Shaped like the [Event] records: a plain immutable value with a tolerant
/// `fromJson`, so the same model survives the move from the bundled catalogue
/// to a Notion base without the screens noticing.
@immutable
class RentalGame {
  const RentalGame({
    required this.id,
    required this.title,
    required this.tagline,
    required this.shelf,
    required this.minPlayers,
    required this.maxPlayers,
    required this.minMinutes,
    required this.maxMinutes,
    required this.minAge,
    required this.weight,
    required this.dailyPrice,
    required this.deposit,
    this.available = true,
    this.imageUrl,
  });

  final String id;
  final String title;

  /// One line that sells the game to someone who has never played it.
  final String tagline;

  final RentalShelf shelf;
  final int minPlayers;
  final int maxPlayers;
  final int minMinutes;
  final int maxMinutes;
  final int minAge;

  /// Complexity from 1 to 5, the way BoardGameGeek's weight reads.
  final double weight;

  final double dailyPrice;

  /// The refundable caução held while the game is out.
  final double deposit;

  final bool available;
  final String? imageUrl;

  String get playersLabel => minPlayers == maxPlayers
      ? '$minPlayers jogadores'
      : '$minPlayers–$maxPlayers jogadores';

  String get durationLabel => minMinutes == maxMinutes
      ? '$minMinutes min'
      : '$minMinutes–$maxMinutes min';

  String get ageLabel => '$minAge+';

  String get weightLabel => switch (weight) {
    < 1.6 => 'Leve',
    < 2.6 => 'Médio',
    < 3.6 => 'Pesadinho',
    _ => 'Pesado',
  };

  /// Whether this game seats a group of [size] people.
  bool seats(int size) => size >= minPlayers && size <= maxPlayers;

  static RentalGame fromJson(Map<String, dynamic> json) {
    double number(Object? value, double fallback) => switch (value) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s.replaceAll(',', '.')) ?? fallback,
      _ => fallback,
    };

    int integer(Object? value, int fallback) => switch (value) {
      final num n => n.round(),
      _ => fallback,
    };

    return RentalGame(
      id: json['id']?.toString() ?? json['title']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Jogo',
      tagline: json['tagline']?.toString() ?? '',
      shelf: RentalShelf.parse(json['shelf']?.toString()),
      minPlayers: integer(json['minPlayers'], 2),
      maxPlayers: integer(json['maxPlayers'], 4),
      minMinutes: integer(json['minMinutes'], 30),
      maxMinutes: integer(json['maxMinutes'], 60),
      minAge: integer(json['minAge'], 10),
      weight: number(json['weight'], 2),
      dailyPrice: number(json['dailyPrice'], 0),
      deposit: number(json['deposit'], 0),
      available: json['available'] as bool? ?? true,
      imageUrl: (json['imageUrl'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['imageUrl'] as String,
    );
  }

  @override
  bool operator ==(Object other) => other is RentalGame && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
