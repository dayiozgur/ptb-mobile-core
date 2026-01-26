import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Avatar boyutları
enum AppAvatarSize {
  /// Extra small - 24px
  xs,

  /// Small - 32px
  small,

  /// Medium - 44px
  medium,

  /// Large - 64px
  large,

  /// Extra large - 96px
  xl,
}

/// Protoolbag Avatar Widget
///
/// Kullanıcı/profil resimleri için avatar komponenti.
///
/// Örnek kullanım:
/// ```dart
/// AppAvatar(
///   imageUrl: 'https://example.com/photo.jpg',
///   name: 'John Doe',
///   size: AppAvatarSize.medium,
/// )
/// ```
class AppAvatar extends StatelessWidget {
  /// Resim URL'i
  final String? imageUrl;

  /// İsim (initials için)
  final String? name;

  /// Boyut
  final AppAvatarSize size;

  /// Arka plan rengi (initials için)
  final Color? backgroundColor;

  /// Metin rengi (initials için)
  final Color? foregroundColor;

  /// İkon (resim ve isim yoksa)
  final IconData? icon;

  /// Online göstergesi
  final bool showOnlineIndicator;

  /// Online durumu
  final bool isOnline;

  /// Border
  final bool showBorder;

  /// Border rengi
  final Color? borderColor;

  /// Tıklama callback'i
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = AppAvatarSize.medium,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.showBorder = false,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final avatarSize = _getSize();

    Widget avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getBackgroundColor(brightness),
        border: showBorder
            ? Border.all(
                color: borderColor ?? AppColors.surface(brightness),
                width: 2,
              )
            : null,
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
                onError: (_, __) {},
              )
            : null,
      ),
      child: imageUrl == null ? _buildContent(brightness) : null,
    );

    if (showOnlineIndicator) {
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: _getIndicatorSize(),
              height: _getIndicatorSize(),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? AppColors.success : AppColors.systemGray,
                border: Border.all(
                  color: AppColors.surface(brightness),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      avatar = GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildContent(Brightness brightness) {
    if (name != null && name!.isNotEmpty) {
      return Center(
        child: Text(
          _getInitials(name!),
          style: _getTextStyle().copyWith(
            color: foregroundColor ?? Colors.white,
          ),
        ),
      );
    }

    return Center(
      child: Icon(
        icon ?? Icons.person,
        size: _getIconSize(),
        color: foregroundColor ?? Colors.white,
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  Color _getBackgroundColor(Brightness brightness) {
    if (backgroundColor != null) return backgroundColor!;
    if (imageUrl != null) return Colors.transparent;

    // Name'e göre renk seç
    if (name != null && name!.isNotEmpty) {
      final colors = [
        AppColors.primary,
        AppColors.secondary,
        AppColors.success,
        AppColors.warning,
        AppColors.info,
        const Color(0xFF5856D6),
        const Color(0xFFFF2D55),
        const Color(0xFFAF52DE),
      ];
      final index = name!.codeUnits.fold(0, (a, b) => a + b) % colors.length;
      return colors[index];
    }

    return AppColors.systemGray;
  }

  double _getSize() {
    switch (size) {
      case AppAvatarSize.xs:
        return 24;
      case AppAvatarSize.small:
        return 32;
      case AppAvatarSize.medium:
        return 44;
      case AppAvatarSize.large:
        return 64;
      case AppAvatarSize.xl:
        return 96;
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppAvatarSize.xs:
        return 14;
      case AppAvatarSize.small:
        return 18;
      case AppAvatarSize.medium:
        return 24;
      case AppAvatarSize.large:
        return 32;
      case AppAvatarSize.xl:
        return 48;
    }
  }

  double _getIndicatorSize() {
    switch (size) {
      case AppAvatarSize.xs:
        return 8;
      case AppAvatarSize.small:
        return 10;
      case AppAvatarSize.medium:
        return 12;
      case AppAvatarSize.large:
        return 16;
      case AppAvatarSize.xl:
        return 20;
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case AppAvatarSize.xs:
        return AppTypography.caption2.copyWith(fontWeight: FontWeight.w600);
      case AppAvatarSize.small:
        return AppTypography.caption1.copyWith(fontWeight: FontWeight.w600);
      case AppAvatarSize.medium:
        return AppTypography.subhead.copyWith(fontWeight: FontWeight.w600);
      case AppAvatarSize.large:
        return AppTypography.title3.copyWith(fontWeight: FontWeight.w600);
      case AppAvatarSize.xl:
        return AppTypography.title1.copyWith(fontWeight: FontWeight.w600);
    }
  }
}

/// Avatar group (birden fazla avatar)
class AppAvatarGroup extends StatelessWidget {
  /// Avatarlar
  final List<AppAvatar> avatars;

  /// Gösterilecek maksimum avatar sayısı
  final int maxVisible;

  /// Avatar boyutu
  final AppAvatarSize size;

  /// Overlap miktarı
  final double overlap;

  const AppAvatarGroup({
    super.key,
    required this.avatars,
    this.maxVisible = 4,
    this.size = AppAvatarSize.small,
    this.overlap = 8,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final visible = avatars.take(maxVisible).toList();
    final remaining = avatars.length - maxVisible;
    final avatarSize = _getSize();

    return SizedBox(
      height: avatarSize,
      child: Stack(
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * (avatarSize - overlap),
              child: AppAvatar(
                imageUrl: visible[i].imageUrl,
                name: visible[i].name,
                size: size,
                backgroundColor: visible[i].backgroundColor,
                showBorder: true,
                borderColor: AppColors.surface(brightness),
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: visible.length * (avatarSize - overlap),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.systemGray,
                  border: Border.all(
                    color: AppColors.surface(brightness),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$remaining',
                    style: _getTextStyle().copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _getSize() {
    switch (size) {
      case AppAvatarSize.xs:
        return 24;
      case AppAvatarSize.small:
        return 32;
      case AppAvatarSize.medium:
        return 44;
      case AppAvatarSize.large:
        return 64;
      case AppAvatarSize.xl:
        return 96;
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case AppAvatarSize.xs:
        return AppTypography.caption2.copyWith(fontWeight: FontWeight.w600);
      case AppAvatarSize.small:
        return AppTypography.caption1.copyWith(fontWeight: FontWeight.w600);
      case AppAvatarSize.medium:
        return AppTypography.subhead.copyWith(fontWeight: FontWeight.w600);
      case AppAvatarSize.large:
        return AppTypography.title3.copyWith(fontWeight: FontWeight.w600);
      case AppAvatarSize.xl:
        return AppTypography.title1.copyWith(fontWeight: FontWeight.w600);
    }
  }
}
