import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/events_providers.dart';
import 'domain/event.dart';
import 'features/events/event_details_sheet.dart';
import 'notifications/interests_controller.dart';
import 'notifications/push_controller.dart';
import 'notifications/subscription_controller.dart';

class TableTopApp extends ConsumerStatefulWidget {
  const TableTopApp({super.key});

  @override
  ConsumerState<TableTopApp> createState() => _TableTopAppState();
}

class _TableTopAppState extends ConsumerState<TableTopApp> {
  final _router = buildRouter();

  @override
  void initState() {
    super.initState();
    // Reminders live in the OS and it drops them on reboot or reinstall, and
    // an event's date can move in Notion. Once the agenda lands, re-schedule
    // whatever the user asked for and forget what no longer applies.
    ref.listenManual(agendaProvider, (previous, next) {
      if (next.hasValue) {
        ref.read(subscriptionsProvider.notifier).reconcile();
        // A push that named an event may have been waiting for exactly this:
        // a tap can launch the app from cold, long before the event it points
        // at has been fetched.
        _openPendingAnnouncement(next.value!);
      }
    });

    // Start receiving push, then line the topic subscriptions up with the
    // games the user follows. Reconciling on launch is what repairs a
    // subscription that failed offline the last time the interests changed.
    ref.read(pushRouterProvider).start();
    ref.read(pushTopicsProvider.notifier).reconcile();

    ref.listenManual(interestsProvider, (previous, next) {
      if (previous == null || !setEquals(previous, next)) {
        ref.read(pushTopicsProvider.notifier).reconcile();
      }
    });
  }

  /// Opens the event a tapped push named, if it is in the agenda.
  ///
  /// Cleared either way. An event can be announced and then pulled from the
  /// agenda before the tap arrives, and leaving it parked would reopen this
  /// attempt on every later refresh.
  void _openPendingAnnouncement(List<Event> agenda) {
    final announcement = ref.read(pendingAnnouncementProvider);
    if (announcement == null) return;
    ref.read(pendingAnnouncementProvider.notifier).state = null;

    final event =
        agenda.where((item) => item.id == announcement.eventId).firstOrNull;
    if (event == null) return;

    final context = _router.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    EventDetailsSheet.show(context, event);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'TableTop Events',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Resolved from the preference loaded before the first frame, so there
      // is no flash of the wrong theme at launch, and ThemeMode.system means
      // the app follows the device by default.
      themeMode: themeMode,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
