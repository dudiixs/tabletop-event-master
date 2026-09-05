import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';

/// The app's five places, always one tap away.
///
/// Hand-rolled rather than a [NavigationBar] for one reason: PLAY is not a
/// peer of the other four. It is the thing someone opens at a table with a
/// deck in their hand, so it gets the raised badge in the middle and the rest
/// of the bar arranges itself around it.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.location});

  /// The path currently on screen, passed in by the shell.
  final String location;

  static const _destinations = [
    _Destination(
      route: AppRoutes.home,
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Início',
    ),
    // One tab for the agenda as a whole. The week is the landing screen —
    // "what's on now" is the question people actually arrive with — and it
    // carries a link through to the full calendar, which lights this same tab.
    _Destination(
      route: AppRoutes.weekly,
      alsoAt: [AppRoutes.calendar],
      icon: AppIcons.today,
      activeIcon: Icons.today,
      label: 'Eventos',
    ),
    _Destination(
      route: AppRoutes.play,
      icon: Icons.sports_esports_outlined,
      activeIcon: Icons.sports_esports,
      label: 'PLAY',
      featured: true,
    ),
    _Destination(
      route: AppRoutes.rentals,
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      label: 'Locação',
    ),
    _Destination(
      route: AppRoutes.profile,
      // Deslogado a tela de perfil oferece o login, então a aba nunca é um
      // beco sem saída.
      alsoAt: [AppRoutes.login, AppRoutes.register, AppRoutes.forgotPassword],
      icon: AppIcons.person,
      activeIcon: Icons.person,
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (final destination in _destinations)
                Expanded(
                  child: _NavButton(
                    destination: destination,
                    selected: destination.covers(location),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (location != destination.route) {
                        context.go(destination.route);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.alsoAt = const [],
    this.featured = false,
  });

  /// Where a tap goes.
  final String route;

  /// Other screens this tab owns — five tabs for more than five screens, and
  /// a lit tab that does not match where you are is worse than no tab at all.
  final List<String> alsoAt;

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Drawn as the raised badge in the middle of the bar.
  final bool featured;

  bool covers(String location) {
    if (location == route) return true;
    if (alsoAt.contains(location)) return true;
    // A nested route still lights its tab: the life counter lives under /play.
    return route != AppRoutes.home && location.startsWith('$route/');
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.primary : palette.textSecondary;

    return InkResponse(
      onTap: onTap,
      radius: 42,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (destination.featured)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46,
              height: 28,
              decoration: BoxDecoration(
                color: selected
                    ? palette.primary
                    : context.tint(palette.primary, 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                selected ? destination.activeIcon : destination.icon,
                size: 19,
                color: selected ? palette.onBrand : palette.primary,
              ),
            )
          else
            Icon(
              selected ? destination.activeIcon : destination.icon,
              size: 22,
              color: color,
            ),
          const SizedBox(height: 3),
          Text(
            destination.label,
            style: TextStyle(
              color: destination.featured && !selected
                  ? palette.primary
                  : color,
              fontSize: 10.5,
              fontWeight: selected || destination.featured
                  ? FontWeight.w800
                  : FontWeight.w600,
              letterSpacing: destination.featured ? 0.6 : 0,
            ),
          ),
        ],
      ),
    );
  }
}
