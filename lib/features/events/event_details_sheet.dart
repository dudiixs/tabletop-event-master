import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_icons.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_palette.dart';
import '../../data/events_providers.dart';
import '../../domain/event.dart';
import '../../notifications/reminder_service.dart';
import 'going_control.dart';
import 'event_status_chip.dart';
import 'rich_text_view.dart';

/// The event detail sheet.
///
/// A real modal bottom sheet rather than a full-screen `Modal` positioned at
/// 85% height, so it gets the drag handle, the swipe-to-dismiss and the
/// scroll-to-expand behaviour for free.
class EventDetailsSheet extends ConsumerWidget {
  const EventDetailsSheet({super.key, required this.event});

  final Event event;

  static Future<void> show(BuildContext context, Event event) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EventDetailsSheet(event: event),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          _Header(event: event),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (event.hasImage) ...[
                  _EventImage(url: event.imageUrl!),
                  const SizedBox(height: 16),
                ],
                _InfoCard(
                  rows: [
                    _InfoRow(
                      icon: AppIcons.calendarOutline,
                      label: 'Data',
                      value: Fmt.fullDate(event.day),
                    ),
                    _InfoRow(
                      icon: AppIcons.time,
                      label: 'Horário',
                      value: Fmt.time(event),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  rows: [
                    _InfoRow(
                      icon: AppIcons.place,
                      label: 'Local',
                      value: event.location,
                    ),
                    _InfoRow(
                      icon: AppIcons.person,
                      label: 'Organizador',
                      value: event.organizer,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  rows: [
                    _InfoRow(
                      icon: AppIcons.price,
                      label: 'Valor',
                      value: Fmt.price(event),
                      valueColor:
                          event.hasPrice ? palette.success : palette.textSecondary,
                      emphasise: true,
                    ),
                  ],
                ),
                // One description section, not two. The Expo sheet showed a
                // truncated "Resumo" immediately above the full text — the
                // same content twice whenever the Notion field was filled.
                if (event.hasDescription) ...[
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Sobre o evento',
                    child: RichTextView(event.description),
                  ),
                ],
                if (event.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Categorias',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in event.tags) Chip(label: Text(tag)),
                      ],
                    ),
                  ),
                ],
                if (event.hasPage) ...[
                  const SizedBox(height: 12),
                  _PageLinkButton(url: event.pageUrl!),
                ],
              ],
            ),
          ),
          _Footer(event: event),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      color: palette.primary,
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    event.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
              if (ReminderService.isSupported)
                GoingIconButton(event: event, onBrand: true),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Fechar',
                icon: const Icon(AppIcons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              EventStatusChip(status: event.status, large: true),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${event.category.emoji} ${event.category.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.onBrandMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventImage extends StatelessWidget {
  const _EventImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          // The placeholder replaces the manual onLoadStart/onLoadEnd state the
          // Expo sheet tracked — which stayed true when a second event without
          // an image reused the same mounted modal.
          placeholder: (context, _) => ColoredBox(
            color: context.tint(palette.primary, 0.08),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: palette.primary,
                ),
              ),
            ),
          ),
          // Notion file URLs are signed and expire in about an hour, so a
          // broken image is expected rather than exceptional.
          errorWidget: (context, _, _) => ColoredBox(
            color: context.tint(palette.textSecondary, 0.1),
            child: Center(
              child: Icon(
                AppIcons.image,
                size: 32,
                color: palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            for (final (index, row) in rows.indexed) ...[
              if (index > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: row,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasise = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.tint(valueColor ?? palette.primary, 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: valueColor ?? palette.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: emphasise
                    ? theme.textTheme.titleLarge?.copyWith(
                        color: valueColor ?? palette.text,
                        fontSize: 19,
                      )
                    : theme.textTheme.bodyLarge?.copyWith(
                        color: valueColor ?? palette.text,
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Opens the event's own page.
///
/// The Expo mapper read this URL out of Notion and nothing ever used it.
class _PageLinkButton extends StatelessWidget {
  const _PageLinkButton({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(AppIcons.openExternal, size: 19, color: palette.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Abrir a página do evento',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: palette.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Icon(AppIcons.chevron,
                  size: 18, color: palette.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Column(
        children: [
          // "Vou nesse" acima e em largura cheia: e a acao principal da tela.
          if (ReminderService.isSupported) ...[
            SizedBox(width: double.infinity, child: GoingButton(event: event)),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openWhatsApp(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              icon: const Icon(AppIcons.whatsapp, size: 20),
              label: const Text(
                'Entrar em contato',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context, WidgetRef ref) async {
    final config = ref.read(appConfigProvider);
    final message = 'Olá! 👋 Gostaria de mais informações sobre o evento:\n\n'
        '🎯 *${event.name}*\n'
        '📅 ${Fmt.fullDate(event.day)} às ${Fmt.time(event)}\n'
        '📍 ${event.location}\n'
        '💰 ${Fmt.price(event)}\n\n'
        'Poderia me dar mais detalhes?';

    final uri = Uri.https('wa.me', '/${config.whatsappNumber}', {
      'text': message,
    });

    final messenger = ScaffoldMessenger.of(context);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }
}
