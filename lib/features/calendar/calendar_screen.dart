import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Our own isSameDay lives in calendar_date.dart and goes through UTC for the
// day arithmetic; table_calendar exports one with the same name.
import 'package:table_calendar/table_calendar.dart' hide isSameDay;

import '../../core/format/formatters.dart';
import '../../core/theme/app_palette.dart';
import '../../data/events_providers.dart';
import '../../domain/calendar_date.dart';
import '../../domain/event.dart';
import '../common/state_views.dart';
import '../events/events_list.dart';

/// The month calendar with the selected day's events underneath.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedMonth = today();

  @override
  Widget build(BuildContext context) {
    final agenda = ref.watch(agendaProvider);
    final palette = context.palette;

    return switch (agenda) {
      AsyncValue(hasError: true, :final error?) => ErrorView(
          error: error,
          onRetry: () => refreshAgenda(ref),
        ),
      AsyncValue(isLoading: true, hasValue: false) => const LoadingView(
          subtitle: 'Buscando a agenda',
        ),
      _ => RefreshIndicator(
          onRefresh: () => refreshAgenda(ref),
          color: palette.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Calendar(
                focusedMonth: _focusedMonth,
                onMonthChanged: (month) =>
                    setState(() => _focusedMonth = month),
              )),
              const _CalendarEventsList(),
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

class _Calendar extends ConsumerWidget {
  const _Calendar({required this.focusedMonth, required this.onMonthChanged});

  final DateTime focusedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final eventsByDay = ref.watch(eventsByDayProvider);
    final selectedDay = ref.watch(selectedDayProvider);

    return Card(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TableCalendar<Event>(
          locale: Fmt.locale,
          firstDay: DateTime(today().year - 1),
          lastDay: DateTime(today().year + 2, 12, 31),
          focusedDay: focusedMonth,
          currentDay: today(),
          // Monday, as the Expo calendar had it.
          startingDayOfWeek: StartingDayOfWeek.monday,
          availableGestures: AvailableGestures.horizontalSwipe,
          eventLoader: (day) => eventsByDay[dateOnly(day)] ?? const [],
          selectedDayPredicate: (day) =>
              selectedDay != null && isSameDay(selectedDay, day),
          onDaySelected: (selected, focused) {
            final day = dateOnly(selected);
            final controller = ref.read(selectedDayProvider.notifier);
            // Tapping the selected day again clears the filter, so there is a
            // way back to the full list without leaving the screen — the Expo
            // calendar had none.
            controller.state =
                selectedDay != null && isSameDay(selectedDay, day) ? null : day;
            onMonthChanged(focused);
          },
          onPageChanged: onMonthChanged,
          calendarBuilders: CalendarBuilders<Event>(
            headerTitleBuilder: (context, month) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                Fmt.monthYear(month),
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 17),
              ),
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            leftChevronIcon:
                Icon(Icons.chevron_left, color: palette.primary),
            rightChevronIcon:
                Icon(Icons.chevron_right, color: palette.primary),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              color: palette.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            weekendStyle: TextStyle(
              color: palette.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          calendarStyle: CalendarStyle(
            // Days from the neighbouring months stay hidden, as before.
            outsideDaysVisible: false,
            defaultTextStyle: TextStyle(color: palette.text, fontSize: 15),
            weekendTextStyle: TextStyle(color: palette.text, fontSize: 15),
            disabledTextStyle: TextStyle(
              color: palette.textSecondary.withValues(alpha: 0.4),
              fontSize: 15,
            ),
            todayDecoration: BoxDecoration(
              color: context.tint(palette.primary, 0.16),
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: palette.primary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            selectedDecoration: BoxDecoration(
              color: palette.primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            markerDecoration: BoxDecoration(
              color: palette.primary,
              shape: BoxShape.circle,
            ),
            markersMaxCount: 3,
            markerSize: 5,
            markerMargin: const EdgeInsets.symmetric(horizontal: 1.2),
          ),
        ),
      ),
    );
  }
}

class _CalendarEventsList extends ConsumerWidget {
  const _CalendarEventsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final events = ref.watch(calendarListProvider);

    return EventsSliverList(
      events: events,
      title: eventsListTitle(selectedDay),
      emptyTitle: selectedDay == null
          ? 'Nenhum evento na agenda'
          : 'Nada marcado neste dia',
      emptyMessage: selectedDay == null
          ? 'Assim que novos eventos entrarem no Notion, eles aparecem aqui.'
          : 'Toque no dia de novo para ver a agenda inteira.',
    );
  }
}
