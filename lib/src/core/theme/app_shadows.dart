import 'package:flutter/material.dart';

/// Protoolbag Core shadow sistemi
///
/// Apple HIG'e uygun gölge tanımlamaları.
/// Light ve Dark mode için optimize edilmiş değerler.
class AppShadows {
  AppShadows._();

  // ============================================
  // LIGHT MODE SHADOWS
  // ============================================

  /// Light mode - No shadow
  static const List<BoxShadow> noneLight = [];

  /// Light mode - Extra small shadow
  static const List<BoxShadow> xsLight = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// Light mode - Small shadow
  static const List<BoxShadow> smLight = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  /// Light mode - Medium shadow (cards)
  static const List<BoxShadow> mdLight = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  /// Light mode - Large shadow (modals, dropdowns)
  static const List<BoxShadow> lgLight = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  /// Light mode - Extra large shadow (floating elements)
  static const List<BoxShadow> xlLight = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  // ============================================
  // DARK MODE SHADOWS
  // ============================================

  /// Dark mode - No shadow
  static const List<BoxShadow> noneDark = [];

  /// Dark mode - Extra small shadow
  static const List<BoxShadow> xsDark = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// Dark mode - Small shadow
  static const List<BoxShadow> smDark = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  /// Dark mode - Medium shadow (cards)
  static const List<BoxShadow> mdDark = [
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  /// Dark mode - Large shadow (modals, dropdowns)
  static const List<BoxShadow> lgDark = [
    BoxShadow(
      color: Color(0x59000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  /// Dark mode - Extra large shadow (floating elements)
  static const List<BoxShadow> xlDark = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Brightness'a göre uygun shadow döner
  static List<BoxShadow> none(Brightness brightness) {
    return brightness == Brightness.light ? noneLight : noneDark;
  }

  /// Extra small shadow
  static List<BoxShadow> xs(Brightness brightness) {
    return brightness == Brightness.light ? xsLight : xsDark;
  }

  /// Small shadow
  static List<BoxShadow> sm(Brightness brightness) {
    return brightness == Brightness.light ? smLight : smDark;
  }

  /// Medium shadow
  static List<BoxShadow> md(Brightness brightness) {
    return brightness == Brightness.light ? mdLight : mdDark;
  }

  /// Large shadow
  static List<BoxShadow> lg(Brightness brightness) {
    return brightness == Brightness.light ? lgLight : lgDark;
  }

  /// Extra large shadow
  static List<BoxShadow> xl(Brightness brightness) {
    return brightness == Brightness.light ? xlLight : xlDark;
  }

  /// Card shadow
  static List<BoxShadow> card(Brightness brightness) => md(brightness);

  /// Modal/Bottom sheet shadow
  static List<BoxShadow> modal(Brightness brightness) => lg(brightness);

  /// Dropdown shadow
  static List<BoxShadow> dropdown(Brightness brightness) => lg(brightness);

  /// Floating action button shadow
  static List<BoxShadow> fab(Brightness brightness) => xl(brightness);
}
