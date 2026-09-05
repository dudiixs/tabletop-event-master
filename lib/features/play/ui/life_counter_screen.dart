import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_controller.dart';
import '../domain/dice.dart';
import '../domain/match_controller.dart';
import '../domain/mtg_match.dart';
import 'board_arrangement.dart';
import 'commander_damage_panel.dart';
import 'dice_panel.dart';
import 'player_panel.dart';
import 'rotated_panel.dart';
import 'seat_style.dart';

/// The table itself.
///
/// Full screen, no app chrome, its own dark palette and the screen held awake:
/// this is the one screen in the app that is meant to sit face-up between four
/// people for two hours.
class LifeCounterScreen extends ConsumerStatefulWidget {
  const LifeCounterScreen({super.key});

  @override
  ConsumerState<LifeCounterScreen> createState() => _LifeCounterScreenState();
}

class _LifeCounterScreenState extends ConsumerState<LifeCounterScreen> {
  /// Set when the winner card has been waved away, so someone can keep
  /// poking at the numbers after the game is decided.
  bool _resultDismissed = false;

  /// Shown over the first game anyone plays, and again from the menu.
  ///
  /// The board is a screen of numbers with no labels on purpose — every pixel
  /// belongs to the life totals. That only works if the first time you open
  /// it, something tells you what the halves and the chips do.
  bool _showHint = false;

  /// Guards against the card coming back before the preference lands on disk:
  /// [didChangeDependencies] runs again on a theme change, and the write is
  /// asynchronous.
  bool _hintDismissed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hintDismissed) return;
    final prefs = ref.read(sharedPreferencesProvider);
    if (!(prefs.getBool(_hintSeenKey) ?? false)) {
      _showHint = true;
    }
  }

  static const _hintSeenKey = 'play_board_hint_seen';

  void _dismissHint() {
    _hintDismissed = true;
    setState(() => _showHint = false);
    ref.read(sharedPreferencesProvider).setBool(_hintSeenKey, true);
  }

  @override
  void initState() {
    super.initState();
    // A phone that sleeps mid-combat is the reason people still use dice.
    _keepAwake(true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Landscape, always. The phone lies flat between the players and each
    // panel gets the screen's long edge — a 40 that fills a wide band reads
    // from across the table, where the same number in a tall portrait column
    // does not.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _keepAwake(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // The rest of the app never asked for an orientation; hand it back.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  /// Holds the screen on while the board is open.
  ///
  /// Failure is not worth an error: there is no wakelock on the web, on some
  /// desktops, or in a widget test, and the board is perfectly usable without
  /// one — the screen just dims the way it always did.
  Future<void> _keepAwake(bool enabled) async {
    try {
      await (enabled ? WakelockPlus.enable() : WakelockPlus.disable());
    } on Object {
      // Nothing to do: this platform simply has no wakelock.
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = ref.watch(matchProvider);

    // Nothing on the table — someone deep-linked here, or ended the game in
    // another tab. Send them back to the setup rather than showing an empty
    // board.
    if (match == null) {
      return const _NoMatch();
    }

    if (!match.isOver && _resultDismissed) _resultDismissed = false;

    final arrangement = BoardArrangement.forCount(match.players.length);

    return Scaffold(
      backgroundColor: SeatStyle.board,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  for (final row in arrangement.rows)
                    Expanded(
                      child: Row(
                        children: [
                          for (final seat in row)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: RotatedBox(
                                  quarterTurns: arrangement.turnsFor(seat),
                                  child: PlayerPanel(
                                    player: match.playerAt(seat),
                                    format: match.format,
                                    compact: arrangement.isCrowded,
                                    onLife: (delta) => ref
                                        .read(matchProvider.notifier)
                                        .adjustLife(seat, delta),
                                    onPoison: (delta) => ref
                                        .read(matchProvider.notifier)
                                        .adjustPoison(seat, delta),
                                    onCommanderDamage: () =>
                                        _openCommanderDamage(
                                          match,
                                          seat,
                                          arrangement.turnsFor(seat),
                                        ),
                                    onRename: () => _rename(
                                      match,
                                      seat,
                                      arrangement.turnsFor(seat),
                                    ),
                                    onConcede: () => ref
                                        .read(matchProvider.notifier)
                                        .toggleConcede(seat),
                                    isMonarch: match.isMonarch(seat),
                                    onMonarch: () {
                                      HapticFeedback.selectionClick();
                                      ref
                                          .read(matchProvider.notifier)
                                          .claimMonarch(seat);
                                    },
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: _CenterControls(
                canUndo: ref.read(matchProvider.notifier).canUndo,
                onUndo: () {
                  HapticFeedback.mediumImpact();
                  ref.read(matchProvider.notifier).undo();
                },
                onDice: () => _openDice(match),
                onMenu: () => _openMenu(match),
              ),
            ),
            if (_showHint)
              Positioned.fill(child: _BoardHint(onDismiss: _dismissHint)),
            if (match.isOver && !_resultDismissed)
              Positioned.fill(
                child: _ResultOverlay(
                  match: match,
                  onRematch: () {
                    ref.read(matchProvider.notifier).restart();
                    setState(() => _resultDismissed = false);
                  },
                  onKeepPlaying: () => setState(() => _resultDismissed = true),
                  onLeave: _leave,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCommanderDamage(MtgMatch match, int seat, int turns) {
    return showRotatedPanel<void>(
      context: context,
      quarterTurns: turns,
      // Rebuilt from the provider so the numbers move while the panel is open.
      child: Consumer(
        builder: (context, ref, _) {
          final current = ref.watch(matchProvider);
          if (current == null) return const SizedBox.shrink();
          return CommanderDamagePanel(
            match: current,
            target: seat,
            onChange: ({required source, required delta}) => ref
                .read(matchProvider.notifier)
                .adjustCommanderDamage(
                  target: seat,
                  source: source,
                  delta: delta,
                ),
          );
        },
      ),
    );
  }

  Future<void> _rename(MtgMatch match, int seat, int turns) async {
    final controller = TextEditingController(text: match.playerAt(seat).name);

    final name = await showRotatedPanel<String>(
      context: context,
      quarterTurns: turns,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PanelTitle('Nome do jogador'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: SeatStyle.ink),
              decoration: const InputDecoration(hintText: 'Como te chamam?'),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(controller.text),
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    controller.dispose();
    if (name != null) ref.read(matchProvider.notifier).rename(seat, name);
  }

  Future<void> _openMenu(MtgMatch match) async {
    final action = await showModalBottomSheet<_BoardAction>(
      context: context,
      backgroundColor: const Color(0xFF14161C),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuTile(
              icon: Icons.casino_outlined,
              label: 'Dados',
              subtitle: 'd20, d6, moeda e companhia',
              action: _BoardAction.dice,
            ),
            _MenuTile(
              icon: Icons.shuffle,
              label: 'Quem começa',
              subtitle: 'Sorteia um jogador da mesa',
              action: _BoardAction.firstPlayer,
            ),
            _MenuTile(
              icon: Icons.help_outline,
              label: 'Como usar a mesa',
              subtitle: 'Toques, marcadores e a ilha do centro',
              action: _BoardAction.help,
            ),
            _MenuTile(
              icon: Icons.restart_alt,
              label: 'Reiniciar partida',
              subtitle: 'Mesma mesa, vida de volta a ${match.startingLife}',
              action: _BoardAction.restart,
            ),
            _MenuTile(
              icon: Icons.logout,
              label: 'Encerrar e sair',
              subtitle: 'Apaga a partida salva',
              action: _BoardAction.leave,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _BoardAction.dice:
        await _openDice(match);
      case _BoardAction.firstPlayer:
        _drawFirstPlayer(match);
      case _BoardAction.help:
        setState(() => _showHint = true);
      case _BoardAction.restart:
        ref.read(matchProvider.notifier).restart();
      case _BoardAction.leave:
        await _leave();
    }
  }

  Future<void> _openDice(MtgMatch match) {
    return showRotatedPanel<void>(
      context: context,
      quarterTurns: 0,
      child: DicePanel(
        onFirstPlayer: () {
          Navigator.of(context).pop();
          _drawFirstPlayer(match);
        },
      ),
    );
  }

  void _drawFirstPlayer(MtgMatch match) {
    final seat = ref
        .read(diceProvider.notifier)
        .firstPlayer(match.players.length);
    final player = match.playerAt(seat);
    HapticFeedback.heavyImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: SeatStyle.of(seat).accent,
        content: Text(
          '${player.name} começa!',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _leave() async {
    await ref.read(matchProvider.notifier).end();
    if (!mounted) return;
    context.go(AppRoutes.play);
  }
}

enum _BoardAction { dice, firstPlayer, help, restart, leave }

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final _BoardAction action;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: SeatStyle.ink),
      title: Text(
        label,
        style: const TextStyle(
          color: SeatStyle.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: SeatStyle.inkMuted, fontSize: 12.5),
      ),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}

/// The little island in the middle of the board.
///
/// Undo sits out here rather than in the menu because it is the button people
/// need in a hurry, right after a thumb lands in the wrong half.
/// The little island in the middle of the board.
///
/// Undo and the dice sit out here rather than in the menu because they are the
/// two things people need mid-turn, in a hurry — right after a thumb lands in
/// the wrong half, or when someone says "rola um d20".
class _CenterControls extends StatelessWidget {
  const _CenterControls({
    required this.canUndo,
    required this.onUndo,
    required this.onDice,
    required this.onMenu,
  });

  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onDice;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SeatStyle.board.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: canUndo ? onUndo : null,
            tooltip: 'Desfazer',
            iconSize: 24,
            icon: const Icon(Icons.undo),
            color: SeatStyle.ink,
            disabledColor: SeatStyle.inkMuted.withValues(alpha: 0.3),
          ),
          IconButton(
            onPressed: onDice,
            tooltip: 'Dados',
            iconSize: 24,
            icon: const Icon(Icons.casino_outlined),
            color: SeatStyle.ink,
          ),
          IconButton(
            onPressed: onMenu,
            tooltip: 'Menu da partida',
            iconSize: 24,
            icon: const Icon(Icons.more_horiz),
            color: SeatStyle.ink,
          ),
        ],
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.match,
    required this.onRematch,
    required this.onKeepPlaying,
    required this.onLeave,
  });

  final MtgMatch match;
  final VoidCallback onRematch;
  final VoidCallback onKeepPlaying;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final winner = match.winner;

    return ColoredBox(
      color: SeatStyle.board.withValues(alpha: 0.88),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                winner == null ? Icons.sentiment_neutral : Icons.emoji_events,
                size: 52,
                color: winner == null
                    ? SeatStyle.inkMuted
                    : SeatStyle.of(winner.seat).accent,
              ),
              const SizedBox(height: 14),
              Text(
                winner == null ? 'Ninguém sobrou' : '${winner.name} venceu!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SeatStyle.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                match.format.label,
                style: const TextStyle(
                  color: SeatStyle.inkMuted,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onRematch,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Revanche'),
                  ),
                  OutlinedButton(
                    onPressed: onKeepPlaying,
                    child: const Text('Continuar mexendo'),
                  ),
                  TextButton(onPressed: onLeave, child: const Text('Sair')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeatStyle.board,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nenhuma partida aberta',
              style: TextStyle(color: SeatStyle.ink, fontSize: 17),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => context.go(AppRoutes.play),
              child: const Text('Montar mesa'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one-screen explanation of the board.
class _BoardHint extends StatelessWidget {
  const _BoardHint({required this.onDismiss});

  final VoidCallback onDismiss;

  static const _lines = [
    (
      Icons.touch_app_outlined,
      'Metade esquerda tira vida, metade direita '
          'soma. Segure para correr.',
    ),
    (
      Icons.science_outlined,
      'Frasco: veneno. Toque soma, segure tira — '
          '10 e o jogador está fora.',
    ),
    (
      Icons.military_tech_outlined,
      'Medalha: dano de comandante, por '
          'oponente. 21 de um só mata, e a vida cai junto.',
    ),
    (Icons.emoji_events_outlined, 'Troféu: a coroa do monarca. Um por mesa.'),
    (Icons.more_horiz, 'No centro: desfazer, dados e o menu da partida.'),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SeatStyle.board.withValues(alpha: 0.93),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Como a mesa funciona',
                  style: TextStyle(
                    color: SeatStyle.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                for (final (icon, text) in _lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 18, color: SeatStyle.inkMuted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: SeatStyle.ink,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: onDismiss,
                    child: const Text('Entendi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
