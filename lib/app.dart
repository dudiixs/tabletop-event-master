import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/events_providers.dart';
import 'notifications/reminder_controller.dart';

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
        ref.read(remindersProvider.notifier).reconcile();
      }
    });
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
