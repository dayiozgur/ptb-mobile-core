import 'package:flutter/material.dart';

/// Protoolbag Core tipografi sistemi
///
/// Apple Human Interface Guidelines'a uygun tipografi.
/// SF Pro Display font ailesi kullanılır.
class AppTypography {
  AppTypography._();

  // ============================================
  // FONT FAMILY
  // ============================================

  /// iOS varsayılan font (SF Pro Display)
  /// Flutter'da .SF Pro Text otomatik kullanılır
  static const String fontFamily = '.SF Pro Display';

  // ============================================
  // LARGE TITLE
  // ============================================

  /// Large Title - 34pt, Bold
  /// Kullanım: Ana ekran başlıkları
  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
    height: 1.2,
  );

  // ============================================
  // TITLES
  // ============================================

  /// Title 1 - 28pt, Bold
  /// Kullanım: Sayfa başlıkları
  static const TextStyle title1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.36,
    height: 1.2,
  );

  /// Title 2 - 22pt, Bold
  /// Kullanım: Section başlıkları
  static const TextStyle title2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.35,
    height: 1.3,
  );

  /// Title 3 - 20pt, Semibold
  /// Kullanım: Alt başlıklar
  static const TextStyle title3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.38,
    height: 1.3,
  );

  // ============================================
  // HEADLINE & BODY
  // ============================================

  /// Headline - 17pt, Semibold
  /// Kullanım: List item başlıkları, önemli metinler
  static const TextStyle headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.3,
  );

  /// Body - 17pt, Regular
  /// Kullanım: Ana içerik metni
  static const TextStyle body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    height: 1.4,
  );

  /// Callout - 16pt, Regular
  /// Kullanım: Açıklama metinleri, form alanları
  static const TextStyle callout = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
    height: 1.4,
  );

  /// Subhead - 15pt, Regular
  /// Kullanım: List item alt başlıkları
  static const TextStyle subhead = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
    height: 1.4,
  );

  /// Subheadline - alias for subhead (iOS naming convention)
  static const TextStyle subheadline = subhead;

  // ============================================
  // FOOTNOTE & CAPTION
  // ============================================

  /// Footnote - 13pt, Regular
  /// Kullanım: Dipnotlar, metadata
  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    height: 1.4,
  );

  /// Caption 1 - 12pt, Regular
  /// Kullanım: Tab bar labels, küçük etiketler
  static const TextStyle caption1 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
  );

  /// Caption 2 - 11pt, Regular
  /// Kullanım: Çok küçük metinler, badge'ler
  static const TextStyle caption2 = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.07,
    height: 1.2,
  );

  // ============================================
  // BUTTON STYLES
  // ============================================

  /// Button Large - 17pt, Semibold
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.2,
  );

  /// Button Medium - 15pt, Semibold
  static const TextStyle buttonMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.24,
    height: 1.2,
  );

  /// Button Small - 13pt, Semibold
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.08,
    height: 1.2,
  );

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Stil'e renk uygular
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Stil'e font weight uygular
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }
}
