part of '../pizza_tracker_app.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({required this.currency, super.key});

  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final expenses = ref.watch(expenseHistoryProvider);
    final categorySpending = ref.watch(categorySpendingProvider);
    final summary = ref.watch(monthlySummaryProvider);
    final budget = ref.watch(budgetSnapshotProvider);
    final resolvedCurrency = profile.asData?.value.currency ?? currency;
    final formatter = NumberFormat.simpleCurrency(name: resolvedCurrency);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _StatsHeader(onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _refresh(ref),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                    children: [
                      summary.when(
                        data: (value) => _StatsSummaryCard(
                          summary: value,
                          budget: budget.asData?.value,
                          currency: resolvedCurrency,
                        ),
                        loading: () =>
                            const _LoadingCard(label: 'Loading summary...'),
                        error: (error, stackTrace) => _ErrorCard(error: error),
                      ),
                      const SizedBox(height: 14),
                      expenses.when(
                        data: (value) => _DailySpendingCard(
                          expenses: value,
                          currency: resolvedCurrency,
                        ),
                        loading: () =>
                            const _LoadingCard(label: 'Loading daily totals...'),
                        error: (error, stackTrace) => _ErrorCard(error: error),
                      ),
                      const SizedBox(height: 14),
                      categorySpending.when(
                        data: (value) => _CategoryPieCard(
                          spending: value,
                          currency: resolvedCurrency,
                        ),
                        loading: () =>
                            const _LoadingCard(label: 'Loading category totals...'),
                        error: (error, stackTrace) => _ErrorCard(error: error),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(expenseHistoryProvider);
    ref.invalidate(categorySpendingProvider);
    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(budgetSnapshotProvider);

    await Future.wait([
      ref.read(expenseHistoryProvider.future),
      ref.read(categorySpendingProvider.future),
      ref.read(monthlySummaryProvider.future),
    ]);
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 0),
      child: Row(
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
                const Kicker('Stats snapshot'),
                const SizedBox(height: 4),
                Text(
                  'Financial stupidity charts',
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

class _StatsSummaryCard extends StatelessWidget {
  const _StatsSummaryCard({
    required this.summary,
    required this.budget,
    required this.currency,
  });

  final MonthlySummary? summary;
  final BudgetSnapshot? budget;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.simpleCurrency(name: currency);
    final spent = summary?.totalSpent ?? 0;
    final receipts = summary?.receiptCount ?? 0;
    final monthLabel = summary == null
        ? 'This month'
        : DateFormat.yMMMM().format(summary!.month);
    final remaining = budget?.remainingBudget;
    final dailyLimit = budget?.dailyLimit;

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
                    const Kicker('Monthly pulse'),
                    const SizedBox(height: 6),
                    Text(
                      monthLabel,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              SoftPill(label: formatter.format(spent)),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final tileWidth = width >= 520
                  ? (width - 24) / 3
                  : (width - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: MetricTile(
                      label: 'Receipts',
                      value: '$receipts',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: MetricTile(
                      label: 'Remaining',
                      value: remaining == null
                          ? '—'
                          : formatter.format(remaining),
                      icon: Icons.savings_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: MetricTile(
                      label: 'Daily limit',
                      value: dailyLimit == null
                          ? '—'
                          : formatter.format(dailyLimit),
                      icon: Icons.local_pizza_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DailySpendingCard extends StatelessWidget {
  const _DailySpendingCard({
    required this.expenses,
    required this.currency,
  });

  final List<ExpenseItem> expenses;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.simpleCurrency(name: currency);
    final now = DateTime.now();
    final dailyTotals = _buildDailyTotals(expenses, now);
    final maxValue = dailyTotals.isEmpty
        ? 0
        : dailyTotals.map((entry) => entry.amount).reduce(
              (a, b) => a > b ? a : b,
            );

    return FrostPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Kicker('Daily damage'),
          const SizedBox(height: 6),
          Text(
            'Daily spending',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Last 14 days of spending in the current budget period.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (dailyTotals.isEmpty)
            const _ChartEmptyState(
              icon: Icons.bar_chart_rounded,
              message: 'No expenses logged for the last two weeks.',
            )
          else
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue <= 0 ? 10 : maxValue * 1.2,
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final entry = dailyTotals[groupIndex];
                        return BarTooltipItem(
                          '${DateFormat.Md().format(entry.date)}\n${formatter.format(entry.amount)}',
                          Theme.of(context).textTheme.bodySmall!,
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: maxValue <= 0 ? 1 : maxValue / 3,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || maxValue <= 0) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            formatter.format(value),
                            style: Theme.of(context).textTheme.labelSmall,
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= dailyTotals.length) {
                            return const SizedBox.shrink();
                          }
                          final entry = dailyTotals[index];
                          return Text(
                            DateFormat.Md().format(entry.date),
                            style: Theme.of(context).textTheme.labelSmall,
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxValue <= 0 ? 1 : maxValue / 3,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: context.palette.border.withValues(alpha: 0.4),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < dailyTotals.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: dailyTotals[i].amount,
                            width: 12,
                            borderRadius: BorderRadius.circular(6),
                            color: context.palette.primaryGlow,
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxValue <= 0 ? 10 : maxValue * 1.2,
                              color: context.palette.surfaceStrong,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryPieCard extends StatelessWidget {
  const _CategoryPieCard({
    required this.spending,
    required this.currency,
  });

  final List<CategorySpending> spending;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.simpleCurrency(name: currency);
    final total = spending.fold<double>(0, (sum, item) => sum + item.amount);

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
                    const Kicker('Where it went'),
                    const SizedBox(height: 6),
                    Text(
                      'Category split',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              SoftPill(label: formatter.format(total)),
            ],
          ),
          const SizedBox(height: 12),
          if (spending.isEmpty)
            const _ChartEmptyState(
              icon: Icons.pie_chart_outline,
              message: 'No category data in this period yet.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 520;
                final chart = SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 36,
                      sections: spending.map((item) {
                        final color = _categoryColor(item.category, context);
                        final percent = total <= 0
                            ? 0
                            : (item.amount / total * 100).round();
                        return PieChartSectionData(
                          value: item.amount,
                          color: color,
                          radius: 60,
                          title: percent > 0 ? '$percent%' : '',
                          titleStyle: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                );

                final breakdown = Column(
                  children: [
                    for (final item in spending) ...[
                      _CategorySplitRow(
                        label: _categoryLabel(item.category),
                        amount: formatter.format(item.amount),
                        color: _categoryColor(item.category, context),
                      ),
                      if (item != spending.last) const SizedBox(height: 8),
                    ],
                  ],
                );

                if (wide) {
                  return Row(
                    children: [
                      Expanded(child: chart),
                      const SizedBox(width: 18),
                      Expanded(child: breakdown),
                    ],
                  );
                }

                return Column(
                  children: [
                    chart,
                    const SizedBox(height: 16),
                    breakdown,
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CategorySplitRow extends StatelessWidget {
  const _CategorySplitRow({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          amount,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

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
      child: Row(
        children: [
          Icon(icon, color: context.palette.primaryGlow, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<_DailyTotal> _buildDailyTotals(List<ExpenseItem> expenses, DateTime now) {
  final totals = <DateTime, double>{};
  final dateFormat = DateFormat('yyyy-MM-dd');
  final start = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 13));

  for (final expense in expenses) {
    if (expense.expenseDate.isBefore(start)) {
      continue;
    }
    final dayKey = DateTime.parse(dateFormat.format(expense.expenseDate));
    totals[dayKey] = (totals[dayKey] ?? 0) + expense.amount;
  }

  final result = <_DailyTotal>[];
  for (var i = 0; i < 14; i++) {
    final day = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: 13 - i));
    final key = DateTime.parse(dateFormat.format(day));
    result.add(_DailyTotal(date: key, amount: totals[key] ?? 0));
  }

  return result;
}

class _DailyTotal {
  const _DailyTotal({required this.date, required this.amount});

  final DateTime date;
  final double amount;
}
