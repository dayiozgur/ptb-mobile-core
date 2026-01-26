import 'package:flutter/material.dart';

/// BuildContext için uzantı metodları
extension ContextExtensions on BuildContext {
  // ============================================
  // THEME
  // ============================================

  /// Mevcut tema
  ThemeData get theme => Theme.of(this);

  /// Renk şeması
  ColorScheme get colorScheme => theme.colorScheme;

  /// Text theme
  TextTheme get textTheme => theme.textTheme;

  /// Brightness (light/dark)
  Brightness get brightness => theme.brightness;

  /// Dark mode mu?
  bool get isDarkMode => brightness == Brightness.dark;

  /// Light mode mu?
  bool get isLightMode => brightness == Brightness.light;

  // ============================================
  // COLORS (shortcuts)
  // ============================================

  /// Primary renk
  Color get primaryColor => colorScheme.primary;

  /// Secondary renk
  Color get secondaryColor => colorScheme.secondary;

  /// Surface rengi
  Color get surfaceColor => colorScheme.surface;

  /// Error rengi
  Color get errorColor => colorScheme.error;

  /// Background rengi
  Color get backgroundColor => theme.scaffoldBackgroundColor;

  // ============================================
  // MEDIA QUERY
  // ============================================

  /// Ekran boyutu
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Ekran genişliği
  double get screenWidth => screenSize.width;

  /// Ekran yüksekliği
  double get screenHeight => screenSize.height;

  /// Safe area padding
  EdgeInsets get padding => MediaQuery.paddingOf(this);

  /// View insets (keyboard vb.)
  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);

  /// Orientation
  Orientation get orientation => MediaQuery.orientationOf(this);

  /// Portrait mi?
  bool get isPortrait => orientation == Orientation.portrait;

  /// Landscape mi?
  bool get isLandscape => orientation == Orientation.landscape;

  /// Text scale factor
  double get textScale => MediaQuery.textScaleFactorOf(this);

  /// Device pixel ratio
  double get devicePixelRatio => MediaQuery.devicePixelRatioOf(this);

  // ============================================
  // RESPONSIVE BREAKPOINTS
  // ============================================

  /// Mobil mi? (< 600px)
  bool get isMobile => screenWidth < 600;

  /// Tablet mi? (600px - 1024px)
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;

  /// Desktop mu? (>= 1024px)
  bool get isDesktop => screenWidth >= 1024;

  /// Küçük ekran mı? (< 375px)
  bool get isSmallScreen => screenWidth < 375;

  /// Büyük ekran mı? (>= 768px)
  bool get isLargeScreen => screenWidth >= 768;

  // ============================================
  // NAVIGATION
  // ============================================

  /// Navigator state
  NavigatorState get navigator => Navigator.of(this);

  /// Can pop?
  bool get canPop => navigator.canPop();

  /// Pop
  void pop<T>([T? result]) => navigator.pop(result);

  /// Push named
  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) {
    return navigator.pushNamed<T>(routeName, arguments: arguments);
  }

  /// Push replacement named
  Future<T?> pushReplacementNamed<T, TO>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return navigator.pushReplacementNamed<T, TO>(
      routeName,
      result: result,
      arguments: arguments,
    );
  }

  /// Pop until
  void popUntil(bool Function(Route<dynamic>) predicate) {
    navigator.popUntil(predicate);
  }

  /// Pop to root
  void popToRoot() {
    navigator.popUntil((route) => route.isFirst);
  }

  // ============================================
  // FOCUS
  // ============================================

  /// Mevcut focus'u kaldır (klavyeyi kapat)
  void unfocus() => FocusScope.of(this).unfocus();

  /// Focus request
  void requestFocus(FocusNode node) => FocusScope.of(this).requestFocus(node);

  // ============================================
  // SNACKBAR & DIALOGS
  // ============================================

  /// SnackBar göster
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    return ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: action,
      ),
    );
  }

  /// Success SnackBar göster
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSuccessSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    return ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Error SnackBar göster
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showErrorSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    return ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: colorScheme.error,
      ),
    );
  }

  /// Tüm SnackBar'ları kapat
  void hideCurrentSnackBar() {
    ScaffoldMessenger.of(this).hideCurrentSnackBar();
  }

  /// Modal bottom sheet göster
  Future<T?> showBottomSheet<T>({
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = false,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
  }) {
    return showModalBottomSheet<T>(
      context: this,
      builder: builder,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
    );
  }

  /// Alert dialog göster
  Future<T?> showAlertDialog<T>({
    String? title,
    String? content,
    String? cancelText,
    String? confirmText,
    VoidCallback? onCancel,
    VoidCallback? onConfirm,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: this,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        title: title != null ? Text(title) : null,
        content: content != null ? Text(content) : null,
        actions: [
          if (cancelText != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onCancel?.call();
              },
              child: Text(cancelText),
            ),
          if (confirmText != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm?.call();
              },
              child: Text(confirmText),
            ),
        ],
      ),
    );
  }
}
