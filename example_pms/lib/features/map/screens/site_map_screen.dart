import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Site Harita Ekrani (PMS App)
///
/// Tum siteleri harita uzerinde gosterir.
/// Alarm durumuna gore marker renkleri degisir.
/// Marker'a tiklaninca site detayina gider.
class SiteMapScreen extends StatefulWidget {
  const SiteMapScreen({super.key});

  @override
  State<SiteMapScreen> createState() => _SiteMapScreenState();
}

class _SiteMapScreenState extends State<SiteMapScreen> {
  List<MapMarkerData> _markers = [];
  List<GeofenceRegion> _geofences = [];
  bool _isLoading = true;
  String? _error;
  LatLng? _userLocation;
  bool _isTracking = false;
  final _mapController = AppMapController();
  MapMarkerData? _selectedMarker;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final organizationId = organizationService.currentOrganizationId;
      if (organizationId == null) {
        setState(() {
          _error = sl<LocalizationService>().translate('org.not_selected');
          _isLoading = false;
        });
        return;
      }

      // Site marker'larini al
      final markers = await mapService.getSiteMarkers(organizationId);

      // Alarm sayilarini marker metadata'ya ekle
      final enrichedMarkers = <MapMarkerData>[];
      for (final marker in markers) {
        final siteId = marker.metadata['site_id'] as String?;
        int alarmCount = 0;
        MapMarkerStatus status = marker.status;

        if (siteId != null) {
          try {
            alarmCount = await alarmService.getResetAlarmCountBySite(siteId);
            if (alarmCount > 5) {
              status = MapMarkerStatus.critical;
            } else if (alarmCount > 0) {
              status = MapMarkerStatus.warning;
            }
          } catch (_) {}
        }

        enrichedMarkers.add(marker.copyWith(
          status: status,
          metadata: {
            ...marker.metadata,
            'alarm_count': alarmCount,
          },
        ));
      }

      // Her site icin 500m geofence olustur
      final geofences = enrichedMarkers.map((m) {
        return GeofenceRegion(
          id: 'geofence_${m.id}',
          center: m.latLng,
          radiusMeters: 500,
          name: m.title,
          type: GeofenceType.site,
        );
      }).toList();

      setState(() {
        _markers = enrichedMarkers;
        _geofences = geofences;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load map markers', e);
      setState(() {
        _error = sl<LocalizationService>().translate('map.load_failed');
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLocationTracking() async {
    if (_isTracking) {
      mapService.stopLocationTracking();
      setState(() {
        _isTracking = false;
        _userLocation = null;
      });
    } else {
      final started = await mapService.startLocationTracking();
      if (started) {
        setState(() => _isTracking = true);
        mapService.locationStream.listen((position) {
          if (mounted) {
            setState(() => _userLocation = position);
          }
        });
        if (mapService.currentPosition != null) {
          setState(() => _userLocation = mapService.currentPosition);
          _mapController.moveTo(mapService.currentPosition!, zoom: 14);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sl<LocalizationService>().translate('map.location_permission_denied'))),
          );
        }
      }
    }
  }

  void _onMarkerTap(MapMarkerData marker) {
    setState(() => _selectedMarker = marker);
  }

  void _navigateToSite(String siteId) {
    context.push('/sites/$siteId');
  }

  void _showAllMarkers() {
    if (_markers.isNotEmpty) {
      _mapController.fitBounds(_markers.map((m) => m.latLng).toList());
    }
    setState(() => _selectedMarker = null);
  }

  @override
  void dispose() {
    if (_isTracking) {
      mapService.stopLocationTracking();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: sl<LocalizationService>().translate('map.title'),
      showBackButton: false,
      actions: [
        AppIconButton(
          icon: _isTracking ? Icons.my_location : Icons.location_searching,
          onPressed: _toggleLocationTracking,
        ),
        AppIconButton(
          icon: Icons.fit_screen,
          onPressed: _showAllMarkers,
        ),
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadMarkers,
        ),
      ],
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_error != null) {
      return AppErrorView(
        title: sl<LocalizationService>().translate('common.error'),
        message: _error!,
        actionLabel: sl<LocalizationService>().translate('common.retry'),
        onAction: _loadMarkers,
      );
    }

    if (_markers.isEmpty) {
      return AppEmptyState(
        icon: Icons.map_outlined,
        title: sl<LocalizationService>().translate('site.not_found_title'),
        message: sl<LocalizationService>().translate('map.no_located_sites'),
      );
    }

    return Stack(
      children: [
        // Harita
        AppMap(
          markers: _markers,
          geofences: _geofences,
          showUserLocation: _isTracking,
          userLocation: _userLocation,
          enableClustering: true,
          onMarkerTap: _onMarkerTap,
          controller: _mapController,
          zoom: 8,
        ),

        // Ust bilgi satiri
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _MapStatsBar(
            siteCount: _markers.length,
            alarmCount:
                _markers.fold(0, (sum, m) => sum + m.alarmCount),
            isTracking: _isTracking,
          ),
        ),

        // Alt legend
        Positioned(
          bottom: 12,
          left: 12,
          child: MapLegend(
            items: [
              MapLegendItem(label: sl<LocalizationService>().translate('map.legend_normal'), color: AppColors.success),
              MapLegendItem(label: sl<LocalizationService>().translate('map.legend_warning'), color: AppColors.warning),
              MapLegendItem(label: sl<LocalizationService>().translate('map.legend_critical'), color: AppColors.error),
              MapLegendItem(label: sl<LocalizationService>().translate('map.legend_offline'), color: AppColors.systemGray),
            ],
          ),
        ),

        // Secili marker detay karti
        if (_selectedMarker != null)
          Positioned(
            bottom: 48,
            left: 16,
            right: 80, // Zoom butonlarina yer birak
            child: _MarkerDetailCard(
              marker: _selectedMarker!,
              onNavigate: () => _navigateToSite(
                _selectedMarker!.metadata['site_id'] as String,
              ),
              onClose: () => setState(() => _selectedMarker = null),
            ),
          ),
      ],
    );
  }
}

/// Ust bilgi cubugu
class _MapStatsBar extends StatelessWidget {
  final int siteCount;
  final int alarmCount;
  final bool isTracking;

  const _MapStatsBar({
    required this.siteCount,
    required this.alarmCount,
    required this.isTracking,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness).withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.location_city,
            label: sl<LocalizationService>().translate(
              'map.site_count',
              params: {'count': siteCount},
            ),
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          if (alarmCount > 0) ...[
            _StatChip(
              icon: Icons.warning_amber,
              label: sl<LocalizationService>().translate(
                'map.alarm_count',
                params: {'count': alarmCount},
              ),
              color: AppColors.error,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          const Spacer(),
          if (isTracking)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'GPS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Secili marker detay karti
class _MarkerDetailCard extends StatelessWidget {
  final MapMarkerData marker;
  final VoidCallback onNavigate;
  final VoidCallback onClose;

  const _MarkerDetailCard({
    required this.marker,
    required this.onNavigate,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _statusColor(marker.status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Bilgi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  marker.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(brightness),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (marker.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    marker.subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(brightness),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (marker.alarmCount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.warning_amber, size: 12, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text(
                        sl<LocalizationService>().translate(
                          'map.active_alarm_count',
                          params: {'count': marker.alarmCount},
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Aksiyon butonlari
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: AppColors.primary,
            ),
            onPressed: onNavigate,
            tooltip: sl<LocalizationService>().translate('map.site_detail_tooltip'),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: AppColors.textSecondary(brightness),
            ),
            onPressed: onClose,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Color _statusColor(MapMarkerStatus status) {
    switch (status) {
      case MapMarkerStatus.normal:
        return AppColors.success;
      case MapMarkerStatus.warning:
        return AppColors.warning;
      case MapMarkerStatus.critical:
        return AppColors.error;
      case MapMarkerStatus.offline:
        return AppColors.systemGray;
      case MapMarkerStatus.inactive:
        return AppColors.systemGray3;
    }
  }
}
