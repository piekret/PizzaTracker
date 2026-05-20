part of '../pizza_tracker_app.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);

    return user.when(
      data: (value) {
        if (value == null) {
          return const AuthScreen();
        }
        return const _SignedInEntryPoint();
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const AuthScreen(),
    );
  }
}

class _SignedInEntryPoint extends ConsumerWidget {
  const _SignedInEntryPoint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    return profile.when(
      data: (value) {
        if (!value.onboardingCompleted && value.monthlyBudget <= 0) {
          return OnboardingSetupScreen(profile: value);
        }
        return const DashboardScreen();
      },
      loading: () => AppBackground(
        child: Center(
          child: CircularProgressIndicator(color: context.palette.primaryGlow),
        ),
      ),
      error: (error, stackTrace) => AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _ErrorCard(error: error),
          ),
        ),
      ),
    );
  }
}
