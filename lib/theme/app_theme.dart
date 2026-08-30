import 'package:flutter/material.dart';

/// Central Yatra design system.
///
/// Everything visual lives here so screens stay consistent and read the
/// theme instead of pinning hard-coded colors, sizes and radii. Screens that
/// use `Theme.of(context)` and the shared widgets pick up this system
/// automatically.
///
/// Palette is Nepal-inspired: a deep Himalayan-teal primary (lakes & skies),
/// a saffron/marigold tertiary accent (the flag & marigolds) and warm
/// off-white neutrals for a calm, premium travel feel.
abstract final class AppColors {
  AppColors._();

  /// Deep Himalayan teal — the brand primary.
  static const Color primary = Color(0xFF0F6A72);

  /// Saffron / marigold — used sparingly for highlights & accents.
  static const Color accent = Color(0xFFC77800);

  /// Warm off-white app background (soft neutral, not stark white).
  static const Color background = Color(0xFFF8F7F4);

  /// Pure surface for cards.
  static const Color surface = Color(0xFFFFFFFF);

  /// Inks.
  static const Color onSurface = Color(0xFF1C1B1A);
  static const Color onSurfaceMuted = Color(0xFF54514C);
  static const Color onSurfaceHint = Color(0xFF797670);

  /// Semantic status colours.
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFB26A00);
  static const Color danger = Color(0xFFC62828);
}

/// Shared spacing scale. Prefer these over ad-hoc values.
abstract final class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double screen = xxl;
}

/// Shared corner-radius scale.
abstract final class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

/// Shared type scale for the app (kept DRY across the TextTheme).
abstract final class AppType {
  AppType._();

  static const display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
    color: AppColors.onSurface,
    height: 1.15,
  );

  static const headline = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
    height: 1.2,
  );

  static const title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
    height: 1.25,
  );

  static const section = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
    height: 1.3,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceMuted,
    height: 1.55,
  );

  static const bodyEmphasis = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
    height: 1.5,
  );

  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceHint,
    height: 1.4,
  );

  static const label = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );
}

/// The central theme for the whole app.
class AppTheme {
  AppTheme._();

  /// The single brand seed colour.
  static const Color brand = AppColors.primary;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      surface: AppColors.surface,
    ).copyWith(
      primary: AppColors.primary,
      tertiary: AppColors.accent,
      error: AppColors.danger,
      outline: AppColors.onSurfaceHint,
      outlineVariant: const Color(0xFFC9C6C0),
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: const Color(0xFFF0EEEA),
      surfaceContainerHigh: const Color(0xFFE8E6E1),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      // ---- Text ----
      textTheme: base.textTheme.copyWith(
        displaySmall: AppType.display,
        headlineMedium: AppType.headline,
        headlineSmall: AppType.title,
        titleLarge: AppType.section,
        titleMedium: AppType.bodyEmphasis,
        bodyLarge: AppType.body.copyWith(fontSize: 16),
        bodyMedium: AppType.body,
        bodySmall: AppType.caption,
        labelLarge: AppType.label,
      ),

      // ---- AppBar ----
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppType.title.copyWith(fontSize: 18),
      ),

      // ---- Buttons ----
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          elevation: 1,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppType.label.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.onSurfaceHint),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppType.label.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: AppType.label.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.onSurfaceMuted,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),

      // ---- Inputs ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 16,
        ),
        hintStyle: AppType.caption,
        prefixIconColor: AppColors.onSurfaceHint,
        suffixIconColor: AppColors.onSurfaceHint,
        border: _inputBorder(scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.primary, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
      ),

      // ---- Cards ----
      cardTheme: CardThemeData(
        elevation: 1,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      ),

      // ---- Chips ----
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        selectedColor: AppColors.primary,
        secondarySelectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 8,
        ),
      ),

      // ---- Dividers ----
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        thickness: 1,
        space: 24,
      ),

      // ---- Progress ----
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.15),
        circularTrackColor: scheme.primary.withValues(alpha: 0.15),
      ),

      // ---- Snackbar ----
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.onSurface,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
