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
              padding: EdgeInsets.fromLTRB(
                _responsiveGutter(context),
                14,
                _responsiveGutter(context),
                150,
              ),
              children: [
                _DashboardHeader(
                  onSignOut: () =>
                      ref.read(supabaseClientProvider).auth.signOut(),
                ),
                const SizedBox(height: 18),
                _DashboardHeroCard(
                  onScanReceipt: () => showReceiptUploadFlow(
                    context: context,
                    ref: ref,
                    onExpenseSaved: () => _invalidateExpenseData(ref),
                  ),
                  onAddExpense: () => _showAddExpense(context, ref),
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
                const SizedBox(height: 14),
                _StatsTeaserCard(currency: currency),
                const SizedBox(height: 12),
                _RecipesTeaserCard(currency: currency),
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

class _StatsTeaserCard extends StatelessWidget {
  const _StatsTeaserCard({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      padding: const EdgeInsets.all(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => StatsScreen(currency: currency),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: context.palette.accentGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bar_chart_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial stupidity charts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'See the category split and daily damage for this month.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _RecipesTeaserCard extends ConsumerWidget {
  const _RecipesTeaserCard({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(budgetSnapshotProvider).asData?.value;
    final index = snapshot?.desperationIndex ?? 0;
    final isLocked = index < 60;

    return FrostPanel(
      padding: const EdgeInsets.all(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RecipesScreen(currency: currency),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.palette.secondaryGlow.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.palette.border),
            ),
            child: Icon(
              Icons.restaurant_menu_outlined,
              color: context.palette.secondaryGlow,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What to cook',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  isLocked
                      ? 'Unlocks at desperation 60+. For now, hydrate.'
                      : 'Use what you have. AI will keep you alive.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
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

class _DashboardHeroCard extends ConsumerWidget {
  const _DashboardHeroCard({
    required this.onScanReceipt,
    required this.onAddExpense,
  });

  final VoidCallback onScanReceipt;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(budgetSnapshotProvider).asData?.value;
    final currency = ref.watch(userProfileProvider).asData?.value.currency ?? 'USD';
    final formatter = NumberFormat.simpleCurrency(name: currency);
    final dailyLimit = snapshot?.dailyLimit;
    final daysLeft = snapshot?.daysLeft;

    return FrostPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Can I afford this?'),
                    const SizedBox(height: 6),
                    Text(
                      'Track the money before it disappears.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (dailyLimit != null)
                SoftPill(
                  label: 'Today: ${formatter.format(dailyLimit)}',
                  icon: Icons.local_pizza_outlined,
                ),
              if (daysLeft != null)
                SoftPill(
                  label: '$daysLeft days left',
                  icon: Icons.calendar_month_outlined,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Snap a receipt or log an expense to keep the Desperation Index honest.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onScanReceipt,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scan receipt'),
              ),
              OutlinedButton.icon(
                onPressed: onAddExpense,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add expense'),
              ),
            ],
          ),
        ],
      ),
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
    final palette = context.palette;
    final borderRadius = BorderRadius.circular(4);

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(right: 3, bottom: 3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: palette.border,
                offset: const Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: palette.surface,
            borderRadius: borderRadius,
            child: InkWell(
              borderRadius: borderRadius,
              onTap: onPressed,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(color: palette.border, width: 2),
                ),
                child: Icon(icon, size: 20, color: palette.border),
              ),
            ),
          ),
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
