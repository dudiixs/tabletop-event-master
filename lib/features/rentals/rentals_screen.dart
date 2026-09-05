import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../data/rentals_data_source.dart';
import '../../domain/rental_game.dart';
import '../common/state_views.dart';
import 'rental_cart.dart';
import 'rental_checkout_sheet.dart';

/// The rental shelf.
///
/// Browsing, picking and asking — the whole thing ends in a WhatsApp message
/// the shop can answer, because that is where these conversations already
/// happen. No account, no checkout, no stock the app cannot actually see.
class RentalsScreen extends ConsumerStatefulWidget {
  const RentalsScreen({super.key});

  @override
  ConsumerState<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends ConsumerState<RentalsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  RentalShelf? _shelf;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RentalGame> _filter(List<RentalGame> games) {
    final query = _query.trim().toLowerCase();
    return games
        .where((game) {
          if (_shelf != null && game.shelf != _shelf) return false;
          if (query.isEmpty) return true;
          return game.title.toLowerCase().contains(query) ||
              game.tagline.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final catalogue = ref.watch(rentalCatalogueProvider);
    final quote = ref.watch(rentalCartProvider);

    return Stack(
      children: [
        Column(
          children: [
            _SearchBar(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
            ),
            _ShelfFilters(
              selected: _shelf,
              onSelected: (shelf) => setState(() => _shelf = shelf),
            ),
            Expanded(
              child: catalogue.when(
                loading: () => const LoadingView(
                  message: 'Abrindo o armário...',
                  subtitle: 'Buscando os jogos disponíveis',
                ),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(rentalCatalogueProvider),
                ),
                data: (games) {
                  final visible = _filter(games);
                  if (visible.isEmpty) {
                    return const EmptyView(
                      title: 'Nada por aqui',
                      message:
                          'Nenhum jogo com esse filtro. Tente outra prateleira.',
                      icon: Icons.search_off,
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      (quote.isEmpty ? 110 : 190) +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final game = visible[index];
                      return _RentalCard(
                        game: game,
                        picked: ref
                            .read(rentalCartProvider.notifier)
                            .contains(game),
                        onToggle: () =>
                            ref.read(rentalCartProvider.notifier).toggle(game),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        if (!quote.isEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _CartBar(
              count: quote.games.length,
              total: quote.total,
              days: quote.days,
              accent: palette.primary,
              onOpen: () => RentalCheckoutSheet.show(context),
            ),
          ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Procurar um jogo',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(AppIcons.close, size: 20),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          isDense: true,
        ),
      ),
    );
  }
}

class _ShelfFilters extends StatelessWidget {
  const _ShelfFilters({required this.selected, required this.onSelected});

  final RentalShelf? selected;
  final ValueChanged<RentalShelf?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Tudo'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final shelf in RentalShelf.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(shelf.label),
                selected: selected == shelf,
                onSelected: (_) => onSelected(selected == shelf ? null : shelf),
              ),
            ),
        ],
      ),
    );
  }
}

class _RentalCard extends StatelessWidget {
  const _RentalCard({
    required this.game,
    required this.picked,
    required this.onToggle,
  });

  final RentalGame game;
  final bool picked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = game.available;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onToggle : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Cover(game: game),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        game.tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MetaChip(
                            icon: Icons.group_outlined,
                            label: game.playersLabel,
                          ),
                          _MetaChip(
                            icon: AppIcons.time,
                            label: game.durationLabel,
                          ),
                          _MetaChip(icon: Icons.speed, label: game.weightLabel),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          // Expanded, not a Spacer: on a 360 dp phone the
                          // price and the button together are wider than the
                          // card, and the price is the half that can shrink.
                          Expanded(
                            child: Text(
                              '${Fmt.money(game.dailyPrice)}/dia',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.success,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!enabled)
                            Text(
                              'ALUGADO',
                              style: TextStyle(
                                color: palette.error,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            )
                          else
                            FilledButton.tonalIcon(
                              onPressed: onToggle,
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: picked
                                    ? context.tint(palette.success, 0.18)
                                    : null,
                                foregroundColor: picked
                                    ? palette.success
                                    : null,
                              ),
                              icon: Icon(
                                picked ? Icons.check : Icons.add,
                                size: 17,
                              ),
                              label: Text(picked ? 'Na lista' : 'Quero'),
                            ),
                        ],
                      ),
                    ],
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

/// The tile that stands in for a box shot.
///
/// The catalogue carries no photos yet, so each game gets a stable colour
/// drawn from its own id and its initials — which still lets someone find a
/// game they have seen before by shape and colour rather than by reading.
class _Cover extends StatelessWidget {
  const _Cover({required this.game});

  final RentalGame game;

  static const _palette = [
    Color(0xFF5166C6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFE0525F),
    Color(0xFF9C6BF0),
    Color(0xFF16BFAE),
  ];

  String get _initials {
    final words = game.title
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _palette[game.id.hashCode.abs() % _palette.length];
    final image = game.imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 72,
        height: 96,
        child: image == null
            ? DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, accent.withValues(alpha: 0.62)],
                  ),
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                errorWidget: (context, _, _) =>
                    ColoredBox(color: context.tint(accent, 0.3)),
              ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.tint(palette.textSecondary, 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: palette.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The running total, pinned above the tab bar while anything is picked.
class _CartBar extends StatelessWidget {
  const _CartBar({
    required this.count,
    required this.total,
    required this.days,
    required this.accent,
    required this.onOpen,
  });

  final int count;
  final double total;
  final int days;
  final Color accent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.card,
      elevation: 12,
      shadowColor: palette.shadow,
      child: SafeArea(
        top: false,
        child: Padding(
          // Clears the floating WhatsApp button on the right.
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count ${count == 1 ? 'jogo' : 'jogos'} · '
                      '$days ${days == 1 ? 'diária' : 'diárias'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    Text(
                      Fmt.money(total),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('Ver pedido'),
              ),
              const SizedBox(width: 64),
            ],
          ),
        ),
      ),
    );
  }
}
