part of '../pizza_tracker_app.dart';

class AddFixedExpenseSheet extends ConsumerStatefulWidget {
  const AddFixedExpenseSheet({super.key});

  @override
  ConsumerState<AddFixedExpenseSheet> createState() =>
      _AddFixedExpenseSheetState();
}

class _AddFixedExpenseSheetState extends ConsumerState<AddFixedExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _billingDayController = TextEditingController(text: '1');

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _billingDayController.dispose();
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
          .addFixedExpense(
            name: _nameController.text,
            amount: double.parse(_amountController.text.replaceAll(',', '.')),
            billingDay: int.parse(_billingDayController.text),
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
            const Kicker('Monthly fixed cost'),
            const SizedBox(height: 8),
            Text(
              'Add fixed cost',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.home_work_outlined),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Monthly amount',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validatePositiveAmount,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _billingDayController,
              decoration: const InputDecoration(
                labelText: 'Billing day',
                prefixIcon: Icon(Icons.event_repeat_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: _validateMonthDay,
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
                  : const Text('Save fixed cost'),
            ),
          ],
        ),
      ),
    );
  }
}

class AddIncomeEventSheet extends ConsumerStatefulWidget {
  const AddIncomeEventSheet({super.key});

  @override
  ConsumerState<AddIncomeEventSheet> createState() =>
      _AddIncomeEventSheetState();
}

class _AddIncomeEventSheetState extends ConsumerState<AddIncomeEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _expectedDayController = TextEditingController(text: '1');

  bool _isRecurring = true;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _expectedDayController.dispose();
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
          .addIncomeEvent(
            name: _nameController.text,
            amount: double.parse(_amountController.text.replaceAll(',', '.')),
            expectedDay: int.parse(_expectedDayController.text),
            isRecurring: _isRecurring,
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
            const Kicker('Incoming money'),
            const SizedBox(height: 8),
            Text(
              'Add income',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.work_outline),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validatePositiveAmount,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _expectedDayController,
              decoration: const InputDecoration(
                labelText: 'Expected day',
                prefixIcon: Icon(Icons.event_available_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: _validateMonthDay,
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isRecurring,
              onChanged: (value) => setState(() => _isRecurring = value),
              title: const Text('Repeats every month'),
              subtitle: const Text('Turn off for one-time transfers.'),
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
                  : const Text('Save income'),
            ),
          ],
        ),
      ),
    );
  }
}
