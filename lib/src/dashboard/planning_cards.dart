part of '../pizza_tracker_app.dart';

class _BudgetSetupCard extends ConsumerWidget {
  const _BudgetSetupCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat.simpleCurrency(name: profile.currency);
    final needsSetup = profile.monthlyBudget <= 0;
    final text = context.text;

    final icon = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color:
            (needsSetup
                    ? context.palette.tertiaryGlow
                    : context.palette.primaryGlow)
                .withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border),
      ),
      child: Icon(
        needsSetup
            ? Icons.priority_high_rounded
            : Icons.account_balance_wallet_outlined,
        color: needsSetup
            ? context.palette.tertiaryGlow
            : context.palette.primaryGlow,
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          needsSetup
              ? text.isPolish
                    ? 'Budżet wciąż potrzebuje kwoty'
                    : 'Budget still needs a number'
              : text.monthlyBudgetLockedIn,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          needsSetup
              ? text.isPolish
                    ? 'Ustaw to najpierw, żeby aplikacja mogła uczciwie oceniać decyzje pizzowe.'
                    : 'Set this first so the app can judge your pizza decisions properly.'
              : text.isPolish
              ? '${formatter.format(profile.monthlyBudget)} resetuje się dnia ${profile.budgetResetDay}.'
              : '${formatter.format(profile.monthlyBudget)} resets on day ${profile.budgetResetDay}.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final action = FilledButton.tonal(
      onPressed: () async {
        final saved = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) => EditBudgetSheet(profile: profile),
        );
        if (saved == true) {
          ref.invalidate(userProfileProvider);
          ref.invalidate(budgetSnapshotProvider);
          ref.invalidate(categorySpendingProvider);
        }
      },
      child: Text(needsSetup ? (text.isPolish ? 'Ustaw' : 'Set') : text.edit),
    );

    return FrostPanel(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(width: 14),
                    Expanded(child: copy),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }

          return Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(child: copy),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _FixedExpensesCard extends ConsumerWidget {
  const _FixedExpensesCard({required this.expenses, required this.currency});

  final List<FixedExpense> expenses;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat.simpleCurrency(name: currency);
    final text = context.text;
    final activeTotal = expenses
        .where((expense) => expense.isActive)
        .fold<double>(0, (sum, expense) => sum + expense.amount);

    return FrostPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(
                    text.isPolish ? 'Planowanie budżetu' : 'Budget planning',
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text.fixedMonthlyCosts,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              );
              final pill = SoftPill(label: formatter.format(activeTotal));
              if (constraints.maxWidth < 320) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 10), pill],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 10),
                  pill,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (expenses.isEmpty)
            _PlanningEmptyState(
              icon: Icons.home_work_outlined,
              title: text.isPolish
                  ? 'Brak stałych kosztów'
                  : 'No fixed costs yet',
              text: text.isPolish
                  ? 'Dodaj koszty, które wracają co miesiąc, żeby dzienny limit był dokładniejszy.'
                  : 'Add monthly recurring costs so the daily limit is more accurate.',
              actionLabel: text.isPolish
                  ? 'Dodaj stały koszt'
                  : 'Add fixed cost',
              onPressed: () => _showAddFixedExpense(context, ref),
            )
          else ...[
            for (final expense in expenses) ...[
              _PlanningRow(
                icon: Icons.receipt_outlined,
                title: expense.name,
                subtitle: text.isPolish
                    ? 'Rozliczane dnia ${expense.billingDay}'
                    : 'Billed on day ${expense.billingDay}',
                amount: formatter.format(expense.amount),
                isMuted: !expense.isActive,
                onDelete: () => _deleteFixedExpense(context, ref, expense),
              ),
              if (expense != expenses.last) const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _showAddFixedExpense(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                text.isPolish ? 'Dodaj stały koszt' : 'Add fixed cost',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddFixedExpense(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddFixedExpenseSheet(),
    );

    if (saved == true) {
      ref.invalidate(fixedExpensesProvider);
      ref.invalidate(budgetSnapshotProvider);
    }
  }

  Future<void> _deleteFixedExpense(
    BuildContext context,
    WidgetRef ref,
    FixedExpense expense,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = context.text;

    try {
      await ref.read(appRepositoryProvider).deleteFixedExpense(expense.id);
      ref.invalidate(fixedExpensesProvider);
      ref.invalidate(budgetSnapshotProvider);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(text.translateKnown(error.toString()))),
      );
    }
  }
}

class _IncomeEventsCard extends ConsumerWidget {
  const _IncomeEventsCard({required this.events, required this.currency});

  final List<IncomeEvent> events;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat.simpleCurrency(name: currency);
    final text = context.text;
    final recurringTotal = events
        .where((event) => event.isRecurring)
        .fold<double>(0, (sum, event) => sum + event.amount);

    return FrostPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(
                    text.isPolish ? 'Kalendarz wpływów' : 'Income calendar',
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text.expectedIncome,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              );
              final pill = SoftPill(
                label: text.isPolish
                    ? '${formatter.format(recurringTotal)} cyklicznie'
                    : '${formatter.format(recurringTotal)} recurring',
              );
              if (constraints.maxWidth < 320) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 10), pill],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 10),
                  pill,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            _PlanningEmptyState(
              icon: Icons.event_available_outlined,
              title: text.isPolish ? 'Brak wpływów' : 'No income yet',
              text: text.isPolish
                  ? 'Dodaj wypłatę, stypendium albo inny regularny wpływ, żeby plan miesiąca był pełniejszy.'
                  : 'Add a paycheck, scholarship, or other regular income to complete the monthly plan.',
              actionLabel: text.isPolish ? 'Dodaj wpływ' : 'Add income',
              onPressed: () => _showAddIncomeEvent(context, ref),
            )
          else ...[
            for (final event in events) ...[
              _PlanningRow(
                icon: Icons.payments_outlined,
                title: event.name,
                subtitle: text.isPolish
                    ? '${event.isRecurring ? 'Cykliczne' : 'Jednorazowe'} dnia ${event.expectedDay}'
                    : '${event.isRecurring ? 'Recurring' : 'One-time'} on day ${event.expectedDay}',
                amount: formatter.format(event.amount),
                onDelete: () => _deleteIncomeEvent(context, ref, event),
              ),
              if (event != events.last) const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _showAddIncomeEvent(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(text.isPolish ? 'Dodaj wpływ' : 'Add income'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddIncomeEvent(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddIncomeEventSheet(),
    );

    if (saved == true) {
      ref.invalidate(incomeEventsProvider);
    }
  }

  Future<void> _deleteIncomeEvent(
    BuildContext context,
    WidgetRef ref,
    IncomeEvent event,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = context.text;

    try {
      await ref.read(appRepositoryProvider).deleteIncomeEvent(event.id);
      ref.invalidate(incomeEventsProvider);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(text.translateKnown(error.toString()))),
      );
    }
  }
}

class _PlanningEmptyState extends StatelessWidget {
  const _PlanningEmptyState({
    required this.icon,
    required this.title,
    required this.text,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String text;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.surfaceStrong,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 30, color: context.palette.primaryGlow),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _PlanningRow extends StatelessWidget {
  const _PlanningRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onDelete,
    this.isMuted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final VoidCallback onDelete;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final opacity = isMuted ? 0.55 : 1.0;

    return Opacity(
      opacity: opacity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useStackedActions = constraints.maxWidth < 360;

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.palette.surfaceStrong,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.palette.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.palette.primaryGlow.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: context.palette.primaryGlow,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (useStackedActions) ...[
                        const SizedBox(height: 8),
                        Text(
                          amount,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!useStackedActions)
                  Flexible(
                    child: Text(
                      amount,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: context.text.delete,
                  onPressed: onDelete,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
