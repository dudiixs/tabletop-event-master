import 'package:flutter/material.dart';

import 'seat_style.dart';

/// Shows [child] as a dialog turned to face one seat at the table.
///
/// The player across the pod asks for their commander damage grid and gets it
/// the right way up for *them*. A normal bottom sheet would arrive upside
/// down and they would have to spin the phone — which is exactly the moment
/// someone knocks over a board.
Future<T?> showRotatedPanel<T>({
  required BuildContext context,
  required int quarterTurns,
  required Widget child,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (context) => RotatedBox(
      quarterTurns: quarterTurns,
      child: Dialog(
        backgroundColor: const Color(0xFF14161C),
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: SeatStyle.ink),
          child: child,
        ),
      ),
    ),
  );
}

/// The title bar every rotated panel wears.
class PanelTitle extends StatelessWidget {
  const PanelTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: SeatStyle.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: SeatStyle.inkMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
