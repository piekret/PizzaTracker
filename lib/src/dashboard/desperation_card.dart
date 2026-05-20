part of '../pizza_tracker_app.dart';

class _DesperationCard extends StatelessWidget {
  const _DesperationCard({
    required this.snapshot,
    required this.currency,
    required this.onRefresh,
  });

  final BudgetSnapshot? snapshot;
  final String currency;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final value = snapshot;
    if (value == null) {
      return const _ErrorCard(error: 'No budget snapshot returned.');
    }

    final level = _levelForIndex(value.desperationIndex);
    final formatter = NumberFormat.simpleCurrency(name: currency);
    final progress = (value.desperationIndex / 100).clamp(0.0, 1.0);

    return FrostPanel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      level.color.withValues(alpha: 0.12),
                      context.palette.surface,
                      context.palette.secondaryGlow.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final actions = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SoftPill(
                            label: level.shortLabel,
                            icon: level.icon,
                            color: level.color,
                          ),
                          IconButton.filledTonal(
                            tooltip: context.text.isPolish
                                ? 'Odśwież budżet'
                                : 'Update budget snapshot',
                            onPressed: onRefresh,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      );

                      if (constraints.maxWidth < 300) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Kicker(
                              context.text.desperationIndex,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            actions,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Kicker(
                              context.text.desperationIndex,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          actions,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${value.desperationIndex}',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              color: level.color,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 9),
                        child: Text(
                          '/100',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    level.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: context.palette.border.withValues(
                        alpha: 0.42,
                      ),
                      valueColor: AlwaysStoppedAnimation(level.color),
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final tileWidth = width >= 560
                          ? (width - 36) / 4
                          : (width - 12) / 2;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: tileWidth,
                            child: MetricTile(
                              label: context.text.remaining,
                              value: formatter.format(value.remainingBudget),
                              icon: Icons.savings_outlined,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: MetricTile(
                              label: context.text.daysLeft,
                              value: '${value.daysLeft}',
                              icon: Icons.calendar_month_outlined,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: MetricTile(
                              label: context.text.dailyLimit,
                              value: formatter.format(value.dailyLimit),
                              icon: Icons.local_pizza_outlined,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: MetricTile(
                              label: context.text.spent,
                              value: formatter.format(value.spentThisPeriod),
                              icon: Icons.receipt_long_outlined,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
