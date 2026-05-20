import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app_config.dart';
import 'src/app_language.dart';
import 'src/pizza_tracker_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await AppConfig.load();
  final initialLanguage = await loadInitialAppLanguage();
  if (config != null) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        initialAppLanguageProvider.overrideWithValue(initialLanguage),
      ],
      child: const PizzaTrackerApp(),
    ),
  );
}
