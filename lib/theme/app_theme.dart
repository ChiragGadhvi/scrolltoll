import 'package:flutter/material.dart';

/// Numerals that don't jitter as values animate or change width. Every figure
/// the user reads as a measurement uses this.
const tabularFigures = <FontFeature>[FontFeature.tabularFigures()];

/// Bundled under `assets/fonts/` and declared in pubspec.
///
/// Previously this came from `google_fonts`, which fetches the font over the
/// network at runtime. That silently could not work in a release build — the
/// release manifest has no INTERNET permission (deliberately, it matches the
/// privacy promise), so the shipped app fell back to the platform font while
/// debug builds looked correct. Vendoring the TTFs is the only way to have both
/// Poppins and no network. Licence in assets/fonts/OFL.txt.
const _fontFamily = 'Poppins';

class AppColors {
  // Surfaces. The page is very slightly lilac so Rotto's purple reads as the
  // brand colour rather than an accident.
  static const background = Color(0xFFFAF9FC);
  static const card = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3F1F8);
  static const divider = Color(0xFFEBE9F1);

  /// The two tones of the "hill" Rotto stands on, on Home.
  static const hill = Color(0xFFE3DCF3);
  static const hillLight = Color(0xFFF3F0FA);

  /// Brand purple — Rotto's own body colour.
  static const primary = Color(0xFF7C5CBF);
  static const primaryDeep = Color(0xFF56399A);
  static const primarySoft = Color(0xFFF1ECFB);

  // The five-step mood ramp, green → red. These values are mirrored in
  // BrainfogWidgetProvider.kt — keep them in sync.
  static const safe = Color(0xFF1B9E4B);

  /// Second rung of the ramp, between [safe] and [warning].
  static const safeDim = Color(0xFF7FA82B);
  static const warning = Color(0xFFC77700);

  /// Fourth rung (Binge Mode). Named explicitly because [primary] used to hold
  /// this orange back when the app was ScrollToll — the ramp must stay
  /// green → red regardless of what the brand colour is.
  static const bingeOrange = Color(0xFFF2622E);
  static const danger = Color(0xFFDC2F3C);

  static const textPrimary = Color(0xFF15131E);
  static const textSecondary = Color(0xFF6B6779);
  static const textTertiary = Color(0xFF9A96A8);
}

/// Light Material 3 — the only theme. There is no dark variant.
class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primarySoft,
        onPrimaryContainer: AppColors.primaryDeep,
        surface: AppColors.card,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceMuted,
        outlineVariant: AppColors.divider,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: AppColors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySoft,
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDeep
                : AppColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDeep
                : AppColors.textSecondary,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.primary
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.textSecondary,
          ),
          side: const WidgetStatePropertyAll(BorderSide.none),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: _fontFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.card),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
