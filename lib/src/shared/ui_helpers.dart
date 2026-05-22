part of '../pizza_tracker_app.dart';

String? _validatePositiveAmount(String? value) {
  final amount = double.tryParse((value ?? '').replaceAll(',', '.'));
  if (amount == null || amount <= 0) {
    return AppText(
      AppLanguage.fromCode(Intl.getCurrentLocale()),
    ).enterAmountAboveZero;
  }
  return null;
}

String? _validateMonthDay(String? value) {
  final day = int.tryParse(value ?? '');
  if (day == null || day < 1 || day > 28) {
    return AppText(
      AppLanguage.fromCode(Intl.getCurrentLocale()),
    ).useDayFrom1To28;
  }
  return null;
}

double _responsiveGutter(BuildContext context, {double maxWidth = 860}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width <= maxWidth) {
    return 16;
  }
  return ((width - maxWidth) / 2).clamp(16, 220).toDouble();
}

({Color color, String label, String shortLabel, IconData icon}) _levelForIndex(
  int index,
) {
  final text = AppText(AppLanguage.fromCode(Intl.getCurrentLocale()));
  final level = text.levelText(index);
  if (index <= 20) {
    return (
      color: const Color(0xff22c55e),
      label: level.label,
      shortLabel: level.shortLabel,
      icon: Icons.check_circle_outline,
    );
  }
  if (index <= 45) {
    return (
      color: const Color(0xffeab308),
      label: level.label,
      shortLabel: level.shortLabel,
      icon: Icons.visibility_outlined,
    );
  }
  if (index <= 70) {
    return (
      color: const Color(0xfff97316),
      label: level.label,
      shortLabel: level.shortLabel,
      icon: Icons.soup_kitchen_outlined,
    );
  }
  if (index <= 90) {
    return (
      color: const Color(0xffef4444),
      label: level.label,
      shortLabel: level.shortLabel,
      icon: Icons.warning_amber_rounded,
    );
  }
  return (
    color: const Color(0xffa855f7),
    label: level.label,
    shortLabel: level.shortLabel,
    icon: Icons.crisis_alert_outlined,
  );
}

String _categoryLabel(String category) {
  return AppText(
    AppLanguage.fromCode(Intl.getCurrentLocale()),
  ).categoryLabel(category);
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

String _normalizeCurrencyCode(String value) {
  final code = value.trim().toUpperCase();
  return supportedCurrencies.contains(code) ? code : 'PLN';
}

String _currencyLabel(BuildContext context, String code) {
  final labels = context.text.isPolish
      ? const {
          'PLN': 'PLN - złoty polski',
          'USD': 'USD - dolar amerykański',
          'EUR': 'EUR - euro',
          'GBP': 'GBP - funt brytyjski',
          'CHF': 'CHF - frank szwajcarski',
          'CZK': 'CZK - korona czeska',
        }
      : const {
          'PLN': 'PLN - Polish zloty',
          'USD': 'USD - US dollar',
          'EUR': 'EUR - euro',
          'GBP': 'GBP - British pound',
          'CHF': 'CHF - Swiss franc',
          'CZK': 'CZK - Czech koruna',
        };
  return labels[code] ?? code;
}
