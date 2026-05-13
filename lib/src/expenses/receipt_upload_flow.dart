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
  ReceiptAnalysis? analysis;
  String? rawOcrText;
  Object? ocrError;
  Object? analysisError;
  try {
    final bytes = await image.readAsBytes();

    try {
      rawOcrText = await _extractReceiptText(image.path);
    } catch (error) {
      ocrError = error;
    }

    receipt = await ref
        .read(appRepositoryProvider)
        .createReceiptUpload(
          bytes: bytes,
          originalName: image.name,
          mimeType: image.mimeType,
        );

    try {
      analysis = await ref
          .read(appRepositoryProvider)
          .analyzeReceipt(receipt.id, rawOcrText: rawOcrText);
    } catch (error) {
      analysisError = error;
    }
    if (analysis?.hasUsefulSuggestion != true) {
      analysis = _fallbackAnalysisFromOcr(rawOcrText) ?? analysis;
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      isUploadingDialogOpen = false;
    }
    if (!context.mounted) {
      return;
    }
    if (analysisError != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(_receiptAnalysisFallbackMessage(analysisError))),
      );
    } else if (ocrError != null && rawOcrText == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Local OCR was unavailable, so receipt analysis used the uploaded image.',
          ),
        ),
      );
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final usefulAnalysis = analysis?.hasUsefulSuggestion == true
            ? analysis
            : null;
        if (usefulAnalysis?.items.isNotEmpty == true) {
          return ReceiptReviewSheet(
            receipt: receipt!,
            analysis: usefulAnalysis!,
          );
        }

        return AddExpenseSheet(
          receipt: receipt,
          receiptAnalysis: analysis,
        );
      },
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

Future<String?> _extractReceiptText(String imagePath) async {
  if (imagePath.trim().isEmpty) {
    return null;
  }

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final recognized = await recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    final text = recognized.text.trim();
    return text.isEmpty ? null : text;
  } finally {
    await recognizer.close();
  }
}

ReceiptAnalysis? _fallbackAnalysisFromOcr(String? rawText) {
  final text = rawText?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.length >= 2)
      .toList();
  if (lines.isEmpty) {
    return null;
  }

  final storeName = _guessReceiptStore(lines);
  final totalAmount = _guessReceiptTotal(lines);
  if (storeName == null && totalAmount == null) {
    return null;
  }

  return ReceiptAnalysis(
    storeName: storeName,
    totalAmount: totalAmount,
    description: storeName == null ? 'Receipt purchase' : '$storeName purchase',
    category: 'other',
    confidence: 0.35,
  );
}

String? _guessReceiptStore(List<String> lines) {
  for (final line in lines.take(8)) {
    final normalized = line.toLowerCase();
    final hasLetter = RegExp(r'[a-zA-ZąćęłńóśźżĄĆĘŁŃÓŚŹŻ]').hasMatch(line);
    final looksLikeMetadata =
        normalized.contains('nip') ||
        normalized.contains('paragon') ||
        normalized.contains('receipt') ||
        normalized.contains('kasa') ||
        normalized.contains('terminal') ||
        normalized.contains('www.') ||
        normalized.contains('@');
    if (hasLetter && !looksLikeMetadata) {
      return line.length > 40 ? line.substring(0, 40).trim() : line;
    }
  }
  return null;
}

double? _guessReceiptTotal(List<String> lines) {
  double? fallback;
  for (final line in lines) {
    final amounts = _extractMoneyValues(line);
    if (amounts.isEmpty) {
      continue;
    }
    fallback = amounts.last;
    final normalized = line.toLowerCase();
    final looksLikeTotal =
        normalized.contains('total') ||
        normalized.contains('suma') ||
        normalized.contains('razem') ||
        normalized.contains('zapłaty') ||
        normalized.contains('zaplata') ||
        normalized.contains('należność') ||
        normalized.contains('naleznosc');
    if (looksLikeTotal) {
      return amounts.last;
    }
  }
  return fallback;
}

List<double> _extractMoneyValues(String line) {
  final matches = RegExp(r'(?<!\d)(\d{1,5})[,.](\d{2})(?!\d)').allMatches(line);
  return matches
      .map((match) => double.tryParse('${match.group(1)}.${match.group(2)}'))
      .whereType<double>()
      .where((value) => value > 0)
      .toList();
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

String _receiptAnalysisFallbackMessage(Object error) {
  final message = error.toString();
  final normalized = message.toLowerCase();
  if (normalized.contains('quota') ||
      normalized.contains('rate limit') ||
      normalized.contains('rate_limit') ||
      normalized.contains('resource_exhausted') ||
      normalized.contains('429')) {
    return 'Gemini quota is exhausted. Using local OCR only; check the fields before saving.';
  }
  if (message.contains('Function not found') ||
      message.contains('not configured') ||
      message.contains('analyze-receipt')) {
    return 'Receipt uploaded. Manual entry is ready; deploy receipt analysis to enable autofill.';
  }
  return 'Receipt uploaded, but automatic reading is unavailable. Fill the expense manually.';
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
                'Uploading and reading receipt...',
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
            'Runs local OCR first, then uses AI to turn receipt text into expense suggestions.',
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
