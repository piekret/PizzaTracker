part of '../pizza_tracker_app.dart';

class _CategorySpendingCard extends StatelessWidget {
  const _CategorySpendingCard({required this.spending, required this.currency});

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
                    context.text.isPolish
                        ? 'Wydatki zmienne'
                        : 'Variable spending',
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.text.spendingMix,
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
          const SizedBox(height: 14),
          if (spending.isEmpty)
            const _CategorySpendingEmpty()
          else ...[
            Text(
              'Current budget period by category.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            for (final item in spending) ...[
              _CategorySpendingRow(
                spending: item,
                total: total,
                amount: formatter.format(item.amount),
              ),
              if (item != spending.last) const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _CategorySpendingEmpty extends StatelessWidget {
  const _CategorySpendingEmpty();

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
          Icon(Icons.pie_chart_outline, color: context.palette.primaryGlow),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No variable spending in this budget period yet.',
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

class _CategorySpendingRow extends StatelessWidget {
  const _CategorySpendingRow({
    required this.spending,
    required this.total,
    required this.amount,
  });

  final CategorySpending spending;
  final double total;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(spending.category, context);
    final share = total <= 0 ? 0.0 : (spending.amount / total).clamp(0.0, 1.0);
    final itemLabel = spending.itemCount == 1
        ? '1 item'
        : '${spending.itemCount} items';

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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_categoryIcon(spending.category), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _categoryLabel(spending.category),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          amount,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 8,
                    backgroundColor: context.palette.border.withValues(
                      alpha: 0.36,
                    ),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${(share * 100).round()}% of variable spending - $itemLabel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
