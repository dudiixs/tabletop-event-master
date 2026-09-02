import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../data/events_data_source.dart';

/// The loading screen: the logo pulsing over a spinner.
///
/// Shown while the agenda is being fetched for the first time. It appears
/// immediately — the Expo screens padded every load with 500 ms from cache and
/// 1000 ms from the network before letting the content through.
class LoadingView extends StatefulWidget {
  const LoadingView({
    super.key,
    this.message = 'Carregando eventos...',
    this.subtitle,
  });

  final String message;
  final String? subtitle;

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Respect the accessibility setting: someone who has asked the system to
    // reduce motion gets a still logo rather than a pulsing one. Read here and
    // not in initState — reading an inherited widget there is an error, and it
    // would also miss the user flipping the setting while the app is open.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!reduceMotion && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ColoredBox(
      color: palette.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 1, end: 1.1).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Image.asset(
                  'assets/images/logo_mark.png',
                  width: 108,
                  height: 108,
                  fit: BoxFit.contain,
                  errorBuilder: (context, _, _) => Icon(
                    AppIcons.brandFallback,
                    size: 88,
                    color: palette.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: palette.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      color: palette.text,
                    ),
              ),
              if (widget.subtitle case final subtitle?) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A failed fetch, with a way out of it.
///
/// This screen simply did not exist in the Expo app: the data layer caught
/// every error, returned an empty list, and the user saw "Nenhum evento
/// encontrado" — indistinguishable from a genuinely empty agenda, and with no
/// way to try again.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final failure = error is EventsFailure ? error as EventsFailure : null;
    final isOffline = failure?.isOffline ?? false;

    return ColoredBox(
      color: palette.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: context.tint(palette.error, 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOffline ? AppIcons.offline : AppIcons.failure,
                  size: 40,
                  color: palette.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isOffline ? 'Sem conexão' : 'Não deu para carregar',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                failure?.message ??
                    'Algo saiu errado ao buscar a agenda. Tente de novo.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(AppIcons.refresh, size: 18),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A genuinely empty agenda, or a day with nothing on it.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    required this.message,
    this.icon = AppIcons.calendarOutline,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData icon;

  /// A tighter version for use inside a scrolling list rather than as a screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 32,
        vertical: compact ? 36 : 64,
      ),
      child: Column(
        children: [
          Icon(icon, size: compact ? 48 : 60, color: palette.textSecondary),
          SizedBox(height: compact ? 16 : 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: compact ? 16 : 18,
                  color: palette.text,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A section heading, optionally with a trailing action.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        ?trailing,
      ],
    );
  }
}
