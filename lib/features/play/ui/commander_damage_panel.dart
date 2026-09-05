import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/mtg_format.dart';
import '../domain/mtg_match.dart';
import 'rotated_panel.dart';
import 'seat_style.dart';

/// How much each opponent's commander has hit one player for.
///
/// Twenty-one from a single commander ends the game (rule 903.10a), and the
/// count is *per commander* — never pooled — so this has to be a grid with one
/// row per opponent rather than a single number. Each row turns red as it
/// approaches lethal, which is the warning a table usually gives too late.
class CommanderDamagePanel extends StatelessWidget {
  const CommanderDamagePanel({
    super.key,
    required this.match,
    required this.target,
    required this.onChange,
  });

  final MtgMatch match;

  /// The player taking the damage.
  final int target;

  final void Function({required int source, required int delta}) onChange;

  final int lethal = MtgFormat.commanderDamageLethal;

  @override
  Widget build(BuildContext context) {
    final player = match.playerAt(target);
    final opponents = match.players
        .where((other) => other.seat != target)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelTitle(
          'Dano de comandante · ${player.name}',
          subtitle:
              'Cada comandante mata sozinho com $lethal. A vida cai junto — '
              'é dano de verdade.',
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final opponent in opponents)
                  _DamageRow(
                    name: opponent.name,
                    accent: SeatStyle.of(opponent.seat).accent,
                    value: player.commanderDamageFrom(opponent.seat),
                    lethal: lethal,
                    onChange: (delta) =>
                        onChange(source: opponent.seat, delta: delta),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DamageRow extends StatelessWidget {
  const _DamageRow({
    required this.name,
    required this.accent,
    required this.value,
    required this.lethal,
    required this.onChange,
  });

  final String name;
  final Color accent;
  final int value;
  final int lethal;
  final void Function(int delta) onChange;

  @override
  Widget build(BuildContext context) {
    final dead = value >= lethal;
    final close = value >= lethal - 4;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: dead
              ? const Color(0xFFFF8B95).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: dead
                ? const Color(0xFFFF8B95)
                : accent.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SeatStyle.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _StepButton(
              icon: Icons.remove,
              onTap: value == 0 ? null : () => onChange(-1),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: close ? const Color(0xFFFF8B95) : SeatStyle.ink,
                ),
              ),
            ),
            _StepButton(icon: Icons.add, onTap: () => onChange(1)),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 20),
      color: SeatStyle.ink,
      disabledColor: SeatStyle.inkMuted.withValues(alpha: 0.35),
    );
  }
}
