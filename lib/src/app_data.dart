import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authUserProvider = StreamProvider<User?>((ref) async* {
  final auth = ref.watch(supabaseClientProvider).auth;
  yield auth.currentUser;

  await for (final state in auth.onAuthStateChange) {
    yield state.session?.user;
  }
});

final appRepositoryProvider = Provider<AppRepository>((ref) {
  ref.watch(authUserProvider.select((user) => user.asData?.value?.id));
  return AppRepository(ref.watch(supabaseClientProvider));
});

final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  return ref.watch(appRepositoryProvider).getProfile();
});

final budgetSnapshotProvider = FutureProvider<BudgetSnapshot?>((ref) async {
  return ref.watch(appRepositoryProvider).getBudgetSnapshot();
});

final recentExpensesProvider = FutureProvider<List<ExpenseItem>>((ref) async {
  return ref.watch(appRepositoryProvider).getRecentExpenses();
});

final expenseHistoryProvider = FutureProvider<List<ExpenseItem>>((ref) async {
  return ref.watch(appRepositoryProvider).getExpenseHistory();
});

final monthlySummaryProvider = FutureProvider<MonthlySummary?>((ref) async {
  return ref.watch(appRepositoryProvider).getMonthlySummary();
});

final receiptUploadProvider = FutureProvider.family<ReceiptUpload, String>((
  ref,
  receiptId,
) async {
  return ref.watch(appRepositoryProvider).getReceiptUpload(receiptId);
});

final receiptImageUrlProvider = FutureProvider.family<String, String>((
  ref,
  imagePath,
) async {
  return ref.watch(appRepositoryProvider).createReceiptImageUrl(imagePath);
});

final categorySpendingProvider = FutureProvider<List<CategorySpending>>((
  ref,
) async {
  final profile = await ref.watch(userProfileProvider.future);
  return ref.watch(appRepositoryProvider).getCategorySpending(profile: profile);
});

final fixedExpensesProvider = FutureProvider<List<FixedExpense>>((ref) async {
  return ref.watch(appRepositoryProvider).getFixedExpenses();
});

final incomeEventsProvider = FutureProvider<List<IncomeEvent>>((ref) async {
  return ref.watch(appRepositoryProvider).getIncomeEvents();
});

final recipeGeneratorProvider =
    FutureProvider.family<List<RecipeSuggestion>, RecipeRequest>((
      ref,
      request,
    ) async {
      return ref
          .watch(appRepositoryProvider)
          .generateRecipes(
            ingredients: request.ingredients,
            desperationIndex: request.desperationIndex,
            languageCode: request.languageCode,
          );
    });

final insightsProvider =
    FutureProvider.family<InsightsResponse, InsightsRequest>((
      ref,
      request,
    ) async {
      return ref
          .watch(appRepositoryProvider)
          .generateInsights(
            month: request.month,
            languageCode: request.languageCode,
          );
    });

final insightsRefreshProvider =
    FutureProvider.family<InsightsResponse, InsightsRequest>((
      ref,
      request,
    ) async {
      return ref
          .watch(appRepositoryProvider)
          .refreshInsights(
            month: request.month,
            languageCode: request.languageCode,
          );
    });

const expenseCategories = ['food', 'alcohol', 'hygiene', 'fun', 'other'];
const supportedCurrencies = ['PLN', 'USD', 'EUR', 'GBP', 'CHF', 'CZK'];
const receiptImagesBucket = 'receipt-images';
const _receiptSelectColumns =
    'id, store_name, total_amount, currency, original_total_amount, '
    'exchange_rate_to_profile, raw_ocr_text, analysis_json, image_path, '
    'scanned_at';
const _legacyReceiptSelectColumns =
    'id, store_name, total_amount, raw_ocr_text, analysis_json, image_path, '
    'scanned_at';
const _expenseSelectColumns =
    'id, receipt_id, name, amount, currency, original_amount, '
    'original_currency, exchange_rate_to_profile, category, expense_date, '
    'created_at';
const _legacyExpenseSelectColumns =
    'id, receipt_id, name, amount, category, expense_date, created_at';
const _offlineCachePrefix = 'offline_cache_v1';
// Offline fallback rates relative to PLN; users can correct the receipt currency before saving.
const _currencyValueInPln = <String, double>{
  'PLN': 1,
  'USD': 3.95,
  'EUR': 4.3,
  'GBP': 5.05,
  'CHF': 4.6,
  'CZK': 0.17,
};

int calculateDesperationIndex({
  required double disposableBudget,
  required double spentThisPeriod,
  required double remainingBudget,
  required double dailyLimit,
  required double idealDaily,
  required int daysLeft,
}) {
  if (disposableBudget <= 0) {
    return remainingBudget < 0 ? 100 : 0;
  }

  final spentPressure = (spentThisPeriod / disposableBudget).clamp(0.0, 1.0);
  final dailyPressure = idealDaily > 0
      ? ((idealDaily - dailyLimit) / idealDaily).clamp(0.0, 1.0)
      : 0.0;
  final expectedRemaining = idealDaily * daysLeft.clamp(1, 1000);
  final schedulePressure =
      ((expectedRemaining - remainingBudget) / disposableBudget).clamp(
        0.0,
        1.0,
      );
  final overBudgetPressure = remainingBudget < 0
      ? ((-remainingBudget) / disposableBudget).clamp(0.0, 1.0)
      : 0.0;

  return ((spentPressure * 45) +
          (schedulePressure * 35) +
          (dailyPressure * 20) +
          (overBudgetPressure * 70))
      .round()
      .clamp(0, 100);
}

class AppRepository {
  AppRepository(this._client);

  final SupabaseClient _client;

  Future<void> ensureProfile() async {
    final user = _requireUser();
    await _client
        .from('users_profiles')
        .upsert(
          {
            'id': user.id,
            'display_name': user.email,
            'monthly_budget': 0,
            'budget_reset_day': 1,
            'currency': 'USD',
            'timezone': 'Europe/Warsaw',
            'onboarding_completed': false,
          },
          onConflict: 'id',
          ignoreDuplicates: true,
        );
  }

  Future<UserProfile> getProfile() async {
    final user = _requireUser();
    final cacheKey = _cacheKey(user.id, 'profile');
    try {
      await ensureProfile();

      final row = await _client
          .from('users_profiles')
          .select(
            'id, display_name, monthly_budget, budget_reset_day, currency, timezone, onboarding_completed',
          )
          .eq('id', user.id)
          .single();
      final map = {
        ...Map<String, dynamic>.from(row),
        'display_name': user.email ?? row['display_name'],
      };
      await _writeCache(cacheKey, map);
      return UserProfile.fromMap(map);
    } catch (_) {
      final cached = await _readCachedMap(cacheKey);
      if (cached != null) {
        return UserProfile.fromMap({
          ...cached,
          'display_name': user.email ?? cached['display_name'],
        });
      }
      rethrow;
    }
  }

  Future<void> updateBudget({
    required double monthlyBudget,
    required int budgetResetDay,
    required String currency,
    bool onboardingCompleted = false,
  }) async {
    final user = _requireUser();
    final normalizedCurrency = currency.trim().toUpperCase();
    if (!supportedCurrencies.contains(normalizedCurrency)) {
      throw StateError('Unsupported currency. Choose one from the list.');
    }
    await ensureProfile();

    await _client
        .from('users_profiles')
        .update({
          'monthly_budget': monthlyBudget,
          'budget_reset_day': budgetResetDay,
          'currency': normalizedCurrency,
          if (onboardingCompleted) 'onboarding_completed': true,
        })
        .eq('id', user.id);
  }

  Future<BudgetSnapshot?> getBudgetSnapshot({DateTime? onDate}) async {
    final user = _requireUser();
    final cacheKey = _cacheKey(user.id, 'budget_snapshot');
    try {
      final profile = await getProfile();
      final date = onDate ?? DateTime.now();
      final today = DateTime(date.year, date.month, date.day);
      final period = _budgetPeriodFor(today, profile.budgetResetDay);
      final dateFormat = DateFormat('yyyy-MM-dd');

      final fixedRows = await _client
          .from('fixed_expenses')
          .select('amount')
          .eq('user_id', user.id)
          .eq('is_active', true);
      final fixedMonthlyExpenses = fixedRows.fold<double>(0, (sum, row) {
        return sum + _toDouble(Map<String, dynamic>.from(row)['amount']);
      });

      final expenseRows = await _client
          .from('expense_items')
          .select('amount')
          .eq('user_id', user.id)
          .gte('expense_date', dateFormat.format(period.start))
          .lte('expense_date', dateFormat.format(period.end));
      final spentThisPeriod = expenseRows.fold<double>(0, (sum, row) {
        return sum + _toDouble(Map<String, dynamic>.from(row)['amount']);
      });

      final disposableBudget = (profile.monthlyBudget - fixedMonthlyExpenses)
          .clamp(0, double.infinity)
          .toDouble();
      final remainingBudget = disposableBudget - spentThisPeriod;
      final daysLeft = (period.end.difference(today).inDays + 1).clamp(0, 1000);
      final totalDays = period.end.difference(period.start).inDays + 1;
      final dailyLimit = remainingBudget / daysLeft.clamp(1, 1000);
      final idealDaily = disposableBudget / totalDays.clamp(1, 1000);
      final snapshot = BudgetSnapshot(
        monthlyBudget: profile.monthlyBudget,
        fixedMonthlyExpenses: fixedMonthlyExpenses,
        disposableBudget: disposableBudget,
        spentThisPeriod: spentThisPeriod,
        remainingBudget: remainingBudget,
        daysLeft: daysLeft,
        dailyLimit: dailyLimit,
        desperationIndex: calculateDesperationIndex(
          disposableBudget: disposableBudget,
          spentThisPeriod: spentThisPeriod,
          remainingBudget: remainingBudget,
          dailyLimit: dailyLimit,
          idealDaily: idealDaily,
          daysLeft: daysLeft,
        ),
      );
      await _writeCache(cacheKey, snapshot.toMap());
      return snapshot;
    } catch (_) {
      final cached = await _readCachedMap(cacheKey);
      if (cached != null) {
        return BudgetSnapshot.fromMap(cached);
      }
      rethrow;
    }
  }

  Future<List<ExpenseItem>> getRecentExpenses() async {
    final user = _requireUser();
    final cacheKey = _cacheKey(user.id, 'recent_expenses');

    try {
      final rows = await _selectExpenseRows(
        userId: user.id,
        limit: 12,
      );
      final maps = rows.map((row) => Map<String, dynamic>.from(row)).toList();
      await _writeCache(cacheKey, maps);
      return maps.map(ExpenseItem.fromMap).toList();
    } catch (_) {
      final cached = await _readCachedList(cacheKey);
      if (cached != null) {
        return cached.map(ExpenseItem.fromMap).toList();
      }
      rethrow;
    }
  }

  Future<List<ExpenseItem>> getExpenseHistory() async {
    final user = _requireUser();
    final cacheKey = _cacheKey(user.id, 'expense_history');

    try {
      final rows = await _selectExpenseRows(userId: user.id);
      final maps = rows.map((row) => Map<String, dynamic>.from(row)).toList();
      await _writeCache(cacheKey, maps);
      return maps.map(ExpenseItem.fromMap).toList();
    } catch (_) {
      final cached = await _readCachedList(cacheKey);
      if (cached != null) {
        return cached.map(ExpenseItem.fromMap).toList();
      }
      rethrow;
    }
  }

  Future<MonthlySummary?> getMonthlySummary() async {
    final user = _requireUser();
    final cacheKey = _cacheKey(user.id, 'monthly_summary');

    try {
      final data = await _client
          .from('v_monthly_summary')
          .select(
            'month, total_spent, food_spent, alcohol_spent, hygiene_spent, fun_spent, other_spent, receipt_count',
          )
          .eq('user_id', user.id)
          .order('month', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) {
        await _writeCache(cacheKey, null);
        return null;
      }

      final map = Map<String, dynamic>.from(data);
      await _writeCache(cacheKey, map);
      return MonthlySummary.fromMap(map);
    } catch (_) {
      final cached = await _readCachedMap(cacheKey);
      if (cached != null) {
        return MonthlySummary.fromMap(cached);
      }
      rethrow;
    }
  }

  Future<List<CategorySpending>> getCategorySpending({
    required UserProfile profile,
    DateTime? onDate,
  }) async {
    final user = _requireUser();
    final cacheKey = _cacheKey(user.id, 'category_spending');
    final period = _budgetPeriodFor(
      onDate ?? DateTime.now(),
      profile.budgetResetDay,
    );
    final dateFormat = DateFormat('yyyy-MM-dd');
    final amountByCategory = <String, double>{};
    final countByCategory = <String, int>{};

    try {
      final rows = await _client
          .from('expense_items')
          .select('category, amount')
          .eq('user_id', user.id)
          .gte('expense_date', dateFormat.format(period.start))
          .lte('expense_date', dateFormat.format(period.end));

      for (final row in rows) {
        final map = Map<String, dynamic>.from(row);
        final rawCategory = (map['category'] as String?) ?? 'other';
        final category = expenseCategories.contains(rawCategory)
            ? rawCategory
            : 'other';

        amountByCategory[category] =
            (amountByCategory[category] ?? 0) + _toDouble(map['amount']);
        countByCategory[category] = (countByCategory[category] ?? 0) + 1;
      }

      final spending = amountByCategory.entries
          .where((entry) => entry.value > 0)
          .map(
            (entry) => CategorySpending(
              category: entry.key,
              amount: entry.value,
              itemCount: countByCategory[entry.key] ?? 0,
            ),
          )
          .toList();

      spending.sort((a, b) {
        final amountComparison = b.amount.compareTo(a.amount);
        if (amountComparison != 0) {
          return amountComparison;
        }
        return expenseCategories
            .indexOf(a.category)
            .compareTo(expenseCategories.indexOf(b.category));
      });
      await _writeCache(
        cacheKey,
        spending.map((item) => item.toMap()).toList(),
      );
      return spending;
    } catch (_) {
      final cached = await _readCachedList(cacheKey);
      if (cached != null) {
        return cached.map(CategorySpending.fromMap).toList();
      }
      rethrow;
    }
  }

  Future<List<FixedExpense>> getFixedExpenses() async {
    final user = _requireUser();
    final cacheKey = _cacheKey(user.id, 'fixed_expenses');

    try {
      final rows = await _client
          .from('fixed_expenses')
          .select('id, name, amount, billing_day, is_active')
          .eq('user_id', user.id)
          .order('billing_day')
          .order('name');
      final maps = rows.map((row) => Map<String, dynamic>.from(row)).toList();
      await _writeCache(cacheKey, maps);
      return maps.map(FixedExpense.fromMap).toList();
    } catch (_) {
      final cached = await _readCachedList(cacheKey);
      if (cached != null) {
        return cached.map(FixedExpense.fromMap).toList();
      }
      rethrow;
    }
  }

  Future<List<IncomeEvent>> getIncomeEvents() async {
    final user = _requireUser();
    final cacheKey = _cacheKey(user.id, 'income_events');

    try {
      final rows = await _client
          .from('income_events')
          .select('id, name, amount, expected_day, is_recurring')
          .eq('user_id', user.id)
          .order('expected_day')
          .order('name');
      final maps = rows.map((row) => Map<String, dynamic>.from(row)).toList();
      await _writeCache(cacheKey, maps);
      return maps.map(IncomeEvent.fromMap).toList();
    } catch (_) {
      final cached = await _readCachedList(cacheKey);
      if (cached != null) {
        return cached.map(IncomeEvent.fromMap).toList();
      }
      rethrow;
    }
  }

  Future<void> addManualExpense({
    required String name,
    required double amount,
    required String category,
    required DateTime expenseDate,
    String? originalCurrency,
    String? receiptId,
  }) async {
    final user = _requireUser();
    final profile = await getProfile();
    final conversion = CurrencyConversion.fromOriginal(
      originalAmount: amount,
      originalCurrency: originalCurrency ?? profile.currency,
      profileCurrency: profile.currency,
    );
    final values = <String, Object?>{
      'user_id': user.id,
      'name': name.trim(),
      'amount': conversion.convertedAmount,
      'currency': conversion.profileCurrency,
      'original_amount': conversion.originalAmount,
      'original_currency': conversion.originalCurrency,
      'exchange_rate_to_profile': conversion.exchangeRateToProfile,
      'category': category,
      'ai_categorized': false,
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
    };
    if (receiptId != null) {
      values['receipt_id'] = receiptId;
    }

    await _insertExpenseValues(values);
    await _clearExpenseCaches(user.id);
  }

  Future<void> addReceiptExpenses({
    required String receiptId,
    required DateTime expenseDate,
    required List<ReceiptExpenseDraft> expenses,
    String? originalCurrency,
  }) async {
    final user = _requireUser();
    final profile = await getProfile();
    final sanitized = expenses
        .where(
          (expense) => expense.name.trim().isNotEmpty && expense.amount > 0,
        )
        .toList();
    if (sanitized.isEmpty) {
      throw StateError('Add at least one receipt item.');
    }

    final receipt = await _client
        .from('receipts')
        .select('id')
        .eq('id', receiptId)
        .eq('user_id', user.id)
        .maybeSingle();
    if (receipt == null) {
      throw StateError('Receipt not found.');
    }

    final date = DateFormat('yyyy-MM-dd').format(expenseDate);
    final values = sanitized.map((expense) {
      final category = expenseCategories.contains(expense.category)
          ? expense.category
          : 'other';
      final conversion = CurrencyConversion.fromOriginal(
        originalAmount: expense.amount,
        originalCurrency: originalCurrency ?? expense.originalCurrency,
        profileCurrency: profile.currency,
      );
      return {
        'receipt_id': receiptId,
        'user_id': user.id,
        'name': expense.name.trim(),
        'amount': conversion.convertedAmount,
        'currency': conversion.profileCurrency,
        'original_amount': conversion.originalAmount,
        'original_currency': conversion.originalCurrency,
        'exchange_rate_to_profile': conversion.exchangeRateToProfile,
        'category': category,
        'ai_categorized': true,
        'expense_date': date,
      };
    }).toList();

    await _insertExpenseValues(values);
    await _clearExpenseCaches(user.id);
  }

  Future<void> updateExpense({
    required String id,
    required String name,
    required double amount,
    required String category,
    required DateTime expenseDate,
    String? originalCurrency,
    String? receiptId,
  }) async {
    final user = _requireUser();
    final profile = await getProfile();
    final conversion = CurrencyConversion.fromOriginal(
      originalAmount: amount,
      originalCurrency: originalCurrency ?? profile.currency,
      profileCurrency: profile.currency,
    );
    final values = <String, Object?>{
      'name': name.trim(),
      'amount': conversion.convertedAmount,
      'currency': conversion.profileCurrency,
      'original_amount': conversion.originalAmount,
      'original_currency': conversion.originalCurrency,
      'exchange_rate_to_profile': conversion.exchangeRateToProfile,
      'category': category,
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
    };
    if (receiptId != null) {
      values['receipt_id'] = receiptId;
    }

    await _updateExpenseValues(id: id, userId: user.id, values: values);
    await _clearExpenseCaches(user.id);
  }

  Future<ReceiptUpload> createReceiptUpload({
    required Uint8List bytes,
    required String originalName,
    String? mimeType,
  }) async {
    final user = _requireUser();
    final profile = await getProfile();
    final receiptValues = <String, Object?>{
      'user_id': user.id,
      'total_amount': 0,
      'currency': profile.currency,
      'original_total_amount': 0,
      'exchange_rate_to_profile': 1,
      'scanned_at': DateTime.now().toUtc().toIso8601String(),
    };
    final inserted = await _insertReceiptUploadValues(receiptValues);
    final receipt = ReceiptUpload.fromMap(Map<String, dynamic>.from(inserted));
    final extension = _receiptExtension(originalName, mimeType);
    final path =
        '${user.id}/${receipt.id}/${DateTime.now().millisecondsSinceEpoch}$extension';

    var uploadedPath = false;
    try {
      await _client.storage
          .from(receiptImagesBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              contentType: _receiptContentType(extension, mimeType),
            ),
          );
      uploadedPath = true;

      final updated = await _updateReceiptImagePath(
        receiptId: receipt.id,
        userId: user.id,
        path: path,
      );

      return ReceiptUpload.fromMap(Map<String, dynamic>.from(updated));
    } catch (_) {
      if (uploadedPath) {
        try {
          await _client.storage.from(receiptImagesBucket).remove([path]);
        } catch (_) {
          // Preserve the original upload/update error.
        }
      }
      try {
        await _client.from('receipts').delete().eq('id', receipt.id);
      } catch (_) {
        // Preserve the original upload/update error.
      }
      rethrow;
    }
  }

  Future<void> deleteReceiptUpload(ReceiptUpload receipt) async {
    final user = _requireUser();
    final imagePath = receipt.imagePath;

    if (imagePath != null && imagePath.isNotEmpty) {
      await _client.storage.from(receiptImagesBucket).remove([imagePath]);
    }

    await _client
        .from('receipts')
        .delete()
        .eq('id', receipt.id)
        .eq('user_id', user.id);
  }

  Future<ReceiptUpload> getReceiptUpload(String receiptId) async {
    final user = _requireUser();

    final row = await _selectReceiptUpload(receiptId: receiptId, userId: user.id);

    return ReceiptUpload.fromMap(Map<String, dynamic>.from(row));
  }

  Future<String> createReceiptImageUrl(String imagePath) async {
    final user = _requireUser();
    if (!_isOwnReceiptPath(imagePath, user.id)) {
      throw StateError('Receipt image path does not belong to current user.');
    }

    return _client.storage
        .from(receiptImagesBucket)
        .createSignedUrl(imagePath, 60 * 15);
  }

  Future<ReceiptAnalysis> analyzeReceipt(
    String receiptId, {
    String? rawOcrText,
    String languageCode = 'en',
  }) async {
    _requireUser();
    final body = <String, Object?>{
      'receiptId': receiptId,
      'language': _normalizeLanguageCode(languageCode),
    };
    final trimmedText = rawOcrText?.trim();
    if (trimmedText != null && trimmedText.isNotEmpty) {
      body['rawText'] = trimmedText;
    }

    final response = await _client.functions.invoke(
      'analyze-receipt',
      body: body,
    );

    final map = _responseMap(response.data);
    final error = map['error'];
    if (error != null) {
      throw StateError(error.toString());
    }
    return ReceiptAnalysis.fromMap(map);
  }

  Future<void> deleteExpense(String id) async {
    final user = _requireUser();
    final existing = await _client
        .from('expense_items')
        .select('receipt_id')
        .eq('id', id)
        .eq('user_id', user.id)
        .maybeSingle();
    final receiptId = existing?['receipt_id'] as String?;

    await _client
        .from('expense_items')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
    await _clearExpenseCaches(user.id);

    if (receiptId != null) {
      try {
        await _deleteReceiptIfUnreferenced(
          receiptId: receiptId,
          userId: user.id,
        );
      } catch (_) {
        // Expense deletion should not fail because optional receipt cleanup failed.
      }
    }
  }

  Future<void> addFixedExpense({
    required String name,
    required double amount,
    required int billingDay,
  }) async {
    final user = _requireUser();

    await _client.from('fixed_expenses').insert({
      'user_id': user.id,
      'name': name.trim(),
      'amount': amount,
      'billing_day': billingDay,
      'is_active': true,
    });
    await _clearPlanningCaches(user.id);
  }

  Future<void> deleteFixedExpense(String id) async {
    final user = _requireUser();

    await _client
        .from('fixed_expenses')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
    await _clearPlanningCaches(user.id);
  }

  Future<void> addIncomeEvent({
    required String name,
    required double amount,
    required int expectedDay,
    required bool isRecurring,
  }) async {
    final user = _requireUser();

    await _client.from('income_events').insert({
      'user_id': user.id,
      'name': name.trim(),
      'amount': amount,
      'expected_day': expectedDay,
      'is_recurring': isRecurring,
    });
    await _clearIncomeCaches(user.id);
  }

  Future<void> deleteIncomeEvent(String id) async {
    final user = _requireUser();

    await _client
        .from('income_events')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
    await _clearIncomeCaches(user.id);
  }

  Future<List<RecipeSuggestion>> generateRecipes({
    required List<String> ingredients,
    required int desperationIndex,
    String languageCode = 'en',
  }) async {
    _requireUser();
    final response = await _client.functions.invoke(
      'generate-recipes',
      body: {
        'ingredients': ingredients,
        'desperationIndex': desperationIndex,
        'language': _normalizeLanguageCode(languageCode),
      },
    );

    final map = _responseMap(response.data);
    final error = map['error'];
    if (error != null) {
      throw StateError(error.toString());
    }
    final rawRecipes = map['recipes'];
    if (rawRecipes is! List) {
      throw StateError('Recipe response missing recipes array.');
    }

    return rawRecipes
        .whereType<Map>()
        .map(
          (recipe) =>
              RecipeSuggestion.fromMap(Map<String, dynamic>.from(recipe)),
        )
        .where((recipe) => recipe.name.isNotEmpty)
        .toList();
  }

  Future<InsightsResponse> generateInsights({
    required String month,
    String languageCode = 'en',
  }) async {
    _requireUser();
    final response = await _client.functions.invoke(
      'generate-insights',
      body: {'month': month, 'language': _normalizeLanguageCode(languageCode)},
    );

    final map = _responseMap(response.data);
    final error = map['error'];
    if (error != null) {
      throw StateError(error.toString());
    }

    return InsightsResponse.fromMap(map);
  }

  Future<InsightsResponse> refreshInsights({
    required String month,
    String languageCode = 'en',
  }) async {
    _requireUser();
    final response = await _client.functions.invoke(
      'generate-insights',
      body: {
        'month': month,
        'force': true,
        'language': _normalizeLanguageCode(languageCode),
      },
    );

    final map = _responseMap(response.data);
    final error = map['error'];
    if (error != null) {
      throw StateError(error.toString());
    }

    return InsightsResponse.fromMap(map);
  }

  Future<List<dynamic>> _selectExpenseRows({
    required String userId,
    int? limit,
  }) async {
    try {
      final query = _client
          .from('expense_items')
          .select(_expenseSelectColumns)
          .eq('user_id', userId)
          .order('expense_date', ascending: false)
          .order('created_at', ascending: false);
      if (limit != null) {
        return await query.limit(limit);
      }
      return await query;
    } catch (error) {
      if (!_isMissingCurrencySchema(error)) {
        rethrow;
      }
      final query = _client
          .from('expense_items')
          .select(_legacyExpenseSelectColumns)
          .eq('user_id', userId)
          .order('expense_date', ascending: false)
          .order('created_at', ascending: false);
      if (limit != null) {
        return await query.limit(limit);
      }
      return await query;
    }
  }

  Future<void> _insertExpenseValues(Object values) async {
    try {
      await _client.from('expense_items').insert(values);
    } catch (error) {
      if (!_isMissingCurrencySchema(error)) {
        rethrow;
      }
      await _client
          .from('expense_items')
          .insert(_legacyExpenseInsertValues(values));
    }
  }

  Future<void> _updateExpenseValues({
    required String id,
    required String userId,
    required Map<String, Object?> values,
  }) async {
    try {
      await _client
          .from('expense_items')
          .update(values)
          .eq('id', id)
          .eq('user_id', userId);
    } catch (error) {
      if (!_isMissingCurrencySchema(error)) {
        rethrow;
      }
      await _client
          .from('expense_items')
          .update(_legacyExpenseValues(values))
          .eq('id', id)
          .eq('user_id', userId);
    }
  }

  Future<dynamic> _insertReceiptUploadValues(
    Map<String, Object?> values,
  ) async {
    try {
      return await _client
          .from('receipts')
          .insert(values)
          .select(_receiptSelectColumns)
          .single();
    } catch (error) {
      if (!_isMissingCurrencySchema(error)) {
        rethrow;
      }
      return await _client
          .from('receipts')
          .insert(_legacyReceiptValues(values))
          .select(_legacyReceiptSelectColumns)
          .single();
    }
  }

  Future<dynamic> _updateReceiptImagePath({
    required String receiptId,
    required String userId,
    required String path,
  }) async {
    try {
      return await _client
          .from('receipts')
          .update({'image_path': path})
          .eq('id', receiptId)
          .eq('user_id', userId)
          .select(_receiptSelectColumns)
          .single();
    } catch (error) {
      if (!_isMissingCurrencySchema(error)) {
        rethrow;
      }
      return await _client
          .from('receipts')
          .update({'image_path': path})
          .eq('id', receiptId)
          .eq('user_id', userId)
          .select(_legacyReceiptSelectColumns)
          .single();
    }
  }

  Future<dynamic> _selectReceiptUpload({
    required String receiptId,
    required String userId,
  }) async {
    try {
      return await _client
          .from('receipts')
          .select(_receiptSelectColumns)
          .eq('id', receiptId)
          .eq('user_id', userId)
          .single();
    } catch (error) {
      if (!_isMissingCurrencySchema(error)) {
        rethrow;
      }
      return await _client
          .from('receipts')
          .select(_legacyReceiptSelectColumns)
          .eq('id', receiptId)
          .eq('user_id', userId)
          .single();
    }
  }

  Future<void> _deleteReceiptIfUnreferenced({
    required String receiptId,
    required String userId,
  }) async {
    final remaining = await _client
        .from('expense_items')
        .select('id')
        .eq('receipt_id', receiptId)
        .eq('user_id', userId)
        .limit(1);
    if (remaining.isNotEmpty) {
      return;
    }

    final row = await _maybeSelectReceiptUpload(
      receiptId: receiptId,
      userId: userId,
    );
    if (row == null) {
      return;
    }

    await deleteReceiptUpload(
      ReceiptUpload.fromMap(Map<String, dynamic>.from(row)),
    );
  }

  Future<dynamic> _maybeSelectReceiptUpload({
    required String receiptId,
    required String userId,
  }) async {
    try {
      return await _client
          .from('receipts')
          .select(_receiptSelectColumns)
          .eq('id', receiptId)
          .eq('user_id', userId)
          .maybeSingle();
    } catch (error) {
      if (!_isMissingCurrencySchema(error)) {
        rethrow;
      }
      return await _client
          .from('receipts')
          .select(_legacyReceiptSelectColumns)
          .eq('id', receiptId)
          .eq('user_id', userId)
          .maybeSingle();
    }
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You need to sign in first.');
    }
    return user;
  }

  String _cacheKey(String userId, String name) {
    return '$_offlineCachePrefix.$userId.$name';
  }

  Future<void> _writeCache(String key, Object? value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<Map<String, dynamic>?> _readCachedMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) {
      return null;
    }
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  Future<List<Map<String, dynamic>>?> _readCachedList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return null;
    }
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _clearExpenseCaches(String userId) async {
    await _removeCacheKeys(userId, const [
      'budget_snapshot',
      'recent_expenses',
      'expense_history',
      'monthly_summary',
      'category_spending',
    ]);
  }

  Future<void> _clearPlanningCaches(String userId) async {
    await _removeCacheKeys(userId, const ['budget_snapshot', 'fixed_expenses']);
  }

  Future<void> _clearIncomeCaches(String userId) async {
    await _removeCacheKeys(userId, const ['income_events']);
  }

  Future<void> _removeCacheKeys(String userId, List<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait(
      names.map((name) => prefs.remove(_cacheKey(userId, name))),
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.monthlyBudget,
    required this.budgetResetDay,
    required this.currency,
    required this.timezone,
    required this.onboardingCompleted,
  });

  final String id;
  final String? displayName;
  final double monthlyBudget;
  final int budgetResetDay;
  final String currency;
  final String timezone;
  final bool onboardingCompleted;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      displayName: map['display_name'] as String?,
      monthlyBudget: _toDouble(map['monthly_budget']),
      budgetResetDay: _toInt(map['budget_reset_day']),
      currency: (map['currency'] as String?) ?? 'USD',
      timezone: (map['timezone'] as String?) ?? 'Europe/Warsaw',
      onboardingCompleted: (map['onboarding_completed'] as bool?) ?? false,
    );
  }
}

class BudgetSnapshot {
  const BudgetSnapshot({
    required this.monthlyBudget,
    required this.fixedMonthlyExpenses,
    required this.disposableBudget,
    required this.spentThisPeriod,
    required this.remainingBudget,
    required this.daysLeft,
    required this.dailyLimit,
    required this.desperationIndex,
  });

  final double monthlyBudget;
  final double fixedMonthlyExpenses;
  final double disposableBudget;
  final double spentThisPeriod;
  final double remainingBudget;
  final int daysLeft;
  final double dailyLimit;
  final int desperationIndex;

  factory BudgetSnapshot.fromMap(Map<String, dynamic> map) {
    return BudgetSnapshot(
      monthlyBudget: _toDouble(map['monthly_budget']),
      fixedMonthlyExpenses: _toDouble(map['fixed_monthly_expenses']),
      disposableBudget: _toDouble(map['disposable_budget']),
      spentThisPeriod: _toDouble(map['spent_this_period']),
      remainingBudget: _toDouble(map['remaining_budget']),
      daysLeft: _toInt(map['days_left']),
      dailyLimit: _toDouble(map['daily_limit']),
      desperationIndex: _toInt(map['desperation_index']).clamp(0, 100),
    );
  }

  Map<String, Object> toMap() {
    return {
      'monthly_budget': monthlyBudget,
      'fixed_monthly_expenses': fixedMonthlyExpenses,
      'disposable_budget': disposableBudget,
      'spent_this_period': spentThisPeriod,
      'remaining_budget': remainingBudget,
      'days_left': daysLeft,
      'daily_limit': dailyLimit,
      'desperation_index': desperationIndex,
    };
  }
}

class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.expenseDate,
    this.currency = 'USD',
    this.originalAmount,
    this.originalCurrency,
    this.exchangeRateToProfile,
    this.receiptId,
  });

  final String id;
  final String? receiptId;
  final String name;
  final double amount;
  final String currency;
  final double? originalAmount;
  final String? originalCurrency;
  final double? exchangeRateToProfile;
  final String category;
  final DateTime expenseDate;

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    final currency = _normalizeCurrencyCode(map['currency']?.toString());
    final originalCurrency =
        _normalizeCurrencyCodeOrNull(map['original_currency']?.toString()) ??
        currency;
    final originalAmount = map['original_amount'] == null
        ? null
        : _toDouble(map['original_amount']);
    return ExpenseItem(
      id: map['id'] as String,
      receiptId: map['receipt_id'] as String?,
      name: map['name'] as String,
      amount: _toDouble(map['amount']),
      currency: currency,
      originalAmount: originalAmount,
      originalCurrency: originalCurrency,
      exchangeRateToProfile: map['exchange_rate_to_profile'] == null
          ? null
          : _toDouble(map['exchange_rate_to_profile']),
      category: (map['category'] as String?) ?? 'other',
      expenseDate: DateTime.parse(map['expense_date'] as String),
    );
  }

  bool get hasCurrencyConversion =>
      originalAmount != null &&
      originalCurrency != null &&
      originalCurrency != currency;
}

class ReceiptUpload {
  const ReceiptUpload({
    required this.id,
    required this.totalAmount,
    required this.scannedAt,
    this.currency = 'USD',
    this.storeName,
    this.originalTotalAmount,
    this.exchangeRateToProfile,
    this.rawOcrText,
    this.analysis,
    this.imagePath,
  });

  final String id;
  final String? storeName;
  final double totalAmount;
  final String currency;
  final double? originalTotalAmount;
  final double? exchangeRateToProfile;
  final String? rawOcrText;
  final ReceiptAnalysis? analysis;
  final String? imagePath;
  final DateTime scannedAt;

  factory ReceiptUpload.fromMap(Map<String, dynamic> map) {
    final rawAnalysis = map['analysis_json'];

    return ReceiptUpload(
      id: map['id'] as String,
      storeName: map['store_name'] as String?,
      totalAmount: _toDouble(map['total_amount']),
      currency: _normalizeCurrencyCode(map['currency']?.toString()),
      originalTotalAmount: map['original_total_amount'] == null
          ? null
          : _toDouble(map['original_total_amount']),
      exchangeRateToProfile: map['exchange_rate_to_profile'] == null
          ? null
          : _toDouble(map['exchange_rate_to_profile']),
      rawOcrText: map['raw_ocr_text'] as String?,
      analysis: rawAnalysis is Map
          ? ReceiptAnalysis.fromMap(Map<String, dynamic>.from(rawAnalysis))
          : null,
      imagePath: map['image_path'] as String?,
      scannedAt: DateTime.parse(map['scanned_at'] as String),
    );
  }
}

class ReceiptAnalysis {
  const ReceiptAnalysis({
    this.storeName,
    this.totalAmount,
    this.currency,
    this.expenseDate,
    this.category,
    this.description,
    this.confidence,
    this.items = const [],
  });

  final String? storeName;
  final double? totalAmount;
  final String? currency;
  final DateTime? expenseDate;
  final String? category;
  final String? description;
  final double? confidence;
  final List<ReceiptAnalysisItem> items;

  factory ReceiptAnalysis.fromMap(Map<String, dynamic> map) {
    final amount = map['totalAmount'] ?? map['total_amount'];
    final rawCurrency = map['currency'] ?? map['detectedCurrency'];
    final rawDate = map['expenseDate'] ?? map['expense_date'];
    final rawCategory = map['category']?.toString();
    final rawItems = map['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) {
                return ReceiptAnalysisItem.fromMap(
                  Map<String, dynamic>.from(item),
                );
              })
              .where((item) => item.name.isNotEmpty && item.amount > 0)
              .toList()
        : <ReceiptAnalysisItem>[];

    return ReceiptAnalysis(
      storeName: _blankToNull(map['storeName'] ?? map['store_name']),
      totalAmount: amount == null ? null : _toDouble(amount),
      currency: _normalizeCurrencyCodeOrNull(rawCurrency?.toString()),
      expenseDate: rawDate == null ? null : DateTime.tryParse('$rawDate'),
      category: expenseCategories.contains(rawCategory) ? rawCategory : null,
      description: _blankToNull(map['description']),
      confidence: map['confidence'] == null
          ? null
          : _toDouble(map['confidence']).clamp(0.0, 1.0).toDouble(),
      items: items,
    );
  }

  bool get hasUsefulSuggestion =>
      items.isNotEmpty ||
      (description != null && description!.isNotEmpty) ||
      (storeName != null && storeName!.isNotEmpty) ||
      (totalAmount != null && totalAmount! > 0) ||
      currency != null ||
      expenseDate != null ||
      category != null;
}

class ReceiptAnalysisItem {
  const ReceiptAnalysisItem({
    required this.name,
    required this.amount,
    required this.category,
    this.currency,
  });

  final String name;
  final double amount;
  final String category;
  final String? currency;

  factory ReceiptAnalysisItem.fromMap(Map<String, dynamic> map) {
    final rawCategory = map['category']?.toString();
    final rawCurrency = map['currency'] ?? map['detectedCurrency'];
    return ReceiptAnalysisItem(
      name: _blankToNull(map['name']) ?? '',
      amount: _toDouble(map['amount']),
      category: expenseCategories.contains(rawCategory)
          ? rawCategory!
          : 'other',
      currency: _normalizeCurrencyCodeOrNull(rawCurrency?.toString()),
    );
  }
}

class ReceiptExpenseDraft {
  const ReceiptExpenseDraft({
    required this.name,
    required this.amount,
    required this.category,
    this.originalCurrency,
  });

  final String name;
  final double amount;
  final String category;
  final String? originalCurrency;
}

class CategorySpending {
  const CategorySpending({
    required this.category,
    required this.amount,
    required this.itemCount,
  });

  final String category;
  final double amount;
  final int itemCount;

  factory CategorySpending.fromMap(Map<String, dynamic> map) {
    return CategorySpending(
      category: map['category']?.toString() ?? 'other',
      amount: _toDouble(map['amount']),
      itemCount: _toInt(map['item_count']),
    );
  }

  Map<String, Object> toMap() {
    return {'category': category, 'amount': amount, 'item_count': itemCount};
  }
}

class FixedExpense {
  const FixedExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.billingDay,
    required this.isActive,
  });

  final String id;
  final String name;
  final double amount;
  final int billingDay;
  final bool isActive;

  factory FixedExpense.fromMap(Map<String, dynamic> map) {
    return FixedExpense(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: _toDouble(map['amount']),
      billingDay: _toInt(map['billing_day']),
      isActive: _toBool(map['is_active']),
    );
  }
}

class IncomeEvent {
  const IncomeEvent({
    required this.id,
    required this.name,
    required this.amount,
    required this.expectedDay,
    required this.isRecurring,
  });

  final String id;
  final String name;
  final double amount;
  final int expectedDay;
  final bool isRecurring;

  factory IncomeEvent.fromMap(Map<String, dynamic> map) {
    return IncomeEvent(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: _toDouble(map['amount']),
      expectedDay: _toInt(map['expected_day']),
      isRecurring: _toBool(map['is_recurring']),
    );
  }
}

class MonthlySummary {
  const MonthlySummary({
    required this.month,
    required this.totalSpent,
    required this.receiptCount,
    required this.amountByCategory,
  });

  final DateTime month;
  final double totalSpent;
  final int receiptCount;
  final Map<String, double> amountByCategory;

  factory MonthlySummary.fromMap(Map<String, dynamic> map) {
    return MonthlySummary(
      month: DateTime.parse(map['month'].toString()),
      totalSpent: _toDouble(map['total_spent']),
      receiptCount: _toInt(map['receipt_count']),
      amountByCategory: {
        'food': _toDouble(map['food_spent']),
        'alcohol': _toDouble(map['alcohol_spent']),
        'hygiene': _toDouble(map['hygiene_spent']),
        'fun': _toDouble(map['fun_spent']),
        'other': _toDouble(map['other_spent']),
      },
    );
  }
}

class RecipeRequest {
  const RecipeRequest({
    required this.ingredients,
    required this.desperationIndex,
    required this.languageCode,
  });

  final List<String> ingredients;
  final int desperationIndex;
  final String languageCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecipeRequest &&
        other.desperationIndex == desperationIndex &&
        other.languageCode == languageCode &&
        _listEquals(other.ingredients, ingredients);
  }

  @override
  int get hashCode =>
      Object.hash(desperationIndex, languageCode, Object.hashAll(ingredients));
}

class RecipeSuggestion {
  const RecipeSuggestion({
    required this.name,
    required this.ingredientsUsed,
    required this.steps,
    required this.estimatedCost,
    required this.calories,
    required this.note,
  });

  final String name;
  final List<String> ingredientsUsed;
  final List<String> steps;
  final double? estimatedCost;
  final int? calories;
  final String? note;

  factory RecipeSuggestion.fromMap(Map<String, dynamic> map) {
    final rawIngredients = map['ingredients_used'];
    final rawSteps = map['steps'];

    return RecipeSuggestion(
      name: (map['name'] as String?)?.trim() ?? '',
      ingredientsUsed: rawIngredients is List
          ? rawIngredients.map((item) => item.toString()).toList()
          : const [],
      steps: rawSteps is List
          ? rawSteps.map((item) => item.toString()).toList()
          : const [],
      estimatedCost: map['estimated_cost'] == null
          ? null
          : _toDouble(map['estimated_cost']),
      calories: map['calories'] == null ? null : _toInt(map['calories']),
      note: (map['note'] as String?)?.trim(),
    );
  }
}

class InsightsRequest {
  const InsightsRequest({required this.month, required this.languageCode});

  final String month;
  final String languageCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InsightsRequest &&
        other.month == month &&
        other.languageCode == languageCode;
  }

  @override
  int get hashCode => Object.hash(month, languageCode);
}

class InsightsResponse {
  const InsightsResponse({
    required this.month,
    required this.cached,
    required this.insights,
  });

  final String month;
  final bool cached;
  final MonthlyInsights insights;

  factory InsightsResponse.fromMap(Map<String, dynamic> map) {
    return InsightsResponse(
      month: map['month']?.toString() ?? '',
      cached: map['cached'] == true,
      insights: MonthlyInsights.fromMap(
        Map<String, dynamic>.from(map['insights'] as Map),
      ),
    );
  }
}

class MonthlyInsights {
  const MonthlyInsights({
    required this.summary,
    required this.absurdPurchases,
    required this.categoryCallouts,
  });

  final String summary;
  final List<AbsurdPurchase> absurdPurchases;
  final List<CategoryCallout> categoryCallouts;

  factory MonthlyInsights.fromMap(Map<String, dynamic> map) {
    return MonthlyInsights(
      summary: map['summary']?.toString() ?? '',
      absurdPurchases:
          (map['absurd_purchases'] as List?)
              ?.whereType<Map>()
              .map(
                (item) =>
                    AbsurdPurchase.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList() ??
          const [],
      categoryCallouts:
          (map['category_callouts'] as List?)
              ?.whereType<Map>()
              .map(
                (item) =>
                    CategoryCallout.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList() ??
          const [],
    );
  }
}

class CurrencyConversion {
  const CurrencyConversion({
    required this.originalAmount,
    required this.originalCurrency,
    required this.profileCurrency,
    required this.exchangeRateToProfile,
    required this.convertedAmount,
  });

  final double originalAmount;
  final String originalCurrency;
  final String profileCurrency;
  final double exchangeRateToProfile;
  final double convertedAmount;

  factory CurrencyConversion.fromOriginal({
    required double originalAmount,
    required String? originalCurrency,
    required String profileCurrency,
  }) {
    final normalizedOriginal = _normalizeCurrencyCode(originalCurrency);
    final normalizedProfile = _normalizeCurrencyCode(profileCurrency);
    final rate = exchangeRate(
      fromCurrency: normalizedOriginal,
      toCurrency: normalizedProfile,
    );
    return CurrencyConversion(
      originalAmount: originalAmount,
      originalCurrency: normalizedOriginal,
      profileCurrency: normalizedProfile,
      exchangeRateToProfile: rate,
      convertedAmount: _roundMoney(originalAmount * rate),
    );
  }

  static double exchangeRate({
    required String fromCurrency,
    required String toCurrency,
  }) {
    final from = _normalizeCurrencyCode(fromCurrency);
    final to = _normalizeCurrencyCode(toCurrency);
    if (from == to) {
      return 1;
    }
    final fromValue = _currencyValueInPln[from] ?? 1;
    final toValue = _currencyValueInPln[to] ?? 1;
    return fromValue / toValue;
  }
}

class AbsurdPurchase {
  const AbsurdPurchase({
    required this.name,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });

  final String name;
  final double amount;
  final String category;
  final DateTime date;
  final String? note;

  factory AbsurdPurchase.fromMap(Map<String, dynamic> map) {
    return AbsurdPurchase(
      name: map['name']?.toString() ?? '',
      amount: _toDouble(map['amount']),
      category: map['category']?.toString() ?? 'other',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      note: map['note']?.toString(),
    );
  }
}

class CategoryCallout {
  const CategoryCallout({
    required this.category,
    required this.amount,
    required this.note,
  });

  final String category;
  final double amount;
  final String note;

  factory CategoryCallout.fromMap(Map<String, dynamic> map) {
    return CategoryCallout(
      category: map['category']?.toString() ?? 'other',
      amount: _toDouble(map['amount']),
      note: map['note']?.toString() ?? '',
    );
  }
}

double _toDouble(Object? value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString()) ?? 0;
}

int _toInt(Object? value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString()) ?? 0;
}

bool _toBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  return value?.toString().toLowerCase() == 'true';
}

bool _isMissingCurrencySchema(Object error) {
  if (error is! PostgrestException) {
    return false;
  }
  final text = [
    error.message,
    error.details,
    error.hint,
    error.code,
  ].whereType<String>().join(' ').toLowerCase();
  final mentionsCurrencyColumn =
      text.contains('currency') ||
      text.contains('original_amount') ||
      text.contains('original_currency') ||
      text.contains('original_total_amount') ||
      text.contains('exchange_rate_to_profile');
  final isMissingColumn =
      text.contains('42703') ||
      text.contains('pgrst204') ||
      text.contains('column') ||
      text.contains('schema cache');
  return mentionsCurrencyColumn && isMissingColumn;
}

Map<String, Object?> _legacyExpenseValues(Map<String, Object?> values) {
  return Map<String, Object?>.from(values)
    ..remove('currency')
    ..remove('original_amount')
    ..remove('original_currency')
    ..remove('exchange_rate_to_profile');
}

Object _legacyExpenseInsertValues(Object values) {
  if (values is List) {
    return values
        .whereType<Map>()
        .map((value) => _legacyExpenseValues(Map<String, Object?>.from(value)))
        .toList();
  }
  if (values is Map) {
    return _legacyExpenseValues(Map<String, Object?>.from(values));
  }
  return values;
}

Map<String, Object?> _legacyReceiptValues(Map<String, Object?> values) {
  return Map<String, Object?>.from(values)
    ..remove('currency')
    ..remove('original_total_amount')
    ..remove('exchange_rate_to_profile');
}

String _normalizeCurrencyCode(String? value) {
  final code = value?.trim().toUpperCase() ?? '';
  return supportedCurrencies.contains(code) ? code : 'PLN';
}

String? _normalizeCurrencyCodeOrNull(String? value) {
  final code = value?.trim().toUpperCase() ?? '';
  return supportedCurrencies.contains(code) ? code : null;
}

double _roundMoney(double value) {
  return (value * 100).roundToDouble() / 100;
}

Map<String, dynamic> _responseMap(Object? data) {
  final decoded = data is String ? jsonDecode(data) : data;
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  throw StateError('Unexpected receipt analysis response.');
}

String? _blankToNull(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

String _normalizeLanguageCode(String code) {
  return code.trim().toLowerCase() == 'pl' ? 'pl' : 'en';
}

String _receiptExtension(String originalName, String? mimeType) {
  final normalizedMimeType = _normalizeReceiptMimeType(mimeType);
  if (normalizedMimeType == 'image/png') {
    return '.png';
  }
  if (normalizedMimeType == 'image/webp') {
    return '.webp';
  }
  if (normalizedMimeType == 'image/jpeg') {
    return '.jpg';
  }

  final lowerName = originalName.toLowerCase();
  if (lowerName.endsWith('.png')) {
    return '.png';
  }
  if (lowerName.endsWith('.webp')) {
    return '.webp';
  }
  if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
    return '.jpg';
  }
  if (lowerName.endsWith('.heic') || lowerName.endsWith('.heif')) {
    throw StateError(
      'Unsupported receipt image format. Use JPG, PNG, or WebP.',
    );
  }
  return '.jpg';
}

String _receiptContentType(String extension, String? mimeType) {
  final normalizedMimeType = _normalizeReceiptMimeType(mimeType);
  if (normalizedMimeType != null) {
    return normalizedMimeType;
  }
  return switch (extension) {
    '.png' => 'image/png',
    '.webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}

String? _normalizeReceiptMimeType(String? mimeType) {
  final value = mimeType?.trim().toLowerCase();
  if (value == null || value.isEmpty) {
    return null;
  }
  if (value == 'image/jpg') {
    return 'image/jpeg';
  }
  if (value == 'image/jpeg' || value == 'image/png' || value == 'image/webp') {
    return value;
  }
  if (value.startsWith('image/')) {
    throw StateError(
      'Unsupported receipt image format. Use JPG, PNG, or WebP.',
    );
  }
  return null;
}

bool _isOwnReceiptPath(String imagePath, String userId) {
  return imagePath == userId || imagePath.startsWith('$userId/');
}

bool _listEquals(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

class _BudgetPeriod {
  const _BudgetPeriod({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

_BudgetPeriod _budgetPeriodFor(DateTime date, int resetDay) {
  final normalizedResetDay = resetDay.clamp(1, 28);
  final periodMonth = date.day < normalizedResetDay
      ? DateTime(date.year, date.month - 1)
      : DateTime(date.year, date.month);
  final start = DateTime(
    periodMonth.year,
    periodMonth.month,
    normalizedResetDay,
  );
  final end = DateTime(
    periodMonth.year,
    periodMonth.month + 1,
    normalizedResetDay,
  ).subtract(const Duration(days: 1));

  return _BudgetPeriod(start: start, end: end);
}
