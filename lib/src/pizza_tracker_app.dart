import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_chrome.dart';
import 'app_config.dart';
import 'app_data.dart';
import 'app_theme.dart';

part 'auth/auth_gate.dart';
part 'auth/auth_screen.dart';
part 'dashboard/category_spending_card.dart';
part 'dashboard/dashboard_screen.dart';
part 'dashboard/desperation_card.dart';
part 'dashboard/edit_budget_sheet.dart';
part 'dashboard/planning_cards.dart';
part 'dashboard/stats_screen.dart';
part 'recipes/recipes_screen.dart';
part 'expenses/expense_history_screen.dart';
part 'expenses/expense_sheet.dart';
part 'expenses/recent_expenses_card.dart';
part 'expenses/receipt_preview_sheet.dart';
part 'expenses/receipt_review_sheet.dart';
part 'expenses/receipt_upload_flow.dart';
part 'planning/planning_sheets.dart';
part 'shared/setup_screen.dart';
part 'shared/status_widgets.dart';
part 'shared/ui_helpers.dart';

class PizzaTrackerApp extends ConsumerWidget {
  const PizzaTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreset = ref.watch(appThemePresetProvider);

    return MaterialApp(
      title: 'PizzaTracker',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(themePreset),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    if (config == null) {
      return const SetupScreen();
    }
    return const AuthGate();
  }
}
