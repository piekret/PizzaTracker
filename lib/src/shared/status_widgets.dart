part of '../pizza_tracker_app.dart';

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
          Expanded(
            child: Text(
              context.text.translateKnown(label),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
            label: context.text.isPolish
                ? 'Coś się zepsuło'
                : 'Something broke',
            icon: Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(context.text.translateKnown(error.toString())),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              context.text.translateKnown(hint!),
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
          Expanded(child: Text(context.text.translateKnown(message))),
        ],
      ),
    );
  }
}
