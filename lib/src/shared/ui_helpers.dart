part of '../pizza_tracker_app.dart';

String? _validatePositiveAmount(String? value) {
  final amount = double.tryParse((value ?? '').replaceAll(',', '.'));
  if (amount == null || amount <= 0) {
    return 'Enter an amount above 0.';
  }
  return null;
}

String? _validateMonthDay(String? value) {
  final day = int.tryParse(value ?? '');
  if (day == null || day < 1 || day > 28) {
    return 'Use a day from 1 to 28.';
  }
  return null;
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
