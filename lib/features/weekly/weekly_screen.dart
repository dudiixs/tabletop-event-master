import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_palette.dart';
import '../../data/events_providers.dart';
import '../../domain/calendar_date.dart';
import '../common/state_views.dart';
import '../events/events_list.dart';

/// The next seven days.
class WeeklyScreen extends ConsumerWidget {
  const WeeklyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaProvider);
    final palette = context.palette;

    return switch (agenda) {
      AsyncValue(hasError: true, :final error?) => ErrorView(
          error: error,
          onRetry: () => refreshAgenda(ref),
        ),
      AsyncValue(isLoading: true, hasValue: false) => const LoadingView(
          message: 'Carregando a semana...',
          subtitle: 'Buscando a agenda',
        ),
      _ => RefreshIndicator(
          onRefresh: () => refreshAgenda(ref),
          color: palette.primary,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _WeekRange()),
              _WeeklyList(),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 96 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
        ),
    };
  }
}

/// Says which seven days are being shown.
///
/// Worth stating plainly, because the Expo screen's "próximos 7 dias" actually
/// spanned eight and there was nothing on screen to reveal that.
class _WeekRange extends StatelessWidget {
  const _WeekRange();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final start = today();
    final end = addDays(start, 6);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: context.tint(palette.primary, 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(AppIcons.today, size: 19, color: palette.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              '${Fmt.dayMonthWeekday(start)} → ${Fmt.dayMonthWeekday(end)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(weeklyEventsProvider);

    return EventsSliverList(
      events: events,
      title: 'Esta Semana',
      emptyTitle: 'Nenhum evento nos próximos 7 dias',
      emptyMessage:
          'Veja o calendário completo para o que vem depois desta semana.',
    );
  }
}
