import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the design tokens into the app's [ThemeData].
///
/// Everything visual that is not screen-specific belongs here. The payoff:
/// a screen can drop to plain `Card`, `TextField`, `FilledButton` and still
/// come out on-brand, which is what keeps 25 screens consistent without
/// every screen re-declaring its own styling.
class AppTheme {
  AppTheme._();

  /// Minimum interactive height. WCAG 2.5.5 asks for 44px; Material asks
  /// for 48. We take 48 for primary controls and never go below 44.
  static const double _minTapTarget = 48;

  static ThemeData light() => _build(
        brightness: Brightness.light,
        tones: AppSemanticColors.light,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        tones: AppSemanticColors.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppSemanticColors tones,
  }) {
    final isLight = brightness == Brightness.light;

    // Seeded for Material's full tonal range, then pinned on the roles we
    // actually care about so the brand reads exactly as specified rather
    // than as whatever the tonal algorithm derives.
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.brand600,
      brightness: brightness,
    ).copyWith(
      primary: isLight ? AppPalette.brand700 : AppPalette.brand300,
      onPrimary: isLight ? AppPalette.neutral0 : AppPalette.brand900,
      primaryContainer: tones.brand.bg,
      onPrimaryContainer: tones.brand.fg,
      error: isLight ? AppPalette.negative600 : AppPalette.negative400,
      surface: tones.surface,
      onSurface: tones.textPrimary,
      onSurfaceVariant: tones.textSecondary,
      outline: tones.border,
      outlineVariant: tones.border,
    );

    final textTheme =
        AppTypography.textTheme(tones.textPrimary, tones.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: tones.canvas,
      canvasColor: tones.surface,
      dividerColor: tones.border,

      // Semantic tokens ride along on the theme so any widget can read them
      // via `context.tones` and stay correct in both brightnesses.
      extensions: <ThemeExtension<dynamic>>[tones],

      // ---------------------------------------------------------------
      // App bar - flat and quiet. A colored, elevated bar competes with
      // the content for attention; on a data screen the data should win.
      // ---------------------------------------------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: tones.surface,
        foregroundColor: tones.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: tones.textSecondary, size: 22),
        actionsIconTheme: IconThemeData(color: tones.textSecondary, size: 22),
        shape: Border(bottom: BorderSide(color: tones.border, width: AppBorders.hairline)),
      ),

      // ---------------------------------------------------------------
      // Cards - hairline border instead of a drop shadow. Borders keep
      // dense financial layouts legible; stacked shadows turn to mud.
      // ---------------------------------------------------------------
      cardTheme: CardThemeData(
        color: tones.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: tones.border, width: AppBorders.hairline),
        ),
      ),

      // ---------------------------------------------------------------
      // Inputs - filled, not outlined-on-white. A subtle fill makes the
      // tappable area obvious at a glance, and the 2px focus ring is an
      // accessibility requirement, not decoration.
      // ---------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppPalette.neutral50 : AppPalette.neutral800,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: tones.textTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: tones.textSecondary),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(color: scheme.primary),
        prefixIconColor: tones.textTertiary,
        suffixIconColor: tones.textTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: tones.border, width: AppBorders.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: tones.border, width: AppBorders.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: AppBorders.focus),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: AppBorders.hairline),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: AppBorders.focus),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, _minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, _minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: textTheme.labelLarge,
          foregroundColor: tones.textPrimary,
          side: BorderSide(color: tones.borderStrong, width: AppBorders.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          textStyle: textTheme.labelLarge,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: tones.textSecondary,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isLight ? AppPalette.neutral100 : AppPalette.neutral800,
        selectedColor: tones.brand.bg,
        checkmarkColor: tones.brand.fg,
        labelStyle: textTheme.labelMedium?.copyWith(color: tones.textSecondary),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: tones.brand.fg),
        side: BorderSide(color: tones.border, width: AppBorders.hairline),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        iconColor: tones.textSecondary,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
       shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: tones.border,
        thickness: AppBorders.hairline,
        space: AppBorders.hairline,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? AppPalette.neutral900 : AppPalette.neutral800,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppPalette.neutral0),
        actionTextColor: AppPalette.brand300,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: tones.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: tones.textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tones.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: tones.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: tones.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: tones.border, width: AppBorders.hairline),
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          side: WidgetStatePropertyAll(
            BorderSide(color: tones.border, width: AppBorders.hairline),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: tones.border,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isLight ? AppPalette.neutral900 : AppPalette.neutral700,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: AppPalette.neutral0),
      ),
    );
  }
}
