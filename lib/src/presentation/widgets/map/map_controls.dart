import 'package:flutter/material.dart';

import '../../../core/map/map_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Harita zoom kontrolleri
///
/// Sağ altta +/- butonları gösterir.
class MapZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const MapZoomControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(
            icon: Icons.add,
            onTap: onZoomIn,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusSm),
            ),
          ),
          Container(
            height: 1,
            width: 36,
            color: AppColors.divider(brightness),
          ),
          _ZoomButton(
            icon: Icons.remove,
            onTap: onZoomOut,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppSpacing.radiusSm),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _ZoomButton({
    required this.icon,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 20,
            color: AppColors.textPrimary(brightness),
          ),
        ),
      ),
    );
  }
}

/// Harita tile katman seçici
///
/// Light/Dark/Satellite tile seçimi yapılmasını sağlar.
class MapLayerSelector extends StatelessWidget {
  final MapTileProvider selected;
  final ValueChanged<MapTileProvider> onChanged;

  const MapLayerSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLayerPicker(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.layers_rounded,
              size: 20,
              color: AppColors.textPrimary(brightness),
            ),
          ),
        ),
      ),
    );
  }

  void _showLayerPicker(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Harita Katmanı',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _LayerOption(
                  title: 'Açık',
                  icon: Icons.wb_sunny_outlined,
                  isSelected: selected == MapTileProvider.light,
                  onTap: () {
                    onChanged(MapTileProvider.light);
                    Navigator.pop(ctx);
                  },
                ),
                _LayerOption(
                  title: 'Koyu',
                  icon: Icons.dark_mode_outlined,
                  isSelected: selected == MapTileProvider.dark,
                  onTap: () {
                    onChanged(MapTileProvider.dark);
                    Navigator.pop(ctx);
                  },
                ),
                _LayerOption(
                  title: 'Uydu',
                  icon: Icons.satellite_alt_outlined,
                  isSelected: selected == MapTileProvider.satellite,
                  onTap: () {
                    onChanged(MapTileProvider.satellite);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LayerOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _LayerOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? AppColors.primary
            : AppColors.textSecondary(brightness),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? AppColors.primary
              : AppColors.textPrimary(brightness),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
    );
  }
}

/// Harita marker açıklama legend widget'ı
class MapLegend extends StatelessWidget {
  final List<MapLegendItem> items;

  const MapLegend({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items
            .map((item) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

/// Legend item
class MapLegendItem {
  final String label;
  final Color color;

  const MapLegendItem({required this.label, required this.color});
}
