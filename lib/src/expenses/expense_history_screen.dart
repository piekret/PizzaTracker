part of '../pizza_tracker_app.dart';

class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  const ExpenseHistoryScreen({required this.currency, super.key});

  final String currency;

  @override
  ConsumerState<ExpenseHistoryScreen> createState() =>
      _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  final _searchController = TextEditingController();

  String _category = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final expenses = ref.watch(expenseHistoryProvider);
    final currency = profile.asData?.value.currency ?? widget.currency;
    final formatter = NumberFormat.simpleCurrency(name: currency);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'history-add-receipt',
            onPressed: () => showReceiptUploadFlow(
              context: context,
              ref: ref,
              onExpenseSaved: _invalidateExpenseData,
            ),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Add receipt'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'history-add-expense',
            onPressed: () => _showAddExpense(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add expense'),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _ExpenseHistoryHeader(onBack: () => Navigator.of(context).pop()),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _responsiveGutter(context),
                    12,
                    _responsiveGutter(context),
                    10,
                  ),
                  child: _HistoryFilters(
                    searchController: _searchController,
                    category: _category,
                  onSearchChanged: () => setState(() {}),
                  onCategoryChanged: (value) {
                    setState(() => _category = value);
                  },
                ),
              ),
              Expanded(
                child: expenses.when(
                  data: (value) {
                    final filtered = _filterExpenses(value);
                    final total = filtered.fold<double>(
                      0,
                      (sum, expense) => sum + expense.amount,
                    );

                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          _responsiveGutter(context),
                          0,
                          _responsiveGutter(context),
                          150,
                        ),
                        children: [
                          _HistorySummary(
                            count: filtered.length,
                            total: formatter.format(total),
                          ),
                          const SizedBox(height: 12),
                          if (filtered.isEmpty)
                            _HistoryEmpty(hasFilters: _hasFilters)
                          else
                            for (final expense in filtered) ...[
                              _ExpenseRow(
                                expense: expense,
                                amount: formatter.format(expense.amount),
                                onEdit: () =>
                                    _showEditExpense(context, expense),
                                onDelete: () =>
                                    _deleteExpense(context, expense),
                                onOpenReceipt: expense.receiptId == null
                                    ? null
                                    : () => showReceiptPreview(
                                        context: context,
                                        receiptId: expense.receiptId!,
                                      ),
                              ),
                              if (expense != filtered.last)
                                const SizedBox(height: 10),
                            ],
                        ],
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: _LoadingCard(label: 'Loading expense history...'),
                  ),
                  error: (error, stackTrace) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: _ErrorCard(error: error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasFilters =>
      _searchController.text.trim().isNotEmpty || _category != 'all';

  List<ExpenseItem> _filterExpenses(List<ExpenseItem> expenses) {
    final query = _searchController.text.trim().toLowerCase();

    return expenses.where((expense) {
      final matchesSearch =
          query.isEmpty || expense.name.toLowerCase().contains(query);
      final matchesCategory =
          _category == 'all' || expense.category == _category;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _refresh() async {
    ref.invalidate(expenseHistoryProvider);
    ref.invalidate(recentExpensesProvider);
    ref.invalidate(categorySpendingProvider);
    ref.invalidate(budgetSnapshotProvider);
    await ref.read(expenseHistoryProvider.future);
  }

  Future<void> _showAddExpense(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddExpenseSheet(),
    );

    if (saved == true && context.mounted) {
      _invalidateExpenseData();
    }
  }

  Future<void> _showEditExpense(
    BuildContext context,
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
      _invalidateExpenseData();
    }
  }

  Future<void> _deleteExpense(BuildContext context, ExpenseItem expense) async {
    final messenger = ScaffoldMessenger.of(context);
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
      await ref.read(appRepositoryProvider).deleteExpense(expense.id);
      if (!context.mounted) {
        return;
      }
      _invalidateExpenseData();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _invalidateExpenseData() {
    ref.invalidate(expenseHistoryProvider);
    ref.invalidate(recentExpensesProvider);
    ref.invalidate(categorySpendingProvider);
    ref.invalidate(budgetSnapshotProvider);
  }
}

class _ExpenseHistoryHeader extends StatelessWidget {
  const _ExpenseHistoryHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 26, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _RoundIconButton(
            tooltip: 'Back',
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Kicker('Full ledger'),
                const SizedBox(height: 4),
                Text(
                  'Expense history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.searchController,
    required this.category,
    required this.onSearchChanged,
    required this.onCategoryChanged,
  });

  final TextEditingController searchController;
  final String category;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            onChanged: (_) => onSearchChanged(),
            decoration: const InputDecoration(
              labelText: 'Search expenses',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CategoryFilterChip(
                  label: 'All',
                  selected: category == 'all',
                  onSelected: () => onCategoryChanged('all'),
                ),
                for (final value in expenseCategories) ...[
                  const SizedBox(width: 8),
                  _CategoryFilterChip(
                    label: _categoryLabel(value),
                    selected: category == value,
                    onSelected: () => onCategoryChanged(value),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.count, required this.total});

  final int count;
  final String total;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 expense' : '$count expenses';

    return FrostPanel(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;
          final pill = SoftPill(label: total);
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Kicker('Filtered total'),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.titleMedium),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 8),
                pill,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: content),
              pill,
            ],
          );
        },
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.hasFilters});

  final bool hasFilters;

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
            hasFilters ? Icons.filter_alt_off_outlined : Icons.receipt_outlined,
            size: 34,
            color: context.palette.primaryGlow,
          ),
          const SizedBox(height: 10),
          Text(
            hasFilters ? 'No matching expenses' : 'No expenses yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            hasFilters
                ? 'Try a different search or category.'
                : 'Add your first expense to start the ledger.',
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
