part of '../pizza_tracker_app.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);

    return user.when(
      data: (value) =>
          value == null ? const AuthScreen() : const DashboardScreen(),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const AuthScreen(),
    );
  }
}
