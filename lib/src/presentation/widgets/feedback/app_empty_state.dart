import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/app_button.dart';

/// Protoolbag Empty State Widget
///
/// Boş liste/veri durumlarını göstermek için kullanılır.
///
/// Örnek kullanım:
/// ```dart
/// AppEmptyState(
///   icon: Icons.inbox_outlined,
///   title: 'No Messages',
///   message: 'You have no messages yet',
///   actionLabel: 'Compose',
///   onAction: () => navigateToCompose(),
/// )
/// ```
class AppEmptyState extends StatelessWidget {
  /// İkon
  final IconData icon;

  /// Başlık
  final String title;

  /// Mesaj
  final String? message;

  /// Aksiyon buton metni
  final String? actionLabel;

  /// Aksiyon callback'i
  final VoidCallback? onAction;

  /// İkinci aksiyon buton metni
  final String? secondaryActionLabel;

  /// İkinci aksiyon callback'i
  final VoidCallback? onSecondaryAction;

  /// İkon rengi
  final Color? iconColor;

  /// Özel resim widget'ı (icon yerine)
  final Widget? image;

  /// Kompakt mod
  final bool compact;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.iconColor,
    this.image,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Center(
      child: Padding(
        padding: compact ? AppSpacing.allSm : AppSpacing.allLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image or Icon
            if (image != null)
              image!
            else
              Container(
                width: compact ? 64 : 80,
                height: compact ? 64 : 80,
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.primary).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: compact ? 32 : 40,
                  color: iconColor ?? AppColors.primary,
                ),
              ),

            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),

            // Title
            Text(
              title,
              style: (compact ? AppTypography.headline : AppTypography.title2)
                  .copyWith(
                color: AppColors.textPrimary(brightness),
              ),
              textAlign: TextAlign.center,
            ),

            // Message
            if (message != null) ...[
              SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
              Text(
                message!,
                style: (compact ? AppTypography.footnote : AppTypography.body)
                    .copyWith(
                  color: AppColors.textSecondary(brightness),
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Actions
            if (actionLabel != null || secondaryActionLabel != null) ...[
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
              if (compact)
                _buildCompactActions()
              else
                _buildActions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        if (actionLabel != null)
          AppButton(
            label: actionLabel!,
            variant: AppButtonVariant.primary,
            onPressed: onAction,
            isFullWidth: false,
          ),
        if (secondaryActionLabel != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: secondaryActionLabel!,
            variant: AppButtonVariant.tertiary,
            onPressed: onSecondaryAction,
            isFullWidth: false,
          ),
        ],
      ],
    );
  }

  Widget _buildCompactActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (secondaryActionLabel != null) ...[
          AppButton(
            label: secondaryActionLabel!,
            variant: AppButtonVariant.tertiary,
            size: AppButtonSize.small,
            onPressed: onSecondaryAction,
            isFullWidth: false,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (actionLabel != null)
          AppButton(
            label: actionLabel!,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: onAction,
            isFullWidth: false,
          ),
      ],
    );
  }
}

/// Arama sonucu boş durumu
class AppNoSearchResultsState extends StatelessWidget {
  final String? query;
  final VoidCallback? onClear;

  const AppNoSearchResultsState({
    super.key,
    this.query,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.search_off,
      title: 'Sonuç Bulunamadı',
      message: query != null
          ? '"$query" için sonuç bulunamadı'
          : 'Aramanızla eşleşen sonuç bulunamadı',
      actionLabel: onClear != null ? 'Aramayı Temizle' : null,
      onAction: onClear,
    );
  }
}

/// Liste boş durumu
class AppNoItemsState extends StatelessWidget {
  final String itemName;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppNoItemsState({
    super.key,
    required this.itemName,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.folder_open_outlined,
      title: 'Henüz $itemName Yok',
      message: 'İlk $itemName oluşturmak için başlayın',
      actionLabel: actionLabel ?? '$itemName Oluştur',
      onAction: onAction,
    );
  }
}

/// Favori/bookmark boş durumu
class AppNoFavoritesState extends StatelessWidget {
  final VoidCallback? onExplore;

  const AppNoFavoritesState({
    super.key,
    this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.favorite_border,
      title: 'Favori Yok',
      message: 'Favorileriniz burada görünecek',
      actionLabel: onExplore != null ? 'Keşfet' : null,
      onAction: onExplore,
    );
  }
}

/// Bildirim boş durumu
class AppNoNotificationsState extends StatelessWidget {
  const AppNoNotificationsState({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.notifications_none,
      title: 'Bildirim Yok',
      message: 'Bildirimleriniz burada görünecek',
    );
  }
}
