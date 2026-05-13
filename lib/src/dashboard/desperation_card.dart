part of '../pizza_tracker_app.dart';

class _DesperationCard extends StatelessWidget {
  const _DesperationCard({required this.snapshot, required this.currency});

  final BudgetSnapshot? snapshot;
  final String currency;

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
                  Row(
                    children: [
                      const Kicker('Desperation Index'),
                      const Spacer(),
                      SoftPill(
                        label: level.shortLabel,
                        icon: level.icon,
                        color: level.color,
                      ),
                    ],
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
                      backgroundColor: context.palette.border.withValues(alpha: 0.42),
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
                              label: 'Remaining',
                              value: formatter.format(value.remainingBudget),
                              icon: Icons.savings_outlined,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: MetricTile(
                              label: 'Days left',
                              value: '${value.daysLeft}',
                              icon: Icons.calendar_month_outlined,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: MetricTile(
                              label: 'Daily limit',
                              value: formatter.format(value.dailyLimit),
                              icon: Icons.local_pizza_outlined,
                            ),
                          ),
                          SizedBox(
                            width: tileWidth,
                            child: MetricTile(
                              label: 'Spent',
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
