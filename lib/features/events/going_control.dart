import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/event.dart';
import '../../notifications/subscription_controller.dart';

/// The compact "vou nesse evento" toggle, for a card or a sheet header.
class GoingIconButton extends ConsumerWidget {
  const GoingIconButton({
    super.key,
    required this.event,
    this.onBrand = false,
  });

  final Event event;

  /// Rendered on the brand-coloured header rather than on a card.
  final bool onBrand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final going = ref.watch(subscriptionsProvider).contains(event.id);
    final color = onBrand
        ? palette.onBrand
        : (going ? palette.warning : palette.textSecondary);

    return IconButton(
      onPressed: () => toggleGoing(context, ref, event),
      visualDensity: VisualDensity.compact,
      tooltip: going ? 'Não vou mais' : 'Vou nesse — me avise antes',
      icon: Icon(
        going ? AppIcons.bellOn : AppIcons.bellOff,
        size: 20,
        color: color,
      ),
    );
  }
}

/// The full-width "vou nesse evento" button for the detail sheet, where it is
/// the primary action and deserves a label rather than an icon to decode.
class GoingButton extends ConsumerWidget {
  const GoingButton({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final going = ref.watch(subscriptionsProvider).contains(event.id);

    if (going) {
      return OutlinedButton.icon(
        onPressed: () => toggleGoing(context, ref, event),
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.warning,
          side: BorderSide(color: context.tint(palette.warning, 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(AppIcons.bellOn, size: 19),
        label: Text(
          'Você vai · avisamos $reminderTiersDescription antes',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: () => toggleGoing(context, ref, event),
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      icon: const Icon(AppIcons.bellOff, size: 19),
      label: const Text(
        'Vou nesse evento',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Marks or unmarks [event] and says what happened.
///
/// A reminder fires hours later, so a silent toggle gives no confidence it
/// worked — and the interesting cases (too close to warn, budget full,
/// permission denied) all need words.
Future<void> toggleGoing(
  BuildContext context,
  WidgetRef ref,
  Event event,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await ref.read(subscriptionsProvider.notifier).toggle(event);
  if (!context.mounted) return;

  final needsExactAlarms = result == SubscriptionResult.subscribed &&
      !await ref.read(reminderServiceProvider).canScheduleExactly();
  if (!context.mounted) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(subscriptionMessage(result)),
      // Android 12+ hides exact alarms behind a system setting. Without it the
      // five-minute warning can arrive minutes late, so offer the fix rather
      // than let it quietly under-deliver.
      action: needsExactAlarms
          ? SnackBarAction(
              label: 'Ajustar',
              onPressed: () =>
                  ref.read(reminderServiceProvider).requestExactAlarms(),
            )
          : null,
    ));
}
