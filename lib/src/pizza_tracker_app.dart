import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_chrome.dart';
import 'app_config.dart';
import 'app_data.dart';
import 'app_theme.dart';

class PizzaTrackerApp extends ConsumerWidget {
  const PizzaTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreset = ref.watch(appThemePresetProvider);

    return MaterialApp(
      title: 'PizzaTracker',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(themePreset),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    if (config == null) {
      return const SetupScreen();
    }
    return const AuthGate();
  }
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: FrostPanel(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandMark(size: 62),
                      const SizedBox(height: 24),
                      const Kicker('Local config missing'),
                      const SizedBox(height: 10),
                      Text(
                        'PizzaTracker setup',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Flutter reads only the client-safe Supabase values from .env.client. Keep OpenAI, service-role, Firebase admin, and database secrets in .env only.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _CommandBox(command: 'flutter run'),
                      const SizedBox(height: 16),
                      Text(
                        'If this screen stays visible, copy .env.client.example to .env.client and fill SUPABASE_URL plus SUPABASE_ANON_KEY.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandBox extends StatelessWidget {
  const _CommandBox({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.palette.surfaceStrong,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border),
      ),
      child: SelectableText(
        command,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null) {
          return const AuthScreen();
        }
        return const DashboardScreen();
      },
    );
  }
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final client = ref.read(supabaseClientProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isSignUp) {
        final response = await client.auth.signUp(
          email: email,
          password: password,
        );
        if (response.session == null) {
          await client.auth.signInWithPassword(
            email: email,
            password: password,
          );
        }
      } else {
        await client.auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (error) {
      setState(() => _message = error.message);
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = MediaQuery.sizeOf(context).width >= 860;

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(child: _AuthBrandPanel()),
                              const SizedBox(width: 18),
                              SizedBox(
                                width: 430,
                                child: _AuthFormPanel(
                                  formKey: _formKey,
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  confirmPasswordController:
                                      _confirmPasswordController,
                                  isSignUp: _isSignUp,
                                  isLoading: _isLoading,
                                  obscurePassword: _obscurePassword,
                                  obscureConfirmPassword:
                                      _obscureConfirmPassword,
                                  message: _message,
                                  onSubmit: _submit,
                                  onTogglePassword: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  onToggleConfirmPassword: () => setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                  onToggleMode: _toggleMode,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              const _AuthBrandPanel(compact: true),
                              const SizedBox(height: 16),
                              _AuthFormPanel(
                                formKey: _formKey,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                confirmPasswordController:
                                    _confirmPasswordController,
                                isSignUp: _isSignUp,
                                isLoading: _isLoading,
                                obscurePassword: _obscurePassword,
                                obscureConfirmPassword: _obscureConfirmPassword,
                                message: _message,
                                onSubmit: _submit,
                                onTogglePassword: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                onToggleConfirmPassword: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                                onToggleMode: _toggleMode,
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _message = null;
      if (!_isSignUp) {
        _confirmPasswordController.clear();
      }
    });
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      padding: EdgeInsets.all(compact ? 22 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              BrandMark(size: compact ? 50 : 64),
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
                      'Student budget survival kit',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 20 : 34),
          const Kicker('Can I afford this?'),
          const SizedBox(height: 10),
          Text(
            compact
                ? 'Know if tonight is pizza night or pasta damage control.'
                : 'Know if tonight is pizza night or pasta damage control before your bank account starts negotiating.',
            style: compact
                ? Theme.of(context).textTheme.headlineMedium
                : Theme.of(context).textTheme.displayMedium,
          ),
          if (!compact) ...[
            const SizedBox(height: 26),
            const _FeatureLine(
              icon: Icons.receipt_long_outlined,
              title: 'Receipts become expenses',
              text: 'Manual now, OCR next.',
            ),
            const SizedBox(height: 14),
            const _FeatureLine(
              icon: Icons.speed_outlined,
              title: 'Desperation Index',
              text: 'One brutal number for the rest of the month.',
            ),
            const SizedBox(height: 14),
            const _FeatureLine(
              icon: Icons.restaurant_menu_outlined,
              title: 'Recipes later',
              text: 'When the budget gets ugly.',
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: context.palette.surfaceStrong,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.palette.border),
          ),
          child: Icon(icon, size: 21, color: context.palette.primaryGlow),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isSignUp,
    required this.isLoading,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.message,
    required this.onSubmit,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onToggleMode,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isSignUp;
  final bool isLoading;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final String? message;
  final VoidCallback onSubmit;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Kicker('Private beta'),
            const SizedBox(height: 10),
            Text(
              isSignUp ? 'Create account' : 'Welcome back',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isSignUp
                  ? 'Start tracking before the pizza tracker becomes a debt tracker.'
                  : 'Sign in and let the receipts explain themselves.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                if (value == null || !value.contains('@')) {
                  return 'Enter a valid email.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              obscureText: obscurePassword,
              autofillHints: const [AutofillHints.password],
              validator: (value) {
                if (value == null || value.length < 6) {
                  return 'Use at least 6 characters.';
                }
                return null;
              },
            ),
            if (isSignUp) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  suffixIcon: IconButton(
                    tooltip: obscureConfirmPassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: onToggleConfirmPassword,
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
                obscureText: obscureConfirmPassword,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) {
                  if (value != passwordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 14),
              _InlineError(message: message!),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: isLoading ? null : onSubmit,
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isSignUp ? 'Create account' : 'Sign in'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: isLoading ? null : onToggleMode,
              child: Text(
                isSignUp ? 'I already have an account' : 'Create an account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final budget = ref.watch(budgetSnapshotProvider);
    final expenses = ref.watch(recentExpensesProvider);
    final currency = profile.asData?.value.currency ?? 'USD';

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpense(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add expense'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
              children: [
                _DashboardHeader(
                  onSignOut: () =>
                      ref.read(supabaseClientProvider).auth.signOut(),
                ),
                const SizedBox(height: 18),
                profile.when(
                  data: (value) => _BudgetSetupCard(profile: value),
                  loading: () =>
                      const _LoadingCard(label: 'Loading profile...'),
                  error: (error, stackTrace) => _ErrorCard(error: error),
                ),
                const SizedBox(height: 14),
                budget.when(
                  data: (value) =>
                      _DesperationCard(snapshot: value, currency: currency),
                  loading: () =>
                      const _LoadingCard(label: 'Calculating desperation...'),
                  error: (error, stackTrace) => _ErrorCard(
                    error: error,
                    hint:
                        'Check that the get_budget_snapshot RPC exists in Supabase.',
                  ),
                ),
                const SizedBox(height: 14),
                expenses.when(
                  data: (value) =>
                      _RecentExpensesCard(expenses: value, currency: currency),
                  loading: () =>
                      const _LoadingCard(label: 'Loading recent expenses...'),
                  error: (error, stackTrace) => _ErrorCard(error: error),
                ),
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

    await Future.wait([
      ref.read(userProfileProvider.future),
      ref.read(budgetSnapshotProvider.future),
      ref.read(recentExpensesProvider.future),
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

    if (saved == true) {
      ref.invalidate(budgetSnapshotProvider);
      ref.invalidate(recentExpensesProvider);
    }
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onSignOut});

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
                'Budget dashboard',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const _ThemePresetMenu(),
        const SizedBox(width: 8),
        _RoundIconButton(
          tooltip: 'Sign out',
          icon: Icons.logout_rounded,
          onPressed: onSignOut,
        ),
      ],
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
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.palette.border),
          ),
          child: Icon(icon, size: 21),
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

    return PopupMenuButton<AppThemePreset>(
      tooltip: 'Theme',
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
                      Text(preset.label),
                      Text(
                        preset.description,
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
}

class _BudgetSetupCard extends ConsumerWidget {
  const _BudgetSetupCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat.simpleCurrency(name: profile.currency);
    final needsSetup = profile.monthlyBudget <= 0;

    return FrostPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  (needsSetup
                          ? context.palette.tertiaryGlow
                          : context.palette.primaryGlow)
                      .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.palette.border),
            ),
            child: Icon(
              needsSetup
                  ? Icons.priority_high_rounded
                  : Icons.account_balance_wallet_outlined,
              color: needsSetup
                  ? context.palette.tertiaryGlow
                  : context.palette.primaryGlow,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  needsSetup
                      ? 'Budget still needs a number'
                      : 'Monthly budget locked in',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  needsSetup
                      ? 'Set this first so the app can judge your pizza decisions properly.'
                      : '${formatter.format(profile.monthlyBudget)} resets on day ${profile.budgetResetDay}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: () async {
              final saved = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (context) => EditBudgetSheet(profile: profile),
              );
              if (saved == true) {
                ref.invalidate(userProfileProvider);
                ref.invalidate(budgetSnapshotProvider);
              }
            },
            child: Text(needsSetup ? 'Set' : 'Edit'),
          ),
        ],
      ),
    );
  }
}

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
                      backgroundColor: context.palette.border.withValues(
                        alpha: 0.42,
                      ),
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

class _RecentExpensesCard extends StatelessWidget {
  const _RecentExpensesCard({required this.expenses, required this.currency});

  final List<ExpenseItem> expenses;
  final String currency;

  @override
  Widget build(BuildContext context) {
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
                    const Kicker('Latest damage'),
                    const SizedBox(height: 6),
                    Text(
                      'Recent expenses',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              SoftPill(label: '${expenses.length} shown'),
            ],
          ),
          const SizedBox(height: 16),
          if (expenses.isEmpty)
            const _EmptyExpenses()
          else
            for (final expense in expenses) ...[
              _ExpenseRow(
                expense: expense,
                amount: NumberFormat.simpleCurrency(
                  name: currency,
                ).format(expense.amount),
              ),
              if (expense != expenses.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.surfaceStrong,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 34,
            color: context.palette.primaryGlow,
          ),
          const SizedBox(height: 10),
          Text(
            'No expenses yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Add one before the pizza place does.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense, required this.amount});

  final ExpenseItem expense;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(expense.category, context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surfaceStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _categoryIcon(expense.category),
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '${_categoryLabel(expense.category)} - ${DateFormat.yMMMd().format(expense.expenseDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({super.key});

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  String _category = 'food';
  DateTime _expenseDate = DateTime.now();
  bool _isSaving = false;
  String? _error;

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
      await ref
          .read(appRepositoryProvider)
          .addManualExpense(
            name: _nameController.text,
            amount: double.parse(_amountController.text.replaceAll(',', '.')),
            category: _category,
            expenseDate: _expenseDate,
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
            const Kicker('Manual entry'),
            const SizedBox(height: 8),
            Text(
              'Add expense',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
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
              validator: (value) {
                final amount = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                if (amount == null || amount <= 0) {
                  return 'Enter an amount above 0.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
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
              label: Text(DateFormat.yMMMd().format(_expenseDate)),
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
                  : const Text('Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.palette.primaryGlow,
            ),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, this.hint});

  final Object error;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoftPill(
            label: 'Something broke',
            icon: Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(error.toString()),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: error.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: error),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

({Color color, String label, String shortLabel, IconData icon}) _levelForIndex(
  int index,
) {
  if (index <= 20) {
    return (
      color: const Color(0xff22c55e),
      label: 'All good. Pizza is legally defensible.',
      shortLabel: 'All good',
      icon: Icons.check_circle_outline,
    );
  }
  if (index <= 45) {
    return (
      color: const Color(0xffeab308),
      label: 'Watch out. Pizza yes, breakfast no.',
      shortLabel: 'Watch out',
      icon: Icons.visibility_outlined,
    );
  }
  if (index <= 70) {
    return (
      color: const Color(0xfff97316),
      label: 'Economy mode. Cook at home.',
      shortLabel: 'Economy',
      icon: Icons.soup_kitchen_outlined,
    );
  }
  if (index <= 90) {
    return (
      color: const Color(0xffef4444),
      label: 'SOS. Start counting pasta portions.',
      shortLabel: 'SOS',
      icon: Icons.warning_amber_rounded,
    );
  }
  return (
    color: const Color(0xffa855f7),
    label: 'Apocalypse. Check the freezer.',
    shortLabel: 'Apocalypse',
    icon: Icons.crisis_alert_outlined,
  );
}

String _categoryLabel(String category) {
  return switch (category) {
    'food' => 'Food',
    'alcohol' => 'Alcohol',
    'hygiene' => 'Hygiene',
    'fun' => 'Fun',
    _ => 'Other',
  };
}

IconData _categoryIcon(String category) {
  return switch (category) {
    'food' => Icons.restaurant_outlined,
    'alcohol' => Icons.local_bar_outlined,
    'hygiene' => Icons.spa_outlined,
    'fun' => Icons.celebration_outlined,
    _ => Icons.more_horiz,
  };
}

Color _categoryColor(String category, BuildContext context) {
  return switch (category) {
    'food' => const Color(0xff22c55e),
    'alcohol' => const Color(0xfff97316),
    'hygiene' => const Color(0xff38bdf8),
    'fun' => const Color(0xffd946ef),
    _ => context.palette.secondaryGlow,
  };
}
