part of '../pizza_tracker_app.dart';

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
    final text = context.text;
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
                  crossAxisAlignment:
                      CrossAxisAlignment.start, // Fixed analyzer issue
                  children: [
                    Text(
                      'PizzaTracker',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text.authTagline,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (compact) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerRight,
              child: _LanguageMenu(),
            ),
          ],
          SizedBox(height: compact ? 20 : 34),
          Kicker(text.canIAffordThis),
          const SizedBox(height: 10),
          Text(
            compact ? text.authHeroShort : text.authHeroLong,
            style: compact
                ? Theme.of(context).textTheme.headlineMedium
                : Theme.of(context).textTheme.displayMedium,
          ),
          if (!compact) ...[
            const SizedBox(height: 26),
            const _FeatureLine(
              icon: Icons.receipt_long_outlined,
              titleKey: 'receiptsBecomeExpenses',
              textKey: 'manualNowOcrNext',
            ),
            const SizedBox(height: 14),
            const _FeatureLine(
              icon: Icons.speed_outlined,
              titleKey: 'desperationIndex',
              textKey: 'oneBrutalNumber',
            ),
            const SizedBox(height: 14),
            const _FeatureLine(
              icon: Icons.restaurant_menu_outlined,
              titleKey: 'recipesLater',
              textKey: 'whenBudgetGetsUgly',
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
    required this.titleKey,
    required this.textKey,
  });

  final IconData icon;
  final String titleKey;
  final String textKey;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final title = switch (titleKey) {
      'receiptsBecomeExpenses' => text.receiptsBecomeExpenses,
      'desperationIndex' => text.desperationIndex,
      'recipesLater' => text.recipesLater,
      _ => titleKey,
    };
    final body = switch (textKey) {
      'manualNowOcrNext' => text.manualNowOcrNext,
      'oneBrutalNumber' => text.oneBrutalNumber,
      'whenBudgetGetsUgly' => text.whenBudgetGetsUgly,
      _ => textKey,
    };
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
                body,
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
    final text = context.text;
    return FrostPanel(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Kicker(text.isPolish ? 'Prywatna beta' : 'Private beta'),
            const SizedBox(height: 10),
            Text(
              isSignUp
                  ? text.isPolish
                        ? 'Utwórz konto'
                        : 'Create account'
                  : text.isPolish
                  ? 'Witaj ponownie'
                  : 'Welcome back',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isSignUp
                  ? text.isPolish
                        ? 'Zacznij śledzić wydatki, zanim tracker pizzy stanie się trackerem długów.'
                        : 'Start tracking before the pizza tracker becomes a debt tracker.'
                  : text.isPolish
                  ? 'Zaloguj się i pozwól paragonom się wytłumaczyć.'
                  : 'Sign in and let the receipts explain themselves.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: text.isPolish ? 'Email' : 'Email',
                prefixIcon: const Icon(Icons.alternate_email),
              ),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                if (value == null || !value.contains('@')) {
                  return text.isPolish
                      ? 'Podaj poprawny email.'
                      : 'Enter a valid email.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: text.isPolish ? 'Hasło' : 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: obscurePassword
                      ? text.isPolish
                            ? 'Pokaż hasło'
                            : 'Show password'
                      : text.isPolish
                      ? 'Ukryj hasło'
                      : 'Hide password',
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
                  return text.isPolish
                      ? 'Użyj co najmniej 6 znaków.'
                      : 'Use at least 6 characters.';
                }
                return null;
              },
            ),
            if (isSignUp) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  labelText: text.isPolish
                      ? 'Potwierdź hasło'
                      : 'Confirm password',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  suffixIcon: IconButton(
                    tooltip: obscureConfirmPassword
                        ? text.isPolish
                              ? 'Pokaż hasło'
                              : 'Show password'
                        : text.isPolish
                        ? 'Ukryj hasło'
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
                    return text.isPolish
                        ? 'Hasła nie są takie same.'
                        : 'Passwords do not match.';
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
                  : Text(
                      isSignUp
                          ? text.isPolish
                                ? 'Utwórz konto'
                                : 'Create account'
                          : text.isPolish
                          ? 'Zaloguj się'
                          : 'Sign in',
                    ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: isLoading ? null : onToggleMode,
              child: Text(
                isSignUp
                    ? text.isPolish
                          ? 'Mam już konto'
                          : 'I already have an account'
                    : text.isPolish
                    ? 'Utwórz konto'
                    : 'Create an account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
