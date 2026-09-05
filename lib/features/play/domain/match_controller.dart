import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import 'mtg_format.dart';
import 'mtg_match.dart';

/// The match on the table right now, or null when nobody is playing.
final matchProvider = NotifierProvider<MatchController, MtgMatch?>(
  MatchController.new,
);

/// Drives the life counter.
///
/// Every mutation pushes the previous match onto an undo stack and writes the
/// new one to disk. The disk write is what lets someone answer a WhatsApp
/// message mid-game — or have Android kill the app for memory — and come back
/// to the same board instead of a lost game of Commander.
class MatchController extends Notifier<MtgMatch?> {
  static const _key = 'mtg_match';

  /// Deep enough to walk back a misclicked sequence, short enough that the
  /// stored history never grows without bound.
  static const _maxUndo = 60;

  final List<MtgMatch> _undoStack = [];

  @override
  MtgMatch? build() {
    final preferences = ref.watch(sharedPreferencesProvider);

    try {
      // The read is inside the try too: `getString` itself throws if anything
      // ever wrote another type under this key, and a stored match is never
      // worth taking the PLAY tab down with it.
      final stored = preferences.getString(_key);
      if (stored == null) return null;

      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic>) return null;
      return MtgMatch.fromJson(decoded);
    } on Object {
      // Anything unreadable — a match written by an older shape of this file,
      // a half-written string — is not worth crashing the PLAY tab over. The
      // table is lost either way; the app should just offer a new one.
      return null;
    }
  }

  bool get canUndo => _undoStack.isNotEmpty;

  void start({
    required MtgFormat format,
    required int playerCount,
    int? startingLife,
    List<String>? names,
  }) {
    _undoStack.clear();
    _commit(
      MtgMatch.start(
        format: format,
        playerCount: playerCount,
        startingLife: startingLife,
        names: names,
      ),
      undoable: false,
    );
  }

  /// Adds [delta] to a player's life. Negative goes down; there is no floor,
  /// because a Commander player on -7 still wants to see how far they went.
  void adjustLife(int seat, int delta) {
    final match = state;
    if (match == null || delta == 0) return;
    final player = match.playerAt(seat);
    _commit(match.withPlayer(player.copyWith(life: player.life + delta)));
  }

  /// Adds poison counters, clamped at zero — you cannot un-poison below none.
  void adjustPoison(int seat, int delta) {
    final match = state;
    if (match == null || delta == 0) return;
    final player = match.playerAt(seat);
    final next = (player.poison + delta).clamp(0, 99);
    if (next == player.poison) return;
    _commit(match.withPlayer(player.copyWith(poison: next)));
  }

  /// Records commander damage from [source]'s commander onto [target].
  ///
  /// Commander damage *is* damage, so the same button takes the life too —
  /// tracking the 21 and forgetting the 21 life lost is the classic way these
  /// counters drift out of sync with the board. Correcting downwards gives the
  /// life back.
  void adjustCommanderDamage({
    required int target,
    required int source,
    required int delta,
  }) {
    final match = state;
    if (match == null || delta == 0 || target == source) return;
    if (!match.format.tracksCommanderDamage) return;

    final player = match.playerAt(target);
    final current = player.commanderDamageFrom(source);
    final next = (current + delta).clamp(0, 99);
    final applied = next - current;
    if (applied == 0) return;

    _commit(
      match.withPlayer(
        player.copyWith(
          commanderDamage: {...player.commanderDamage, source: next},
          life: player.life - applied,
        ),
      ),
    );
  }

  /// Puts the crown on [seat] — or takes it off, if that seat already wears it.
  ///
  /// The rules move the monarchy on combat damage, which no counter can see,
  /// so this is a deliberate tap. What it does guarantee is the part tables
  /// get wrong: exactly one monarch, and everyone can see who.
  void claimMonarch(int seat) {
    final match = state;
    if (match == null) return;
    _commit(match.withMonarch(match.isMonarch(seat) ? null : seat));
  }

  void rename(int seat, String name) {
    final match = state;
    final trimmed = name.trim();
    if (match == null || trimmed.isEmpty) return;
    _commit(match.withPlayer(match.playerAt(seat).copyWith(name: trimmed)));
  }

  void toggleConcede(int seat) {
    final match = state;
    if (match == null) return;
    final player = match.playerAt(seat);
    _commit(match.withPlayer(player.copyWith(conceded: !player.conceded)));
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _commit(_undoStack.removeLast(), undoable: false);
  }

  /// Same table, same names, life back to the start.
  void restart() {
    final match = state;
    if (match == null) return;
    _undoStack.clear();
    _commit(match.restarted(), undoable: false);
  }

  /// Leaves the table for good and forgets the saved game.
  Future<void> end() async {
    _undoStack.clear();
    state = null;
    await ref.read(sharedPreferencesProvider).remove(_key);
  }

  void _commit(MtgMatch next, {bool undoable = true}) {
    final previous = state;
    if (undoable && previous != null) {
      _undoStack.add(previous);
      if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    }
    state = next;
    // Fire and forget: the board should never wait on the disk between a tap
    // and the number changing.
    ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(next.toJson()));
  }
}
