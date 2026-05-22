part of '../pizza_tracker_app.dart';

class EditBudgetSheet extends ConsumerStatefulWidget {
  const EditBudgetSheet({required this.profile, super.key});

  final UserProfile profile;

  @override
  ConsumerState<EditBudgetSheet> createState() => _EditBudgetSheetState();
}

class _EditBudgetSheetState extends ConsumerState<EditBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _budgetController;
  late final TextEditingController _resetDayController;
  late final TextEditingController _currencyController;

  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController(
      text: widget.profile.monthlyBudget == 0
          ? ''
          : widget.profile.monthlyBudget.toStringAsFixed(2),
    );
    _resetDayController = TextEditingController(
      text: '${widget.profile.budgetResetDay}',
    );
    _currencyController = TextEditingController(
      text: _normalizeCurrencyCode(widget.profile.currency),
    );
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _resetDayController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref
          .read(appRepositoryProvider)
          .updateBudget(
            monthlyBudget: double.parse(
              _budgetController.text.replaceAll(',', '.'),
            ),
            budgetResetDay: int.parse(_resetDayController.text),
            currency: _currencyController.text,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return AppSheetFrame(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Kicker(text.isPolish ? 'Zasady miesiąca' : 'Monthly rules'),
            const SizedBox(height: 8),
            Text(
              text.isPolish ? 'Ustawienia budżetu' : 'Budget setup',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _budgetController,
              decoration: InputDecoration(
                labelText: text.isPolish
                    ? 'Budżet miesięczny'
                    : 'Monthly budget',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final amount = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                if (amount == null || amount < 0) {
                  return text.isPolish
                      ? 'Podaj poprawny budżet.'
                      : 'Enter a valid budget.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _resetDayController,
              decoration: InputDecoration(
                labelText: text.isPolish
                    ? 'Dzień resetu budżetu'
                    : 'Budget reset day',
                prefixIcon: const Icon(Icons.event_repeat_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final day = int.tryParse(value ?? '');
                if (day == null || day < 1 || day > 28) {
                  return text.useDayFrom1To28;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _normalizeCurrencyCode(_currencyController.text),
              decoration: InputDecoration(
                labelText: text.isPolish ? 'Waluta' : 'Currency',
                prefixIcon: const Icon(Icons.attach_money_outlined),
              ),
              selectedItemBuilder: (context) {
                return supportedCurrencies
                    .map((currency) => Text(currency))
                    .toList();
              },
              items: supportedCurrencies.map((currency) {
                return DropdownMenuItem(
                  value: currency,
                  child: Text(
                    _currencyLabel(context, currency),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) => _currencyController.text = value ?? 'PLN',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _InlineError(message: _error!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(text.isPolish ? 'Zapisz budżet' : 'Save budget'),
            ),
          ],
        ),
      ),
    );
  }
}
