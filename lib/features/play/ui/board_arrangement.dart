import 'package:flutter/foundation.dart';

/// Where each seat sits on the screen, and which way it faces.
///
/// A phone in the middle of a Commander pod is read from four sides at once,
/// so the panels on the far side are drawn upside down. Keeping the geometry
/// in a plain value — rows of seats, plus a rotation per seat — means the
/// board widget just lays out what this says, and a test can assert that a
/// four-player table really does face two players the other way.
@immutable
class BoardArrangement {
  const BoardArrangement({required this.rows, required this.quarterTurns});

  /// Seats per row, from the top of the screen down.
  final List<List<int>> rows;

  /// Rotation per seat, in quarter turns clockwise.
  final Map<int, int> quarterTurns;

  static BoardArrangement forCount(int count) {
    final rows = switch (count) {
      2 => const [
        [1],
        [0],
      ],
      3 => const [
        [1, 2],
        [0],
      ],
      4 => const [
        [2, 3],
        [0, 1],
      ],
      5 => const [
        [2, 3, 4],
        [0, 1],
      ],
      _ => const [
        [3, 4, 5],
        [0, 1, 2],
      ],
    };

    return BoardArrangement(
      rows: rows,
      quarterTurns: {
        // Everyone on the top row faces the other way; the bottom row faces
        // whoever is holding the phone.
        for (final seat in rows.first) seat: 2,
        for (final seat in rows.last) seat: 0,
      },
    );
  }

  int turnsFor(int seat) => quarterTurns[seat] ?? 0;

  /// Whether panels are small enough to drop the less-used controls.
  bool get isCrowded => rows.any((row) => row.length > 1) && rows.length > 1;
}
