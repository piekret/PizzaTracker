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
    expect(
      find.text('./scripts/sync_client_env.sh && flutter run'),
      findsOneWidget,
    );
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
                receiptId: 'receipt-id',
              ),
            ];
          }),
          expenseHistoryProvider.overrideWith((ref) async {
            return [
              ExpenseItem(
                id: 'expense-id',
                name: 'Test pizza',
                amount: 19.99,
                category: 'food',
                expenseDate: DateTime(2026, 5, 9),
                receiptId: 'receipt-id',
              ),
              ExpenseItem(
                id: 'expense-soap',
                name: 'Soap',
                amount: 7.5,
                category: 'hygiene',
                expenseDate: DateTime(2026, 5, 8),
              ),
            ];
          }),
          categorySpendingProvider.overrideWith((ref) async {
            return const [
              CategorySpending(category: 'food', amount: 45, itemCount: 2),
              CategorySpending(category: 'hygiene', amount: 15, itemCount: 1),
            ];
          }),
          fixedExpensesProvider.overrideWith((ref) async {
            return const [
              FixedExpense(
                id: 'fixed-id',
                name: 'Rent',
                amount: 500,
                billingDay: 1,
                isActive: true,
              ),
            ];
          }),
          incomeEventsProvider.overrideWith((ref) async {
            return const [
              IncomeEvent(
                id: 'income-id',
                name: 'Scholarship',
                amount: 900,
                expectedDay: 5,
                isRecurring: true,
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

    expect(find.text('Add receipt'), findsOneWidget);
    expect(find.text('DESPERATION INDEX'), findsOneWidget);
    expect(find.text('Monthly budget locked in'), findsOneWidget);
    expect(find.text('Fixed monthly costs'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Expected income'),
      500,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Expected income'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Spending mix'),
      500,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Spending mix'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('75% of variable spending - 2 items'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Test pizza'),
      500,
      scrollable: find.byType(Scrollable),
    );

    expect(find.byTooltip('Expense actions'), findsOneWidget);
    expect(find.byTooltip('Receipt attached'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('View all'),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();

    expect(find.text('Expense history'), findsOneWidget);
    expect(find.text('Search expenses'), findsOneWidget);
    expect(find.text('2 expenses'), findsOneWidget);
    expect(find.text('Soap'), findsOneWidget);
  });
}
