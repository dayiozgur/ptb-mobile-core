import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../core/map/map_models.dart';
import '../../../core/theme/app_colors.dart';

/// Geofence daireleri katmanı
///
/// flutter_map CircleLayer ile geofence bölgelerini haritada çizer.
/// Kullanıcı içerideyken yeşil, dışarıdayken gri gösterir.
///
/// Örnek kullanım:
/// ```dart
/// GeofenceCircleLayer(
///   regions: geofences,
///   insideRegionIds: {'region-1'},
/// )
/// ```
class GeofenceCircleLayer extends StatelessWidget {
  /// Gösterilecek geofence bölgeleri
  final List<GeofenceRegion> regions;

  /// Kullanıcının içinde olduğu bölge ID'leri
  final Set<String> insideRegionIds;

  /// Dolgu opaklığı
  final double fillOpacity;

  /// Kenarlık genişliği
  final double borderWidth;

  const GeofenceCircleLayer({
    super.key,
    required this.regions,
    this.insideRegionIds = const {},
    this.fillOpacity = 0.12,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    if (regions.isEmpty) return const SizedBox.shrink();

    return CircleLayer(
      circles: regions.map((region) {
        final isInside = insideRegionIds.contains(region.id);
        final baseColor = _regionColor(region.type, isInside);

        return CircleMarker(
          point: region.center,
          radius: region.radiusMeters,
          useRadiusInMeter: true,
          color: baseColor.withValues(alpha: fillOpacity),
          borderColor: baseColor.withValues(alpha: 0.6),
          borderStrokeWidth: borderWidth,
        );
      }).toList(),
    );
  }

  Color _regionColor(GeofenceType type, bool isInside) {
    if (isInside) return AppColors.success;

    switch (type) {
      case GeofenceType.site:
        return AppColors.primary;
      case GeofenceType.restricted:
        return AppColors.error;
      case GeofenceType.monitoring:
        return AppColors.warning;
    }
  }
}
