/// The game category an event belongs to, inferred from its name and tags.
///
/// The Notion database has no category field, so the Expo app guessed from
/// substrings — a heuristic worth keeping, since it is what produces the emoji
/// and label on every card. Ported with the accent-insensitive matching the
/// original lacked ("pokemon" and "Pokémon" both hit), and with the tag list
/// matched as real tags instead of a joined string.
enum EventCategory {
  pokemon('⚡', 'Pokémon TCG', ['pokemon', 'ptcg']),
  digimon('🔥', 'Digimon', ['digimon']),
  magic('✨', 'Magic: The Gathering', ['magic', 'mtg']),
  yugioh('🌟', 'Yu-Gi-Oh!', ['yugioh', 'yu-gi-oh', 'ygo']),
  gundam('🤖', 'Gundam', ['gundam']),
  boardGames('🎲', 'Board Games', ['board', 'tabuleiro', 'boardgame']),
  rpg('🐉', 'RPG', ['rpg', 'd&d', 'dnd', 'tormenta']),
  tournament('🏆', 'Torneio', ['torneio', 'campeonato', 'tournament', 'liga']),
  other('🎮', 'Evento Especial', []);

  const EventCategory(this.emoji, this.label, this.keywords);

  final String emoji;
  final String label;
  final List<String> keywords;

  /// Picks the first category whose keywords appear in [name] or [tags].
  ///
  /// Declaration order is the precedence order: a "Torneio de Pokémon" is
  /// filed under Pokémon, because the specific game matters more to someone
  /// scanning the list than the format does.
  static EventCategory detect({
    required String name,
    required List<String> tags,
  }) {
    final haystack = _fold('$name ${tags.join(' ')}');
    for (final category in values) {
      if (category == other) continue;
      if (category.keywords.any(haystack.contains)) return category;
    }
    return other;
  }

  /// Lowercases and strips the accents Portuguese event names carry, so
  /// "Pokémon" and "pokemon" match the same keyword.
  static String _fold(String value) {
    var folded = value.toLowerCase();
    const accents = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    accents.forEach((accented, plain) {
      folded = folded.replaceAll(accented, plain);
    });
    return folded;
  }
}
