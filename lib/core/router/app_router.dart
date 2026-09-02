import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/calendar_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/weekly/weekly_screen.dart';

/// The app's routes.
///
/// Real routes, which the Expo app never had: it kept the active screen in a
/// `useState` and switched on a string, so the declared `tabletopevents://`
/// deep-link scheme could not reach anything, and its router config declared
/// two screens (`index` and an `explore` tab) that had no files behind them.
///
/// Three destinations, each with a URL that works as a deep link and shows up
/// in the browser address bar on web.
abstract final class AppRoutes {
  static const home = '/';
  static const weekly = '/semana';
  static const calendar = '/calendario';
}

GoRouter buildRouter() => GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomeScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.weekly,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: WeeklyScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.calendar,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: CalendarScreen(),
              ),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => const _RouteNotFound(),
    );

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Página não encontrada',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => GoRouter.of(context).go(AppRoutes.home),
                child: const Text('Ir para o início'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
