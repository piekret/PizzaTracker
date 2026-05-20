part of '../pizza_tracker_app.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({required this.currency, super.key});

  final String currency;

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  final _ingredientController = TextEditingController();
  final _ingredients = <String>[];
  RecipeRequest? _lastRequest;
  final _suggested = const [
    'pasta',
    'eggs',
    'onion',
    'rice',
    'beans',
    'cheese',
    'tomato',
  ];

  @override
  void dispose() {
    _ingredientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final budget = ref.watch(budgetSnapshotProvider);
    final language = ref.watch(appLanguageProvider);
    final currency = profile.asData?.value.currency ?? widget.currency;
    final snapshot = budget.asData?.value;
    final index = snapshot?.desperationIndex ?? 0;
    final isLocked = index < 60;
    final activeRequest = _lastRequest?.languageCode == language.code
        ? _lastRequest
        : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _RecipesHeader(onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    _responsiveGutter(context),
                    6,
                    _responsiveGutter(context),
                    120,
                  ),
                  children: [
                    _RecipeIntroCard(
                      desperationIndex: index,
                      isLocked: isLocked,
                    ),
                    const SizedBox(height: 14),
                    _IngredientInputCard(
                      controller: _ingredientController,
                      ingredients: _ingredients,
                      isLocked: isLocked,
                      onAdd: _addIngredient,
                      suggestions: _suggested,
                      onAddSuggestion: _addSuggested,
                      onRemove: _removeIngredient,
                    ),
                    const SizedBox(height: 14),
                    _GenerateButton(
                      isLocked: isLocked,
                      ingredients: _ingredients,
                      onPressed: () => _generateRecipes(index),
                    ),
                    const SizedBox(height: 14),
                    _RecipesResultPanel(
                      currency: currency,
                      isLocked: isLocked,
                      request: activeRequest,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addIngredient() {
    final value = _ingredientController.text.trim();
    if (value.isEmpty) {
      return;
    }
    setState(() {
      _ingredients.add(value);
      _ingredientController.clear();
    });
  }

  void _removeIngredient(String value) {
    setState(() => _ingredients.remove(value));
  }

  void _addSuggested(String value) {
    if (_ingredients.contains(value)) {
      return;
    }
    setState(() => _ingredients.add(value));
  }

  void _generateRecipes(int desperationIndex) {
    if (_ingredients.isEmpty) {
      return;
    }
    final request = RecipeRequest(
      ingredients: List<String>.from(_ingredients),
      desperationIndex: desperationIndex,
      languageCode: ref.read(appLanguageProvider).code,
    );
    setState(() => _lastRequest = request);
    ref.invalidate(recipeGeneratorProvider(request));
  }
}

class _RecipesHeader extends StatelessWidget {
  const _RecipesHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 26, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _RoundIconButton(
            tooltip: context.text.back,
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(context.text.emergencyRecipes),
                const SizedBox(height: 4),
                Text(
                  context.text.whatToCook,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeIntroCard extends StatelessWidget {
  const _RecipeIntroCard({
    required this.desperationIndex,
    required this.isLocked,
  });

  final int desperationIndex;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final level = _levelForIndex(desperationIndex);
    return FrostPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Kicker(context.text.desperationIndex),
                    const SizedBox(height: 6),
                    Text(
                      '$desperationIndex / 100',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              SoftPill(
                label: isLocked
                    ? context.text.isPolish
                          ? 'Zablokowane'
                          : 'Locked'
                    : level.shortLabel,
                icon: isLocked ? Icons.lock_outline : level.icon,
                color: isLocked
                    ? Theme.of(context).colorScheme.error
                    : level.color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isLocked
                ? context.text.isPolish
                      ? 'Przepisy odblokują się, gdy budżet wejdzie w tryb kryzysowy (Indeks 60+).'
                      : 'Recipes unlock when your budget hits crisis mode (Index 60+).'
                : context.text.isPolish
                ? 'Powiedz, co zostało w kuchni. Zrobię z tego coś jadalnego.'
                : 'Tell me what is left in your kitchen. I will make it edible.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientInputCard extends StatelessWidget {
  const _IngredientInputCard({
    required this.controller,
    required this.ingredients,
    required this.isLocked,
    required this.onAdd,
    required this.suggestions,
    required this.onAddSuggestion,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<String> ingredients;
  final bool isLocked;
  final VoidCallback onAdd;
  final List<String> suggestions;
  final ValueChanged<String> onAddSuggestion;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(context.text.yourPantry),
          const SizedBox(height: 6),
          Text(
            context.text.isPolish
                ? 'Co masz w lodówce?'
                : 'What is in your fridge?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isLocked,
                  decoration: InputDecoration(
                    labelText: context.text.addIngredient,
                    prefixIcon: const Icon(Icons.kitchen_outlined),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: isLocked ? null : onAdd,
                child: Text(context.text.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ingredients.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.text.isPolish
                      ? 'Dodaj co najmniej 2 składniki dla lepszych wyników.'
                      : 'Add at least 2 ingredients for better results.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions
                      .map(
                        (item) => InputChip(
                          label: Text(item),
                          onPressed: isLocked
                              ? null
                              : () => onAddSuggestion(item),
                        ),
                      )
                      .toList(),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ingredients
                  .map(
                    (ingredient) => Chip(
                      label: Text(ingredient),
                      onDeleted: isLocked ? null : () => onRemove(ingredient),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.isLocked,
    required this.ingredients,
    required this.onPressed,
  });

  final bool isLocked;
  final List<String> ingredients;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final canGenerate = !isLocked && ingredients.length >= 2;

    return FilledButton.icon(
      onPressed: canGenerate ? onPressed : null,
      icon: const Icon(Icons.auto_awesome_outlined),
      label: Text(
        ingredients.length < 2
            ? context.text.isPolish
                  ? 'Dodaj co najmniej 2 składniki'
                  : 'Add at least 2 ingredients'
            : context.text.generateRecipes,
      ),
    );
  }
}

class _RecipesResultPanel extends ConsumerWidget {
  const _RecipesResultPanel({
    required this.currency,
    required this.isLocked,
    required this.request,
  });

  final String currency;
  final bool isLocked;
  final RecipeRequest? request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLocked) {
      return _ChartEmptyState(
        icon: Icons.lock_outline,
        message: context.text.isPolish
            ? 'Przepisy odblokują się, gdy Indeks Desperacji osiągnie 60.'
            : 'Recipes unlock once the desperation index hits 60.',
      );
    }

    if (request == null) {
      return _ChartEmptyState(
        icon: Icons.restaurant_menu_outlined,
        message: context.text.isPolish
            ? 'Dodaj składniki i wygeneruj menu przetrwania.'
            : 'Add ingredients and generate your survival menu.',
      );
    }

    final recipes = ref.watch(recipeGeneratorProvider(request!));
    final formatter = NumberFormat.simpleCurrency(name: currency);

    return recipes.when(
      data: (value) {
        if (value.isEmpty) {
          return _ChartEmptyState(
            icon: Icons.restaurant_outlined,
            message: context.text.isPolish
                ? 'Nie wrócił żaden przepis. Spróbuj dodać więcej składników.'
                : 'No recipes came back. Try adding more ingredients.',
          );
        }

        return Column(
          children: [
            for (final recipe in value) ...[
              _RecipeCard(recipe: recipe, formatter: formatter),
              if (recipe != value.last) const SizedBox(height: 12),
            ],
          ],
        );
      },
      loading: () => _LoadingCard(
        label: context.text.isPolish
            ? 'Generowanie przepisów...'
            : 'Generating recipes...',
      ),
      error: (error, stackTrace) => _ErrorCard(error: error),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.formatter});

  final RecipeSuggestion recipe;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final cost = recipe.estimatedCost;
    final calories = recipe.calories;
    final hasIngredients = recipe.ingredientsUsed.isNotEmpty;

    return FrostPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(recipe.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (cost != null) SoftPill(label: formatter.format(cost)),
              if (calories != null) SoftPill(label: '$calories kcal'),
            ],
          ),
          if (hasIngredients) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recipe.ingredientsUsed
                  .map((item) => Chip(label: Text(item)))
                  .toList(),
            ),
          ],
          if (recipe.note != null && recipe.note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              recipe.note!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            context.text.isPolish ? 'Kroki' : 'Steps',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < recipe.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${i + 1}. ${recipe.steps[i]}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
