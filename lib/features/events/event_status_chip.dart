import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../domain/event.dart';

/// The status badge on a card and in the detail sheet.
///
/// Five states, not two. The Expo badge was green for "Disponível" and red for
/// "Esgotado", and because anything unrecognised fell through to available, a
/// cancelled event wore the green badge.
class EventStatusChip extends StatelessWidget {
  const EventStatusChip({super.key, required this.status, this.large = false});

  final EventStatus status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final (label, color) = switch (status) {
      EventStatus.available => (
          large ? 'Vagas disponíveis' : 'Disponível',
          palette.success,
        ),
      EventStatus.soldOut => ('Esgotado', palette.error),
      EventStatus.cancelled => ('Cancelado', palette.error),
      EventStatus.postponed => ('Adiado', palette.warning),
      // Say so rather than guess. An unmapped Notion status is a data problem,
      // and announcing free seats that may not exist is the worse failure.
      EventStatus.unknown => ('Confirmar', palette.textSecondary),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 9,
        vertical: large ? 7 : 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(large ? 20 : 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: large ? 12.5 : 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
