import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The dice a Magic table actually reaches for, plus the coin.
///
/// A coin is a two-sided die here so the roller has one shape to render and
/// one history to keep.
enum Die {
  coin(2, 'Moeda'),
  d4(4, 'd4'),
  d6(6, 'd6'),
  d8(8, 'd8'),
  d10(10, 'd10'),
  d12(12, 'd12'),
  d20(20, 'd20');

  const Die(this.sides, this.label);

  final int sides;
  final String label;

  bool get isCoin => this == Die.coin;

  /// Coin faces read as faces, not as 1 and 2.
  String face(int value) => isCoin ? (value == 1 ? 'Cara' : 'Coroa') : '$value';
}

/// One throw: the die, and what came up.
class DiceRoll {
  const DiceRoll({required this.die, required this.values});

  final Die die;
  final List<int> values;

  int get total => values.fold(0, (sum, value) => sum + value);

  String get faces => values.map(die.face).join('  ·  ');
}

/// Rolls dice, and remembers the last throw so the board can show it.
///
/// The [Random] is a field so a test can hand it a seeded one and assert on
/// actual numbers instead of on a range.
final diceProvider = NotifierProvider<DiceController, DiceRoll?>(
  DiceController.new,
);

class DiceController extends Notifier<DiceRoll?> {
  DiceController([Random? random]) : _random = random ?? Random();

  final Random _random;

  @override
  DiceRoll? build() => null;

  DiceRoll roll(Die die, {int count = 1}) {
    final result = DiceRoll(
      die: die,
      values: [for (var i = 0; i < count; i++) _random.nextInt(die.sides) + 1],
    );
    state = result;
    return result;
  }

  /// Who starts. Returns a seat index.
  int firstPlayer(int playerCount) => _random.nextInt(playerCount);

  void clear() => state = null;
}
