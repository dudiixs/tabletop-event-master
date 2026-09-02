import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/calendar_date.dart';
import '../../domain/event.dart';
import '../../notifications/reminder_service.dart';
import 'event_status_chip.dart';
import 'going_control.dart';

/// One event in a list.
class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final daysAway = daysBetween(today(), event.day);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The accent stripe the Expo card drew as a decorative overlay.
            Container(height: 3, color: palette.primary),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DateBadge(event: event),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontSize: 16.5, height: 1.25),
                            ),
                            const SizedBox(height: 6),
                            // Time and how-far-off in one ellipsized line.
                            // Two sibling Texts overflowed here as soon as the
                            // time read "Horário a confirmar".
                            Row(
                              children: [
                                Icon(AppIcons.time,
                                    size: 14, color: palette.primary),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(children: [
                                      TextSpan(
                                        text: Fmt.time(event),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: palette.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            '  ·  ${Fmt.relativeDay(daysAway)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: palette.textSecondary,
                                        ),
                                      ),
                                    ]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      EventStatusChip(status: event.status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _CategoryChip(event: event),
                  if (event.hasDescription) ...[
                    const SizedBox(height: 10),
                    Text(
                      event.plainDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: palette.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(AppIcons.place,
                          size: 15, color: palette.textSecondary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          event.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: palette.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _PriceTag(event: event),
                      if (ReminderService.isSupported) ...[
                        const SizedBox(width: 4),
                        GoingIconButton(event: event),
                      ],
                    ],
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

/// The day-and-month circle on the left of a card.
class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: palette.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${event.day.day}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Fmt.monthBadge(event.day),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final category = event.category;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: context.tint(palette.primary, 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: TextStyle(
                color: palette.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // "A definir" is not good news, so it does not get the success green the
    // Expo card gave every price including an empty one.
    final color = event.hasPrice ? palette.success : palette.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: context.tint(color, 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.tint(color, 0.5)),
      ),
      child: Text(
        Fmt.price(event),
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
