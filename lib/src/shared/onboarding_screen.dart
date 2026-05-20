part of '../pizza_tracker_app.dart';

class OnboardingSetupScreen extends ConsumerStatefulWidget {
  const OnboardingSetupScreen({required this.profile, super.key});

  final UserProfile profile;

  @override
  ConsumerState<OnboardingSetupScreen> createState() =>
      _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState extends ConsumerState<OnboardingSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _budgetController;
  late final TextEditingController _resetDayController;
  late final TextEditingController _currencyController;
  final _fixedNameController = TextEditingController();
  final _fixedAmountController = TextEditingController();
  final _fixedDayController = TextEditingController(text: '1');
  final _incomeNameController = TextEditingController();
  final _incomeAmountController = TextEditingController();
  final _incomeDayController = TextEditingController(text: '1');

  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController();
    _resetDayController = TextEditingController(
      text: '${widget.profile.budgetResetDay}',
    );
    _currencyController = TextEditingController(text: widget.profile.currency);
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _resetDayController.dispose();
    _currencyController.dispose();
    _fixedNameController.dispose();
    _fixedAmountController.dispose();
    _fixedDayController.dispose();
    _incomeNameController.dispose();
    _incomeAmountController.dispose();
    _incomeDayController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final repository = ref.read(appRepositoryProvider);
      await repository.updateBudget(
        monthlyBudget: double.parse(
          _budgetController.text.replaceAll(',', '.'),
        ),
        budgetResetDay: int.parse(_resetDayController.text),
        currency: _currencyController.text.trim(),
        onboardingCompleted: true,
      );

      if (_hasFixedExpense) {
        await repository.addFixedExpense(
          name: _fixedNameController.text.trim(),
          amount: double.parse(
            _fixedAmountController.text.replaceAll(',', '.'),
          ),
          billingDay: int.parse(_fixedDayController.text),
        );
      }

      if (_hasIncomeEvent) {
        await repository.addIncomeEvent(
          name: _incomeNameController.text.trim(),
          amount: double.parse(
            _incomeAmountController.text.replaceAll(',', '.'),
          ),
          expectedDay: int.parse(_incomeDayController.text),
          isRecurring: true,
        );
      }

      ref.invalidate(userProfileProvider);
      ref.invalidate(budgetSnapshotProvider);
      ref.invalidate(fixedExpensesProvider);
      ref.invalidate(incomeEventsProvider);
      ref.invalidate(categorySpendingProvider);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  bool get _hasFixedExpense =>
      _fixedNameController.text.trim().isNotEmpty ||
      _fixedAmountController.text.trim().isNotEmpty;

  bool get _hasIncomeEvent =>
      _incomeNameController.text.trim().isNotEmpty ||
      _incomeAmountController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                _responsiveGutter(context, maxWidth: 720),
                18,
                _responsiveGutter(context, maxWidth: 720),
                28,
              ),
              children: [
                _OnboardingHeader(
                  onSignOut: () =>
                      ref.read(supabaseClientProvider).auth.signOut(),
                ),
                const SizedBox(height: 18),
                FrostPanel(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker(text.isPolish ? 'Start budżetu' : 'Budget start'),
                      const SizedBox(height: 8),
                      Text(
                        text.isPolish
                            ? 'Ustaw podstawy w minutę'
                            : 'Set the basics in one minute',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        text.isPolish
                            ? 'Najpierw potrzebujemy budżetu miesięcznego. Stałe koszty i wpływy możesz dodać teraz albo później z dashboardu.'
                            : 'First we need your monthly budget. Fixed costs and income can be added now or later from the dashboard.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _OnboardingBudgetCard(
                  budgetController: _budgetController,
                  resetDayController: _resetDayController,
                  currencyController: _currencyController,
                ),
                const SizedBox(height: 14),
                _OnboardingOptionalCard(
                  kicker: text.isPolish ? 'Opcjonalnie' : 'Optional',
                  title: text.isPolish
                      ? 'Dodaj największy stały koszt'
                      : 'Add your biggest fixed cost',
                  description: text.isPolish
                      ? 'Czynsz, internet albo subskrypcja. Jeden wpis wystarczy na start.'
                      : 'Rent, internet, or a subscription. One entry is enough to start.',
                  nameController: _fixedNameController,
                  amountController: _fixedAmountController,
                  dayController: _fixedDayController,
                  nameLabel: text.isPolish ? 'Nazwa kosztu' : 'Cost name',
                  amountLabel: text.isPolish
                      ? 'Kwota miesięczna'
                      : 'Monthly amount',
                  dayLabel: text.isPolish ? 'Dzień rozliczenia' : 'Billing day',
                  icon: Icons.home_work_outlined,
                  onSkip: () {
                    _fixedNameController.clear();
                    _fixedAmountController.clear();
                    _fixedDayController.text = '1';
                  },
                ),
                const SizedBox(height: 14),
                _OnboardingOptionalCard(
                  kicker: text.isPolish ? 'Opcjonalnie' : 'Optional',
                  title: text.isPolish
                      ? 'Dodaj regularny wpływ'
                      : 'Add regular income',
                  description: text.isPolish
                      ? 'Stypendium, wypłata albo przelew od rodziców. To pomoże planować miesiąc.'
                      : 'Scholarship, paycheck, or parent transfer. This helps plan the month.',
                  nameController: _incomeNameController,
                  amountController: _incomeAmountController,
                  dayController: _incomeDayController,
                  nameLabel: text.isPolish ? 'Nazwa wpływu' : 'Income name',
                  amountLabel: text.amount,
                  dayLabel: text.isPolish ? 'Oczekiwany dzień' : 'Expected day',
                  icon: Icons.payments_outlined,
                  onSkip: () {
                    _incomeNameController.clear();
                    _incomeAmountController.clear();
                    _incomeDayController.text = '1';
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _InlineError(message: _error!),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _finish,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    text.isPolish
                        ? 'Zapisz i przejdź do dashboardu'
                        : 'Save and open dashboard',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandMark(size: 50),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PizzaTracker',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                context.text.isPolish ? 'Pierwsza konfiguracja' : 'First setup',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const _LanguageMenu(),
        const SizedBox(width: 8),
        _RoundIconButton(
          tooltip: context.text.signOut,
          icon: Icons.logout_rounded,
          onPressed: onSignOut,
        ),
      ],
    );
  }
}

class _OnboardingBudgetCard extends StatelessWidget {
  const _OnboardingBudgetCard({
    required this.budgetController,
    required this.resetDayController,
    required this.currencyController,
  });

  final TextEditingController budgetController;
  final TextEditingController resetDayController;
  final TextEditingController currencyController;

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    return FrostPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(text.isPolish ? 'Wymagane' : 'Required'),
          const SizedBox(height: 8),
          Text(
            text.isPolish ? 'Twój budżet miesięczny' : 'Your monthly budget',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: budgetController,
            decoration: InputDecoration(
              labelText: text.isPolish ? 'Budżet miesięczny' : 'Monthly budget',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final amount = double.tryParse(
                (value ?? '').replaceAll(',', '.'),
              );
              if (amount == null || amount <= 0) {
                return text.isPolish
                    ? 'Podaj budżet większy od 0.'
                    : 'Enter a budget above 0.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final resetField = TextFormField(
                controller: resetDayController,
                decoration: InputDecoration(
                  labelText: text.isPolish
                      ? 'Dzień resetu budżetu'
                      : 'Budget reset day',
                  prefixIcon: const Icon(Icons.event_repeat_outlined),
                ),
                keyboardType: TextInputType.number,
                validator: _validateMonthDay,
              );
              final currencyField = TextFormField(
                controller: currencyController,
                decoration: InputDecoration(
                  labelText: text.isPolish ? 'Waluta' : 'Currency',
                  prefixIcon: const Icon(Icons.attach_money_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  final currency = (value ?? '').trim();
                  if (currency.length < 3 || currency.length > 8) {
                    return text.isPolish
                        ? 'Użyj kodu waluty, np. USD albo PLN.'
                        : 'Use a currency code like USD or PLN.';
                  }
                  return null;
                },
              );

              if (constraints.maxWidth < 420) {
                return Column(
                  children: [
                    resetField,
                    const SizedBox(height: 12),
                    currencyField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: resetField),
                  const SizedBox(width: 12),
                  Expanded(child: currencyField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OnboardingOptionalCard extends StatefulWidget {
  const _OnboardingOptionalCard({
    required this.kicker,
    required this.title,
    required this.description,
    required this.nameController,
    required this.amountController,
    required this.dayController,
    required this.nameLabel,
    required this.amountLabel,
    required this.dayLabel,
    required this.icon,
    required this.onSkip,
  });

  final String kicker;
  final String title;
  final String description;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController dayController;
  final String nameLabel;
  final String amountLabel;
  final String dayLabel;
  final IconData icon;
  final VoidCallback onSkip;

  @override
  State<_OnboardingOptionalCard> createState() =>
      _OnboardingOptionalCardState();
}

class _OnboardingOptionalCardState extends State<_OnboardingOptionalCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    return FrostPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, color: context.palette.primaryGlow),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Kicker(widget.kicker, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                if (_expanded) {
                  widget.onSkip();
                }
                setState(() => _expanded = !_expanded);
              },
              icon: Icon(_expanded ? Icons.expand_less : Icons.add_rounded),
              label: Text(
                _expanded
                    ? text.isPolish
                          ? 'Pomiń'
                          : 'Skip'
                    : text.isPolish
                    ? 'Dodaj teraz'
                    : 'Add now',
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.nameController,
              decoration: InputDecoration(
                labelText: widget.nameLabel,
                prefixIcon: const Icon(Icons.label_outline),
              ),
              textInputAction: TextInputAction.next,
              validator: _optionalNameValidator,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final amountField = TextFormField(
                  controller: widget.amountController,
                  decoration: InputDecoration(
                    labelText: widget.amountLabel,
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _optionalAmountValidator,
                );
                final dayField = TextFormField(
                  controller: widget.dayController,
                  decoration: InputDecoration(
                    labelText: widget.dayLabel,
                    prefixIcon: const Icon(Icons.event_available_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _optionalDayValidator,
                );

                if (constraints.maxWidth < 420) {
                  return Column(
                    children: [
                      amountField,
                      const SizedBox(height: 12),
                      dayField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: amountField),
                    const SizedBox(width: 12),
                    Expanded(child: dayField),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasAnyValue =>
      widget.nameController.text.trim().isNotEmpty ||
      widget.amountController.text.trim().isNotEmpty;

  String? _optionalNameValidator(String? value) {
    if (!_expanded || !_hasAnyValue) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return context.text.nameRequired;
    }
    return null;
  }

  String? _optionalAmountValidator(String? value) {
    if (!_expanded || !_hasAnyValue) {
      return null;
    }
    return _validatePositiveAmount(value);
  }

  String? _optionalDayValidator(String? value) {
    if (!_expanded || !_hasAnyValue) {
      return null;
    }
    return _validateMonthDay(value);
  }
}
