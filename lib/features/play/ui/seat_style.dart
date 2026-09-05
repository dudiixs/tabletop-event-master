import 'package:flutter/material.dart';

/// The look of one seat at the table.
///
/// The board runs on its own dark palette instead of the app's, in both
/// themes. A life counter lives face-up on a table for two hours: white
/// panels are a glare in a games shop and a battery drain on OLED, and the
/// seat colours only read as distinct against a dark ground.
@immutable
class SeatStyle {
  const SeatStyle({required this.accent, required this.label});

  final Color accent;

  /// The Magic colour the accent is borrowed from, for the seat picker.
  final String label;

  static const seats = [
    SeatStyle(accent: Color(0xFFE0525F), label: 'Vermelho'),
    SeatStyle(accent: Color(0xFF4C8DF6), label: 'Azul'),
    SeatStyle(accent: Color(0xFF35C46B), label: 'Verde'),
    SeatStyle(accent: Color(0xFFE8B23C), label: 'Branco'),
    SeatStyle(accent: Color(0xFF9C6BF0), label: 'Roxo'),
    SeatStyle(accent: Color(0xFF16BFAE), label: 'Turquesa'),
  ];

  static SeatStyle of(int seat) => seats[seat % seats.length];

  /// The ground of a panel: the accent, drowned in near-black.
  Color get panel =>
      Color.alphaBlend(accent.withValues(alpha: 0.16), const Color(0xFF0F1116));

  Color get panelEdge => accent.withValues(alpha: 0.42);

  static const board = Color(0xFF07080B);
  static const ink = Color(0xFFF5F6F8);
  static const inkMuted = Color(0xFF9BA1AE);
}
