import 'package:flutter_test/flutter_test.dart';
import 'package:pizza_tracker/src/app_data.dart';

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
      });

      expect(analysis.storeName, 'Pizza Place');
      expect(analysis.totalAmount, 42.5);
      expect(analysis.expenseDate, DateTime(2026, 5, 10));
      expect(analysis.category, 'food');
      expect(analysis.description, 'Pizza Place dinner');
      expect(analysis.confidence, 0.82);
      expect(analysis.hasUsefulSuggestion, isTrue);
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
}
