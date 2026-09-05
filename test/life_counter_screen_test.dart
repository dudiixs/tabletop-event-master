import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabletop_events/features/play/domain/match_controller.dart';
import 'package:tabletop_events/features/play/domain/mtg_format.dart';
import 'package:tabletop_events/features/play/ui/board_arrangement.dart';
import 'package:tabletop_events/features/play/ui/life_counter_screen.dart';
import 'package:tabletop_events/features/play/ui/player_panel.dart';

import 'app_harness.dart';

/// The board explains itself the first time it opens; every test that drives
/// the table has to get past that card first.
Future<void> dismissHint(WidgetTester tester) async {
  if (find.text('Entendi').evaluate().isEmpty) return;
  await tester.tap(find.text('Entendi'));
  await tester.pumpAndSettle();
}

void main() {
  group('the table layout', () {
    test('a duel faces the two players at each other', () {
      final duel = BoardArrangement.forCount(2);

      expect(duel.rows, [
        [1],
        [0],
      ]);
      expect(duel.turnsFor(1), 2, reason: 'o de cima joga de cabeça pra baixo');
      expect(duel.turnsFor(0), 0);
      expect(duel.isCrowded, isFalse);
    });

    test('a pod seats everyone and faces the far side the other way', () {
      for (final count in [3, 4, 5, 6]) {
        final pod = BoardArrangement.forCount(count);
        final seats = pod.rows.expand((row) => row).toList();

        expect(
          seats..sort(),
          List.generate(count, (index) => index),
          reason: 'mesa de $count',
        );
        expect(pod.isCrowded, isTrue, reason: 'mesa de $count');
        expect(
          pod.rows.first.every((seat) => pod.turnsFor(seat) == 2),
          isTrue,
          reason: 'mesa de $count',
        );
      }
    });
  });

  group('the board', () {
    testWidgets('draws one panel per seat, all on the format life', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        const LifeCounterScreen(),
        size: const Size(420, 900),
      );
      container
          .read(matchProvider.notifier)
          .start(format: MtgFormat.commander, playerCount: 4);
      await tester.pumpAndSettle();
      await dismissHint(tester);

      expect(find.byType(PlayerPanel), findsNWidgets(4));
      expect(find.text('40'), findsNWidgets(4));
      expect(find.text('Jogador 1'), findsOne);
      expect(find.text('Jogador 4'), findsOne);
    });

    testWidgets('the right half gives life and the left half takes it', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        const LifeCounterScreen(),
        size: const Size(420, 900),
      );
      container
          .read(matchProvider.notifier)
          .start(format: MtgFormat.modern, playerCount: 2);
      await tester.pumpAndSettle();
      await dismissHint(tester);

      // Seat 0 is the bottom panel, the one facing whoever holds the phone.
      final panel = find.byType(PlayerPanel).last;
      final box = tester.getRect(panel);

      await tester.tapAt(Offset(box.right - 30, box.center.dy));
      await tester.pump();
      expect(container.read(matchProvider)!.playerAt(0).life, 21);

      await tester.tapAt(Offset(box.left + 30, box.center.dy));
      await tester.tapAt(Offset(box.left + 30, box.center.dy));
      await tester.pump();
      expect(container.read(matchProvider)!.playerAt(0).life, 19);

      // And the running total of the last few taps is on screen.
      expect(find.text('-1'), findsOne);
    });

    testWidgets('a dead player is marked, and the winner card appears', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        const LifeCounterScreen(),
        size: const Size(420, 900),
      );
      final match = container.read(matchProvider.notifier)
        ..start(format: MtgFormat.commander, playerCount: 2);
      await tester.pumpAndSettle();
      await dismissHint(tester);

      match.adjustCommanderDamage(target: 1, source: 0, delta: 21);
      await tester.pumpAndSettle();

      expect(find.textContaining('21 DE DANO DE COMANDANTE'), findsOne);
      expect(find.text('Jogador 1 venceu!'), findsOne);
      expect(find.text('Revanche'), findsOne);
    });

    testWidgets('the crown shows over the monarch, and only there', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        const LifeCounterScreen(),
        size: const Size(420, 900),
      );
      final match = container.read(matchProvider.notifier)
        ..start(format: MtgFormat.commander, playerCount: 4);
      await tester.pumpAndSettle();
      await dismissHint(tester);

      expect(find.text('MONARCA'), findsNothing);

      match.claimMonarch(1);
      await tester.pumpAndSettle();
      expect(find.text('MONARCA'), findsOne);

      match.claimMonarch(3);
      await tester.pumpAndSettle();
      expect(find.text('MONARCA'), findsOne, reason: 'uma coroa só na mesa');
    });

    testWidgets('the crown is not offered in a Modern duel', (tester) async {
      final container = await pumpScreen(
        tester,
        const LifeCounterScreen(),
        size: const Size(420, 900),
      );
      container
          .read(matchProvider.notifier)
          .start(format: MtgFormat.modern, playerCount: 2);
      await tester.pumpAndSettle();
      await dismissHint(tester);

      expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);
    });

    testWidgets('the first game explains the table, and only the first', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        const LifeCounterScreen(),
        size: const Size(900, 420),
      );
      container
          .read(matchProvider.notifier)
          .start(format: MtgFormat.commander, playerCount: 4);
      await tester.pumpAndSettle();

      expect(find.text('Como a mesa funciona'), findsOne);
      expect(find.textContaining('Metade esquerda tira vida'), findsOne);

      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(find.text('Como a mesa funciona'), findsNothing);

      // And it stays gone: the next table does not re-explain itself.
      container
          .read(matchProvider.notifier)
          .start(format: MtgFormat.commander, playerCount: 2);
      await tester.pumpAndSettle();
      expect(find.text('Como a mesa funciona'), findsNothing);
    });

    testWidgets('undo walks a mistaken tap back', (tester) async {
      final container = await pumpScreen(
        tester,
        const LifeCounterScreen(),
        size: const Size(420, 900),
      );
      container
          .read(matchProvider.notifier)
          .start(format: MtgFormat.commander, playerCount: 2);
      await tester.pumpAndSettle();
      await dismissHint(tester);

      final box = tester.getRect(find.byType(PlayerPanel).last);
      await tester.tapAt(Offset(box.left + 30, box.center.dy));
      await tester.pump();
      expect(container.read(matchProvider)!.playerAt(0).life, 39);

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pump();
      expect(container.read(matchProvider)!.playerAt(0).life, 40);
    });
  });
}
