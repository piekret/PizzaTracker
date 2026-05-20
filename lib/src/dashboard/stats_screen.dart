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
                    padding: EdgeInsets.fromLTRB(
                      _responsiveGutter(context),
                      6,
                      _responsiveGutter(context),
                      120,
                    ),
                    children: [
                      _StatsHeroCard(currency: resolvedCurrency),
                      const SizedBox(height: 14),
                      summary.when(
                        data: (value) => _StatsSummaryCard(
                          summary: value,
                          budget: budget.asData?.value,
                          currency: resolvedCurrency,
                        ),
                        loading: () =>
                            _LoadingCard(label: context.text.loadingSummary),
                        error: (error, stackTrace) => _ErrorCard(error: error),
                      ),
                      const SizedBox(height: 14),
                      expenses.when(
                        data: (value) => _DailySpendingCard(
                          expenses: value,
                          currency: resolvedCurrency,
                        ),
                        loading: () => _LoadingCard(
                          label: context.text.loadingDailyTotals,
                        ),
                        error: (error, stackTrace) => _ErrorCard(error: error),
                      ),
                      const SizedBox(height: 14),
                      categorySpending.when(
                        data: (value) => _CategoryPieCard(
                          spending: value,
                          currency: resolvedCurrency,
                        ),
                        loading: () => _LoadingCard(
                          label: context.text.loadingCategoryTotals,
                        ),
                        error: (error, stackTrace) => _ErrorCard(error: error),
                      ),
                      const SizedBox(height: 14),
                      _InsightsActionCard(currency: resolvedCurrency),
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
      padding: const EdgeInsets.fromLTRB(14, 26, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _RoundIconButton(
            tooltip: context.text.back,
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(context.text.statsSnapshot),
                const SizedBox(height: 4),
                Text(
                  context.text.financialCharts,
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
        ? context.text.thisMonth
        : DateFormat.yMMMM(
            context.text.appLanguage.code,
          ).format(summary!.month);
    final remaining = budget?.remainingBudget;
    final dailyLimit = budget?.dailyLimit;

    return FrostPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(context.text.monthlyPulse),
                  const SizedBox(height: 6),
                  Text(
                    monthLabel,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
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
                      label: context.text.receipts,
                      value: '$receipts',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: MetricTile(
                      label: context.text.remaining,
                      value: remaining == null
                          ? '—'
                          : formatter.format(remaining),
                      icon: Icons.savings_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: MetricTile(
                      label: context.text.dailyLimit,
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

class _StatsHeroCard extends ConsumerWidget {
  const _StatsHeroCard({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(budgetSnapshotProvider).asData?.value;
    final formatter = NumberFormat.simpleCurrency(name: currency);
    final spent = budget?.spentThisPeriod ?? 0;
    final remaining = budget?.remainingBudget ?? 0;
    final daysLeft = budget?.daysLeft ?? 0;
    final level = _levelForIndex(budget?.desperationIndex ?? 0);

    return FrostPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(context.text.budgetStory),
                  const SizedBox(height: 6),
                  Text(
                    context.text.thisMonthInOneGlance,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              SoftPill(
                label: level.shortLabel,
                icon: level.icon,
                color: level.color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            level.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: budget == null
                  ? 0
                  : (budget.spentThisPeriod /
                            (budget.disposableBudget == 0
                                ? 1
                                : budget.disposableBudget))
                        .clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: context.palette.border.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(level.color),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final tileWidth = width >= 520 ? (width - 24) / 3 : width;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: MetricTile(
                      label: context.text.spent,
                      value: formatter.format(spent),
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: MetricTile(
                      label: context.text.remaining,
                      value: formatter.format(remaining),
                      icon: Icons.savings_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: MetricTile(
                      label: context.text.daysLeft,
                      value: '$daysLeft',
                      icon: Icons.calendar_month_outlined,
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

class _AbsurdPurchaseRow extends StatelessWidget {
  const _AbsurdPurchaseRow({required this.purchase, required this.amount});

  final AbsurdPurchase purchase;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(purchase.category, context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_categoryIcon(purchase.category), color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                purchase.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                '${_categoryLabel(purchase.category)} - ${DateFormat.yMMMd().format(purchase.date)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (purchase.note != null && purchase.note!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  purchase.note!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryCalloutRow extends StatelessWidget {
  const _CategoryCalloutRow({required this.callout, required this.amount});

  final CategoryCallout callout;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(callout.category, context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_categoryIcon(callout.category), color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _categoryLabel(callout.category),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                callout.note,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightsActionCard extends ConsumerStatefulWidget {
  const _InsightsActionCard({required this.currency});

  final String currency;

  @override
  ConsumerState<_InsightsActionCard> createState() =>
      _InsightsActionCardState();
}

class _InsightsActionCardState extends ConsumerState<_InsightsActionCard> {
  InsightsRequest? _request;
  bool _forceRefresh = false;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final request = InsightsRequest(
      month: month,
      languageCode: ref.watch(appLanguageProvider).code,
    );
    final activeRequest = _request?.languageCode == request.languageCode
        ? _request
        : null;

    return FrostPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(text.aiInsights),
          const SizedBox(height: 6),
          Text(
            text.isPolish ? 'Miesięczny roast' : 'Monthly roast',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            text.isPolish
                ? 'Wygeneruj brutalnie szczere podsumowanie wydatków z tego miesiąca.'
                : 'Generate a brutally honest summary of your spending this month.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              setState(() => _request = request);
              _forceRefresh = false;
              ref.invalidate(insightsProvider(request));
            },
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(text.generateInsights),
          ),
          if (activeRequest != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() => _forceRefresh = true);
                ref.invalidate(insightsRefreshProvider(activeRequest));
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(text.isPolish ? 'Wygeneruj ponownie' : 'Regenerate'),
            ),
          ],
          if (activeRequest != null) ...[
            const SizedBox(height: 14),
            _InsightsResult(
              request: activeRequest,
              currency: widget.currency,
              forceRefresh: _forceRefresh,
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightsResult extends ConsumerWidget {
  const _InsightsResult({
    required this.request,
    required this.currency,
    required this.forceRefresh,
  });

  final InsightsRequest request;
  final String currency;
  final bool forceRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat.simpleCurrency(name: currency);
    final insights = forceRefresh
        ? ref.watch(insightsRefreshProvider(request))
        : ref.watch(insightsProvider(request));

    return insights.when(
      data: (value) {
        final data = value.insights;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.summary, style: Theme.of(context).textTheme.bodyMedium),
            if (value.cached) ...[
              const SizedBox(height: 6),
              SoftPill(label: context.text.cachedResult),
            ],
            if (data.categoryCallouts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.text.isPolish
                    ? 'Komentarze kategorii'
                    : 'Category callouts',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              for (final item in data.categoryCallouts) ...[
                _CategoryCalloutRow(
                  callout: item,
                  amount: formatter.format(item.amount),
                ),
                if (item != data.categoryCallouts.last)
                  const SizedBox(height: 8),
              ],
            ],
            if (data.absurdPurchases.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.text.isPolish
                    ? 'Top 3 absurdalne zakupy'
                    : 'Top 3 absurd purchases',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              for (final item in data.absurdPurchases) ...[
                _AbsurdPurchaseRow(
                  purchase: item,
                  amount: formatter.format(item.amount),
                ),
                if (item != data.absurdPurchases.last)
                  const SizedBox(height: 8),
              ],
            ],
          ],
        );
      },
      loading: () => _LoadingCard(label: context.text.generatingInsights),
      error: (error, stackTrace) => _ErrorCard(error: error),
    );
  }
}

class _DailySpendingCard extends StatelessWidget {
  const _DailySpendingCard({required this.expenses, required this.currency});

  final List<ExpenseItem> expenses;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.simpleCurrency(name: currency);
    final compactFormatter = NumberFormat.compactSimpleCurrency(name: currency);
    final now = DateTime.now();
    final dailyTotals = _buildDailyTotals(expenses, now);
    final maxValue = dailyTotals.isEmpty
        ? 0.0
        : dailyTotals
              .map((entry) => entry.amount)
              .reduce((a, b) => a > b ? a : b);

    return FrostPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(context.text.isPolish ? 'Dzienne szkody' : 'Daily damage'),
          const SizedBox(height: 6),
          Text(
            context.text.isPolish ? 'Dzienne wydatki' : 'Daily spending',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            context.text.isPolish
                ? 'Ostatnie 14 dni wydatków w bieżącym okresie budżetowym.'
                : 'Last 14 days of spending in the current budget period.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (dailyTotals.isEmpty)
            _ChartEmptyState(
              icon: Icons.bar_chart_rounded,
              message: context.text.isPolish
                  ? 'Brak wydatków z ostatnich dwóch tygodni.'
                  : 'No expenses logged for the last two weeks.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 520;
                final barWidth = isNarrow ? 8.0 : 12.0;
                final interval = maxValue <= 0 ? 1.0 : maxValue / 3.0;
                return SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxValue <= 0 ? 10.0 : maxValue * 1.2,
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
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: interval,
                            reservedSize: isNarrow ? 32 : 42,
                            getTitlesWidget: (value, meta) {
                              if (value == 0 || maxValue <= 0) {
                                return const SizedBox.shrink();
                              }
                              final label = isNarrow
                                  ? compactFormatter.format(value)
                                  : formatter.format(value);
                              return Text(
                                label,
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
                              if (isNarrow && index.isOdd) {
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
                        horizontalInterval: interval,
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
                                width: barWidth,
                                borderRadius: BorderRadius.circular(6),
                                color: context.palette.primaryGlow,
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxValue <= 0 ? 10.0 : maxValue * 1.2,
                                  color: context.palette.surfaceStrong,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CategoryPieCard extends StatelessWidget {
  const _CategoryPieCard({required this.spending, required this.currency});

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
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(
                    context.text.isPolish ? 'Gdzie to poszło' : 'Where it went',
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.text.isPolish
                        ? 'Podział kategorii'
                        : 'Category split',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              );
              final pill = SoftPill(label: formatter.format(total));
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
          const SizedBox(height: 12),
          if (spending.isEmpty)
            _ChartEmptyState(
              icon: Icons.pie_chart_outline,
              message: context.text.isPolish
                  ? 'Brak danych kategorii w tym okresie.'
                  : 'No category data in this period yet.',
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
                        return PieChartSectionData(
                          value: item.amount,
                          color: color,
                          radius: 60,
                          title: total <= 0
                              ? '0%'
                              : '${(item.amount / total * 100).round()}%',
                          titleStyle: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: Colors.white),
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
                  children: [chart, const SizedBox(height: 16), breakdown],
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
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
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 13));

  for (final expense in expenses) {
    if (expense.expenseDate.isBefore(start)) {
      continue;
    }
    final dayKey = DateTime.parse(dateFormat.format(expense.expenseDate));
    totals[dayKey] = (totals[dayKey] ?? 0) + expense.amount;
  }

  final result = <_DailyTotal>[];
  for (var i = 0; i < 14; i++) {
    final day = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: 13 - i));
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
