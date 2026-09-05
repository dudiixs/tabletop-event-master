import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../data/events_providers.dart';
import 'rental_cart.dart';

/// The rental request, right before it becomes a WhatsApp message.
///
/// Everything the shop needs to answer with a yes or a no is on this one
/// screen — the games, the period, the price the customer was shown — and the
/// send button hands exactly that text over. No booking is created, and the
/// sheet says so, because the app cannot see the shop's real shelf.
class RentalCheckoutSheet extends ConsumerWidget {
  const RentalCheckoutSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const RentalCheckoutSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final quote = ref.watch(rentalCartProvider);
    final cart = ref.read(rentalCartProvider.notifier);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Seu pedido de locação',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Retirada',
                        value: quote.pickup,
                        onPick: (date) => cart.setPeriod(pickup: date),
                        first: DateTime.now().subtract(const Duration(days: 1)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: 'Devolução',
                        value: quote.dropoff,
                        onPick: (date) => cart.setPeriod(dropoff: date),
                        first: quote.pickup,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${quote.days} ${quote.days == 1 ? 'diária' : 'diárias'} · '
                  'a diária conta por dia corrido, não por 24 horas.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
                ),
                const SizedBox(height: 22),
                for (final game in quote.games)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.title,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${Fmt.money(game.dailyPrice)}/dia · '
                                'caução ${Fmt.money(game.deposit)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: palette.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Fmt.money(game.dailyPrice * quote.days),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          onPressed: () => cart.remove(game),
                          tooltip: 'Tirar do pedido',
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 28),
                _TotalRow(
                  label: 'Total das diárias',
                  value: Fmt.money(quote.total),
                  strong: true,
                ),
                const SizedBox(height: 6),
                _TotalRow(
                  label: 'Caução (devolvida na entrega)',
                  value: Fmt.money(quote.deposit),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.tint(palette.warning, 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: palette.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Isto é um pedido, não uma reserva. A loja confirma '
                          'a disponibilidade pelo WhatsApp.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: quote.isEmpty
                        ? null
                        : () {
                            cart.clear();
                            Navigator.of(context).pop();
                          },
                    child: const Text('Limpar'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: quote.isValid
                          ? () => _send(context, ref)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(AppIcons.whatsapp, size: 18),
                      label: const Text('Pedir pelo WhatsApp'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final config = ref.read(appConfigProvider);
    final quote = ref.read(rentalCartProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final uri = Uri.https('wa.me', '/${config.whatsappNumber}', {
      'text': quote.whatsappMessage(),
    });

    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      navigator.pop();
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.first,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onPick;
  final DateTime first;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value.isBefore(first) ? first : value,
          firstDate: DateTime(first.year, first.month, first.day),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: label,
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  AppIcons.calendarOutline,
                  size: 15,
                  color: palette.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    Fmt.dayMonthWeekday(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? palette.text : palette.textSecondary,
              fontSize: strong ? 15 : 13,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: strong ? palette.success : palette.textSecondary,
            fontSize: strong ? 19 : 13,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
