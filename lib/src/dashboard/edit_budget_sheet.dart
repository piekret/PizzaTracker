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
    _currencyController = TextEditingController(text: widget.profile.currency);
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
    return AppSheetFrame(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Kicker('Monthly rules'),
            const SizedBox(height: 8),
            Text(
              'Budget setup',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _budgetController,
              decoration: const InputDecoration(
                labelText: 'Monthly budget',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final amount = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                if (amount == null || amount < 0) {
                  return 'Enter a valid budget.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _resetDayController,
              decoration: const InputDecoration(
                labelText: 'Budget reset day',
                prefixIcon: Icon(Icons.event_repeat_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final day = int.tryParse(value ?? '');
                if (day == null || day < 1 || day > 28) {
                  return 'Use a day from 1 to 28.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _currencyController,
              decoration: const InputDecoration(
                labelText: 'Currency',
                prefixIcon: Icon(Icons.attach_money_outlined),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                final currency = (value ?? '').trim();
                if (currency.length < 3 || currency.length > 8) {
                  return 'Use a currency code like USD or PLN.';
                }
                return null;
              },
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
                  : const Text('Save budget'),
            ),
          ],
        ),
      ),
    );
  }
}
