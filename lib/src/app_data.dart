import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final appRepositoryProvider = Provider<AppRepository>((ref) {
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

final recipeGeneratorProvider = FutureProvider.family<
    List<RecipeSuggestion>, RecipeRequest>((ref, request) async {
  return ref.watch(appRepositoryProvider).generateRecipes(
        ingredients: request.ingredients,
        desperationIndex: request.desperationIndex,
      );
});

final insightsProvider = FutureProvider.family<
    InsightsResponse, InsightsRequest>((ref, request) async {
  return ref.watch(appRepositoryProvider).generateInsights(
        month: request.month,
      );
});

final insightsRefreshProvider = FutureProvider.family<
    InsightsResponse, InsightsRequest>((ref, request) async {
  return ref.watch(appRepositoryProvider).refreshInsights(
        month: request.month,
      );
});

const expenseCategories = ['food', 'alcohol', 'hygiene', 'fun', 'other'];
const receiptImagesBucket = 'receipt-images';
const _receiptSelectColumns =
    'id, store_name, total_amount, raw_ocr_text, analysis_json, image_path, scanned_at';

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
            'display_name': user.email?.split('@').first,
            'monthly_budget': 0,
            'budget_reset_day': 1,
            'currency': 'USD',
            'timezone': 'Europe/Warsaw',
          },
          onConflict: 'id',
          ignoreDuplicates: true,
        );
  }

  Future<UserProfile> getProfile() async {
    final user = _requireUser();
    await ensureProfile();

    final row = await _client
        .from('users_profiles')
        .select(
          'id, display_name, monthly_budget, budget_reset_day, currency, timezone',
        )
        .eq('id', user.id)
        .single();

    return UserProfile.fromMap(row);
  }

  Future<void> updateBudget({
    required double monthlyBudget,
    required int budgetResetDay,
    required String currency,
  }) async {
    final user = _requireUser();
    await ensureProfile();

    await _client
        .from('users_profiles')
        .update({
          'monthly_budget': monthlyBudget,
          'budget_reset_day': budgetResetDay,
          'currency': currency.trim().toUpperCase(),
        })
        .eq('id', user.id);
  }

  Future<BudgetSnapshot?> getBudgetSnapshot() async {
    await ensureProfile();

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final data = await _client.rpc(
      'get_budget_snapshot',
      params: {'p_on_date': today},
    );

    if (data is List && data.isNotEmpty) {
      return BudgetSnapshot.fromMap(
        Map<String, dynamic>.from(data.first as Map),
      );
    }

    if (data is Map) {
      return BudgetSnapshot.fromMap(Map<String, dynamic>.from(data));
    }

    return null;
  }

  Future<List<ExpenseItem>> getRecentExpenses() async {
    final user = _requireUser();

    final rows = await _client
        .from('expense_items')
        .select(
          'id, receipt_id, name, amount, category, expense_date, created_at',
        )
        .eq('user_id', user.id)
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(12);

    return rows
        .map((row) => ExpenseItem.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<ExpenseItem>> getExpenseHistory() async {
    final user = _requireUser();

    final rows = await _client
        .from('expense_items')
        .select(
          'id, receipt_id, name, amount, category, expense_date, created_at',
        )
        .eq('user_id', user.id)
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false);

    return rows
        .map((row) => ExpenseItem.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<MonthlySummary?> getMonthlySummary() async {
    final user = _requireUser();

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
      return null;
    }

    return MonthlySummary.fromMap(Map<String, dynamic>.from(data));
  }

  Future<List<CategorySpending>> getCategorySpending({
    required UserProfile profile,
    DateTime? onDate,
  }) async {
    final user = _requireUser();
    final period = _budgetPeriodFor(
      onDate ?? DateTime.now(),
      profile.budgetResetDay,
    );
    final dateFormat = DateFormat('yyyy-MM-dd');
    final amountByCategory = <String, double>{};
    final countByCategory = <String, int>{};

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

    return spending;
  }

  Future<List<FixedExpense>> getFixedExpenses() async {
    final user = _requireUser();

    final rows = await _client
        .from('fixed_expenses')
        .select('id, name, amount, billing_day, is_active')
        .eq('user_id', user.id)
        .order('billing_day')
        .order('name');

    return rows
        .map((row) => FixedExpense.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<IncomeEvent>> getIncomeEvents() async {
    final user = _requireUser();

    final rows = await _client
        .from('income_events')
        .select('id, name, amount, expected_day, is_recurring')
        .eq('user_id', user.id)
        .order('expected_day')
        .order('name');

    return rows
        .map((row) => IncomeEvent.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> addManualExpense({
    required String name,
    required double amount,
    required String category,
    required DateTime expenseDate,
    String? receiptId,
  }) async {
    final user = _requireUser();
    final values = <String, Object?>{
      'user_id': user.id,
      'name': name.trim(),
      'amount': amount,
      'category': category,
      'ai_categorized': false,
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
    };
    if (receiptId != null) {
      values['receipt_id'] = receiptId;
    }

    await _client.from('expense_items').insert(values);
  }

  Future<void> addReceiptExpenses({
    required String receiptId,
    required DateTime expenseDate,
    required List<ReceiptExpenseDraft> expenses,
  }) async {
    final user = _requireUser();
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
      return {
        'receipt_id': receiptId,
        'user_id': user.id,
        'name': expense.name.trim(),
        'amount': expense.amount,
        'category': category,
        'ai_categorized': true,
        'expense_date': date,
      };
    }).toList();

    await _client.from('expense_items').insert(values);
  }

  Future<void> updateExpense({
    required String id,
    required String name,
    required double amount,
    required String category,
    required DateTime expenseDate,
    String? receiptId,
  }) async {
    final user = _requireUser();
    final values = <String, Object?>{
      'name': name.trim(),
      'amount': amount,
      'category': category,
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
    };
    if (receiptId != null) {
      values['receipt_id'] = receiptId;
    }

    await _client
        .from('expense_items')
        .update(values)
        .eq('id', id)
        .eq('user_id', user.id);
  }

  Future<ReceiptUpload> createReceiptUpload({
    required Uint8List bytes,
    required String originalName,
    String? mimeType,
  }) async {
    final user = _requireUser();
    final inserted = await _client
        .from('receipts')
        .insert({
          'user_id': user.id,
          'total_amount': 0,
          'scanned_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select(_receiptSelectColumns)
        .single();
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

      final updated = await _client
          .from('receipts')
          .update({'image_path': path})
          .eq('id', receipt.id)
          .eq('user_id', user.id)
          .select(_receiptSelectColumns)
          .single();

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

    final row = await _client
        .from('receipts')
        .select(_receiptSelectColumns)
        .eq('id', receiptId)
        .eq('user_id', user.id)
        .single();

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
  }) async {
    _requireUser();
    final body = <String, Object?>{'receiptId': receiptId};
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
  }

  Future<void> deleteFixedExpense(String id) async {
    final user = _requireUser();

    await _client
        .from('fixed_expenses')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
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
  }

  Future<void> deleteIncomeEvent(String id) async {
    final user = _requireUser();

    await _client
        .from('income_events')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
  }

  Future<List<RecipeSuggestion>> generateRecipes({
    required List<String> ingredients,
    required int desperationIndex,
  }) async {
    _requireUser();
    final response = await _client.functions.invoke(
      'generate-recipes',
      body: {
        'ingredients': ingredients,
        'desperationIndex': desperationIndex,
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
        .map((recipe) => RecipeSuggestion.fromMap(
              Map<String, dynamic>.from(recipe),
            ))
        .where((recipe) => recipe.name.isNotEmpty)
        .toList();
  }

  Future<InsightsResponse> generateInsights({required String month}) async {
    _requireUser();
    final response = await _client.functions.invoke(
      'generate-insights',
      body: {
        'month': month,
      },
    );

    final map = _responseMap(response.data);
    final error = map['error'];
    if (error != null) {
      throw StateError(error.toString());
    }

    return InsightsResponse.fromMap(map);
  }

  Future<InsightsResponse> refreshInsights({required String month}) async {
    _requireUser();
    final response = await _client.functions.invoke(
      'generate-insights',
      body: {
        'month': month,
        'force': true,
      },
    );

    final map = _responseMap(response.data);
    final error = map['error'];
    if (error != null) {
      throw StateError(error.toString());
    }

    return InsightsResponse.fromMap(map);
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

    final row = await _client
        .from('receipts')
        .select(_receiptSelectColumns)
        .eq('id', receiptId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return;
    }

    await deleteReceiptUpload(
      ReceiptUpload.fromMap(Map<String, dynamic>.from(row)),
    );
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You need to sign in first.');
    }
    return user;
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
  });

  final String id;
  final String? displayName;
  final double monthlyBudget;
  final int budgetResetDay;
  final String currency;
  final String timezone;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      displayName: map['display_name'] as String?,
      monthlyBudget: _toDouble(map['monthly_budget']),
      budgetResetDay: _toInt(map['budget_reset_day']),
      currency: (map['currency'] as String?) ?? 'USD',
      timezone: (map['timezone'] as String?) ?? 'Europe/Warsaw',
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
}

class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.expenseDate,
    this.receiptId,
  });

  final String id;
  final String? receiptId;
  final String name;
  final double amount;
  final String category;
  final DateTime expenseDate;

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      id: map['id'] as String,
      receiptId: map['receipt_id'] as String?,
      name: map['name'] as String,
      amount: _toDouble(map['amount']),
      category: (map['category'] as String?) ?? 'other',
      expenseDate: DateTime.parse(map['expense_date'] as String),
    );
  }
}

class ReceiptUpload {
  const ReceiptUpload({
    required this.id,
    required this.totalAmount,
    required this.scannedAt,
    this.storeName,
    this.rawOcrText,
    this.analysis,
    this.imagePath,
  });

  final String id;
  final String? storeName;
  final double totalAmount;
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
    this.expenseDate,
    this.category,
    this.description,
    this.confidence,
    this.items = const [],
  });

  final String? storeName;
  final double? totalAmount;
  final DateTime? expenseDate;
  final String? category;
  final String? description;
  final double? confidence;
  final List<ReceiptAnalysisItem> items;

  factory ReceiptAnalysis.fromMap(Map<String, dynamic> map) {
    final amount = map['totalAmount'] ?? map['total_amount'];
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
      expenseDate != null ||
      category != null;
}

class ReceiptAnalysisItem {
  const ReceiptAnalysisItem({
    required this.name,
    required this.amount,
    required this.category,
  });

  final String name;
  final double amount;
  final String category;

  factory ReceiptAnalysisItem.fromMap(Map<String, dynamic> map) {
    final rawCategory = map['category']?.toString();
    return ReceiptAnalysisItem(
      name: _blankToNull(map['name']) ?? '',
      amount: _toDouble(map['amount']),
      category: expenseCategories.contains(rawCategory)
          ? rawCategory!
          : 'other',
    );
  }
}

class ReceiptExpenseDraft {
  const ReceiptExpenseDraft({
    required this.name,
    required this.amount,
    required this.category,
  });

  final String name;
  final double amount;
  final String category;
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
  });

  final List<String> ingredients;
  final int desperationIndex;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecipeRequest &&
        other.desperationIndex == desperationIndex &&
        _listEquals(other.ingredients, ingredients);
  }

  @override
  int get hashCode =>
      Object.hash(desperationIndex, Object.hashAll(ingredients));
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
  const InsightsRequest({required this.month});

  final String month;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InsightsRequest && other.month == month;
  }

  @override
  int get hashCode => month.hashCode;
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
      absurdPurchases: (map['absurd_purchases'] as List?)
              ?.whereType<Map>()
              .map((item) => AbsurdPurchase.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .toList() ??
          const [],
      categoryCallouts: (map['category_callouts'] as List?)
              ?.whereType<Map>()
              .map((item) => CategoryCallout.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .toList() ??
          const [],
    );
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
