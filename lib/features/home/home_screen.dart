import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../data/events_providers.dart';
import '../common/state_views.dart';
import 'featured_event_card.dart';

/// The landing screen: where to go, plus one event worth looking at.
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
          const SliverToBoxAdapter(child: _Hero()),
          const SliverToBoxAdapter(child: _NavigationCards()),
          SliverToBoxAdapter(
            child: FeaturedEventSection(agenda: agenda),
          ),
          const SliverToBoxAdapter(child: _WhyUs()),
          // Clears the floating WhatsApp button and the system gesture bar.
          SliverToBoxAdapter(
            child: SizedBox(
              height: 96 + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      color: palette.brand,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: palette.onBrand.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: palette.onBrand.withValues(alpha: 0.28),
                width: 2,
              ),
            ),
            child: Icon(AppIcons.calendar, size: 30, color: palette.onBrand),
          ),
          const SizedBox(height: 20),
          Text(
            'Bem-vindo! 👋',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineLarge
                ?.copyWith(color: palette.onBrand),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              'Descubra os melhores eventos de board games e card games',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: palette.onBrandMuted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationCards extends ConsumerWidget {
  const _NavigationCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final weeklyCount = ref.watch(weeklyEventsProvider).length;
    final totalCount = ref.watch(upcomingEventsProvider).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('🚀 Explorar Eventos'),
          const SizedBox(height: 18),
          _NavCard(
            icon: AppIcons.today,
            accent: palette.primary,
            title: 'Eventos da Semana',
            subtitle: 'O que está rolando nos próximos 7 dias',
            // A real count instead of the static "Esta Semana" pill, so the
            // card says something before you tap it.
            badge: weeklyCount == 0
                ? 'Nada esta semana'
                : '$weeklyCount ${weeklyCount == 1 ? 'evento' : 'eventos'}',
            onTap: () => context.go('/semana'),
          ),
          const SizedBox(height: 14),
          _NavCard(
            icon: AppIcons.calendarOutline,
            accent: palette.success,
            title: 'Calendário Completo',
            subtitle: 'Navegue por mês e veja tudo o que vem',
            badge: totalCount == 0
                ? 'Agenda vazia'
                : '$totalCount na agenda',
            onTap: () => context.go('/calendario'),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(width: 4, height: 116, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: context.tint(accent, 0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(icon, size: 26, color: accent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: palette.textSecondary),
                          ),
                          const SizedBox(height: 9),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.tint(accent, 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badge.toUpperCase(),
                              style: TextStyle(
                                color: accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(AppIcons.chevron, size: 22, color: accent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhyUs extends StatelessWidget {
  const _WhyUs();

  static const _items = [
    (AppIcons.community, 'Comunidade', 'Encontre outros jogadores'),
    (AppIcons.quality, 'Qualidade', 'Eventos bem organizados'),
    (AppIcons.time, 'Sempre atual', 'Agenda atualizada do Notion'),
    (AppIcons.fun, 'Diversão', 'Experiências inesquecíveis'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accents = [
      palette.primary,
      palette.warning,
      palette.success,
      palette.error,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('💎 Por que jogar com a gente'),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              // Two columns on a phone, four on a tablet — the Expo grid was
              // hard-coded to 48% width and stretched oddly on a wide screen.
              final columns = constraints.maxWidth > 620 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: columns == 2 ? 0.95 : 0.85,
                children: [
                  for (final (index, item) in _items.indexed)
                    _FeatureTile(
                      icon: item.$1,
                      title: item.$2,
                      description: item.$3,
                      accent: accents[index],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.tint(accent, 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 23, color: accent),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Flexible(
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: palette.textSecondary, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
