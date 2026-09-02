import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../notifications/interests_controller.dart';
import '../../notifications/reminder_service.dart';
import '../../notifications/subscription_controller.dart';

/// Where the user picks which games they want to hear about.
class InterestsScreen extends ConsumerWidget {
  const InterestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final controller = ref.read(interestsProvider.notifier);
    final selected = ref.watch(interestsProvider);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        96 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          'Avise-me sobre',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Escolha os jogos que você acompanha. Você recebe um aviso quando '
          'entra um evento novo desses na agenda — e de mais nada.',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 20),
        // Wrap, not Row: the two labels plus the theme's tap-target padding
        // do not fit side by side on a narrow phone.
        Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: controller.followAll,
              child: const Text('Marcar todos'),
            ),
            TextButton(
              onPressed: controller.followNone,
              child: const Text('Desmarcar todos'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, category)
                  in InterestsController.selectable.indexed) ...[
                if (index > 0) const Divider(height: 1),
                SwitchListTile(
                  value: selected.contains(category),
                  onChanged: (_) => controller.toggle(category),
                  activeThumbColor: palette.primary,
                  title: Text(
                    '${category.emoji}  ${category.label}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (selected.isEmpty) ...[
          const SizedBox(height: 14),
          _Notice(
            icon: AppIcons.bellOff,
            text: 'Com nada marcado você não recebe aviso de evento novo. '
                'Os lembretes dos eventos que você marcar como "vou" '
                'continuam funcionando.',
          ),
        ],
        const SizedBox(height: 28),
        Text(
          'Lembretes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        _RemindersCard(),
      ],
    );
  }
}

/// Explains the reminder tiers and, on Android, the exact-alarm setting.
class _RemindersCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RemindersCard> createState() => _RemindersCardState();
}

class _RemindersCardState extends ConsumerState<_RemindersCard> {
  bool? _exactAllowed;

  @override
  void initState() {
    super.initState();
    _checkExact();
  }

  Future<void> _checkExact() async {
    if (!ReminderService.isSupported) return;
    final allowed =
        await ref.read(reminderServiceProvider).canScheduleExactly();
    if (mounted) setState(() => _exactAllowed = allowed);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final going = ref.watch(subscriptionsProvider);

    if (!ReminderService.isSupported) {
      return _Notice(
        icon: AppIcons.bellOff,
        text: 'Lembretes só funcionam no app instalado no celular.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quando você marca "vou nesse evento", avisamos '
                  '$reminderTiersDescription antes de começar.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: palette.textSecondary),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(AppIcons.bellOn, size: 17, color: palette.warning),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        going.isEmpty
                            ? 'Nenhum evento marcado ainda.'
                            : '${going.length} '
                                '${going.length == 1 ? 'evento marcado' : 'eventos marcados'}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                // The iOS ceiling is worth stating once, here, rather than
                // surprising someone with a reminder that never arrives.
                if (going.length > ReminderService.eventBudget) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Seu celular guarda lembrete para '
                    '${ReminderService.eventBudget} eventos por vez. Os mais '
                    'próximos vêm primeiro; os outros entram conforme eles '
                    'passam.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: palette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_exactAllowed == false) ...[
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                await ref.read(reminderServiceProvider).requestExactAlarms();
                await _checkExact();
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(AppIcons.time, size: 20, color: palette.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Permitir horário exato',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sem essa permissão o aviso de 5 minutos pode '
                            'atrasar alguns minutos.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: palette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(AppIcons.chevron, size: 18, color: palette.warning),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tint(palette.textSecondary, 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: palette.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The home-screen entry point into [InterestsScreen].
class InterestsSummaryCard extends ConsumerWidget {
  const InterestsSummaryCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final selected = ref.watch(interestsProvider);
    final controller = ref.read(interestsProvider.notifier);

    final summary = switch (selected.length) {
      0 => 'Nenhum jogo marcado',
      _ when controller.followsEverything => 'Todos os jogos',
      1 => selected.first.label,
      _ => selected.take(2).map((c) => c.label).join(', ') +
          (selected.length > 2 ? ' +${selected.length - 2}' : ''),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.tint(palette.warning, 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(AppIcons.bellOn, size: 22, color: palette.warning),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Avise-me sobre',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.chevron, size: 20, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
