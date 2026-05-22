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
                      suggestions: context.text.ingredientSuggestions,
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
    final unlockCopy = _recipeUnlockCopy(context, desperationIndex, isLocked);

    return FrostPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final accent = isLocked
                  ? Theme.of(context).colorScheme.error
                  : level.color;
              final icon = Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: context.palette.border, width: 2),
                ),
                child: Icon(
                  isLocked ? Icons.lock_outline : Icons.soup_kitchen_outlined,
                  color: accent,
                ),
              );
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(context.text.desperationIndex),
                  const SizedBox(height: 6),
                  Text(
                    unlockCopy.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SoftPill(
                        label: '$desperationIndex / 100',
                        icon: Icons.speed_outlined,
                        color: accent,
                      ),
                      SoftPill(
                        label: isLocked
                            ? context.text.locked
                            : level.shortLabel,
                        icon: isLocked ? Icons.lock_outline : level.icon,
                        color: accent,
                      ),
                    ],
                  ),
                ],
              );

              if (constraints.maxWidth < 460) {
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
          const SizedBox(height: 10),
          Text(
            unlockCopy.body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

({String title, String body}) _recipeUnlockCopy(
  BuildContext context,
  int desperationIndex,
  bool isLocked,
) {
  final text = context.text;
  if (isLocked) {
    final pointsLeft = (60 - desperationIndex).clamp(0, 60);
    return (
      title: text.isPolish
          ? 'Kuchnia awaryjna jeszcze śpi.'
          : 'Emergency kitchen is still asleep.',
      body: text.isPolish
          ? 'Brakuje $pointsLeft punktów Indeksu Desperacji do odblokowania. Na razie budżet nie wygląda wystarczająco dramatycznie.'
          : '$pointsLeft Desperation Index points to unlock. For now, the budget is not dramatic enough.',
    );
  }

  return (
    title: text.isPolish
        ? 'Tryb przetrwania odblokowany.'
        : 'Survival kitchen unlocked.',
    body: text.isPolish
        ? 'Wpisz to, co zostało w kuchni. AI spróbuje zrobić z tego tani posiłek zamiast kolejnej wymówki na dostawę.'
        : 'Add what is left in the kitchen. AI will try to turn it into a cheap meal instead of another delivery excuse.',
  );
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
            _IngredientEmptyState(
              isLocked: isLocked,
              suggestions: suggestions,
              onAddSuggestion: onAddSuggestion,
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

class _IngredientEmptyState extends StatelessWidget {
  const _IngredientEmptyState({
    required this.isLocked,
    required this.suggestions,
    required this.onAddSuggestion,
  });

  final bool isLocked;
  final List<String> suggestions;
  final ValueChanged<String> onAddSuggestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
              Icon(
                Icons.inventory_2_outlined,
                color: context.palette.primaryGlow,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.text.isPolish
                      ? 'Pantry check: zacznij od dwóch rzeczy.'
                      : 'Pantry check: start with two things.',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.text.isPolish
                ? 'Kliknij sugestie albo wpisz własne składniki. Im bardziej prawdziwa lista, tym mniej smutny obiad.'
                : 'Tap suggestions or type your own ingredients. The more honest the list, the less tragic the meal.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map(
                  (item) => InputChip(
                    label: Text(item),
                    onPressed: isLocked ? null : () => onAddSuggestion(item),
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
      return _RecipeStatusCard(
        icon: Icons.lock_outline,
        title: context.text.isPolish
            ? 'Przepisy czekają na kryzys.'
            : 'Recipes are waiting for crisis mode.',
        message: context.text.isPolish
            ? 'Przepisy odblokują się, gdy Indeks Desperacji osiągnie 60.'
            : 'Recipes unlock once the desperation index hits 60.',
      );
    }

    if (request == null) {
      return _RecipeStatusCard(
        icon: Icons.restaurant_menu_outlined,
        title: context.text.isPolish
            ? 'Jeszcze nie gotujemy.'
            : 'Nothing is cooking yet.',
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
          return _RecipeStatusCard(
            icon: Icons.restaurant_outlined,
            title: context.text.isPolish
                ? 'AI wróciło z pustą patelnią.'
                : 'AI came back with an empty pan.',
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

class _RecipeStatusCard extends StatelessWidget {
  const _RecipeStatusCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.palette.primaryGlow.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.palette.border, width: 2),
            ),
            child: Icon(icon, color: context.palette.primaryGlow),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
