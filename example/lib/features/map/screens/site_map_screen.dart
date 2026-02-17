import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Site Harita Ekranı (Example App)
///
/// Tüm siteleri harita üzerinde gösterir.
/// Marker'a tıklayınca site detayına gider.
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
          _error = 'Organizasyon secilmemis';
          _isLoading = false;
        });
        return;
      }

      final markers = await mapService.getSiteMarkers(organizationId);

      // Her site icin 500m geofence olustur
      final geofences = markers.map((m) {
        return GeofenceRegion(
          id: 'geofence_${m.id}',
          center: m.latLng,
          radiusMeters: 500,
          name: m.title,
          type: GeofenceType.site,
        );
      }).toList();

      setState(() {
        _markers = markers;
        _geofences = geofences;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Harita verileri yuklenemedi';
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
        // Ilk konuma git
        if (mapService.currentPosition != null) {
          setState(() => _userLocation = mapService.currentPosition);
          _mapController.moveTo(mapService.currentPosition!, zoom: 14);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum izni alinamadi')),
          );
        }
      }
    }
  }

  void _onMarkerTap(MapMarkerData marker) {
    final siteId = marker.metadata['site_id'] as String?;
    if (siteId != null) {
      context.push('/sites/$siteId');
    }
  }

  void _showAllMarkers() {
    if (_markers.isNotEmpty) {
      _mapController.fitBounds(_markers.map((m) => m.latLng).toList());
    }
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
      title: 'Site Haritasi',
      actions: [
        AppIconButton(
          icon: _isTracking
              ? Icons.my_location
              : Icons.location_searching,
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
        title: 'Hata',
        message: _error!,
        actionLabel: 'Tekrar Dene',
        onAction: _loadMarkers,
      );
    }

    if (_markers.isEmpty) {
      return const AppEmptyState(
        icon: Icons.map_outlined,
        title: 'Site Bulunamadi',
        message: 'Konumu olan site bulunmamaktadir.',
      );
    }

    return Column(
      children: [
        // Bilgi satiri
        _MapInfoBar(
          siteCount: _markers.length,
          isTracking: _isTracking,
        ),

        // Harita
        Expanded(
          child: AppMap(
            markers: _markers,
            geofences: _geofences,
            showUserLocation: _isTracking,
            userLocation: _userLocation,
            enableClustering: true,
            onMarkerTap: _onMarkerTap,
            controller: _mapController,
            zoom: 8,
          ),
        ),

        // Legend
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: MapLegend(
            items: [
              MapLegendItem(label: 'Aktif', color: AppColors.success),
              MapLegendItem(label: 'Uyari', color: AppColors.warning),
              MapLegendItem(label: 'Kritik', color: AppColors.error),
              MapLegendItem(label: 'Cevrimdisi', color: AppColors.systemGray),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapInfoBar extends StatelessWidget {
  final int siteCount;
  final bool isTracking;

  const _MapInfoBar({
    required this.siteCount,
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
      color: AppColors.surface(brightness),
      child: Row(
        children: [
          Icon(
            Icons.location_city,
            size: 16,
            color: AppColors.textSecondary(brightness),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$siteCount site',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(brightness),
            ),
          ),
          const Spacer(),
          if (isTracking) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Konum aktif',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
