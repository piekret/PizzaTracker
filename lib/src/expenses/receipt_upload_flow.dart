part of '../pizza_tracker_app.dart';

Future<void> showReceiptUploadFlow({
  required BuildContext context,
  required WidgetRef ref,
  required VoidCallback onExpenseSaved,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _ReceiptSourceSheet(),
  );

  if (source == null || !context.mounted) {
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  final picker = ImagePicker();
  final image = await _pickReceiptImage(
    picker: picker,
    source: source,
    messenger: messenger,
  );

  if (image == null || !context.mounted) {
    return;
  }

  var isUploadingDialogOpen = true;
  _showReceiptUploadingDialog(context);

  ReceiptUpload? receipt;
  try {
    final bytes = await image.readAsBytes();
    receipt = await ref
        .read(appRepositoryProvider)
        .createReceiptUpload(
          bytes: bytes,
          originalName: image.name,
          mimeType: image.mimeType,
        );

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      isUploadingDialogOpen = false;
    }
    if (!context.mounted) {
      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseSheet(receipt: receipt),
    );

    if (saved == true) {
      onExpenseSaved();
      return;
    }

    await ref.read(appRepositoryProvider).deleteReceiptUpload(receipt);
  } catch (error) {
    if (isUploadingDialogOpen && context.mounted) {
      Navigator.of(context, rootNavigator: true).maybePop();
      isUploadingDialogOpen = false;
    }

    if (receipt != null) {
      try {
        await ref.read(appRepositoryProvider).deleteReceiptUpload(receipt);
      } catch (_) {
        // Keep the upload error visible; cleanup failures can be retried later.
      }
    }

    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

Future<XFile?> _pickReceiptImage({
  required ImagePicker picker,
  required ImageSource source,
  required ScaffoldMessengerState messenger,
}) async {
  try {
    return await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1800,
    );
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(_receiptPickerError(error))));
    return null;
  }
}

String _receiptPickerError(Object error) {
  final message = error.toString();
  if (message.contains('channel-error') || message.contains('ImagePickerApi')) {
    return 'Receipt picker is unavailable. Fully restart the app, then try again.';
  }
  return message;
}

void _showReceiptUploadingDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        content: Row(
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Uploading receipt...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ReceiptSourceSheet extends StatelessWidget {
  const _ReceiptSourceSheet();

  @override
  Widget build(BuildContext context) {
    return AppSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Kicker('Receipt upload'),
          const SizedBox(height: 8),
          Text(
            'Add receipt',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Upload an image now. OCR and automatic categorization come next.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Take photo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from gallery'),
          ),
        ],
      ),
    );
  }
}
