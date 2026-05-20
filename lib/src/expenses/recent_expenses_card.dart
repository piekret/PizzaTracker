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
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;
              final header = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(
                    context.text.isPolish ? 'Ostatnie wpisy' : 'Latest entries',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.text.recentExpenses,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _showExpenseHistory(context),
                    icon: const Icon(Icons.history_rounded),
                    label: Text(
                      context.text.isPolish ? 'Zobacz wszystko' : 'View all',
                    ),
                  ),
                  SoftPill(
                    label: context.text.isPolish
                        ? 'Pokazano: ${expenses.length}'
                        : '${expenses.length} shown',
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [header, const SizedBox(height: 12), actions],
                );
              }

              return Row(
                children: [
                  Expanded(child: header),
                  actions,
                ],
              );
            },
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
                onOpenReceipt: expense.receiptId == null
                    ? null
                    : () => showReceiptPreview(
                        context: context,
                        receiptId: expense.receiptId!,
                      ),
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
      ref.invalidate(expenseHistoryProvider);
      ref.invalidate(categorySpendingProvider);
    }
  }

  void _showExpenseHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpenseHistoryScreen(currency: currency),
      ),
    );
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
          title: Text(context.text.deleteExpenseQuestion),
          content: Text(context.text.removeExpenseFromHistory(expense.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.text.cancel),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.text.delete),
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
      ref.invalidate(expenseHistoryProvider);
      ref.invalidate(categorySpendingProvider);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(context.text.translateKnown(error.toString()))),
      );
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
            context.text.noExpensesYet,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.text.isPolish
                ? 'Dodaj paragon albo ręczny wydatek, żeby historia zaczęła mieć sens.'
                : 'Add a receipt or manual expense to start building your history.',
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
    this.onOpenReceipt,
  });

  final ExpenseItem expense;
  final String amount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onOpenReceipt;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(expense.category, context);
    final leading = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(_categoryIcon(expense.category), color: color, size: 22),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          expense.name,
          style: Theme.of(context).textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          '${_categoryLabel(expense.category)} - ${MaterialLocalizations.of(context).formatMediumDate(expense.expenseDate)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    final amountText = Text(
      amount,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final receiptButton = expense.receiptId == null
        ? null
        : IconButton(
            tooltip: context.text.isPolish ? 'Otwórz paragon' : 'Open receipt',
            onPressed: onOpenReceipt,
            icon: Icon(
              Icons.image_outlined,
              size: 19,
              color: context.palette.primaryGlow,
            ),
          );
    final menuButton = PopupMenuButton<String>(
      tooltip: context.text.isPolish ? 'Akcje wydatku' : 'Expense actions',
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
          return;
        }
        onDelete();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(context.text.edit),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(context.text.delete),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surfaceStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 330) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    menuButton,
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: amountText),
                    ?receiptButton,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: details),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(fit: BoxFit.scaleDown, child: amountText),
              ),
              if (receiptButton != null) ...[
                const SizedBox(width: 6),
                receiptButton,
              ],
              menuButton,
            ],
          );
        },
      ),
    );
  }
}
