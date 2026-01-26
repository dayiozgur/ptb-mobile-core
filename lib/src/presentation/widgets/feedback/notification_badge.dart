import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Bildirim rozeti widget'ı
///
/// Okunmamış bildirim sayısını göstermek için kullanılır.
///
/// Örnek kullanım:
/// ```dart
/// Stack(
///   children: [
///     IconButton(icon: Icon(Icons.notifications)),
///     Positioned(
///       right: 0,
///       top: 0,
///       child: NotificationBadge(count: 5),
///     ),
///   ],
/// )
/// ```
class NotificationBadge extends StatelessWidget {
  /// Bildirim sayısı
  final int count;

  /// Maksimum gösterilecek sayı
  final int maxCount;

  /// Rozet rengi
  final Color? color;

  /// Metin rengi
  final Color? textColor;

  /// Boyut
  final NotificationBadgeSize size;

  /// Sadece nokta göster (sayı olmadan)
  final bool dotOnly;

  const NotificationBadge({
    super.key,
    required this.count,
    this.maxCount = 99,
    this.color,
    this.textColor,
    this.size = NotificationBadgeSize.medium,
    this.dotOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final badgeColor = color ?? AppColors.error;
    final badgeTextColor = textColor ?? Colors.white;

    if (dotOnly) {
      return Container(
        width: _getDotSize(),
        height: _getDotSize(),
        decoration: BoxDecoration(
          color: badgeColor,
          shape: BoxShape.circle,
        ),
      );
    }

    final displayCount = count > maxCount ? '$maxCount+' : count.toString();

    return Container(
      padding: _getPadding(),
      constraints: BoxConstraints(
        minWidth: _getMinSize(),
        minHeight: _getMinSize(),
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(_getMinSize() / 2),
      ),
      child: Center(
        child: Text(
          displayCount,
          style: _getTextStyle().copyWith(
            color: badgeTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  double _getDotSize() {
    switch (size) {
      case NotificationBadgeSize.small:
        return 8;
      case NotificationBadgeSize.medium:
        return 10;
      case NotificationBadgeSize.large:
        return 12;
    }
  }

  double _getMinSize() {
    switch (size) {
      case NotificationBadgeSize.small:
        return 16;
      case NotificationBadgeSize.medium:
        return 20;
      case NotificationBadgeSize.large:
        return 24;
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case NotificationBadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 4, vertical: 1);
      case NotificationBadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 5, vertical: 2);
      case NotificationBadgeSize.large:
        return const EdgeInsets.symmetric(horizontal: 6, vertical: 2);
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case NotificationBadgeSize.small:
        return AppTypography.caption2;
      case NotificationBadgeSize.medium:
        return AppTypography.caption1;
      case NotificationBadgeSize.large:
        return AppTypography.footnote;
    }
  }
}

/// Rozet boyutu
enum NotificationBadgeSize {
  small,
  medium,
  large,
}

/// İkonla birlikte bildirim rozeti
///
/// Icon ve badge'i birlikte gösterir.
///
/// Örnek kullanım:
/// ```dart
/// NotificationIconBadge(
///   icon: Icons.notifications,
///   count: 5,
///   onTap: () => navigateToNotifications(),
/// )
/// ```
class NotificationIconBadge extends StatelessWidget {
  /// İkon
  final IconData icon;

  /// Bildirim sayısı
  final int count;

  /// Tıklama callback'i
  final VoidCallback? onTap;

  /// İkon rengi
  final Color? iconColor;

  /// İkon boyutu
  final double iconSize;

  /// Rozet boyutu
  final NotificationBadgeSize badgeSize;

  const NotificationIconBadge({
    super.key,
    this.icon = Icons.notifications_outlined,
    required this.count,
    this.onTap,
    this.iconColor,
    this.iconSize = 24,
    this.badgeSize = NotificationBadgeSize.small,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: iconSize + 12,
        height: iconSize + 8,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 4,
              child: Icon(
                icon,
                color: iconColor ?? AppColors.label(context),
                size: iconSize,
              ),
            ),
            if (count > 0)
              Positioned(
                right: 0,
                top: 0,
                child: NotificationBadge(
                  count: count,
                  size: badgeSize,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
