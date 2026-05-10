part of '../pizza_tracker_app.dart';

class _RecentExpensesCard extends ConsumerWidget {
  const _RecentExpensesCard({required this.expenses, required this.currency});

  final List<ExpenseItem> expenses;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FrostPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Latest damage'),
                    const SizedBox(height: 6),
                    Text(
                      'Recent expenses',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              SoftPill(label: '${expenses.length} shown'),
            ],
          ),
          const SizedBox(height: 16),
          if (expenses.isEmpty)
            const _EmptyExpenses()
          else
            for (final expense in expenses) ...[
              _ExpenseRow(
                expense: expense,
                amount: NumberFormat.simpleCurrency(
                  name: currency,
                ).format(expense.amount),
                onEdit: () => _showEditExpense(context, ref, expense),
                onDelete: () => _deleteExpense(context, ref, expense),
              ),
              if (expense != expenses.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Future<void> _showEditExpense(
    BuildContext context,
    WidgetRef ref,
    ExpenseItem expense,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseSheet(expense: expense),
    );

    if (saved == true && context.mounted) {
      ref.invalidate(budgetSnapshotProvider);
      ref.invalidate(recentExpensesProvider);
      ref.invalidate(categorySpendingProvider);
    }
  }

  Future<void> _deleteExpense(
    BuildContext context,
    WidgetRef ref,
    ExpenseItem expense,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(appRepositoryProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete expense?'),
          content: Text('Remove ${expense.name} from your budget history?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await repository.deleteExpense(expense.id);
      if (!context.mounted) {
        return;
      }
      ref.invalidate(budgetSnapshotProvider);
      ref.invalidate(recentExpensesProvider);
      ref.invalidate(categorySpendingProvider);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses();

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
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 34,
            color: context.palette.primaryGlow,
          ),
          const SizedBox(height: 10),
          Text(
            'No expenses yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Add one before the pizza place does.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.amount,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseItem expense;
  final String amount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(expense.category, context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surfaceStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _categoryIcon(expense.category),
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '${_categoryLabel(expense.category)} - ${DateFormat.yMMMd().format(expense.expenseDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Expense actions',
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
                return;
              }
              onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
