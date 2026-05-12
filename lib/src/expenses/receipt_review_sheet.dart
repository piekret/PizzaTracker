part of '../pizza_tracker_app.dart';

class ReceiptReviewSheet extends ConsumerStatefulWidget {
  const ReceiptReviewSheet({
    required this.receipt,
    required this.analysis,
    super.key,
  });

  final ReceiptUpload receipt;
  final ReceiptAnalysis analysis;

  @override
  ConsumerState<ReceiptReviewSheet> createState() => _ReceiptReviewSheetState();
}

class _ReceiptReviewSheetState extends ConsumerState<ReceiptReviewSheet> {
  final _formKey = GlobalKey<FormState>();
  late final List<_ReceiptItemDraft> _items;
  late DateTime _expenseDate;

  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _expenseDate = widget.analysis.expenseDate ?? DateTime.now();
    _items = widget.analysis.items
        .map((item) => _ReceiptItemDraft.fromAnalysis(item))
        .toList();
    if (_items.isEmpty) {
      _items.add(_ReceiptItemDraft.empty());
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _total {
    return _items.fold(0, (sum, item) {
      return sum +
          (double.tryParse(item.amount.text.replaceAll(',', '.')) ?? 0);
    });
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
      final expenses = _items.map((item) {
        return ReceiptExpenseDraft(
          name: item.name.text,
          amount: double.parse(item.amount.text.replaceAll(',', '.')),
          category: item.category,
        );
      }).toList();

      await ref
          .read(appRepositoryProvider)
          .addReceiptExpenses(
            receiptId: widget.receipt.id,
            expenseDate: _expenseDate,
            expenses: expenses,
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
    final currency =
        ref.watch(userProfileProvider).asData?.value.currency ?? 'USD';
    final formatter = NumberFormat.simpleCurrency(name: currency);
    final confidence = widget.analysis.confidence;
    final receiptTotal = widget.analysis.totalAmount;

    return AppSheetFrame(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Kicker('Receipt review'),
                      const SizedBox(height: 8),
                      Text(
                        widget.analysis.storeName ?? 'Review receipt items',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                if (confidence != null)
                  SoftPill(label: '${(confidence * 100).round()}% confidence'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Check names, amounts, and categories before saving. These will become separate expense rows tied to this receipt.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickExpenseDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(DateFormat.yMMMd().format(_expenseDate)),
                  ),
                ),
                const SizedBox(width: 10),
                SoftPill(label: formatter.format(_total)),
              ],
            ),
            if (receiptTotal != null && receiptTotal > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Receipt total: ${formatter.format(receiptTotal)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            for (var index = 0; index < _items.length; index++) ...[
              _ReceiptItemEditor(
                item: _items[index],
                index: index,
                canRemove: _items.length > 1,
                onAmountChanged: () => setState(() {}),
                onCategoryChanged: (value) {
                  setState(() => _items[index].category = value);
                },
                onRemove: () => _removeItem(index),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add missing item'),
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
                  : Text(
                      _items.length == 1
                          ? 'Save 1 expense'
                          : 'Save ${_items.length} expenses',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickExpenseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _expenseDate = picked);
    }
  }

  void _addItem() {
    setState(() => _items.add(_ReceiptItemDraft.empty()));
  }

  void _removeItem(int index) {
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }
}

class _ReceiptItemEditor extends StatelessWidget {
  const _ReceiptItemEditor({
    required this.item,
    required this.index,
    required this.canRemove,
    required this.onAmountChanged,
    required this.onCategoryChanged,
    required this.onRemove,
  });

  final _ReceiptItemDraft item;
  final int index;
  final bool canRemove;
  final VoidCallback onAmountChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surfaceStrong,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Item ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (canRemove)
                IconButton(
                  tooltip: 'Remove item',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: item.name,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.shopping_bag_outlined),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required.';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: item.amount,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => onAmountChanged(),
                  validator: _validatePositiveAmount,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: item.category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: expenseCategories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(_categoryLabel(category)),
                    );
                  }).toList(),
                  onChanged: (value) => onCategoryChanged(value ?? 'other'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptItemDraft {
  _ReceiptItemDraft({
    required String name,
    required double amount,
    required this.category,
  }) : name = TextEditingController(text: name),
       amount = TextEditingController(
         text: amount > 0 ? amount.toStringAsFixed(2) : '',
       );

  factory _ReceiptItemDraft.fromAnalysis(ReceiptAnalysisItem item) {
    return _ReceiptItemDraft(
      name: item.name,
      amount: item.amount,
      category: item.category,
    );
  }

  factory _ReceiptItemDraft.empty() {
    return _ReceiptItemDraft(name: '', amount: 0, category: 'other');
  }

  final TextEditingController name;
  final TextEditingController amount;
  String category;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}
