part of '../pizza_tracker_app.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final budget = ref.watch(budgetSnapshotProvider);
    final expenses = ref.watch(recentExpensesProvider);
    final categorySpending = ref.watch(categorySpendingProvider);
    final fixedExpenses = ref.watch(fixedExpensesProvider);
    final incomeEvents = ref.watch(incomeEventsProvider);
    final currency = profile.asData?.value.currency ?? 'USD';

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'dashboard-add-receipt',
            onPressed: () => showReceiptUploadFlow(
              context: context,
              ref: ref,
              onExpenseSaved: () => _invalidateExpenseData(ref),
            ),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Add receipt'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'dashboard-add-expense',
            onPressed: () => _showAddExpense(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add expense'),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 150),
              children: [
                _DashboardHeader(
                  onSignOut: () =>
                      ref.read(supabaseClientProvider).auth.signOut(),
                ),
                const SizedBox(height: 18),
                budget.when(
                  data: (value) =>
                      _DesperationCard(snapshot: value, currency: currency),
                  loading: () =>
                      const _LoadingCard(label: 'Calculating desperation...'),
                  error: (error, stackTrace) => _ErrorCard(
                    error: error,
                    hint:
                        'Check that the get_budget_snapshot RPC exists in Supabase.',
                  ),
                ),
                const SizedBox(height: 14),
                profile.when(
                  data: (value) => _BudgetSetupCard(profile: value),
                  loading: () =>
                      const _LoadingCard(label: 'Loading profile...'),
                  error: (error, stackTrace) => _ErrorCard(error: error),
                ),
                const SizedBox(height: 14),
                fixedExpenses.when(
                  data: (value) =>
                      _FixedExpensesCard(expenses: value, currency: currency),
                  loading: () =>
                      const _LoadingCard(label: 'Loading fixed costs...'),
                  error: (error, stackTrace) => _ErrorCard(error: error),
                ),
                const SizedBox(height: 14),
                incomeEvents.when(
                  data: (value) =>
                      _IncomeEventsCard(events: value, currency: currency),
                  loading: () =>
                      const _LoadingCard(label: 'Loading income schedule...'),
                  error: (error, stackTrace) => _ErrorCard(error: error),
                ),
                const SizedBox(height: 14),
                categorySpending.when(
                  data: (value) => _CategorySpendingCard(
                    spending: value,
                    currency: currency,
                  ),
                  loading: () =>
                      const _LoadingCard(label: 'Loading spending mix...'),
                  error: (error, stackTrace) => _ErrorCard(error: error),
                ),
                const SizedBox(height: 14),
                expenses.when(
                  data: (value) =>
                      _RecentExpensesCard(expenses: value, currency: currency),
                  loading: () =>
                      const _LoadingCard(label: 'Loading recent expenses...'),
                  error: (error, stackTrace) => _ErrorCard(error: error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(userProfileProvider);
    ref.invalidate(budgetSnapshotProvider);
    ref.invalidate(recentExpensesProvider);
    ref.invalidate(expenseHistoryProvider);
    ref.invalidate(categorySpendingProvider);
    ref.invalidate(fixedExpensesProvider);
    ref.invalidate(incomeEventsProvider);

    await Future.wait([
      ref.read(userProfileProvider.future),
      ref.read(budgetSnapshotProvider.future),
      ref.read(recentExpensesProvider.future),
      ref.read(categorySpendingProvider.future),
      ref.read(fixedExpensesProvider.future),
      ref.read(incomeEventsProvider.future),
    ]);
  }

  Future<void> _showAddExpense(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddExpenseSheet(),
    );

    if (saved == true && context.mounted) {
      _invalidateExpenseData(ref);
    }
  }

  void _invalidateExpenseData(WidgetRef ref) {
    ref.invalidate(budgetSnapshotProvider);
    ref.invalidate(recentExpensesProvider);
    ref.invalidate(expenseHistoryProvider);
    ref.invalidate(categorySpendingProvider);
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandMark(size: 50),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PizzaTracker',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                'Budget dashboard',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const _ThemePresetMenu(),
        const SizedBox(width: 8),
        _RoundIconButton(
          tooltip: 'Sign out',
          icon: Icons.logout_rounded,
          onPressed: onSignOut,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.palette.border),
          ),
          child: Icon(icon, size: 21),
        ),
      ),
    );
  }
}

class _ThemePresetMenu extends ConsumerWidget {
  const _ThemePresetMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appThemePresetProvider);

    return PopupMenuButton<AppThemePreset>(
      tooltip: 'Theme',
      initialValue: selected,
      onSelected: (preset) {
        ref.read(appThemePresetProvider.notifier).select(preset);
      },
      itemBuilder: (context) {
        return AppThemePreset.values.map((preset) {
          return PopupMenuItem(
            value: preset,
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: preset.palette.accentGradient,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(preset.label),
                      Text(
                        preset.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (preset == selected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.palette.border),
        ),
        child: const Icon(Icons.palette_outlined, size: 21),
      ),
    );
  }
}
