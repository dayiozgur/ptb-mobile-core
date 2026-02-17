import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/map_models.dart';
import 'app_map_controller.dart';
import 'geofence_circle.dart';
import 'map_controls.dart';
import 'map_marker_widget.dart';

/// Tile URL'leri
const _lightTileUrl =
    'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
const _darkTileUrl =
    'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
const _satelliteTileUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

/// Ana harita widget'ı
///
/// flutter_map tabanlı, clustering destekli, dark mode uyumlu harita bileşeni.
///
/// Örnek kullanım:
/// ```dart
/// AppMap(
///   markers: siteMarkers,
///   showUserLocation: true,
///   enableClustering: true,
///   onMarkerTap: (marker) => navigateToSite(marker.id),
/// )
/// ```
class AppMap extends StatefulWidget {
  /// Başlangıç merkez noktası
  final LatLng? center;

  /// Başlangıç zoom seviyesi
  final double zoom;

  /// Marker listesi
  final List<MapMarkerData> markers;

  /// Geofence bölgeleri
  final List<GeofenceRegion>? geofences;

  /// Kullanıcının içinde olduğu geofence ID'leri
  final Set<String> insideGeofenceIds;

  /// Canlı konum göster (mavi dot)
  final bool showUserLocation;

  /// Kullanıcı konumu
  final LatLng? userLocation;

  /// Marker clustering aktif mi?
  final bool enableClustering;

  /// Marker'a tıklama
  final ValueChanged<MapMarkerData>? onMarkerTap;

  /// Haritaya tıklama
  final ValueChanged<LatLng>? onMapTap;

  /// Tile sağlayıcı (null = otomatik: tema brightness'ına göre)
  final MapTileProvider? tileProvider;

  /// Harita yüksekliği (null = Expanded)
  final double? height;

  /// Programmatic kontrol
  final AppMapController? controller;

  /// Zoom kontrolleri göster
  final bool showZoomControls;

  /// Katman seçici göster
  final bool showLayerSelector;

  /// Min zoom
  final double minZoom;

  /// Max zoom
  final double maxZoom;

  const AppMap({
    super.key,
    this.center,
    this.zoom = 10,
    this.markers = const [],
    this.geofences,
    this.insideGeofenceIds = const {},
    this.showUserLocation = false,
    this.userLocation,
    this.enableClustering = true,
    this.onMarkerTap,
    this.onMapTap,
    this.tileProvider,
    this.height,
    this.controller,
    this.showZoomControls = true,
    this.showLayerSelector = true,
    this.minZoom = 3,
    this.maxZoom = 18,
  });

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  late MapController _mapController;
  late MapTileProvider _currentTileProvider;
  String? _selectedMarkerId;

  // Default center: Türkiye merkezi
  static const _defaultCenter = LatLng(39.9334, 32.8597);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentTileProvider = widget.tileProvider ?? MapTileProvider.light;
    widget.controller?.attach(_mapController);
  }

  @override
  void didUpdateWidget(AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(_mapController);
    }
    if (widget.tileProvider != null &&
        widget.tileProvider != oldWidget.tileProvider) {
      _currentTileProvider = widget.tileProvider!;
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _mapController.dispose();
    super.dispose();
  }

  String _tileUrl(Brightness brightness) {
    // Otomatik tile: tileProvider null ise brightness'a göre seç
    final provider = widget.tileProvider ?? _currentTileProvider;

    // Eğer tileProvider null ve otomatik modda: brightness'a göre
    if (widget.tileProvider == null &&
        _currentTileProvider != MapTileProvider.satellite) {
      return brightness == Brightness.dark ? _darkTileUrl : _lightTileUrl;
    }

    switch (provider) {
      case MapTileProvider.light:
        return _lightTileUrl;
      case MapTileProvider.dark:
        return _darkTileUrl;
      case MapTileProvider.satellite:
        return _satelliteTileUrl;
    }
  }

  LatLng get _effectiveCenter {
    if (widget.center != null) return widget.center!;
    if (widget.markers.isNotEmpty) return widget.markers.first.latLng;
    if (widget.userLocation != null) return widget.userLocation!;
    return _defaultCenter;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final mapWidget = _buildMap(brightness);

    if (widget.height != null) {
      return SizedBox(height: widget.height, child: mapWidget);
    }
    return mapWidget;
  }

  Widget _buildMap(Brightness brightness) {
    return Stack(
      children: [
        // Harita
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _effectiveCenter,
            initialZoom: widget.zoom,
            minZoom: widget.minZoom,
            maxZoom: widget.maxZoom,
            onTap: widget.onMapTap != null
                ? (_, latLng) => widget.onMapTap!(latLng)
                : null,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            // Tile layer
            TileLayer(
              urlTemplate: _tileUrl(brightness),
              userAgentPackageName: 'com.protoolbag.core',
              maxZoom: widget.maxZoom,
            ),

            // Geofence circles
            if (widget.geofences != null && widget.geofences!.isNotEmpty)
              GeofenceCircleLayer(
                regions: widget.geofences!,
                insideRegionIds: widget.insideGeofenceIds,
              ),

            // Markers (clustered or plain)
            if (widget.markers.isNotEmpty)
              widget.enableClustering
                  ? _buildClusteredMarkers()
                  : _buildPlainMarkers(),

            // User location
            if (widget.showUserLocation && widget.userLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.userLocation!,
                    width: 40,
                    height: 40,
                    child: const UserLocationMarker(),
                  ),
                ],
              ),
          ],
        ),

        // Harita kontrolleri
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showLayerSelector) ...[
                MapLayerSelector(
                  selected: _currentTileProvider,
                  onChanged: (provider) {
                    setState(() => _currentTileProvider = provider);
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (widget.showZoomControls)
                MapZoomControls(
                  onZoomIn: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                  onZoomOut: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClusteredMarkers() {
    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 80,
        size: const Size(44, 44),
        markers: widget.markers.map((data) => _buildMarker(data)).toList(),
        builder: (context, markers) {
          // Cluster'daki MapMarkerData'ları bul
          final clusterMarkers = <MapMarkerData>[];
          for (final marker in markers) {
            final found = widget.markers.where(
              (m) => m.latLng == marker.point,
            );
            clusterMarkers.addAll(found);
          }

          final clusterData = MapClusterData(
            count: markers.length,
            markers: clusterMarkers,
          );

          return ClusterMapMarker(
            count: clusterData.count,
            hasAlarms: clusterData.hasAlarms,
            worstStatus: clusterData.worstStatus,
          );
        },
        onMarkerTap: (marker) {
          if (widget.onMarkerTap == null) return;
          final found = widget.markers.where(
            (m) => m.latLng == marker.point,
          );
          if (found.isNotEmpty) {
            setState(() => _selectedMarkerId = found.first.id);
            widget.onMarkerTap!(found.first);
          }
        },
      ),
    );
  }

  MarkerLayer _buildPlainMarkers() {
    return MarkerLayer(
      markers: widget.markers.map((data) => _buildMarker(data)).toList(),
    );
  }

  Marker _buildMarker(MapMarkerData data) {
    final isSelected = _selectedMarkerId == data.id;
    final size = isSelected ? 48.0 : 40.0;

    return Marker(
      point: data.latLng,
      width: size,
      height: size,
      child: SiteMapMarker(
        marker: data,
        alarmCount: data.alarmCount,
        isSelected: isSelected,
        onTap: widget.enableClustering
            ? null // clustering handles taps
            : () {
                if (widget.onMarkerTap != null) {
                  setState(() => _selectedMarkerId = data.id);
                  widget.onMarkerTap!(data);
                }
              },
      ),
    );
  }
}
