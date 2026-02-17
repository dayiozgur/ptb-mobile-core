import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../site/site_model.dart';
import '../site/site_service.dart';
import '../utils/logger.dart';
import 'map_models.dart';

/// Map Servisi
///
/// Harita iş mantığı: marker dönüşümü, konum takibi, geofence yönetimi.
///
/// Örnek kullanım:
/// ```dart
/// final mapService = MapService(
///   siteService: sl<SiteService>(),
/// );
///
/// // Site marker'larını al
/// final markers = await mapService.getSiteMarkers(orgId);
///
/// // Konum takibini başlat
/// await mapService.startLocationTracking();
/// ```
class MapService {
  final SiteService _siteService;

  // Location tracking
  StreamSubscription<Position>? _locationSubscription;
  final _locationController = StreamController<LatLng>.broadcast();
  final _geofenceEventController = StreamController<GeofenceEvent>.broadcast();
  LatLng? _currentPosition;

  // Geofences
  final List<GeofenceRegion> _geofences = [];
  final Set<String> _insideRegions = {};

  MapService({
    required SiteService siteService,
  }) : _siteService = siteService;

  // ============================================
  // GETTERS
  // ============================================

  /// Mevcut konum
  LatLng? get currentPosition => _currentPosition;

  /// Konum stream'i
  Stream<LatLng> get locationStream => _locationController.stream;

  /// Geofence olay stream'i
  Stream<GeofenceEvent> get geofenceEventStream =>
      _geofenceEventController.stream;

  /// Kayıtlı geofence'ler
  List<GeofenceRegion> get geofences => List.unmodifiable(_geofences);

  /// Konum takibi aktif mi?
  bool get isTracking => _locationSubscription != null;

  // ============================================
  // MARKER OPERATIONS
  // ============================================

  /// Site listesini MapMarkerData listesine dönüştür
  Future<List<MapMarkerData>> getSiteMarkers(
    String organizationId, {
    bool forceRefresh = false,
  }) async {
    try {
      final sites = await _siteService.getSites(
        organizationId,
        forceRefresh: forceRefresh,
      );

      final markers = sites
          .where((site) => site.hasLocation)
          .map((site) => _siteToMarker(site))
          .toList();

      Logger.debug('Generated ${markers.length} map markers from sites');
      return markers;
    } catch (e) {
      Logger.error('Failed to get site markers', e);
      return [];
    }
  }

  /// Tek site'ı marker'a dönüştür
  MapMarkerData _siteToMarker(Site site) {
    return MapMarkerData(
      id: site.id,
      latLng: LatLng(site.latitude!, site.longitude!),
      title: site.name,
      subtitle: site.fullAddress.isNotEmpty ? site.fullAddress : null,
      type: MapMarkerType.site,
      status: site.active ? MapMarkerStatus.normal : MapMarkerStatus.inactive,
      metadata: {
        'site_id': site.id,
        'organization_id': site.organizationId,
        'color': site.color,
        'zoom': site.zoom,
        'has_main_unit': site.hasMainUnit,
      },
    );
  }

  // ============================================
  // LOCATION TRACKING
  // ============================================

  /// Konum izni kontrol et
  Future<bool> checkLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Logger.warning('Location services are disabled');
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Logger.warning('Location permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Logger.warning('Location permission permanently denied');
        return false;
      }

      return true;
    } catch (e) {
      Logger.error('Failed to check location permission', e);
      return false;
    }
  }

  /// Konum takibini başlat
  Future<bool> startLocationTracking({
    int distanceFilter = 10,
  }) async {
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) return false;

      // Mevcut konumu al
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _updatePosition(LatLng(position.latitude, position.longitude));

      // Stream'i dinle
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter,
        ),
      ).listen(
        (position) {
          _updatePosition(LatLng(position.latitude, position.longitude));
        },
        onError: (e) {
          Logger.error('Location stream error', e);
        },
      );

      Logger.info('Location tracking started');
      return true;
    } catch (e) {
      Logger.error('Failed to start location tracking', e);
      return false;
    }
  }

  /// Konum takibini durdur
  void stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    Logger.info('Location tracking stopped');
  }

  void _updatePosition(LatLng position) {
    _currentPosition = position;
    _locationController.add(position);
    _checkGeofences(position);
  }

  // ============================================
  // GEOFENCE
  // ============================================

  /// Geofence ekle
  void addGeofence(GeofenceRegion region) {
    _geofences.add(region);
    // Mevcut konum varsa hemen kontrol et
    if (_currentPosition != null) {
      _checkSingleGeofence(region, _currentPosition!);
    }
    Logger.debug('Geofence added: ${region.name}');
  }

  /// Geofence kaldır
  void removeGeofence(String regionId) {
    _geofences.removeWhere((r) => r.id == regionId);
    _insideRegions.remove(regionId);
    Logger.debug('Geofence removed: $regionId');
  }

  /// Tüm geofence'leri temizle
  void clearGeofences() {
    _geofences.clear();
    _insideRegions.clear();
    Logger.debug('All geofences cleared');
  }

  /// Belirli konum için geofence kontrolü
  void checkGeofences(LatLng position) {
    _checkGeofences(position);
  }

  void _checkGeofences(LatLng position) {
    for (final region in _geofences) {
      _checkSingleGeofence(region, position);
    }
  }

  void _checkSingleGeofence(GeofenceRegion region, LatLng position) {
    final distance = calculateDistance(
      position.latitude,
      position.longitude,
      region.center.latitude,
      region.center.longitude,
    );

    final isInside = distance <= region.radiusMeters;
    final wasInside = _insideRegions.contains(region.id);

    if (isInside && !wasInside) {
      // Giriş
      _insideRegions.add(region.id);
      _geofenceEventController.add(GeofenceEvent(
        regionId: region.id,
        eventType: GeofenceEventType.enter,
        timestamp: DateTime.now(),
        position: position,
      ));
      Logger.debug('Geofence enter: ${region.name}');
    } else if (!isInside && wasInside) {
      // Çıkış
      _insideRegions.remove(region.id);
      _geofenceEventController.add(GeofenceEvent(
        regionId: region.id,
        eventType: GeofenceEventType.exit,
        timestamp: DateTime.now(),
        position: position,
      ));
      Logger.debug('Geofence exit: ${region.name}');
    }
  }

  /// Kullanıcı belirli bölge içinde mi?
  bool isInsideRegion(String regionId) {
    return _insideRegions.contains(regionId);
  }

  // ============================================
  // DISTANCE CALCULATION
  // ============================================

  /// Haversine formülü ile iki nokta arası mesafe (metre)
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusM * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  // ============================================
  // CLEANUP
  // ============================================

  /// Servisi kapat
  void dispose() {
    stopLocationTracking();
    _locationController.close();
    _geofenceEventController.close();
    _geofences.clear();
    _insideRegions.clear();
    Logger.debug('MapService disposed');
  }
}
