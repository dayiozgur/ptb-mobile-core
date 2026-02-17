import 'package:latlong2/latlong.dart';

/// Harita marker veri modeli
class MapMarkerData {
  /// Benzersiz ID
  final String id;

  /// Konum
  final LatLng latLng;

  /// Marker başlığı
  final String title;

  /// Alt başlık
  final String? subtitle;

  /// Marker türü
  final MapMarkerType type;

  /// Marker durumu
  final MapMarkerStatus status;

  /// Ek veri (site id, alarm count, vs.)
  final Map<String, dynamic> metadata;

  const MapMarkerData({
    required this.id,
    required this.latLng,
    required this.title,
    this.subtitle,
    this.type = MapMarkerType.site,
    this.status = MapMarkerStatus.normal,
    this.metadata = const {},
  });

  /// Alarm sayısı (metadata'dan)
  int get alarmCount => (metadata['alarm_count'] as int?) ?? 0;

  /// Seçili mi?
  bool get isSelected => (metadata['is_selected'] as bool?) ?? false;

  MapMarkerData copyWith({
    String? id,
    LatLng? latLng,
    String? title,
    String? subtitle,
    MapMarkerType? type,
    MapMarkerStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return MapMarkerData(
      id: id ?? this.id,
      latLng: latLng ?? this.latLng,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapMarkerData &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MapMarkerData(id: $id, title: $title, type: $type)';
}

/// Marker türü
enum MapMarkerType {
  site,
  controller,
  alarm,
  user,
  custom,
}

/// Marker durumu
enum MapMarkerStatus {
  normal,
  warning,
  critical,
  offline,
  inactive,
}

/// Geofence bölgesi
class GeofenceRegion {
  /// Benzersiz ID
  final String id;

  /// Merkez noktası
  final LatLng center;

  /// Yarıçap (metre)
  final double radiusMeters;

  /// Bölge adı
  final String name;

  /// Bölge türü
  final GeofenceType type;

  /// Ek veri
  final Map<String, dynamic> metadata;

  const GeofenceRegion({
    required this.id,
    required this.center,
    required this.radiusMeters,
    required this.name,
    this.type = GeofenceType.site,
    this.metadata = const {},
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeofenceRegion &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'GeofenceRegion(id: $id, name: $name, radius: ${radiusMeters}m)';
}

/// Geofence türü
enum GeofenceType {
  site,
  restricted,
  monitoring,
}

/// Geofence olayı
class GeofenceEvent {
  /// Bölge ID
  final String regionId;

  /// Olay türü (giriş/çıkış)
  final GeofenceEventType eventType;

  /// Zaman damgası
  final DateTime timestamp;

  /// Kullanıcı konumu
  final LatLng position;

  const GeofenceEvent({
    required this.regionId,
    required this.eventType,
    required this.timestamp,
    required this.position,
  });
}

/// Geofence olay türü
enum GeofenceEventType {
  enter,
  exit,
}

/// Harita cluster verisi
class MapClusterData {
  /// Cluster'daki marker sayısı
  final int count;

  /// Cluster'daki marker'lar
  final List<MapMarkerData> markers;

  /// Alarm içeren marker var mı?
  bool get hasAlarms => markers.any((m) => m.alarmCount > 0);

  /// En yüksek öncelikli durum
  MapMarkerStatus get worstStatus {
    if (markers.any((m) => m.status == MapMarkerStatus.critical)) {
      return MapMarkerStatus.critical;
    }
    if (markers.any((m) => m.status == MapMarkerStatus.warning)) {
      return MapMarkerStatus.warning;
    }
    if (markers.any((m) => m.status == MapMarkerStatus.offline)) {
      return MapMarkerStatus.offline;
    }
    return MapMarkerStatus.normal;
  }

  const MapClusterData({
    required this.count,
    required this.markers,
  });
}

/// Harita tile sağlayıcı türü
enum MapTileProvider {
  light,
  dark,
  satellite,
}
