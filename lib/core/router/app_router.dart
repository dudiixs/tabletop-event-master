import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/preferences/interests_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/weekly/weekly_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const weekly = '/semana';
  static const calendar = '/calendario';
  static const interests = '/avisos';
  static const login = '/login';
  static const register = '/cadastro';
  static const forgotPassword = '/esqueci-senha';
  static const profile = '/perfil';
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
            GoRoute(
              path: AppRoutes.interests,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: InterestsScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.login,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: LoginScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.register,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: RegisterScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.forgotPassword,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ForgotPasswordScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.profile,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ProfileScreen(),
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
