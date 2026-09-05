import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/formatters.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../data/events_providers.dart';
import '../../domain/calendar_date.dart';
import '../../domain/event.dart';
import '../events/event_details_sheet.dart';
import 'featured_event_card.dart';

/// The landing screen: what is on, and what to do about it.
///
/// It used to be a hero, three navigation cards and a "why play with us"
/// section — a menu of doors on top of a bar that already has those doors.
/// With the tab bar carrying navigation, the home screen's only job is the
/// question people actually open the app with: *o que tem pra mim agora?*
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaProvider);

    return RefreshIndicator(
      onRefresh: () => refreshAgenda(ref),
      color: context.palette.primary,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _TodayLine()),
          SliverToBoxAdapter(child: FeaturedEventSection(agenda: agenda)),
          const SliverToBoxAdapter(child: _WeekStrip()),
          const SliverToBoxAdapter(child: _Shortcuts()),
          // Clears the floating WhatsApp button and the tab bar.
          SliverToBoxAdapter(
            child: SizedBox(height: 96 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }
}

/// Today's date and how much is on it. Two lines, no box.
///
/// Replaces the welcome hero: a greeting nobody reads was taking a third of
/// the first screen.
class _TodayLine extends ConsumerWidget {
  const _TodayLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final todayCount = ref
        .watch(upcomingEventsProvider)
        .where((event) => isSameDay(event.day, today()))
        .length;
    final weekCount = ref.watch(weeklyEventsProvider).length;

    final summary = switch ((todayCount, weekCount)) {
      (0, 0) => 'Nada marcado nos próximos dias',
      (0, final week) =>
        '$week ${week == 1 ? 'evento' : 'eventos'} nesta semana',
      (final today, _) =>
        '$today ${today == 1 ? 'evento' : 'eventos'} hoje — bora?',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Fmt.fullDate(today()),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 3),
          Text(
            summary,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// The week, sideways: one small card per event, in date order.
///
/// A horizontal strip rather than a list, because the week is context — the
/// full list lives one tab away and does not need to be repeated here.
class _WeekStrip extends ConsumerWidget {
  const _WeekStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final week = ref.watch(weeklyEventsProvider);
    if (week.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Esta semana',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.weekly),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: palette.primary,
                ),
                child: const Text('Ver tudo'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            itemCount: week.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _WeekCard(event: week[index]),
          ),
        ),
      ],
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final days = daysBetween(today(), event.day);
    final when = switch (days) {
      0 => 'HOJE',
      1 => 'AMANHÃ',
      _ => Fmt.dayMonthWeekday(event.day).toUpperCase(),
    };
    final soon = days <= 1;

    return SizedBox(
      width: 190,
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => EventDetailsSheet.show(context, event),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: soon
                    ? context.tint(palette.primary, 0.5)
                    : palette.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  when,
                  style: TextStyle(
                    color: soon ? palette.primary : palette.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 7),
                Expanded(
                  child: Text(
                    event.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(AppIcons.time, size: 13, color: palette.textSecondary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        Fmt.time(event),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The two things the app does besides the agenda, on one line.
///
/// Deliberately small: they are already tabs. This is a reminder that they
/// exist, not a second navigation.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _Shortcut(
              icon: Icons.sports_esports_outlined,
              accent: palette.warning,
              title: 'Contador de vida',
              subtitle: 'Magic, mesa de até 6',
              onTap: () => context.go(AppRoutes.play),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Shortcut(
              icon: Icons.inventory_2_outlined,
              accent: palette.success,
              title: 'Alugar um jogo',
              subtitle: 'Leve pra casa',
              onTap: () => context.go(AppRoutes.rentals),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: context.tint(accent, 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: accent),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
