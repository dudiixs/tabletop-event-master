import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/mtg_format.dart';
import '../domain/mtg_match.dart';
import 'seat_style.dart';

/// One player's half (or quarter) of the board.
///
/// The whole panel is the button: the left side takes life away, the right
/// side gives it back, and holding either one runs. That is the interaction
/// every life counter converged on, because at a real table you are looking at
/// the board, not at the phone.
class PlayerPanel extends StatefulWidget {
  const PlayerPanel({
    super.key,
    required this.player,
    required this.format,
    required this.onLife,
    required this.onPoison,
    required this.onCommanderDamage,
    required this.onRename,
    required this.onConcede,
    required this.onMonarch,
    this.isMonarch = false,
    this.compact = false,
  });

  final MatchPlayer player;
  final MtgFormat format;
  final void Function(int delta) onLife;
  final void Function(int delta) onPoison;

  /// Opens the grid of "how hard has each commander hit me".
  final VoidCallback onCommanderDamage;
  final VoidCallback onRename;
  final VoidCallback onConcede;

  /// Takes the crown, or gives it up if this seat already wears it.
  final VoidCallback onMonarch;

  final bool isMonarch;

  /// Set on a crowded table, where a panel is a quarter of the screen.
  final bool compact;

  @override
  State<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<PlayerPanel> {
  /// What the last few taps added up to, shown under the life total and
  /// cleared once the hand stops. Without it nobody can tell whether the
  /// eleventh tap registered.
  int _delta = 0;
  Timer? _deltaTimer;
  Timer? _repeatTimer;

  @override
  void dispose() {
    _deltaTimer?.cancel();
    _repeatTimer?.cancel();
    super.dispose();
  }

  void _change(int delta) {
    widget.onLife(delta);
    HapticFeedback.selectionClick();
    setState(() => _delta += delta);
    _deltaTimer?.cancel();
    _deltaTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _delta = 0);
    });
  }

  /// Holding accelerates: nothing for a moment so a long press is never an
  /// accident, then fast enough to walk 40 life down in a couple of seconds.
  void _startRepeat(int delta) {
    _repeatTimer?.cancel();
    var ticks = 0;
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      ticks++;
      if (ticks < 3) return;
      _change(delta * (ticks > 24 ? 5 : 1));
    });
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final style = SeatStyle.of(player.seat);
    final dead = player.deathCause;

    return LayoutBuilder(
      builder: (context, constraints) {
        final lifeSize = (constraints.maxHeight * 0.42).clamp(
          40.0,
          widget.compact ? 96.0 : 150.0,
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: style.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: dead == null
                  ? style.panelEdge
                  : SeatStyle.inkMuted.withValues(alpha: 0.25),
              width: 1.4,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              children: [
                // The tap zones sit underneath everything, so the chips
                // layered on top still get their own taps.
                Row(
                  children: [
                    Expanded(
                      child: _TapZone(
                        icon: Icons.remove,
                        alignment: Alignment.centerLeft,
                        onTap: () => _change(-1),
                        onHoldStart: () => _startRepeat(-1),
                        onHoldEnd: _stopRepeat,
                      ),
                    ),
                    Expanded(
                      child: _TapZone(
                        icon: Icons.add,
                        alignment: Alignment.centerRight,
                        onTap: () => _change(1),
                        onHoldStart: () => _startRepeat(1),
                        onHoldEnd: _stopRepeat,
                      ),
                    ),
                  ],
                ),
                IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: lifeSize * 1.05,
                          child: FittedBox(
                            child: Text(
                              '${player.life}',
                              style: TextStyle(
                                fontSize: lifeSize,
                                height: 1,
                                fontWeight: FontWeight.w300,
                                color: dead == null
                                    ? SeatStyle.ink
                                    : SeatStyle.ink.withValues(alpha: 0.35),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: _delta == 0 ? 0 : 1,
                          duration: const Duration(milliseconds: 160),
                          child: Text(
                            _delta > 0 ? '+$_delta' : '$_delta',
                            style: TextStyle(
                              fontSize: widget.compact ? 15 : 19,
                              fontWeight: FontWeight.w700,
                              color: _delta > 0
                                  ? const Color(0xFF6EE7A8)
                                  : const Color(0xFFFF8B95),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // The crown sits at the top of the panel — above the life
                // total from that player's own side of the table, which is
                // where a table looks to ask "who is the monarch?".
                if (widget.isMonarch)
                  const Positioned(
                    top: 8,
                    right: 10,
                    // Corner, not centre: in a duel the two panels meet in the
                    // middle of the screen and a centred crown ends up behind
                    // the control island.
                    child: IgnorePointer(child: _MonarchBadge()),
                  ),
                // Name and counters share one strip along the panel's own
                // bottom edge — which rotation puts at the *outer* edge of the
                // screen. That keeps the middle of the board clear for the
                // control island, which used to sit on top of the two names
                // in a duel.
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _PanelStrip(
                    player: player,
                    format: widget.format,
                    accent: style.accent,
                    compact: widget.compact,
                    onRename: widget.onRename,
                    onPoison: widget.onPoison,
                    onCommanderDamage: widget.onCommanderDamage,
                    onConcede: widget.onConcede,
                    onMonarch: widget.onMonarch,
                    isMonarch: widget.isMonarch,
                  ),
                ),
                if (dead != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: SeatStyle.board.withValues(alpha: 0.55),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.sentiment_very_dissatisfied,
                                color: Color(0xFFFF8B95),
                                size: 30,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'FORA · ${dead.label}'.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFFF8B95),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Half a panel: a tap changes life by one, a hold runs.
///
/// The sign is drawn inside a visible disc rather than as a faint glyph: the
/// two halves are the main control on the screen and nothing else says so.
class _TapZone extends StatelessWidget {
  const _TapZone({
    required this.icon,
    required this.alignment,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final IconData icon;
  final Alignment alignment;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: (_) => onHoldStart(),
      onLongPressEnd: (_) => onHoldEnd(),
      onLongPressCancel: onHoldEnd,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Icon(
              icon,
              size: 24,
              color: SeatStyle.ink.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}

/// The strip along a panel's outer edge: who this is, and what is on them.
class _PanelStrip extends StatelessWidget {
  const _PanelStrip({
    required this.player,
    required this.format,
    required this.accent,
    required this.compact,
    required this.onRename,
    required this.onPoison,
    required this.onCommanderDamage,
    required this.onConcede,
    required this.onMonarch,
    required this.isMonarch,
  });

  final MatchPlayer player;
  final MtgFormat format;
  final Color accent;
  final bool compact;
  final VoidCallback onRename;
  final void Function(int delta) onPoison;
  final VoidCallback onCommanderDamage;
  final VoidCallback onConcede;
  final VoidCallback onMonarch;
  final bool isMonarch;

  @override
  Widget build(BuildContext context) {
    final worst = player.worstCommanderDamage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 0, 9, 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Spelled-out chips only where they fit. An unlabelled flask is a
          // riddle, but a chip cut in half is worse — so the labels appear
          // from the width where all of them still fit on one line.
          final showLabels = !compact && constraints.maxWidth >= 360;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stacked, not side by side: on a four-player table the counter
              // chips leave a name barely wider than one letter, and a life
              // counter that cannot show whose seat it is has lost the plot.
              GestureDetector(
                onTap: onRename,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SeatStyle.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Wrap, so a narrow panel drops to a second line instead of
              // overflowing off the edge.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Poison rides along in every format: infect and toxic are
                  // not a Commander thing. It stays a quiet chip at zero and
                  // turns loud as the counters pile up.
                  _CounterChip(
                    icon: Icons.science_outlined,
                    label: showLabels ? 'VENENO' : null,
                    value: player.poison,
                    danger: player.poison >= MtgFormat.poisonLethal - 2,
                    tooltip: 'Veneno (infect/toxic) · toque soma, segure tira',
                    onTap: () => onPoison(1),
                    onLongPress: () => onPoison(-1),
                  ),
                  if (format.tracksCommanderDamage)
                    _CounterChip(
                      icon: Icons.military_tech_outlined,
                      label: showLabels ? 'COMANDANTE' : null,
                      value: worst,
                      danger: worst >= MtgFormat.commanderDamageLethal - 4,
                      tooltip: 'Dano de comandante',
                      onTap: onCommanderDamage,
                      onLongPress: onCommanderDamage,
                    ),
                  if (format.offersMonarch)
                    _CounterChip(
                      icon: isMonarch
                          ? Icons.emoji_events
                          : Icons.emoji_events_outlined,
                      label: showLabels ? 'COROA' : null,
                      value: null,
                      danger: false,
                      highlight: isMonarch,
                      tooltip: isMonarch
                          ? 'Você é o monarca · toque para tirar a coroa'
                          : 'Tornar-se o monarca',
                      onTap: onMonarch,
                      onLongPress: onMonarch,
                    ),
                  if (!compact)
                    _CounterChip(
                      icon: player.conceded ? Icons.flag : Icons.outlined_flag,
                      value: null,
                      danger: player.conceded,
                      tooltip: 'Desistir',
                      onTap: onConcede,
                      onLongPress: onConcede,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({
    required this.icon,
    required this.value,
    required this.danger,
    required this.tooltip,
    required this.onTap,
    required this.onLongPress,
    this.label,
    this.highlight = false,
  });

  final IconData icon;

  /// Spelled out when the panel is wide enough. An unlabelled flask is a
  /// riddle; "VENENO 3" is not.
  final String? label;
  final int? value;
  final bool danger;

  /// Drawn in gold: the crown, when this seat wears it.
  final bool highlight;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final active = danger || highlight || (value ?? 0) > 0;
    final color = switch ((danger, highlight)) {
      (true, _) => const Color(0xFFFF8B95),
      (_, true) => _MonarchBadge.gold,
      _ => SeatStyle.inkMuted,
    };

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: value == null ? 9 : 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label!,
                  style: TextStyle(
                    color: color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
              if (value != null) ...[
                const SizedBox(width: 5),
                Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The crown, over the monarch's life total.
class _MonarchBadge extends StatelessWidget {
  const _MonarchBadge();

  static const gold = Color(0xFFE8C15A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.55)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 14, color: gold),
          SizedBox(width: 5),
          Text(
            'MONARCA',
            style: TextStyle(
              color: gold,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}
