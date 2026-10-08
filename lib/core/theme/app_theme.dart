import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const green = Color(0xFF00796B);
  static const deepGreen = Color(0xFF064E50);
  static const mint = Color(0xFFDDF5EF);
  static const ink = Color(0xFF173344);
  static const muted = Color(0xFF526977);
  static const surface = Color(0xFFF3F7FB);
  static const warning = Color(0xFF9A5B00);
  static const ocean = Color(0xFF245DA8);
  static const violet = Color(0xFF7154AD);
  static const amber = Color(0xFFFFCC73);
  static const border = Color(0xFFDCE6EE);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepGreen, green, ocean],
    stops: [0, 0.55, 1],
  );

  static const canvasGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEAF7F3), surface, Color(0xFFEEF1FB)],
  );

  static const danger = Color(0xFFB63E45);
}

enum AppPalette {
  teal('Radiant Teal', AppColors.green),
  ocean('Ocean Blue', AppColors.ocean),
  violet('Royal Violet', AppColors.violet);

  const AppPalette(this.label, this.seed);
  final String label;
  final Color seed;
}

class AppTheme {
  AppTheme._();

  static ThemeData light({AppPalette palette = AppPalette.teal}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.seed,
      brightness: Brightness.light,
      primary: palette.seed,
      surface: Colors.white,
      secondary: AppColors.ocean,
      tertiary: AppColors.violet,
      onSurface: AppColors.ink,
      error: AppColors.danger,
      outline: AppColors.muted,
      outlineVariant: AppColors.border,
    );

    final accent = scheme.primary;
    final accentSurface = scheme.primaryContainer;
    final accentInk = scheme.onPrimaryContainer;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accentSurface,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? accentInk
                : AppColors.muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: accentSurface,
        selectedIconTheme: IconThemeData(color: accentInk),
        unselectedIconTheme: IconThemeData(color: AppColors.muted),
        selectedLabelTextStyle: TextStyle(
          color: accentInk,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: TextStyle(color: AppColors.muted),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: accentSurface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      scaffoldBackgroundColor: Color.alphaBlend(
        accent.withValues(alpha: 0.04),
        AppColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: const Color(0x18173344),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFDCE6EE)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD9E3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD9E3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: Color(0xFFB5CAD8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        backgroundColor: const Color(0xFFEAF1F7),
        labelStyle: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
