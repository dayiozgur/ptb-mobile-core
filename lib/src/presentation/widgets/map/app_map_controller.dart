import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Harita programmatic kontrol sınıfı
///
/// AppMap widget'ını dışarıdan kontrol etmek için kullanılır.
///
/// Örnek kullanım:
/// ```dart
/// final controller = AppMapController();
///
/// AppMap(
///   controller: controller,
///   markers: markers,
/// );
///
/// // Belirli konuma git
/// controller.moveTo(LatLng(41.0, 29.0), zoom: 14);
///
/// // Tüm marker'ları göster
/// controller.fitBounds(markers.map((m) => m.latLng).toList());
/// ```
class AppMapController {
  MapController? _mapController;

  /// flutter_map MapController'ı bağla (AppMap tarafından çağrılır)
  void attach(MapController mapController) {
    _mapController = mapController;
  }

  /// flutter_map MapController'ı ayır
  void detach() {
    _mapController = null;
  }

  /// Belirli konuma animasyonlu hareket
  void moveTo(LatLng center, {double? zoom}) {
    final mc = _mapController;
    if (mc == null) return;
    mc.move(center, zoom ?? mc.camera.zoom);
  }

  /// Birden fazla noktayı kapsayacak şekilde zoom ayarla
  void fitBounds(List<LatLng> points, {EdgeInsets? padding}) {
    final mc = _mapController;
    if (mc == null || points.isEmpty) return;

    if (points.length == 1) {
      mc.move(points.first, 14);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    mc.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: padding ?? const EdgeInsets.all(50),
      ),
    );
  }

  /// Zoom in
  void zoomIn() {
    final mc = _mapController;
    if (mc == null) return;
    mc.move(mc.camera.center, mc.camera.zoom + 1);
  }

  /// Zoom out
  void zoomOut() {
    final mc = _mapController;
    if (mc == null) return;
    mc.move(mc.camera.center, mc.camera.zoom - 1);
  }

  /// Tüm marker'ları sığdır (fitBounds ile aynı, convenience method)
  void showAllMarkers(List<LatLng> markerPositions) {
    fitBounds(markerPositions);
  }

  /// Mevcut zoom seviyesi
  double? get currentZoom => _mapController?.camera.zoom;

  /// Mevcut merkez
  LatLng? get currentCenter => _mapController?.camera.center;
}
