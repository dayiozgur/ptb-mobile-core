import 'package:flutter/material.dart';

/// Protoolbag Core renk sistemi
///
/// Apple Human Interface Guidelines'a uygun renk paleti.
/// Light ve Dark mode için ayrı renkler tanımlanmıştır.
class AppColors {
  AppColors._();

  // ============================================
  // BRAND COLORS
  // ============================================

  /// Primary brand color - iOS Blue
  static const Color primary = Color(0xFF007AFF);

  /// Secondary brand color
  static const Color secondary = Color(0xFF5856D6);

  /// Accent color
  static const Color accent = Color(0xFF5AC8FA);

  // ============================================
  // SEMANTIC COLORS
  // ============================================

  /// Success color - iOS Green
  static const Color success = Color(0xFF34C759);

  /// Warning color - iOS Orange
  static const Color warning = Color(0xFFFF9500);

  /// Error color - iOS Red
  static const Color error = Color(0xFFFF3B30);

  /// Info color - iOS Teal
  static const Color info = Color(0xFF5AC8FA);

  // ============================================
  // NEUTRAL COLORS - LIGHT MODE
  // ============================================

  /// Light mode background
  static const Color backgroundLight = Color(0xFFF2F2F7);

  /// Light mode surface (cards, sheets)
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Light mode primary text
  static const Color textPrimaryLight = Color(0xFF000000);

  /// Light mode secondary text
  static const Color textSecondaryLight = Color(0xFF8E8E93);

  /// Light mode tertiary text
  static const Color textTertiaryLight = Color(0xFFC7C7CC);

  /// Light mode divider
  static const Color dividerLight = Color(0xFFE5E5EA);

  /// Light mode border
  static const Color borderLight = Color(0xFFD1D1D6);

  // ============================================
  // NEUTRAL COLORS - DARK MODE
  // ============================================

  /// Dark mode background
  static const Color backgroundDark = Color(0xFF000000);

  /// Dark mode surface (cards, sheets)
  static const Color surfaceDark = Color(0xFF1C1C1E);

  /// Dark mode elevated surface
  static const Color surfaceElevatedDark = Color(0xFF2C2C2E);

  /// Dark mode primary text
  static const Color textPrimaryDark = Color(0xFFFFFFFF);

  /// Dark mode secondary text
  static const Color textSecondaryDark = Color(0xFF8E8E93);

  /// Dark mode tertiary text
  static const Color textTertiaryDark = Color(0xFF48484A);

  /// Dark mode divider
  static const Color dividerDark = Color(0xFF38383A);

  /// Dark mode border
  static const Color borderDark = Color(0xFF48484A);

  // ============================================
  // SYSTEM COLORS (iOS specific)
  // ============================================

  /// iOS system gray
  static const Color systemGray = Color(0xFF8E8E93);

  /// iOS system gray 2
  static const Color systemGray2 = Color(0xFFAEAEB2);

  /// iOS system gray 3
  static const Color systemGray3 = Color(0xFFC7C7CC);

  /// iOS system gray 4
  static const Color systemGray4 = Color(0xFFD1D1D6);

  /// iOS system gray 5
  static const Color systemGray5 = Color(0xFFE5E5EA);

  /// iOS system gray 6
  static const Color systemGray6 = Color(0xFFF2F2F7);

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Brightness'a göre uygun background rengi döner
  static Color background(Brightness brightness) {
    return brightness == Brightness.light ? backgroundLight : backgroundDark;
  }

  /// Brightness'a göre uygun surface rengi döner
  static Color surface(Brightness brightness) {
    return brightness == Brightness.light ? surfaceLight : surfaceDark;
  }

  /// Brightness'a göre uygun primary text rengi döner
  static Color textPrimary(Brightness brightness) {
    return brightness == Brightness.light ? textPrimaryLight : textPrimaryDark;
  }

  /// Brightness'a göre uygun secondary text rengi döner
  static Color textSecondary(Brightness brightness) {
    return brightness == Brightness.light
        ? textSecondaryLight
        : textSecondaryDark;
  }

  /// Brightness'a göre uygun divider rengi döner
  static Color divider(Brightness brightness) {
    return brightness == Brightness.light ? dividerLight : dividerDark;
  }

  /// Brightness'a göre uygun border rengi döner
  static Color border(Brightness brightness) {
    return brightness == Brightness.light ? borderLight : borderDark;
  }

  // ============================================
  // CONTEXT-AWARE HELPERS (iOS Label Colors)
  // ============================================

  /// Primary label color (for primary text)
  static Color primaryLabel(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? textPrimaryLight : textPrimaryDark;
  }

  /// Secondary label color (for secondary text)
  static Color secondaryLabel(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? textSecondaryLight : textSecondaryDark;
  }

  /// Tertiary label color (for tertiary/placeholder text)
  static Color tertiaryLabel(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? textTertiaryLight : textTertiaryDark;
  }

  /// Quaternary label color (for disabled text)
  static Color quaternaryLabel(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const Color(0xFFD1D1D6)
        : const Color(0xFF3A3A3C);
  }

  /// Separator color (for dividers and separators)
  static Color separator(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? dividerLight : dividerDark;
  }

  /// Opaque separator color (non-transparent separator)
  static Color opaqueSeparator(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const Color(0xFFC6C6C8)
        : const Color(0xFF38383A);
  }

  /// System background color
  static Color systemBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? backgroundLight : backgroundDark;
  }

  /// Grouped background color (for grouped table views)
  static Color groupedBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const Color(0xFFF2F2F7)
        : const Color(0xFF000000);
  }

  /// Card background color
  static Color cardBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? surfaceLight : surfaceDark;
  }

  /// Secondary system background color (for grouped content backgrounds)
  static Color secondarySystemBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const Color(0xFFF2F2F7)
        : const Color(0xFF1C1C1E);
  }

  /// Tertiary system background color (for nested content backgrounds)
  static Color tertiarySystemBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF2C2C2E);
  }

  /// Segmented control / inner tab bar background (iOS tarz)
  static Color segmentedBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const Color(0xFFF2F2F7) // systemGray6 light
        : const Color(0xFF2C2C2E); // elevated surface dark
  }

  /// Segmented control / inner tab bar seçili indicator rengi
  static Color segmentedIndicator(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const Color(0xFFFFFFFF) // white
        : const Color(0xFF3A3A3C); // systemGray dark
  }
}
