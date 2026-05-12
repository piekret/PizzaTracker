part of '../pizza_tracker_app.dart';

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
                        'Flutter reads client-safe Supabase values from dart-defines first, then the generated assets/env/client.env asset. Keep OpenAI, service-role, Firebase admin, and database secrets in .env only.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _CommandBox(
                        command:
                            'macOS/Linux: ./scripts/sync_client_env.sh && flutter run\n'
                            'Windows: powershell -ExecutionPolicy Bypass -File .\\scripts\\sync_client_env.ps1; flutter run',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'If this screen stays visible, fill .env with SUPABASE_URL plus SUPABASE_ANON_KEY, run the sync script, then start Flutter again.',
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
