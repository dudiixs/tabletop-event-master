import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/format/formatters.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portuguese month and weekday names, loaded before anything formats a date.
  initializeDateFormatting(Fmt.locale);

  // Read the saved theme before the first frame. This is what removes the
  // white flash the Expo app showed at every launch: its theme context started
  // in light and only then went to disk for the preference.
  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const TableTopApp(),
    ),
  );
}
