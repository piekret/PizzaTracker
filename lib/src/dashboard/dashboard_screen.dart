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
      floatingActionButton: Builder(
        builder: (context) {
          final compactActions = MediaQuery.sizeOf(context).width < 360;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              compactActions
                  ? FloatingActionButton.small(
                      heroTag: 'dashboard-add-receipt',
                      tooltip: context.text.addReceipt,
                      onPressed: () => showReceiptUploadFlow(
                        context: context,
                        ref: ref,
                        onExpenseSaved: () => _refreshExpenseData(ref),
                      ),
                      child: const Icon(Icons.document_scanner_outlined),
                    )
                  : FloatingActionButton.extended(
                      heroTag: 'dashboard-add-receipt',
                      onPressed: () => showReceiptUploadFlow(
                        context: context,
                        ref: ref,
                        onExpenseSaved: () => _refreshExpenseData(ref),
                      ),
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: Text(context.text.addReceipt),
                    ),
              const SizedBox(height: 10),
              compactActions
                  ? FloatingActionButton.small(
                      heroTag: 'dashboard-add-expense',
                      tooltip: context.text.addExpense,
                      onPressed: () => _showAddExpense(context, ref),
                      child: const Icon(Icons.add_rounded),
                    )
                  : FloatingActionButton.extended(
                      heroTag: 'dashboard-add-expense',
                      onPressed: () => _showAddExpense(context, ref),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(context.text.addExpense),
                    ),
            ],
          );
        },
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
                    onExpenseSaved: () => _refreshExpenseData(ref),
                  ),
                  onAddExpense: () => _showAddExpense(context, ref),
                ),
                if (expenses.asData?.value.isEmpty ?? false) ...[
                  const SizedBox(height: 14),
                  _FirstRunNextStepCard(
                    onScanReceipt: () => showReceiptUploadFlow(
                      context: context,
                      ref: ref,
                      onExpenseSaved: () => _refreshExpenseData(ref),
                    ),
                    onAddExpense: () => _showAddExpense(context, ref),
                    onAddFixedCost: () => _showAddFixedExpense(context, ref),
                  ),
                ],
                const SizedBox(height: 18),
                budget.when(
                  data: (value) => _DesperationCard(
                    snapshot: value,
                    currency: currency,
                    onRefresh: () => _refreshExpenseData(ref),
                  ),
                  loading: () =>
                      _LoadingCard(label: context.text.calculatingDesperation),
                  error: (error, stackTrace) => _ErrorCard(
                    error: error,
                    hint:
                        'Pull to refresh. If this keeps happening, check your profile and budget data.',
                  ),
                ),
                const SizedBox(height: 14),
                profile.when(
                  data: (value) => _BudgetSetupCard(profile: value),
                  loading: () =>
                      _LoadingCard(label: context.text.loadingProfile),
                  error: (error, stackTrace) => _ErrorCard(error: error),
                ),
                const SizedBox(height: 14),
                fixedExpenses.when(
                  data: (value) =>
                      _FixedExpensesCard(expenses: value, currency: currency),
                  loading: () => _LoadingCard(
                    label: context.text.translateKnown(
                      'Loading fixed costs...',
                    ),
                  ),
                  error: (error, stackTrace) => _ErrorCard(error: error),
                ),
                const SizedBox(height: 14),
                incomeEvents.when(
                  data: (value) =>
                      _IncomeEventsCard(events: value, currency: currency),
                  loading: () => _LoadingCard(
                    label: context.text.translateKnown(
                      'Loading income schedule...',
                    ),
                  ),
                  error: (error, stackTrace) => _ErrorCard(error: error),
                ),
                const SizedBox(height: 14),
                categorySpending.when(
                  data: (value) => _CategorySpendingCard(
                    spending: value,
                    currency: currency,
                  ),
                  loading: () => _LoadingCard(
                    label: context.text.translateKnown(
                      'Loading spending mix...',
                    ),
                  ),
                  error: (error, stackTrace) => _ErrorCard(error: error),
                ),
                const SizedBox(height: 14),
                expenses.when(
                  data: (value) =>
                      _RecentExpensesCard(expenses: value, currency: currency),
                  loading: () => _LoadingCard(
                    label: context.text.translateKnown(
                      'Loading recent expenses...',
                    ),
                  ),
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
      await _refreshExpenseData(ref);
    }
  }

  Future<void> _showAddFixedExpense(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddFixedExpenseSheet(),
    );

    if (saved == true && context.mounted) {
      ref.invalidate(fixedExpensesProvider);
      ref.invalidate(budgetSnapshotProvider);
      await Future.wait([
        ref.read(fixedExpensesProvider.future),
        ref.read(budgetSnapshotProvider.future),
      ]);
    }
  }

  Future<void> _refreshExpenseData(WidgetRef ref) async {
    ref.invalidate(budgetSnapshotProvider);
    ref.invalidate(recentExpensesProvider);
    ref.invalidate(expenseHistoryProvider);
    ref.invalidate(categorySpendingProvider);

    await Future.wait([
      ref.read(budgetSnapshotProvider.future),
      ref.read(recentExpensesProvider.future),
      ref.read(categorySpendingProvider.future),
    ]);
  }
}

class _FirstRunNextStepCard extends StatelessWidget {
  const _FirstRunNextStepCard({
    required this.onScanReceipt,
    required this.onAddExpense,
    required this.onAddFixedCost,
  });

  final VoidCallback onScanReceipt;
  final VoidCallback onAddExpense;
  final VoidCallback onAddFixedCost;

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    return FrostPanel(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final icon = Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: context.palette.accentGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.rocket_launch_outlined,
              color: Colors.white,
            ),
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker(text.isPolish ? 'Następny krok' : 'Next step'),
              const SizedBox(height: 6),
              Text(
                text.isPolish
                    ? 'Budżet gotowy. Dodaj pierwszy wydatek.'
                    : 'Budget ready. Add your first expense.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                text.isPolish
                    ? 'Po pierwszym wpisie dzienny limit, kategorie i podpowiedzi zaczną pokazywać realny obraz miesiąca.'
                    : 'After the first entry, the daily limit, categories, and insights start reflecting the real month.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: onScanReceipt,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: Text(
                      text.isPolish
                          ? 'Skanuj pierwszy paragon'
                          : 'Scan first receipt',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onAddExpense,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(text.addExpense),
                  ),
                  TextButton.icon(
                    onPressed: onAddFixedCost,
                    icon: const Icon(Icons.home_work_outlined),
                    label: Text(
                      text.isPolish ? 'Dodaj stały koszt' : 'Add fixed cost',
                    ),
                  ),
                ],
              ),
            ],
          );

          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [icon, const SizedBox(height: 14), copy],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
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
                  context.text.financialCharts,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  context.text.isPolish
                      ? 'Zobacz kategorie, tempo wydatków i dni, które najbardziej bolały.'
                      : 'See categories, spending pace, and the days that hit hardest.',
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
                  context.text.whatToCook,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  isLocked
                      ? context.text.isPolish
                            ? 'Odblokuje się przy Indeksie Desperacji 60+.'
                            : 'Unlocks when the Desperation Index reaches 60+.'
                      : context.text.isPolish
                      ? 'Zrób tani posiłek z tego, co już masz.'
                      : 'Make a cheap meal from what you already have.',
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
    final text = context.text;
    final titleBlock = Row(
      children: [
        const BrandMark(size: 50),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PizzaTracker',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                text.isPolish ? 'Panel budżetu' : 'Budget dashboard',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        const _ThemePresetMenu(),
        const _LanguageMenu(),
        _RoundIconButton(
          tooltip: text.signOut,
          icon: Icons.logout_rounded,
          onPressed: onSignOut,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleBlock,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
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
    final text = context.text;
    final snapshot = ref.watch(budgetSnapshotProvider).asData?.value;
    final currency =
        ref.watch(userProfileProvider).asData?.value.currency ?? 'USD';
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
                    Kicker(text.canIAffordThis),
                    const SizedBox(height: 6),
                    Text(
                      text.isPolish
                          ? 'Śledź pieniądze, zanim znikną.'
                          : 'Track the money before it disappears.',
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
                  label: text.isPolish
                      ? 'Dzisiaj: ${formatter.format(dailyLimit)}'
                      : 'Today: ${formatter.format(dailyLimit)}',
                  icon: Icons.local_pizza_outlined,
                ),
              if (daysLeft != null)
                SoftPill(
                  label: text.isPolish
                      ? '$daysLeft dni do końca'
                      : '$daysLeft days left',
                  icon: Icons.calendar_month_outlined,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text.isPolish
                ? 'Aktualizuj wydatki, żeby dzienny limit i Indeks Desperacji były wiarygodne.'
                : 'Keep expenses updated so the daily limit and Desperation Index stay accurate.',
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
                label: Text(text.scanReceipt),
              ),
              OutlinedButton.icon(
                onPressed: onAddExpense,
                icon: const Icon(Icons.add_rounded),
                label: Text(text.addExpense),
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
    final text = context.text;

    return PopupMenuButton<AppThemePreset>(
      tooltip: context.text.theme,
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
                      Text(_themePresetLabel(preset, text)),
                      Text(
                        _themePresetDescription(preset, text),
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

  String _themePresetLabel(AppThemePreset preset, AppText text) {
    if (!text.isPolish) {
      return preset.label;
    }

    return switch (preset) {
      AppThemePreset.pizza => 'Księga Margherity',
      AppThemePreset.midnight => 'Oksfordzki granat',
      AppThemePreset.matcha => 'Targowa zieleń',
      AppThemePreset.berry => 'Jagodowy paragon',
      AppThemePreset.espresso => 'Księga espresso',
    };
  }

  String _themePresetDescription(AppThemePreset preset, AppText text) {
    if (!text.isPolish) {
      return preset.description;
    }

    return switch (preset) {
      AppThemePreset.pizza => 'Ciepłe pomidorowe i papierowe tony',
      AppThemePreset.midnight => 'Ciemny granat wieczornego rejestru',
      AppThemePreset.matcha => 'Spokojna zielona paleta notatnika',
      AppThemePreset.berry => 'Ciemne jagody i archiwum paragonów',
      AppThemePreset.espresso => 'Kawa, tusz i stare księgi',
    };
  }
}

class _LanguageMenu extends ConsumerWidget {
  const _LanguageMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appLanguageProvider);

    return PopupMenuButton<AppLanguage>(
      tooltip: context.text.language,
      initialValue: selected,
      onSelected: (language) {
        ref.read(appLanguageProvider.notifier).select(language);
      },
      itemBuilder: (context) {
        return AppLanguage.values.map((language) {
          return PopupMenuItem(
            value: language,
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    language.shortLabel,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(child: Text(language.label)),
                if (language == selected)
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
        child: Center(
          child: Text(
            selected.shortLabel,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}
