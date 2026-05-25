import 'package:flutter_test/flutter_test.dart';
import 'package:pizza_tracker/src/app_data.dart';
import 'package:pizza_tracker/src/app_language.dart';

void main() {
  group('ReceiptAnalysis', () {
    test('parses app-ready suggestions from function response', () {
      final analysis = ReceiptAnalysis.fromMap({
        'storeName': 'Pizza Place',
        'totalAmount': 42.5,
        'expenseDate': '2026-05-10',
        'category': 'food',
        'description': 'Pizza Place dinner',
        'confidence': 0.82,
        'items': [
          {'name': 'Margherita', 'amount': 32.5, 'category': 'food'},
          {'name': 'Cola', 'amount': 10, 'category': 'other'},
        ],
      });

      expect(analysis.storeName, 'Pizza Place');
      expect(analysis.totalAmount, 42.5);
      expect(analysis.expenseDate, DateTime(2026, 5, 10));
      expect(analysis.category, 'food');
      expect(analysis.description, 'Pizza Place dinner');
      expect(analysis.confidence, 0.82);
      expect(analysis.items, hasLength(2));
      expect(analysis.items.first.name, 'Margherita');
      expect(analysis.items.first.amount, 32.5);
      expect(analysis.items.first.category, 'food');
      expect(analysis.hasUsefulSuggestion, isTrue);
    });

    test('sanitizes invalid receipt line items', () {
      final analysis = ReceiptAnalysis.fromMap({
        'items': [
          {'name': 'Soap', 'amount': 7.5, 'category': 'hygiene'},
          {'name': '', 'amount': 2, 'category': 'food'},
          {'name': 'Coupon', 'amount': -1, 'category': 'discount'},
          {'name': 'Mystery', 'amount': 1.25, 'category': 'transport'},
        ],
      });

      expect(analysis.items, hasLength(2));
      expect(analysis.items.first.category, 'hygiene');
      expect(analysis.items.last.name, 'Mystery');
      expect(analysis.items.last.category, 'other');
    });

    test('ignores invalid categories and blank text', () {
      final analysis = ReceiptAnalysis.fromMap({
        'store_name': '  ',
        'total_amount': null,
        'expense_date': 'not-a-date',
        'category': 'transport',
        'description': '',
        'confidence': 2,
      });

      expect(analysis.storeName, isNull);
      expect(analysis.totalAmount, isNull);
      expect(analysis.expenseDate, isNull);
      expect(analysis.category, isNull);
      expect(analysis.description, isNull);
      expect(analysis.confidence, 1);
      expect(analysis.hasUsefulSuggestion, isFalse);
    });
  });

  group('ReceiptUpload', () {
    test('parses persisted analysis metadata', () {
      final receipt = ReceiptUpload.fromMap({
        'id': 'receipt-id',
        'store_name': 'Pizza Place',
        'total_amount': 42.5,
        'raw_ocr_text': 'Pizza Place total 42.50',
        'analysis_json': {
          'storeName': 'Pizza Place',
          'totalAmount': 42.5,
          'expenseDate': '2026-05-10',
          'category': 'food',
          'description': 'Pizza Place dinner',
          'confidence': 0.82,
          'items': [
            {'name': 'Slice', 'amount': 12, 'category': 'food'},
          ],
        },
        'image_path': 'user-id/receipt-id/image.jpg',
        'scanned_at': '2026-05-10T12:00:00Z',
      });

      expect(receipt.rawOcrText, 'Pizza Place total 42.50');
      expect(receipt.analysis?.description, 'Pizza Place dinner');
      expect(receipt.analysis?.category, 'food');
      expect(receipt.analysis?.items.single.name, 'Slice');
      expect(receipt.analysis?.hasUsefulSuggestion, isTrue);
    });
  });

  group('UserProfile', () {
    test('defaults missing onboarding flag to false', () {
      final profile = UserProfile.fromMap({
        'id': 'user-id',
        'display_name': 'Tester',
        'monthly_budget': 0,
        'budget_reset_day': 1,
        'currency': 'USD',
        'timezone': 'Europe/Warsaw',
      });

      expect(profile.onboardingCompleted, isFalse);
    });

    test('parses completed onboarding flag', () {
      final profile = UserProfile.fromMap({
        'id': 'user-id',
        'display_name': 'tester@example.com',
        'monthly_budget': 1200,
        'budget_reset_day': 1,
        'currency': 'USD',
        'timezone': 'Europe/Warsaw',
        'onboarding_completed': true,
      });

      expect(profile.displayName, 'tester@example.com');
      expect(profile.onboardingCompleted, isTrue);
    });
  });

  group('calculateDesperationIndex', () {
    test('stays zero before any spending', () {
      final index = calculateDesperationIndex(
        disposableBudget: 1000,
        spentThisPeriod: 0,
        remainingBudget: 1000,
        dailyLimit: 50,
        idealDaily: 33.33,
        daysLeft: 20,
      );

      expect(index, 0);
    });

    test('reflects used budget even when spending is not over schedule', () {
      final index = calculateDesperationIndex(
        disposableBudget: 1000,
        spentThisPeriod: 500,
        remainingBudget: 500,
        dailyLimit: 33.33,
        idealDaily: 33.33,
        daysLeft: 15,
      );

      expect(index, 23);
    });

    test('rises when spending is ahead of schedule', () {
      final index = calculateDesperationIndex(
        disposableBudget: 1000,
        spentThisPeriod: 800,
        remainingBudget: 200,
        dailyLimit: 13.33,
        idealDaily: 33.33,
        daysLeft: 15,
      );

      expect(index, greaterThan(50));
    });
  });

  group('offline cache models', () {
    test('BudgetSnapshot round-trips through cache map', () {
      const snapshot = BudgetSnapshot(
        monthlyBudget: 1200,
        fixedMonthlyExpenses: 300,
        disposableBudget: 900,
        spentThisPeriod: 180,
        remainingBudget: 720,
        daysLeft: 18,
        dailyLimit: 40,
        desperationIndex: 24,
      );

      final restored = BudgetSnapshot.fromMap(snapshot.toMap());

      expect(restored.monthlyBudget, snapshot.monthlyBudget);
      expect(restored.remainingBudget, snapshot.remainingBudget);
      expect(restored.desperationIndex, snapshot.desperationIndex);
    });

    test('CategorySpending round-trips through cache map', () {
      const spending = CategorySpending(
        category: 'food',
        amount: 42.5,
        itemCount: 3,
      );

      final restored = CategorySpending.fromMap(spending.toMap());

      expect(restored.category, 'food');
      expect(restored.amount, 42.5);
      expect(restored.itemCount, 3);
    });
  });

  group('AI request cache keys', () {
    test('recipe requests include language', () {
      const english = RecipeRequest(
        ingredients: ['pasta', 'eggs'],
        desperationIndex: 70,
        languageCode: 'en',
      );
      const polish = RecipeRequest(
        ingredients: ['pasta', 'eggs'],
        desperationIndex: 70,
        languageCode: 'pl',
      );

      expect(english, isNot(polish));
    });

    test('insight requests include language', () {
      const english = InsightsRequest(month: '2026-05', languageCode: 'en');
      const polish = InsightsRequest(month: '2026-05', languageCode: 'pl');

      expect(english, isNot(polish));
    });
  });

  group('AppText', () {
    test('English error translation strips technical state prefixes', () {
      const text = AppText(AppLanguage.english);

      expect(
        text.translateKnown('Bad state: You need to sign in first.'),
        'You need to sign in first.',
      );
    });

    test(
      'Polish error translation strips and translates known state prefixes',
      () {
        const text = AppText(AppLanguage.polish);

        expect(
          text.translateKnown('Bad state: You need to sign in first.'),
          'Najpierw musisz się zalogować.',
        );
      },
    );

    test('English error translation explains offline write failures', () {
      const text = AppText(AppLanguage.english);

      expect(
        text.translateKnown(
          'ClientException with SocketException: Failed host lookup',
        ),
        contains('offline mode'),
      );
      expect(
        text.translateKnown('Exception: Failed to fetch'),
        contains('changes cannot be saved'),
      );
    });

    test('Polish error translation explains offline write failures', () {
      const text = AppText(AppLanguage.polish);

      expect(
        text.translateKnown(
          'ClientException with SocketException: Failed host lookup',
        ),
        contains('Jesteś w trybie offline'),
      );
      expect(
        text.translateKnown('Exception: Failed to fetch'),
        contains('zmian nie da się teraz zapisać'),
      );
    });
  });

  group('supportedCurrencies', () {
    test('contains only selectable app currencies', () {
      expect(supportedCurrencies, containsAll(['PLN', 'USD', 'EUR']));
      expect(supportedCurrencies, isNot(contains('DOGE')));
    });
  });
}
