import 'package:flutter/material.dart';

/// Protoolbag Core spacing sistemi
///
/// 4px grid sistemine dayalı tutarlı spacing değerleri.
/// Tüm UI elementleri arasındaki boşluklar bu değerlerle tanımlanır.
class AppSpacing {
  AppSpacing._();

  // ============================================
  // BASE SPACING VALUES
  // ============================================

  /// Extra small - 4px
  static const double xs = 4.0;

  /// Small - 8px
  static const double sm = 8.0;

  /// Medium - 16px
  static const double md = 16.0;

  /// Large - 24px
  static const double lg = 24.0;

  /// Extra large - 32px
  static const double xl = 32.0;

  /// Extra extra large - 48px
  static const double xxl = 48.0;

  /// Extra extra extra large - 64px
  static const double xxxl = 64.0;

  // ============================================
  // SEMANTIC SPACING
  // ============================================

  /// Screen horizontal padding
  static const double screenHorizontal = 16.0;

  /// Screen vertical padding
  static const double screenVertical = 16.0;

  /// Card internal padding
  static const double cardPadding = 16.0;

  /// List item vertical padding
  static const double listItemVertical = 12.0;

  /// List item horizontal padding
  static const double listItemHorizontal = 16.0;

  /// Section spacing (between sections)
  static const double sectionSpacing = 32.0;

  /// Form field spacing
  static const double formFieldSpacing = 16.0;

  /// Button spacing (between buttons)
  static const double buttonSpacing = 12.0;

  /// Icon text spacing
  static const double iconTextSpacing = 8.0;

  // ============================================
  // BORDER RADIUS
  // ============================================

  /// Extra small radius - 4px
  static const double radiusXs = 4.0;

  /// Small radius - 8px
  static const double radiusSm = 8.0;

  /// Medium radius - 12px
  static const double radiusMd = 12.0;

  /// Large radius - 16px
  static const double radiusLg = 16.0;

  /// Extra large radius - 20px
  static const double radiusXl = 20.0;

  /// Full radius (circular)
  static const double radiusFull = 9999.0;

  // ============================================
  // COMPONENT SIZES
  // ============================================

  /// Button height - small
  static const double buttonHeightSm = 32.0;

  /// Button height - medium
  static const double buttonHeightMd = 44.0;

  /// Button height - large
  static const double buttonHeightLg = 52.0;

  /// Text field height
  static const double textFieldHeight = 44.0;

  /// Icon size - small
  static const double iconSizeSm = 16.0;

  /// Icon size - medium
  static const double iconSizeMd = 24.0;

  /// Icon size - large
  static const double iconSizeLg = 32.0;

  /// Avatar size - small
  static const double avatarSizeSm = 32.0;

  /// Avatar size - medium
  static const double avatarSizeMd = 44.0;

  /// Avatar size - large
  static const double avatarSizeLg = 64.0;

  // ============================================
  // EDGE INSETS HELPERS
  // ============================================

  /// All sides - xs
  static const EdgeInsets allXs = EdgeInsets.all(xs);

  /// All sides - sm
  static const EdgeInsets allSm = EdgeInsets.all(sm);

  /// All sides - md
  static const EdgeInsets allMd = EdgeInsets.all(md);

  /// All sides - lg
  static const EdgeInsets allLg = EdgeInsets.all(lg);

  /// Horizontal - md
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);

  /// Vertical - md
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);

  /// Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
    vertical: screenVertical,
  );

  /// Card padding
  static const EdgeInsets cardInsets = EdgeInsets.all(cardPadding);

  /// List item padding
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: listItemHorizontal,
    vertical: listItemVertical,
  );
}
