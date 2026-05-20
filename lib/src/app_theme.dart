import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appThemePresetProvider =
    NotifierProvider<AppThemePresetController, AppThemePreset>(
      AppThemePresetController.new,
    );

class AppThemePresetController extends Notifier<AppThemePreset> {
  @override
  AppThemePreset build() => AppThemePreset.pizza;

  void select(AppThemePreset preset) {
    state = preset;
  }
}

enum AppThemePreset { pizza, midnight, matcha, berry, espresso }

extension AppThemePresetDetails on AppThemePreset {
  String get label {
    return switch (this) {
      AppThemePreset.pizza => 'Margherita Ledger',
      AppThemePreset.midnight => 'Oxford Blue',
      AppThemePreset.matcha => 'Market Green',
      AppThemePreset.berry => 'Berry Receipt',
      AppThemePreset.espresso => 'Espresso Book',
    };
  }

  String get description {
    return switch (this) {
      AppThemePreset.pizza => 'Warm tomato and paper tones',
      AppThemePreset.midnight => 'Dark navy evening ledger',
      AppThemePreset.matcha => 'Calm green notebook palette',
      AppThemePreset.berry => 'Dark berry receipt archive',
      AppThemePreset.espresso => 'Coffee, ink, and old ledgers',
    };
  }

  Brightness get brightness {
    return switch (this) {
      AppThemePreset.midnight || AppThemePreset.berry => Brightness.dark,
      _ => Brightness.light,
    };
  }

  Color get seedColor {
    return switch (this) {
      AppThemePreset.pizza => const Color(0xffc2572a),
      AppThemePreset.midnight => const Color(0xff8fbce6),
      AppThemePreset.matcha => const Color(0xff5f7f42),
      AppThemePreset.berry => const Color(0xffe4a2bd),
      AppThemePreset.espresso => const Color(0xff7a4a28),
    };
  }

  AppPalette get palette {
    return switch (this) {
      AppThemePreset.pizza => const AppPalette(
        backgroundTop: Color(0xfff7e7c8),
        backgroundBottom: Color(0xfff1d8a6),
        surface: Color(0xfffff5dd),
        surfaceStrong: Color(0xfffae3b6),
        border: Color(0xff2a1810),
        primaryGlow: Color(0xffc62828),
        secondaryGlow: Color(0xffe8a33d),
        tertiaryGlow: Color(0xff2f5d2b),
      ),
      AppThemePreset.midnight => const AppPalette(
        backgroundTop: Color(0xff101827),
        backgroundBottom: Color(0xff070b12),
        surface: Color(0xff151d2b),
        surfaceStrong: Color(0xff1f2a3a),
        border: Color(0xff34445c),
        primaryGlow: Color(0xff8fbce6),
        secondaryGlow: Color(0xffb8c8d9),
        tertiaryGlow: Color(0xffd09b7a),
      ),
      AppThemePreset.matcha => const AppPalette(
        backgroundTop: Color(0xfff7f8ef),
        backgroundBottom: Color(0xffe9eddc),
        surface: Color(0xfffffff8),
        surfaceStrong: Color(0xfff0f4e4),
        border: Color(0xffd3dcc1),
        primaryGlow: Color(0xff5f7f42),
        secondaryGlow: Color(0xff91a96d),
        tertiaryGlow: Color(0xffb47936),
      ),
      AppThemePreset.berry => const AppPalette(
        backgroundTop: Color(0xff22121a),
        backgroundBottom: Color(0xff10090d),
        surface: Color(0xff2a1721),
        surfaceStrong: Color(0xff351d2a),
        border: Color(0xff553447),
        primaryGlow: Color(0xffe4a2bd),
        secondaryGlow: Color(0xffc78aa7),
        tertiaryGlow: Color(0xffd4b06d),
      ),
      AppThemePreset.espresso => const AppPalette(
        backgroundTop: Color(0xfff8f2ea),
        backgroundBottom: Color(0xffeadfd2),
        surface: Color(0xfffffcf7),
        surfaceStrong: Color(0xfff2e7d8),
        border: Color(0xffd9c4ad),
        primaryGlow: Color(0xff7a4a28),
        secondaryGlow: Color(0xffaa7a51),
        tertiaryGlow: Color(0xffb35c38),
      ),
    };
  }
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.surface,
    required this.surfaceStrong,
    required this.border,
    required this.primaryGlow,
    required this.secondaryGlow,
    required this.tertiaryGlow,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color surface;
  final Color surfaceStrong;
  final Color border;
  final Color primaryGlow;
  final Color secondaryGlow;
  final Color tertiaryGlow;

  LinearGradient get pageGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundBottom],
  );

  LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGlow, secondaryGlow],
  );

  LinearGradient get panelGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface, surfaceStrong.withValues(alpha: 0.55)],
  );

  @override
  AppPalette copyWith({
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? surface,
    Color? surfaceStrong,
    Color? border,
    Color? primaryGlow,
    Color? secondaryGlow,
    Color? tertiaryGlow,
  }) {
    return AppPalette(
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      surface: surface ?? this.surface,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      border: border ?? this.border,
      primaryGlow: primaryGlow ?? this.primaryGlow,
      secondaryGlow: secondaryGlow ?? this.secondaryGlow,
      tertiaryGlow: tertiaryGlow ?? this.tertiaryGlow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }

    return AppPalette(
      backgroundTop: Color.lerp(backgroundTop, other.backgroundTop, t)!,
      backgroundBottom: Color.lerp(
        backgroundBottom,
        other.backgroundBottom,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      border: Color.lerp(border, other.border, t)!,
      primaryGlow: Color.lerp(primaryGlow, other.primaryGlow, t)!,
      secondaryGlow: Color.lerp(secondaryGlow, other.secondaryGlow, t)!,
      tertiaryGlow: Color.lerp(tertiaryGlow, other.tertiaryGlow, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

ThemeData buildAppTheme(AppThemePreset preset) {
  final palette = preset.palette;
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: preset.seedColor,
        brightness: preset.brightness,
      ).copyWith(
        surface: palette.surface,
        surfaceContainerHighest: palette.surfaceStrong,
      );

  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: preset.brightness,
    colorScheme: colorScheme,
    splashFactory: InkRipple.splashFactory,
  );
  final baseText = baseTheme.textTheme;
  final textTheme = baseText
      .copyWith(
        displayLarge: TextStyle(
          fontFamily: 'serif',
          fontSize: 56,
          height: 0.95,
          letterSpacing: -1.6,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: colorScheme.onSurface,
        ),
        displayMedium: TextStyle(
          fontFamily: 'serif',
          fontSize: 40,
          height: 1.02,
          letterSpacing: -1.0,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: colorScheme.onSurface,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'serif',
          fontSize: 30,
          height: 1.05,
          letterSpacing: -0.6,
          fontWeight: FontWeight.w900,
          color: colorScheme.onSurface,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'serif',
          fontSize: 24,
          height: 1.1,
          letterSpacing: -0.4,
          fontWeight: FontWeight.w900,
          color: colorScheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontFamily: 'serif',
          fontSize: 22,
          letterSpacing: -0.2,
          fontWeight: FontWeight.w900,
          color: colorScheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        labelLarge: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        labelSmall: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
      )
      .apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      );

  return baseTheme.copyWith(
    extensions: [palette],
    scaffoldBackgroundColor: palette.backgroundBottom,
    textTheme: textTheme,
    cardTheme: CardThemeData(
      color: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.backgroundTop,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'serif',
        fontSize: 24,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        color: colorScheme.onSurface,
        letterSpacing: -0.4,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: palette.border, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: palette.border, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: palette.primaryGlow, width: 2.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(
        color: colorScheme.onSurface,
        fontFamily: 'monospace',
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primaryGlow,
        foregroundColor: _foregroundFor(palette.primaryGlow),
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: palette.border, width: 2),
        ),
        textStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        side: BorderSide(color: palette.border, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        foregroundColor: colorScheme.onSurface,
        textStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.primaryGlow,
        textStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.primaryGlow,
      foregroundColor: _foregroundFor(palette.primaryGlow),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: palette.border, width: 2.5),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: palette.border, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: palette.border,
      thickness: 1.2,
      space: 1.2,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.surface,
      side: BorderSide(color: palette.border, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      labelStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: colorScheme.onSurface,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
    ),
  );
}

Color _foregroundFor(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : const Color(0xff1f1712);
}
