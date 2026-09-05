import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabletop_events/core/theme/theme_controller.dart';
import 'package:tabletop_events/features/play/domain/match_controller.dart';
import 'package:tabletop_events/features/play/domain/mtg_format.dart';
import 'package:tabletop_events/features/play/domain/mtg_match.dart';

/// The rules the counter is supposed to know.
///
/// These are the assertions that make the feature more than a pair of buttons:
/// a Commander game that ends at 21 damage from one commander, a poison count
/// that ends it at ten, and a board that survives the app being killed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> containerWith([
    Map<String, Object> preferences = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(preferences);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('starting a table', () {
    test('Commander starts everyone on 40', () {
      final match = MtgMatch.start(format: MtgFormat.commander, playerCount: 4);

      expect(match.players, hasLength(4));
      expect(match.players.map((player) => player.life), everyElement(40));
    });

    test('the constructed formats start on 20 and seat two', () {
      for (final format in [
        MtgFormat.standard,
        MtgFormat.pauper,
        MtgFormat.modern,
        MtgFormat.legacy,
      ]) {
        expect(format.startingLife, 20, reason: format.label);
        expect(format.playerCounts, [2], reason: format.label);
        expect(format.tracksCommanderDamage, isFalse, reason: format.label);
      }
    });

    test('Livre honours the life it was given', () {
      final match = MtgMatch.start(
        format: MtgFormat.free,
        playerCount: 3,
        startingLife: 30,
      );

      expect(match.players.map((player) => player.life), everyElement(30));
      // And a restart returns to it, not to the format's default.
      expect(
        match.restarted().players.map((player) => player.life),
        everyElement(30),
      );
    });
  });

  group('death', () {
    test('zero life is out', () {
      const player = MatchPlayer(seat: 0, name: 'A', life: 0);
      expect(player.deathCause, DeathCause.life);
    });

    test('ten poison counters are out, nine are not', () {
      const alive = MatchPlayer(seat: 0, name: 'A', life: 20, poison: 9);
      const dead = MatchPlayer(seat: 0, name: 'A', life: 20, poison: 10);

      expect(alive.deathCause, isNull);
      expect(dead.deathCause, DeathCause.poison);
    });

    test('21 from one commander is out; 20 from two others is not', () {
      const spread = MatchPlayer(
        seat: 0,
        name: 'A',
        life: 5,
        commanderDamage: {1: 20, 2: 20},
      );
      const lethal = MatchPlayer(
        seat: 0,
        name: 'A',
        life: 5,
        commanderDamage: {1: 21},
      );

      // Commander damage is never pooled — 40 spread over two commanders
      // leaves the player very much alive.
      expect(spread.deathCause, isNull);
      expect(lethal.deathCause, DeathCause.commanderDamage);
    });
  });

  group('the controller', () {
    test(
      'commander damage takes the life with it, and undo gives it back',
      () async {
        final container = await containerWith();
        final match = container.read(matchProvider.notifier)
          ..start(format: MtgFormat.commander, playerCount: 4);

        match.adjustCommanderDamage(target: 0, source: 1, delta: 7);

        var player = container.read(matchProvider)!.playerAt(0);
        expect(player.commanderDamageFrom(1), 7);
        expect(player.life, 33, reason: 'dano de comandante é dano');

        match.undo();
        player = container.read(matchProvider)!.playerAt(0);
        expect(player.commanderDamageFrom(1), 0);
        expect(player.life, 40);
      },
    );

    test('21 of commander damage ends the game', () async {
      final container = await containerWith();
      final match = container.read(matchProvider.notifier)
        ..start(format: MtgFormat.commander, playerCount: 2);

      // Life is topped up along the way, so the only thing that can kill here
      // is the commander damage itself.
      match
        ..adjustCommanderDamage(target: 0, source: 1, delta: 21)
        ..adjustLife(0, 40);

      final state = container.read(matchProvider)!;
      expect(state.playerAt(0).life, greaterThan(0));
      expect(state.playerAt(0).deathCause, DeathCause.commanderDamage);
      expect(state.winner?.seat, 1);
      expect(state.isOver, isTrue);
    });

    test('commander damage is ignored outside Commander', () async {
      final container = await containerWith();
      final match = container.read(matchProvider.notifier)
        ..start(format: MtgFormat.modern, playerCount: 2);

      match.adjustCommanderDamage(target: 0, source: 1, delta: 5);

      final player = container.read(matchProvider)!.playerAt(0);
      expect(player.commanderDamageFrom(1), 0);
      expect(player.life, 20);
    });

    test(
      'poison is tracked in every format and never goes below zero',
      () async {
        final container = await containerWith();
        final match = container.read(matchProvider.notifier)
          ..start(format: MtgFormat.standard, playerCount: 2);

        match
          ..adjustPoison(1, 3)
          ..adjustPoison(1, -5);
        expect(container.read(matchProvider)!.playerAt(1).poison, 0);

        match.adjustPoison(1, MtgFormat.poisonLethal);
        expect(
          container.read(matchProvider)!.playerAt(1).deathCause,
          DeathCause.poison,
        );
      },
    );

    test('conceding takes a player out and names the winner', () async {
      final container = await containerWith();
      final match = container.read(matchProvider.notifier)
        ..start(format: MtgFormat.commander, playerCount: 3);

      match
        ..toggleConcede(0)
        ..toggleConcede(1);

      final state = container.read(matchProvider)!;
      expect(state.winner?.seat, 2);

      match.toggleConcede(0);
      expect(container.read(matchProvider)!.winner, isNull);
    });

    test('restart clears the damage and keeps the names', () async {
      final container = await containerWith();
      final match = container.read(matchProvider.notifier)
        ..start(format: MtgFormat.commander, playerCount: 2);

      match
        ..rename(0, 'Duda')
        ..adjustCommanderDamage(target: 0, source: 1, delta: 12)
        ..adjustPoison(0, 4)
        ..restart();

      final player = container.read(matchProvider)!.playerAt(0);
      expect(player.name, 'Duda');
      expect(player.life, 40);
      expect(player.poison, 0);
      expect(player.commanderDamageFrom(1), 0);
    });

    test('the crown moves, and only one seat wears it', () async {
      final container = await containerWith();
      final match = container.read(matchProvider.notifier)
        ..start(format: MtgFormat.commander, playerCount: 4);

      match.claimMonarch(2);
      expect(container.read(matchProvider)!.monarch, 2);
      expect(container.read(matchProvider)!.isMonarch(2), isTrue);

      // Someone connects with a creature: the crown changes hands rather than
      // being held by two people at once.
      match.claimMonarch(0);
      final crowned = container.read(matchProvider)!;
      expect(crowned.monarch, 0);
      expect(crowned.isMonarch(2), isFalse);

      // Tapping your own crown gives it up.
      match.claimMonarch(0);
      expect(container.read(matchProvider)!.monarch, isNull);
    });

    test(
      'the crown survives a life change and undo, but not a restart',
      () async {
        final container = await containerWith();
        final match = container.read(matchProvider.notifier)
          ..start(format: MtgFormat.commander, playerCount: 3)
          ..claimMonarch(1)
          ..adjustLife(1, -6);

        expect(container.read(matchProvider)!.monarch, 1);

        match.undo();
        expect(
          container.read(matchProvider)!.monarch,
          1,
          reason: 'desfazer a vida não tira a coroa',
        );

        match.restart();
        expect(container.read(matchProvider)!.monarch, isNull);
      },
    );

    test('the monarch is only offered where it is played', () {
      expect(MtgFormat.commander.offersMonarch, isTrue);
      expect(MtgFormat.free.offersMonarch, isTrue);
      expect(MtgFormat.modern.offersMonarch, isFalse);
      expect(MtgFormat.standard.offersMonarch, isFalse);
    });

    test('a match survives the app being killed', () async {
      final first = await containerWith();
      first.read(matchProvider.notifier)
        ..start(format: MtgFormat.commander, playerCount: 4)
        ..rename(2, 'Tio')
        ..adjustLife(2, -13)
        ..adjustCommanderDamage(target: 2, source: 0, delta: 6)
        ..claimMonarch(2);

      // The write is fire-and-forget, so let it land before reading it back.
      await Future<void>.delayed(Duration.zero);

      // Whatever the first container wrote to disk is what a cold start reads.
      final written = (await SharedPreferences.getInstance()).getString(
        'mtg_match',
      );
      expect(written, isNotNull, reason: 'a partida é salva a cada mudança');

      final second = await containerWith({'mtg_match': written!});
      final restored = second.read(matchProvider)!;

      expect(restored.format, MtgFormat.commander);
      expect(restored.players, hasLength(4));
      expect(restored.playerAt(2).name, 'Tio');
      expect(restored.playerAt(2).life, 40 - 13 - 6);
      expect(restored.playerAt(2).commanderDamageFrom(0), 6);
      expect(restored.monarch, 2, reason: 'a coroa volta com a partida');
    });
  });
}
