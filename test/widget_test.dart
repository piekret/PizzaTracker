import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pizza_tracker/src/app_config.dart';
import 'package:pizza_tracker/src/app_data.dart';
import 'package:pizza_tracker/src/app_language.dart';
import 'package:pizza_tracker/src/app_theme.dart';
import 'package:pizza_tracker/src/pizza_tracker_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    Intl.defaultLocale = 'en';
    SharedPreferences.setMockInitialValues({});
  });

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
      find.text(
        'macOS/Linux: ./scripts/sync_client_env.sh && flutter run\n'
        'Windows: powershell -ExecutionPolicy Bypass -File .\\scripts\\sync_client_env.ps1; flutter run',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows Polish setup screen when language is Polish', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(null),
          initialAppLanguageProvider.overrideWithValue(AppLanguage.polish),
        ],
        child: const PizzaTrackerApp(),
      ),
    );

    expect(find.text('Konfiguracja PizzaTracker'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });

  testWidgets('switches setup screen language from menu', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(null)],
        child: const PizzaTrackerApp(),
      ),
    );

    expect(find.text('PizzaTracker setup'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polski'));
    await tester.pumpAndSettle();

    expect(find.text('Konfiguracja PizzaTracker'), findsOneWidget);

    await tester.tap(find.text('PL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('PizzaTracker setup'), findsOneWidget);
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
              onboardingCompleted: true,
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
    expect(find.textContaining('DESPERATION INDEX'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Monthly budget locked in'),
      500,
      scrollable: find.byType(Scrollable),
    );

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
    expect(find.byTooltip('Open receipt'), findsOneWidget);

    final viewAllFinder = find.widgetWithText(TextButton, 'View all');
    await tester.scrollUntilVisible(
      viewAllFinder,
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(viewAllFinder, findsOneWidget);
  });

  testWidgets('dashboard guides new users with no expenses', (tester) async {
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
              onboardingCompleted: true,
            );
          }),
          budgetSnapshotProvider.overrideWith((ref) async {
            return const BudgetSnapshot(
              monthlyBudget: 1200,
              fixedMonthlyExpenses: 0,
              disposableBudget: 1200,
              spentThisPeriod: 0,
              remainingBudget: 1200,
              daysLeft: 20,
              dailyLimit: 60,
              desperationIndex: 0,
            );
          }),
          recentExpensesProvider.overrideWith((ref) async => const []),
          expenseHistoryProvider.overrideWith((ref) async => const []),
          categorySpendingProvider.overrideWith((ref) async => const []),
          fixedExpensesProvider.overrideWith((ref) async => const []),
          incomeEventsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: buildAppTheme(AppThemePreset.pizza),
          home: const DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Budget ready. Add your first expense.'), findsOneWidget);
    expect(find.text('Scan first receipt'), findsOneWidget);
    expect(find.text('Add fixed cost'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard does not overflow at very narrow Polish width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(260, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAppLanguageProvider.overrideWithValue(AppLanguage.polish),
          userProfileProvider.overrideWith((ref) async {
            return const UserProfile(
              id: 'user-id',
              displayName: 'Tester',
              monthlyBudget: 1200,
              budgetResetDay: 1,
              currency: 'USD',
              timezone: 'Europe/Warsaw',
              onboardingCompleted: true,
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
              desperationIndex: 64,
            );
          }),
          recentExpensesProvider.overrideWith((ref) async {
            return [
              ExpenseItem(
                id: 'expense-id',
                name: 'Very long narrow screen pizza and groceries entry',
                amount: 119.99,
                category: 'food',
                expenseDate: DateTime(2026, 5, 9),
                receiptId: 'receipt-id',
              ),
            ];
          }),
          expenseHistoryProvider.overrideWith((ref) async => const []),
          categorySpendingProvider.overrideWith((ref) async {
            return const [
              CategorySpending(category: 'food', amount: 145, itemCount: 2),
              CategorySpending(category: 'hygiene', amount: 15, itemCount: 1),
            ];
          }),
          fixedExpensesProvider.overrideWith((ref) async {
            return const [
              FixedExpense(
                id: 'fixed-id',
                name: 'Very long rent and internet bundle',
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
                name: 'Long scholarship transfer name',
                amount: 900,
                expectedDay: 5,
                isRecurring: true,
              ),
            ];
          }),
        ],
        child: MaterialApp(
          locale: const Locale('pl'),
          supportedLocales: AppLanguage.values.map(
            (language) => language.locale,
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: buildAppTheme(AppThemePreset.pizza),
          home: const DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders onboarding setup for missing budget', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(AppThemePreset.pizza),
          home: const OnboardingSetupScreen(
            profile: UserProfile(
              id: 'user-id',
              displayName: 'Tester',
              monthlyBudget: 0,
              budgetResetDay: 1,
              currency: 'USD',
              timezone: 'Europe/Warsaw',
              onboardingCompleted: false,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Set the basics in one minute'), findsOneWidget);
    expect(find.text('Your monthly budget'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Add your biggest fixed cost'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Add your biggest fixed cost'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Add regular income'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Add regular income'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding requires a positive monthly budget', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(AppThemePreset.pizza),
          home: const OnboardingSetupScreen(
            profile: UserProfile(
              id: 'user-id',
              displayName: 'Tester',
              monthlyBudget: 0,
              budgetResetDay: 1,
              currency: 'USD',
              timezone: 'Europe/Warsaw',
              onboardingCompleted: false,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save and open dashboard'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save and open dashboard'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Enter a budget above 0.'),
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Enter a budget above 0.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prefills expense sheet from receipt analysis', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(AppThemePreset.pizza),
          home: Scaffold(
            body: AddExpenseSheet(
              receipt: ReceiptUpload(
                id: 'receipt-id',
                totalAmount: 42.5,
                scannedAt: DateTime(2026, 5, 10),
                imagePath: 'user-id/receipt-id/image.jpg',
              ),
              receiptAnalysis: ReceiptAnalysis(
                storeName: 'Pizza Place',
                totalAmount: 42.5,
                expenseDate: DateTime(2026, 5, 10),
                category: 'food',
                description: 'Pizza Place dinner',
                confidence: 0.82,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final nameField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(0),
    );
    final amountField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );

    expect(nameField.controller?.text, 'Pizza Place dinner');
    expect(amountField.controller?.text, '42.50');
    expect(find.text('Receipt analysis suggestions'), findsOneWidget);
    expect(find.text('82% CONFIDENCE'), findsOneWidget);
    expect(find.textContaining('Pizza Place'), findsWidgets);
  });

  testWidgets('shows receipt line item review from analysis', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
              onboardingCompleted: true,
            );
          }),
        ],
        child: MaterialApp(
          theme: buildAppTheme(AppThemePreset.pizza),
          home: Scaffold(
            body: ReceiptReviewSheet(
              receipt: ReceiptUpload(
                id: 'receipt-id',
                totalAmount: 42.5,
                scannedAt: DateTime(2026, 5, 10),
                imagePath: 'user-id/receipt-id/image.jpg',
              ),
              analysis: ReceiptAnalysis(
                storeName: 'Pizza Place',
                totalAmount: 42.5,
                expenseDate: DateTime(2026, 5, 10),
                category: 'food',
                description: 'Pizza Place dinner',
                confidence: 0.82,
                items: const [
                  ReceiptAnalysisItem(
                    name: 'Margherita',
                    amount: 32.5,
                    category: 'food',
                  ),
                  ReceiptAnalysisItem(
                    name: 'Cola',
                    amount: 10,
                    category: 'other',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('RECEIPT REVIEW'), findsWidgets);
    expect(find.text('Pizza Place'), findsOneWidget);
    expect(find.text('Save 2 expenses'), findsOneWidget);
    expect(find.text('Receipt total: \$42.50'), findsOneWidget);

    final firstNameField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(0),
    );
    final firstAmountField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );

    expect(firstNameField.controller?.text, 'Margherita');
    expect(firstAmountField.controller?.text, '32.50');
  });
}
