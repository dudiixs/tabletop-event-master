/// The Magic formats the life counter knows, and what each one changes.
///
/// A life counter is only useful if it enforces the format's *own* rules: a
/// Commander game starts at 40 and someone dies to 21 damage from a single
/// commander, while a Standard game starts at 20 and has no such thing. Putting
/// that here — instead of behind `if (format == commander)` checks scattered
/// through the widgets — means the board never has to ask what game it is.
library;

enum MtgFormat {
  standard(
    label: 'Standard',
    blurb: 'Só as coleções recentes',
    startingLife: 20,
  ),
  pauper(label: 'Pauper', blurb: 'Só commons', startingLife: 20),
  modern(label: 'Modern', blurb: 'De 8ª Edição pra cá', startingLife: 20),
  legacy(label: 'Legacy', blurb: 'Tudo, com restrições', startingLife: 20),
  commander(
    label: 'Commander',
    blurb: '40 de vida, 21 de dano de comandante',
    startingLife: 40,
    playerCounts: [2, 3, 4, 5, 6],
  ),
  free(
    label: 'Livre',
    blurb: 'Vida inicial à sua escolha',
    startingLife: 20,
    playerCounts: [2, 3, 4, 5, 6],
  );

  const MtgFormat({
    required this.label,
    required this.blurb,
    required this.startingLife,
    this.playerCounts = const [2],
  });

  final String label;

  /// One line of context for the format picker.
  final String blurb;

  final int startingLife;

  /// How many players this format seats.
  ///
  /// The constructed formats are duels — a "mesão" is a Commander thing — so
  /// they only ever offer two seats and the picker hides the choice entirely.
  final List<int> playerCounts;

  /// Whether a single commander dealing 21 damage kills.
  ///
  /// Rule 903.10a, and it is the rule most casual tables forget to track,
  /// which is exactly why the counter should.
  bool get tracksCommanderDamage => this == MtgFormat.commander;

  /// The damage from one commander that ends a game.
  static const commanderDamageLethal = 21;

  /// Ten poison counters lose the game — rule 704.5c.
  ///
  /// This one is *not* Commander-only: infect and toxic exist in Standard too,
  /// so every format gets the counter. It just stays out of the way until the
  /// first counter lands.
  static const poisonLethal = 10;

  /// Whether the crown is on the table.
  ///
  /// The monarch comes from Conspiracy and lives in Commander and casual
  /// multiplayer; nobody is playing the monarch in a Modern duel, and a chip
  /// nobody uses is a chip in the way.
  bool get offersMonarch => this == MtgFormat.commander || this == MtgFormat.free;

  bool get seatsMoreThanTwo => playerCounts.length > 1;
}
