import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/events_providers.dart';
import 'app_bottom_nav.dart';

/// The frame every screen sits inside: header, content, WhatsApp button.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final router = GoRouter.of(context);
    // Read off the route state, not `router.state`, and handed down to the
    // header and the tab bar. Both used to be `const`, which meant Flutter
    // reused the same widget on every navigation and neither ever noticed
    // where it was — the back arrow stayed hidden and the tab bar would have
    // stayed lit on whatever tab opened first.
    final location = GoRouterState.of(context).uri.path;
    final isHome = location == AppRoutes.home;

    // Paints the system bars to match the header and the page ground. One
    // place, driven by the resolved theme — the Expo app set the status bar
    // from the app theme and the navigation bar from the *system* theme, so
    // the two could disagree.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: palette.surface,
        systemNavigationBarIconBrightness:
            ThemeData.estimateBrightnessForColor(palette.surface) ==
                Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: PopScope(
        // Off the home screen the back gesture returns home; on the home
        // screen it asks before leaving, as the Expo BackHandler did.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (!isHome) {
            router.go('/');
            return;
          }
          if (await _confirmExit(context)) {
            await SystemNavigator.pop();
          }
        },
        child: Scaffold(
          body: Column(
            children: [
              AppHeader(location: location),
              Expanded(child: child),
            ],
          ),
          bottomNavigationBar: AppBottomNav(location: location),
          floatingActionButton: const _WhatsAppButton(),
        ),
      ),
    );
  }

  Future<bool> _confirmExit(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do app?'),
        content: const Text('Você pode voltar quando quiser.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }
}

/// The brand header: back, logo, theme toggle.
///
/// The profile used to live up here as an avatar too. It moved to the tab bar
/// — one door per destination beats two, and the header is now just identity
/// and the one control that belongs to every screen.
class AppHeader extends ConsumerWidget {
  const AppHeader({super.key, required this.location});

  /// The path on screen, so the back arrow knows whether there is anywhere to
  /// go back to.
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final config = ref.watch(appConfigProvider);
    final themeMode = ref.watch(themeModeProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };

    final router = GoRouter.of(context);
    final isHome = location == AppRoutes.home;

    return Container(
      color: palette.brand,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: isHome
                    ? null
                    : IconButton(
                        onPressed: () => router.go('/'),
                        tooltip: 'Voltar',
                        icon: Icon(AppIcons.back, color: palette.onBrand),
                      ),
              ),
              Expanded(
                child: Center(child: _Logo(companyName: config.companyName)),
              ),
              IconButton(
                onPressed: () => ref
                    .read(themeModeProvider.notifier)
                    .toggle(platformBrightness),
                tooltip: isDark ? 'Usar tema claro' : 'Usar tema escuro',
                icon: Icon(
                  isDark ? AppIcons.themeLight : AppIcons.themeDark,
                  size: 21,
                  color: palette.onBrand,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.companyName});

  final String companyName;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Sized to the asset's own aspect ratio. The Expo header asked for
    // 260×75 with `contain` on a 609×842 portrait image, so the logo actually
    // rendered 54px wide inside a box built for 260.
    return Image.asset(
      'assets/images/logo_wordmark.png',
      height: 34,
      fit: BoxFit.contain,
      errorBuilder: (context, _, _) => Text(
        companyName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: palette.onBrand,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// The floating WhatsApp button, on every screen.
class _WhatsAppButton extends ConsumerWidget {
  const _WhatsAppButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      onPressed: () => _open(context, ref),
      backgroundColor: const Color(0xFF25D366),
      foregroundColor: Colors.white,
      tooltip: 'Falar no WhatsApp',
      child: const Icon(AppIcons.whatsapp, size: 27),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final config = ref.read(appConfigProvider);
    final uri = Uri.https('wa.me', '/${config.whatsappNumber}', {
      'text': 'Olá! Vim pelo app de eventos da TableTop.',
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
