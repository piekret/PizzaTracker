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

const expenseCategories = ['food', 'alcohol', 'hygiene', 'fun', 'other'];
const receiptImagesBucket = 'receipt-images';

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
    _requireUser();

    final rows = await _client
        .from('expense_items')
        .select(
          'id, receipt_id, name, amount, category, expense_date, created_at',
        )
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
    _requireUser();

    final rows = await _client
        .from('fixed_expenses')
        .select('id, name, amount, billing_day, is_active')
        .order('billing_day')
        .order('name');

    return rows
        .map((row) => FixedExpense.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<IncomeEvent>> getIncomeEvents() async {
    _requireUser();

    final rows = await _client
        .from('income_events')
        .select('id, name, amount, expected_day, is_recurring')
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
        .select('id, store_name, total_amount, image_path, scanned_at')
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
          .select('id, store_name, total_amount, image_path, scanned_at')
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

  Future<void> deleteExpense(String id) async {
    final user = _requireUser();

    await _client
        .from('expense_items')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
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
    _requireUser();

    await _client.from('fixed_expenses').delete().eq('id', id);
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
    _requireUser();

    await _client.from('income_events').delete().eq('id', id);
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
    this.imagePath,
  });

  final String id;
  final String? storeName;
  final double totalAmount;
  final String? imagePath;
  final DateTime scannedAt;

  factory ReceiptUpload.fromMap(Map<String, dynamic> map) {
    return ReceiptUpload(
      id: map['id'] as String,
      storeName: map['store_name'] as String?,
      totalAmount: _toDouble(map['total_amount']),
      imagePath: map['image_path'] as String?,
      scannedAt: DateTime.parse(map['scanned_at'] as String),
    );
  }
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

String _receiptExtension(String originalName, String? mimeType) {
  final lowerName = originalName.toLowerCase();
  if (lowerName.endsWith('.png') || mimeType == 'image/png') {
    return '.png';
  }
  if (lowerName.endsWith('.webp') || mimeType == 'image/webp') {
    return '.webp';
  }
  return '.jpg';
}

String _receiptContentType(String extension, String? mimeType) {
  if (mimeType != null && mimeType.startsWith('image/')) {
    return mimeType;
  }
  return switch (extension) {
    '.png' => 'image/png',
    '.webp' => 'image/webp',
    _ => 'image/jpeg',
  };
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
