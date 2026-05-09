import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pizza_tracker/src/app_config.dart';
import 'package:pizza_tracker/src/app_data.dart';
import 'package:pizza_tracker/src/app_theme.dart';
import 'package:pizza_tracker/src/pizza_tracker_app.dart';

void main() {
  testWidgets('shows setup screen when Supabase config is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(null)],
        child: const PizzaTrackerApp(),
      ),
    );

    expect(find.text('PizzaTracker setup'), findsOneWidget);
    expect(find.text('flutter run'), findsOneWidget);
  });

  testWidgets('renders dashboard with budget card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) async {
            return const UserProfile(
              id: 'user-id',
              displayName: 'Tester',
              monthlyBudget: 1200,
              budgetResetDay: 1,
              currency: 'USD',
              timezone: 'Europe/Warsaw',
            );
          }),
          budgetSnapshotProvider.overrideWith((ref) async {
            return const BudgetSnapshot(
              monthlyBudget: 1200,
              fixedMonthlyExpenses: 300,
              disposableBudget: 900,
              spentThisPeriod: 180,
              remainingBudget: 720,
              daysLeft: 18,
              dailyLimit: 40,
              desperationIndex: 24,
            );
          }),
          recentExpensesProvider.overrideWith((ref) async {
            return [
              ExpenseItem(
                id: 'expense-id',
                name: 'Test pizza',
                amount: 19.99,
                category: 'food',
                expenseDate: DateTime(2026, 5, 9),
              ),
            ];
          }),
        ],
        child: MaterialApp(
          theme: buildAppTheme(AppThemePreset.pizza),
          home: const DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Monthly budget locked in'), findsOneWidget);
    expect(find.text('DESPERATION INDEX'), findsOneWidget);
  });
}
