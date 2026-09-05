import 'package:flutter/foundation.dart';

import 'mtg_format.dart';

/// Why a player is out of the game.
enum DeathCause {
  life('sem vida'),
  poison('10 de veneno'),
  commanderDamage('21 de dano de comandante'),
  conceded('desistiu');

  const DeathCause(this.label);

  final String label;
}

/// One seat at the table.
///
/// Immutable: every change produces a new player, a new match, and a new entry
/// on the undo stack. A life counter that cannot undo is a life counter people
/// stop trusting the first time a thumb lands on the wrong half of the screen.
@immutable
class MatchPlayer {
  const MatchPlayer({
    required this.seat,
    required this.name,
    required this.life,
    this.poison = 0,
    this.commanderDamage = const {},
    this.conceded = false,
  });

  /// Position at the table, 0-based. Also the player's identity: commander
  /// damage is recorded as "seat 2 took 7 from seat 0's commander".
  final int seat;

  final String name;
  final int life;
  final int poison;

  /// Damage taken from each opponent's commander, keyed by that opponent's
  /// seat. Absent means zero.
  final Map<int, int> commanderDamage;

  final bool conceded;

  int commanderDamageFrom(int seat) => commanderDamage[seat] ?? 0;

  /// The worst commander damage from any single opponent — the number that
  /// actually threatens, since the 21 is per commander and never pooled.
  int get worstCommanderDamage => commanderDamage.values.fold(
    0,
    (worst, value) => value > worst ? value : worst,
  );

  /// Why this player is dead, or null if they are still in it.
  ///
  /// Checked in the order a table would announce it.
  DeathCause? get deathCause {
    if (conceded) return DeathCause.conceded;
    if (life <= 0) return DeathCause.life;
    if (poison >= MtgFormat.poisonLethal) return DeathCause.poison;
    if (worstCommanderDamage >= MtgFormat.commanderDamageLethal) {
      return DeathCause.commanderDamage;
    }
    return null;
  }

  bool get isDead => deathCause != null;

  MatchPlayer copyWith({
    String? name,
    int? life,
    int? poison,
    Map<int, int>? commanderDamage,
    bool? conceded,
  }) => MatchPlayer(
    seat: seat,
    name: name ?? this.name,
    life: life ?? this.life,
    poison: poison ?? this.poison,
    commanderDamage: commanderDamage ?? this.commanderDamage,
    conceded: conceded ?? this.conceded,
  );

  Map<String, dynamic> toJson() => {
    'seat': seat,
    'name': name,
    'life': life,
    'poison': poison,
    'conceded': conceded,
    'commanderDamage': {
      for (final entry in commanderDamage.entries)
        entry.key.toString(): entry.value,
    },
  };

  static MatchPlayer fromJson(Map<String, dynamic> json) => MatchPlayer(
    seat: json['seat'] as int,
    name: json['name'] as String? ?? 'Jogador',
    life: json['life'] as int? ?? 0,
    poison: json['poison'] as int? ?? 0,
    conceded: json['conceded'] as bool? ?? false,
    commanderDamage: _damageFromJson(json['commanderDamage']),
  );

  static int? _seatOrNull(Object? key) => int.tryParse(key.toString());

  static Map<int, int> _damageFromJson(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        ?_seatOrNull(entry.key): (entry.value as num?)?.round() ?? 0,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is MatchPlayer &&
      other.seat == seat &&
      other.name == name &&
      other.life == life &&
      other.poison == poison &&
      other.conceded == conceded &&
      mapEquals(other.commanderDamage, commanderDamage);

  @override
  int get hashCode => Object.hash(
    seat,
    name,
    life,
    poison,
    conceded,
    Object.hashAll(
      commanderDamage.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// A game in progress.
@immutable
class MtgMatch {
  const MtgMatch({
    required this.format,
    required this.startingLife,
    required this.players,
    required this.startedAt,
    this.monarch,
  });

  /// Opens a table: [playerCount] seats, everyone on the format's starting
  /// life unless [startingLife] overrides it.
  factory MtgMatch.start({
    required MtgFormat format,
    required int playerCount,
    int? startingLife,
    List<String>? names,
  }) {
    final life = startingLife ?? format.startingLife;
    return MtgMatch(
      format: format,
      startingLife: life,
      startedAt: DateTime.now(),
      players: [
        for (var seat = 0; seat < playerCount; seat++)
          MatchPlayer(
            seat: seat,
            name: names != null && seat < names.length
                ? names[seat]
                : 'Jogador ${seat + 1}',
            life: life,
          ),
      ],
    );
  }

  final MtgFormat format;

  /// What everyone started on. Kept on the match rather than read back off the
  /// format, so a "Livre" game at 30 restarts at 30.
  final int startingLife;

  final List<MatchPlayer> players;
  final DateTime startedAt;

  /// The seat wearing the crown, or null when nobody is the monarch.
  ///
  /// One at a time, by rule: the monarch draws at their end step and loses the
  /// crown to whoever deals them combat damage. The counter does not enforce
  /// that — the table does — but it does the one thing a table is bad at,
  /// which is remembering who has it three combats later.
  final int? monarch;

  MatchPlayer playerAt(int seat) =>
      players.firstWhere((player) => player.seat == seat);

  List<MatchPlayer> get survivors =>
      players.where((player) => !player.isDead).toList(growable: false);

  /// The last player standing, once there is exactly one.
  MatchPlayer? get winner {
    final alive = survivors;
    return alive.length == 1 && players.length > 1 ? alive.single : null;
  }

  bool get isOver => winner != null || survivors.isEmpty;

  MtgMatch withPlayer(MatchPlayer player) => MtgMatch(
    format: format,
    startingLife: startingLife,
    startedAt: startedAt,
    monarch: monarch,
    players: [
      for (final existing in players)
        existing.seat == player.seat ? player : existing,
    ],
  );

  /// Hands the crown to [seat], or takes it off the table with null.
  MtgMatch withMonarch(int? seat) => MtgMatch(
    format: format,
    startingLife: startingLife,
    startedAt: startedAt,
    players: players,
    monarch: seat,
  );

  bool isMonarch(int seat) => monarch == seat;

  /// A fresh game with the same table and the same names.
  MtgMatch restarted() => MtgMatch(
    format: format,
    startingLife: startingLife,
    startedAt: DateTime.now(),
    players: [
      for (final player in players)
        MatchPlayer(seat: player.seat, name: player.name, life: startingLife),
    ],
  );

  Map<String, dynamic> toJson() => {
    'format': format.name,
    'startingLife': startingLife,
    'startedAt': startedAt.toIso8601String(),
    'monarch': monarch,
    'players': players.map((player) => player.toJson()).toList(),
  };

  static MtgMatch? fromJson(Map<String, dynamic> json) {
    final format = MtgFormat.values
        .where((value) => value.name == json['format'])
        .firstOrNull;
    final players = json['players'];
    if (format == null || players is! List || players.isEmpty) return null;

    return MtgMatch(
      format: format,
      startingLife: json['startingLife'] as int? ?? format.startingLife,
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      monarch: (json['monarch'] as num?)?.round(),
      players: players
          .whereType<Map>()
          .map((player) => MatchPlayer.fromJson(player.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}
