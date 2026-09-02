import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_icons.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_palette.dart';
import '../../data/events_data_source.dart';
import '../../data/events_providers.dart';
import '../../domain/calendar_date.dart';
import '../../domain/event.dart';
import '../events/event_details_sheet.dart';
import '../events/event_status_chip.dart';
import '../common/state_views.dart';

/// The "Em Destaque" block: one upcoming event, with a shuffle.
class FeaturedEventSection extends ConsumerWidget {
  const FeaturedEventSection({super.key, required this.agenda});

  final AsyncValue<List<Event>> agenda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            '⭐ Em Destaque',
            trailing: IconButton(
              onPressed: agenda.hasValue
                  ? () => ref.read(featuredEventProvider.notifier).shuffle()
                  : null,
              tooltip: 'Sortear outro evento',
              style: IconButton.styleFrom(
                backgroundColor: context.tint(palette.primary, 0.12),
              ),
              icon: Icon(AppIcons.shuffle, size: 18, color: palette.primary),
            ),
          ),
          const SizedBox(height: 16),
          switch (agenda) {
            AsyncValue(hasError: true, :final error?) =>
              _FeaturedShell(child: _FeaturedError(error: error, ref: ref)),
            AsyncValue(isLoading: true) =>
              const _FeaturedShell(child: _FeaturedSkeleton()),
            _ => const _FeaturedContent(),
          },
        ],
      ),
    );
  }
}

class _FeaturedShell extends StatelessWidget {
  const _FeaturedShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
  }
}

class _FeaturedSkeleton extends StatelessWidget {
  const _FeaturedSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final width in [0.7, 0.45, 0.9, 0.6])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FractionallySizedBox(
              widthFactor: width,
              alignment: Alignment.centerLeft,
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: context.tint(palette.textSecondary, 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeaturedError extends StatelessWidget {
  const _FeaturedError({required this.error, required this.ref});

  final Object error;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final failure = error is EventsFailure ? error as EventsFailure : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              failure?.isOffline ?? false
                  ? AppIcons.offline
                  : AppIcons.failure,
              size: 20,
              color: palette.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                failure?.message ?? 'Não deu para carregar a agenda.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => refreshAgenda(ref),
            icon: const Icon(AppIcons.refresh, size: 17),
            label: const Text('Tentar novamente'),
          ),
        ),
      ],
    );
  }
}

class _FeaturedContent extends ConsumerWidget {
  const _FeaturedContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(featuredEventProvider);
    final palette = context.palette;

    if (event == null) {
      return _FeaturedShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎲 Nada marcado ainda',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'A agenda está vazia por enquanto. Fale com a gente pelo '
              'WhatsApp para saber dos próximos encontros.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: palette.textSecondary),
            ),
          ],
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => EventDetailsSheet.show(context, event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: palette.warning),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${event.category.emoji} ${event.name}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontSize: 19, height: 1.3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      EventStatusChip(status: event.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // The same date formatting the card and the sheet use. In the
                  // Expo app this one spot parsed the date differently and
                  // showed the day before.
                  _MetaRow(
                    icon: AppIcons.calendarOutline,
                    text: Fmt.longDate(event.day),
                    highlight: Fmt.relativeDay(daysBetween(today(), event.day)),
                  ),
                  _MetaRow(
                    icon: AppIcons.time,
                    text: Fmt.time(event),
                  ),
                  _MetaRow(
                    icon: AppIcons.place,
                    text: event.location,
                  ),
                  if (event.hasDescription) ...[
                    const SizedBox(height: 14),
                    Text(
                      event.plainDescription,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: palette.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: context.tint(
                            event.hasPrice
                                ? palette.success
                                : palette.textSecondary,
                            0.12,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: context.tint(
                              event.hasPrice
                                  ? palette.success
                                  : palette.textSecondary,
                              0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          Fmt.price(event),
                          style: TextStyle(
                            color: event.hasPrice
                                ? palette.success
                                : palette.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Full width rather than sharing a row with the price chip:
                  // a long price and a long label together overflowed a narrow
                  // card, and a featured card's call to action deserves the
                  // whole width anyway.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.go('/semana'),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(AppIcons.forward, size: 16),
                      label: const Text('Ver a semana'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, this.highlight});

  final IconData icon;
  final String text;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: palette.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          if (highlight case final highlight?)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.tint(palette.warning, 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                highlight,
                style: TextStyle(
                  color: palette.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
