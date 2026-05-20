part of '../pizza_tracker_app.dart';

Future<void> showReceiptPreview({
  required BuildContext context,
  required String receiptId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ReceiptPreviewSheet(receiptId: receiptId),
  );
}

class _ReceiptPreviewSheet extends ConsumerWidget {
  const _ReceiptPreviewSheet({required this.receiptId});

  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(receiptUploadProvider(receiptId));

    return AppSheetFrame(
      child: receipt.when(
        data: (value) {
          final imagePath = value.imagePath;
          if (imagePath == null || imagePath.isEmpty) {
            return const _ReceiptPreviewMessage(
              icon: Icons.image_not_supported_outlined,
              title: 'No receipt image',
              text: 'This receipt record does not have an image path.',
            );
          }

          final imageUrl = ref.watch(receiptImageUrlProvider(imagePath));
          return imageUrl.when(
            data: (url) => _ReceiptImagePreview(receipt: value, imageUrl: url),
            loading: () => const _ReceiptPreviewLoading(),
            error: (error, stackTrace) => _ReceiptPreviewError(error: error),
          );
        },
        loading: () => const _ReceiptPreviewLoading(),
        error: (error, stackTrace) => _ReceiptPreviewError(error: error),
      ),
    );
  }
}

class _ReceiptImagePreview extends StatelessWidget {
  const _ReceiptImagePreview({required this.receipt, required this.imageUrl});

  final ReceiptUpload receipt;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(
                    context.text.isPolish
                        ? 'Dołączony paragon'
                        : 'Attached receipt',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.text.isPolish ? 'Obraz paragonu' : 'Receipt image',
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.text.isPolish ? 'Zamknij' : 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.62,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.palette.surfaceStrong,
                border: Border.all(color: context.palette.border),
              ),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return const _ReceiptPreviewLoading();
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return _ReceiptPreviewError(error: error);
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Signed link expires automatically. Reopen this sheet to refresh it.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (receipt.analysis?.hasUsefulSuggestion == true) ...[
          const SizedBox(height: 12),
          _ReceiptAnalysisSummary(analysis: receipt.analysis!),
        ],
      ],
    );
  }
}

class _ReceiptPreviewLoading extends StatelessWidget {
  const _ReceiptPreviewLoading();

  @override
  Widget build(BuildContext context) {
    return const _ReceiptPreviewMessage(
      icon: Icons.image_search_outlined,
      title: 'Loading receipt',
      text: 'Preparing a private image link...',
      isLoading: true,
    );
  }
}

class _ReceiptPreviewError extends StatelessWidget {
  const _ReceiptPreviewError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return _ReceiptPreviewMessage(
      icon: Icons.error_outline,
      title: 'Could not open receipt',
      text: error.toString(),
    );
  }
}

class _ReceiptPreviewMessage extends StatelessWidget {
  const _ReceiptPreviewMessage({
    required this.icon,
    required this.title,
    required this.text,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool isLoading;

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
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 34, color: context.palette.primaryGlow),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            text,
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
