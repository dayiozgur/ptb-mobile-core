import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

/// Protoolbag Core tema yapılandırması
///
/// Apple HIG uyumlu light ve dark temalar.
/// MaterialApp'de doğrudan kullanılabilir.
class AppTheme {
  AppTheme._();

  // ============================================
  // LIGHT THEME
  // ============================================

  /// Light mode tema
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surfaceLight,
          error: AppColors.error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textPrimaryLight,
          onError: Colors.white,
        ),

        // AppBar Theme
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: AppColors.surfaceLight,
          foregroundColor: AppColors.textPrimaryLight,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryLight,
            letterSpacing: -0.41,
          ),
        ),

        // Card Theme
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          margin: EdgeInsets.zero,
        ),

        // Divider Theme
        dividerTheme: const DividerThemeData(
          color: AppColors.dividerLight,
          thickness: 0.5,
          space: 0,
        ),

        // Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.systemGray6,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: const BorderSide(color: AppColors.error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          hintStyle: AppTypography.body.copyWith(
            color: AppColors.textSecondaryLight,
          ),
          labelStyle: AppTypography.subhead.copyWith(
            color: AppColors.textSecondaryLight,
          ),
          errorStyle: AppTypography.caption1.copyWith(
            color: AppColors.error,
          ),
        ),

        // Elevated Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, AppSpacing.buttonHeightMd),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            textStyle: AppTypography.buttonMedium,
          ),
        ),

        // Text Button Theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(44, AppSpacing.buttonHeightMd),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            textStyle: AppTypography.buttonMedium,
          ),
        ),

        // Outlined Button Theme
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, AppSpacing.buttonHeightMd),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            side: const BorderSide(color: AppColors.primary),
            textStyle: AppTypography.buttonMedium,
          ),
        ),

        // Icon Theme
        iconTheme: const IconThemeData(
          color: AppColors.textPrimaryLight,
          size: AppSpacing.iconSizeMd,
        ),

        // Bottom Navigation Bar Theme
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceLight,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.systemGray,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: AppTypography.caption2,
          unselectedLabelStyle: AppTypography.caption2,
        ),

        // Tab Bar Theme
        tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.systemGray,
          indicatorColor: AppColors.primary,
          labelStyle: AppTypography.subhead,
          unselectedLabelStyle: AppTypography.subhead,
        ),

        // Bottom Sheet Theme
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceLight,
          modalBackgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLg),
            ),
          ),
        ),

        // Dialog Theme
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          titleTextStyle: AppTypography.headline.copyWith(
            color: AppColors.textPrimaryLight,
          ),
          contentTextStyle: AppTypography.body.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),

        // Snackbar Theme
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.textPrimaryLight,
          contentTextStyle: AppTypography.subhead.copyWith(
            color: Colors.white,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          behavior: SnackBarBehavior.floating,
        ),

        // List Tile Theme
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          minVerticalPadding: AppSpacing.sm,
        ),

        // Chip Theme
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.systemGray6,
          selectedColor: AppColors.primary.withOpacity(0.15),
          labelStyle: AppTypography.subhead,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
        ),

        // Progress Indicator Theme
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
          linearTrackColor: AppColors.systemGray5,
          circularTrackColor: AppColors.systemGray5,
        ),

        // Switch Theme
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.success;
            }
            return AppColors.systemGray4;
          }),
        ),

        // Text Theme
        textTheme: TextTheme(
          displayLarge: AppTypography.largeTitle.copyWith(
            color: AppColors.textPrimaryLight,
          ),
          displayMedium: AppTypography.title1.copyWith(
            color: AppColors.textPrimaryLight,
          ),
          displaySmall: AppTypography.title2.copyWith(
            color: AppColors.textPrimaryLight,
          ),
          headlineMedium: AppTypography.title3.copyWith(
            color: AppColors.textPrimaryLight,
          ),
          headlineSmall: AppTypography.headline.copyWith(
            color: AppColors.textPrimaryLight,
          ),
          titleLarge: AppTypography.headline.copyWith(
            color: AppColors.textPrimaryLight,
          ),
          titleMedium: AppTypography.callout.copyWith(
            color: AppColors.textPrimaryLight,
          ),
          titleSmall: AppTypography.subhead.copyWith(
            color: AppColors.textPrimaryLight,
          ),
          bodyLarge: AppTypography.body.copyWith(
            color: AppColors.textPrimaryLight,
          ),
          bodyMedium: AppTypography.callout.copyWith(
            color: AppColors.textPrimaryLight,
          ),
          bodySmall: AppTypography.footnote.copyWith(
            color: AppColors.textSecondaryLight,
          ),
          labelLarge: AppTypography.buttonMedium.copyWith(
            color: AppColors.textPrimaryLight,
          ),
          labelMedium: AppTypography.caption1.copyWith(
            color: AppColors.textSecondaryLight,
          ),
          labelSmall: AppTypography.caption2.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
      );

  // ============================================
  // DARK THEME
  // ============================================

  /// Dark mode tema
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surfaceDark,
          error: AppColors.error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textPrimaryDark,
          onError: Colors.white,
        ),

        // AppBar Theme
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: AppColors.surfaceDark,
          foregroundColor: AppColors.textPrimaryDark,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryDark,
            letterSpacing: -0.41,
          ),
        ),

        // Card Theme
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          margin: EdgeInsets.zero,
        ),

        // Divider Theme
        dividerTheme: const DividerThemeData(
          color: AppColors.dividerDark,
          thickness: 0.5,
          space: 0,
        ),

        // Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceElevatedDark,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: const BorderSide(color: AppColors.error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          hintStyle: AppTypography.body.copyWith(
            color: AppColors.textSecondaryDark,
          ),
          labelStyle: AppTypography.subhead.copyWith(
            color: AppColors.textSecondaryDark,
          ),
          errorStyle: AppTypography.caption1.copyWith(
            color: AppColors.error,
          ),
        ),

        // Elevated Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, AppSpacing.buttonHeightMd),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            textStyle: AppTypography.buttonMedium,
          ),
        ),

        // Text Button Theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(44, AppSpacing.buttonHeightMd),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            textStyle: AppTypography.buttonMedium,
          ),
        ),

        // Outlined Button Theme
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, AppSpacing.buttonHeightMd),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            side: const BorderSide(color: AppColors.primary),
            textStyle: AppTypography.buttonMedium,
          ),
        ),

        // Icon Theme
        iconTheme: const IconThemeData(
          color: AppColors.textPrimaryDark,
          size: AppSpacing.iconSizeMd,
        ),

        // Bottom Navigation Bar Theme
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.systemGray,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: AppTypography.caption2,
          unselectedLabelStyle: AppTypography.caption2,
        ),

        // Tab Bar Theme
        tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.systemGray,
          indicatorColor: AppColors.primary,
          labelStyle: AppTypography.subhead,
          unselectedLabelStyle: AppTypography.subhead,
        ),

        // Bottom Sheet Theme
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceElevatedDark,
          modalBackgroundColor: AppColors.surfaceElevatedDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLg),
            ),
          ),
        ),

        // Dialog Theme
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceElevatedDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          titleTextStyle: AppTypography.headline.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          contentTextStyle: AppTypography.body.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),

        // Snackbar Theme
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.surfaceElevatedDark,
          contentTextStyle: AppTypography.subhead.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          behavior: SnackBarBehavior.floating,
        ),

        // List Tile Theme
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          minVerticalPadding: AppSpacing.sm,
        ),

        // Chip Theme
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceElevatedDark,
          selectedColor: AppColors.primary.withOpacity(0.3),
          labelStyle: AppTypography.subhead.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
        ),

        // Progress Indicator Theme
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
          linearTrackColor: AppColors.surfaceElevatedDark,
          circularTrackColor: AppColors.surfaceElevatedDark,
        ),

        // Switch Theme
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.success;
            }
            return AppColors.systemGray;
          }),
        ),

        // Text Theme
        textTheme: TextTheme(
          displayLarge: AppTypography.largeTitle.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          displayMedium: AppTypography.title1.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          displaySmall: AppTypography.title2.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          headlineMedium: AppTypography.title3.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          headlineSmall: AppTypography.headline.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          titleLarge: AppTypography.headline.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          titleMedium: AppTypography.callout.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          titleSmall: AppTypography.subhead.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          bodyLarge: AppTypography.body.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          bodyMedium: AppTypography.callout.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          bodySmall: AppTypography.footnote.copyWith(
            color: AppColors.textSecondaryDark,
          ),
          labelLarge: AppTypography.buttonMedium.copyWith(
            color: AppColors.textPrimaryDark,
          ),
          labelMedium: AppTypography.caption1.copyWith(
            color: AppColors.textSecondaryDark,
          ),
          labelSmall: AppTypography.caption2.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
      );

  // ============================================
  // CUSTOM THEME BUILDERS
  // ============================================

  /// Özel primary renk ile light tema oluşturur
  static ThemeData customLight({
    Color? primaryColor,
    Color? accentColor,
  }) {
    final base = light;
    final primary = primaryColor ?? AppColors.primary;

    return base.copyWith(
      primaryColor: primary,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: accentColor ?? base.colorScheme.secondary,
      ),
    );
  }

  /// Özel primary renk ile dark tema oluşturur
  static ThemeData customDark({
    Color? primaryColor,
    Color? accentColor,
  }) {
    final base = dark;
    final primary = primaryColor ?? AppColors.primary;

    return base.copyWith(
      primaryColor: primary,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: accentColor ?? base.colorScheme.secondary,
      ),
    );
  }
}
