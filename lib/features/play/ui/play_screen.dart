import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_palette.dart';
import '../domain/match_controller.dart';
import '../domain/mtg_format.dart';
import 'dice_panel.dart';
import 'rotated_panel.dart';

/// The PLAY tab: pick a format, seat the table, open the counter.
///
/// Three decisions on one screen, in the order a table makes them — qual jogo,
/// quantos somos, começar. It used to be six stacked cards with the player
/// count below the fold, which meant the second decision was invisible until
/// you scrolled past the first.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  MtgFormat _format = MtgFormat.commander;
  int _playerCount = 4;

  /// Only the "Livre" format lets this move; every other format's number is
  /// the rules' number.
  int _customLife = 20;

  void _selectFormat(MtgFormat format) {
    setState(() {
      _format = format;
      if (!format.playerCounts.contains(_playerCount)) {
        _playerCount = format.playerCounts.first;
      }
    });
  }

  void _start() {
    ref
        .read(matchProvider.notifier)
        .start(
          format: _format,
          playerCount: _playerCount,
          startingLife: _format == MtgFormat.free ? _customLife : null,
        );
    context.go(AppRoutes.lifeCounter);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final running = ref.watch(matchProvider);
    final life = _format == MtgFormat.free ? _customLife : _format.startingLife;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        120 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (running != null) ...[
          _ResumeCard(
            summary:
                '${running.format.label} · '
                '${running.players.length} jogadores',
            detail: running.players
                .map((player) => '${player.name} ${player.life}')
                .join('   ·   '),
            onResume: () => context.go(AppRoutes.lifeCounter),
            onDiscard: () => ref.read(matchProvider.notifier).end(),
          ),
          const SizedBox(height: 22),
        ],
        _Step(number: 1, label: 'Formato'),
        const SizedBox(height: 10),
        // A grid, not a list of cards: six formats fit in the space three
        // cards used, and the whole choice is visible at once.
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final format in MtgFormat.values)
              _FormatTile(
                format: format,
                selected: _format == format,
                onTap: () => _selectFormat(format),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _format.blurb,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 22),
        _Step(number: 2, label: 'Jogadores'),
        const SizedBox(height: 10),
        if (_format.seatsMoreThanTwo)
          Wrap(
            spacing: 8,
            children: [
              for (final count in _format.playerCounts)
                ChoiceChip(
                  label: Text(count == 2 ? '1 × 1' : '$count'),
                  selected: _playerCount == count,
                  onSelected: (_) => setState(() => _playerCount = count),
                ),
            ],
          )
        else
          Text(
            'Duelo — 1 × 1',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
          ),
        const SizedBox(height: 22),
        _Step(number: 3, label: 'Vida inicial'),
        const SizedBox(height: 10),
        Row(
          children: [
            if (_format == MtgFormat.free)
              IconButton.filledTonal(
                onPressed: _customLife <= 5
                    ? null
                    : () => setState(() => _customLife -= 5),
                icon: const Icon(Icons.remove),
              ),
            Expanded(
              child: Text(
                '$life',
                textAlign: _format == MtgFormat.free
                    ? TextAlign.center
                    : TextAlign.start,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _format == MtgFormat.free
                      ? palette.text
                      : palette.textSecondary,
                ),
              ),
            ),
            if (_format == MtgFormat.free)
              IconButton.filledTonal(
                onPressed: () => setState(() => _customLife += 5),
                icon: const Icon(Icons.add),
              ),
          ],
        ),
        const SizedBox(height: 26),
        FilledButton.icon(
          onPressed: _start,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(
            running == null ? 'Começar partida' : 'Começar uma nova',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: () => showRotatedPanel<void>(
              context: context,
              quarterTurns: 0,
              child: const DicePanel(),
            ),
            icon: const Icon(Icons.casino_outlined, size: 18),
            label: const Text('Só rolar um dado'),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'A mesa abre deitada, em tela cheia, e a partida fica salva se você '
          'sair do app. Em breve: contadores para outros TCGs.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: palette.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// A numbered step heading, so the screen reads as three decisions.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.tint(palette.primary, 0.16),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: TextStyle(
              color: palette.primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.format,
    required this.selected,
    required this.onTap,
  });

  final MtgFormat format;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: selected ? context.tint(palette.primary, 0.14) : palette.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? palette.primary : palette.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                format.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? palette.primary : palette.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${format.startingLife} vidas'
                '${format.seatsMoreThanTwo ? ' · até ${format.playerCounts.last}' : ' · 1×1'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The game already on the table, offered before anything else.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.summary,
    required this.detail,
    required this.onResume,
    required this.onDiscard,
  });

  final String summary;
  final String detail;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tint(palette.success, 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.tint(palette.success, 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_outline, color: palette.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Partida em andamento',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
          ),
          Text(
            detail,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: onResume,
                child: const Text('Voltar pra mesa'),
              ),
              const SizedBox(width: 10),
              TextButton(onPressed: onDiscard, child: const Text('Descartar')),
            ],
          ),
        ],
      ),
    );
  }
}
