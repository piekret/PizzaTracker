part of '../pizza_tracker_app.dart';

class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({
    this.expense,
    this.receipt,
    this.receiptAnalysis,
    super.key,
  });

  final ExpenseItem? expense;
  final ReceiptUpload? receipt;
  final ReceiptAnalysis? receiptAnalysis;

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  String _category = 'food';
  DateTime _expenseDate = DateTime.now();
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.expense != null;
  String? get _attachedReceiptId =>
      widget.receipt?.id ?? widget.expense?.receiptId;
  bool get _hasReceiptAutofill =>
      widget.receiptAnalysis?.hasUsefulSuggestion == true && !_isEditing;

  @override
  void initState() {
    super.initState();

    final expense = widget.expense;
    final analysis = widget.receiptAnalysis;
    final suggestedName = analysis?.description ?? analysis?.storeName ?? '';
    final suggestedAmount = analysis?.totalAmount;

    _nameController = TextEditingController(
      text: expense?.name ?? suggestedName,
    );
    _amountController = TextEditingController(
      text: expense == null
          ? suggestedAmount == null || suggestedAmount <= 0
                ? ''
                : suggestedAmount.toStringAsFixed(2)
          : expense.amount.toStringAsFixed(2),
    );
    _category = expenseCategories.contains(expense?.category)
        ? expense!.category
        : analysis?.category ?? 'other';
    _expenseDate =
        expense?.expenseDate ?? analysis?.expenseDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
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
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      final repository = ref.read(appRepositoryProvider);
      final expense = widget.expense;

      if (expense == null) {
        await repository.addManualExpense(
          name: _nameController.text,
          amount: amount,
          category: _category,
          expenseDate: _expenseDate,
          receiptId: widget.receipt?.id,
        );
        if (mounted) {
          _showSavedToast();
        }
      } else {
        await repository.updateExpense(
          id: expense.id,
          name: _nameController.text,
          amount: amount,
          category: _category,
          expenseDate: _expenseDate,
          receiptId: widget.receipt?.id,
        );
        if (mounted) {
          _showSavedToast(isEdit: true);
        }
      }
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

  void _showSavedToast({bool isEdit = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isEdit ? Icons.check_circle_outline : Icons.check_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEdit
                    ? context.text.expenseUpdated
                    : context.text.expenseSaved,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
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
            Kicker(
              _hasReceiptAutofill ? text.receiptAutofill : text.manualEntry,
            ),
            const SizedBox(height: 8),
            Text(
              _isEditing
                  ? text.editExpense
                  : _hasReceiptAutofill
                  ? text.reviewExtractedExpense
                  : text.addExpense,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: text.name,
                prefixIcon: const Icon(Icons.shopping_bag_outlined),
              ),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return text.nameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: text.amount,
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                final amount = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                if (amount == null || amount <= 0) {
                  return text.enterAmountAboveZero;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: text.category,
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              items: expenseCategories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(_categoryLabel(category)),
                );
              }).toList(),
              onChanged: (value) =>
                  setState(() => _category = value ?? 'other'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _expenseDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _expenseDate = picked);
                }
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                DateFormat.yMMMd(text.appLanguage.code).format(_expenseDate),
              ),
            ),
            if (_attachedReceiptId != null) ...[
              const SizedBox(height: 12),
              _AttachedReceiptNotice(
                isNewUpload: widget.receipt != null,
                analysis: widget.receiptAnalysis,
              ),
            ],
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
                  : Text(_isEditing ? 'Save changes' : 'Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachedReceiptNotice extends StatelessWidget {
  const _AttachedReceiptNotice({
    required this.isNewUpload,
    required this.analysis,
  });

  final bool isNewUpload;
  final ReceiptAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final wasAnalyzed = analysis?.hasUsefulSuggestion == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.primaryGlow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_outlined, color: context.palette.primaryGlow),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  wasAnalyzed
                      ? 'Receipt uploaded and suggestions were applied. Check before saving.'
                      : isNewUpload
                      ? 'Receipt uploaded. Save the expense to attach it.'
                      : 'Receipt attached to this expense.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (wasAnalyzed) ...[
            const SizedBox(height: 10),
            _ReceiptAnalysisSummary(analysis: analysis!),
          ],
        ],
      ),
    );
  }
}

class _ReceiptAnalysisSummary extends StatelessWidget {
  const _ReceiptAnalysisSummary({required this.analysis});

  final ReceiptAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (analysis.storeName != null) analysis.storeName!,
      if (analysis.items.isNotEmpty)
        analysis.items.length == 1
            ? '1 line item'
            : '${analysis.items.length} line items',
      if (analysis.category != null) _categoryLabel(analysis.category!),
      if (analysis.expenseDate != null)
        DateFormat.yMMMd().format(analysis.expenseDate!),
    ];
    final confidence = analysis.confidence;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.palette.surface.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Receipt analysis suggestions',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              if (confidence != null)
                SoftPill(label: '${(confidence * 100).round()}% confidence'),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              details.join(' - '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
