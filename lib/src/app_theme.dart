import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
        backgroundTop: Color(0xfffff8ef),
        backgroundBottom: Color(0xfff6eadc),
        surface: Color(0xfffffcf8),
        surfaceStrong: Color(0xfffbf1e6),
        border: Color(0xffe8d3bd),
        primaryGlow: Color(0xffc2572a),
        secondaryGlow: Color(0xffd9923b),
        tertiaryGlow: Color(0xffad3f32),
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
  );
  final baseText = GoogleFonts.interTextTheme(baseTheme.textTheme);
  final textTheme = baseText
      .copyWith(
        displayLarge: GoogleFonts.lora(
          fontSize: 58,
          height: 0.95,
          letterSpacing: -2.8,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        displayMedium: GoogleFonts.lora(
          fontSize: 42,
          height: 1.02,
          letterSpacing: -1.8,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        headlineLarge: GoogleFonts.lora(
          fontSize: 32,
          height: 1.05,
          letterSpacing: -1.2,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        headlineMedium: GoogleFonts.lora(
          fontSize: 26,
          height: 1.08,
          letterSpacing: -0.9,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 21,
          letterSpacing: -0.4,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 17,
          letterSpacing: -0.25,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurfaceVariant,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.backgroundTop,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.lora(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
        letterSpacing: -0.6,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.primaryGlow, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: colorScheme.onSurface,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.primaryGlow,
      foregroundColor: _foregroundFor(palette.primaryGlow),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.border),
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
