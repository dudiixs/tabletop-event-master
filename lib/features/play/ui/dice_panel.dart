import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dice.dart';
import 'rotated_panel.dart';
import 'seat_style.dart';

/// The dice tray: every die a Magic table needs, plus the coin.
///
/// It lives inside the counter instead of sending people looking for a
/// physical d20 — the roll that decides who starts, the coin for Krark's
/// Thumb, the d6 for a random discard.
class DicePanel extends ConsumerStatefulWidget {
  const DicePanel({super.key, this.onFirstPlayer});

  /// Offered only when there is a table to pick from.
  final VoidCallback? onFirstPlayer;

  @override
  ConsumerState<DicePanel> createState() => _DicePanelState();
}

class _DicePanelState extends ConsumerState<DicePanel> {
  int _count = 1;

  @override
  Widget build(BuildContext context) {
    final roll = ref.watch(diceProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PanelTitle('Dados', subtitle: 'Toque num dado para rolar.'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
            ),
            child: roll == null
                ? const Text(
                    'Nenhuma rolagem ainda',
                    style: TextStyle(color: SeatStyle.inkMuted, fontSize: 13),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        roll.faces,
                        style: const TextStyle(
                          color: SeatStyle.ink,
                          fontSize: 34,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        roll.values.length > 1
                            ? '${roll.die.label} × ${roll.values.length} · total ${roll.total}'
                            : roll.die.label,
                        style: const TextStyle(
                          color: SeatStyle.inkMuted,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final die in Die.values)
                _DieButton(
                  label: die.label,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(diceProvider.notifier).roll(die, count: _count);
                  },
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              const Text(
                'Quantidade',
                style: TextStyle(color: SeatStyle.inkMuted, fontSize: 12.5),
              ),
              const Spacer(),
              for (final option in const [1, 2, 3, 4])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text('$option'),
                    selected: _count == option,
                    onSelected: (_) => setState(() => _count = option),
                    labelStyle: TextStyle(
                      color: _count == option
                          ? SeatStyle.board
                          : SeatStyle.inkMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    selectedColor: SeatStyle.ink,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              if (widget.onFirstPlayer != null)
                TextButton.icon(
                  onPressed: widget.onFirstPlayer,
                  icon: const Icon(Icons.casino_outlined, size: 18),
                  label: const Text('Quem começa'),
                ),
              const Spacer(),
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

class _DieButton extends StatelessWidget {
  const _DieButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 72,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: SeatStyle.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
