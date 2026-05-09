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

final fixedExpensesProvider = FutureProvider<List<FixedExpense>>((ref) async {
  return ref.watch(appRepositoryProvider).getFixedExpenses();
});

final incomeEventsProvider = FutureProvider<List<IncomeEvent>>((ref) async {
  return ref.watch(appRepositoryProvider).getIncomeEvents();
});

const expenseCategories = ['food', 'alcohol', 'hygiene', 'fun', 'other'];

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
        .select('id, name, amount, category, expense_date, created_at')
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(12);

    return rows
        .map((row) => ExpenseItem.fromMap(Map<String, dynamic>.from(row)))
        .toList();
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
  }) async {
    final user = _requireUser();

    await _client.from('expense_items').insert({
      'user_id': user.id,
      'name': name.trim(),
      'amount': amount,
      'category': category,
      'ai_categorized': false,
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
    });
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
  });

  final String id;
  final String name;
  final double amount;
  final String category;
  final DateTime expenseDate;

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: _toDouble(map['amount']),
      category: (map['category'] as String?) ?? 'other',
      expenseDate: DateTime.parse(map['expense_date'] as String),
    );
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
