import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/event.dart';
import '../common/state_views.dart';
import 'event_card.dart';
import 'event_details_sheet.dart';

/// A titled list of events, as slivers.
///
/// Slivers rather than a `ListView`, so the calendar screen can put the
/// calendar and this list in one scroll view and keep virtualization. The Expo
/// version nested a `FlatList` with `scrollEnabled={false}` inside a
/// `ScrollView`, which builds every card up front.
class EventsSliverList extends ConsumerWidget {
  const EventsSliverList({
    super.key,
    required this.events,
    required this.title,
    this.emptyTitle = 'Nenhum evento encontrado',
    this.emptyMessage =
        'Explore outras datas no calendário para encontrar eventos.',
  });

  final List<Event> events;
  final String title;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          sliver: SliverToBoxAdapter(
            child: _ListHeader(title: title, count: events.length),
          ),
        ),
        if (events.isEmpty)
          SliverToBoxAdapter(
            child: EmptyView(
              title: emptyTitle,
              message: emptyMessage,
              compact: true,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final event = events[index];
                return EventCard(
                  key: ValueKey(event.id),
                  event: event,
                  onTap: () => EventDetailsSheet.show(context, event),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 21),
          ),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: palette.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

/// The title above a list, given the selected day.
String eventsListTitle(DateTime? selectedDay) => selectedDay == null
    ? 'Todos os Eventos'
    : 'Eventos de ${Fmt.dayMonthWeekday(selectedDay)}';
