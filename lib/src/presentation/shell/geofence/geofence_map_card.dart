import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// İşyeri geofence'ini (kapsam dairesi) + kullanıcının **canlı GPS konumunu**
/// haritada gösterir; altında en yakın işyerine mesafe + içeride/dışarıda durumu.
///
/// [GeofenceAttendanceService]'ten geofence'leri, cihazdan GPS'i alır. PDKS
/// ekranında oto-PDKS kartının altında yer alır (opsiyonel görsel yardımcı).
class GeofenceMapCard extends StatefulWidget {
  const GeofenceMapCard({super.key});

  @override
  State<GeofenceMapCard> createState() => _GeofenceMapCardState();
}

class _GeofenceMapCardState extends State<GeofenceMapCard> {
  GeofenceAttendanceService get _svc => sl<GeofenceAttendanceService>();
  static const _distance = Distance();

  bool _loading = true;
  bool _hasGeofences = false;
  List<GeofenceRegion> _regions = [];
  LatLng? _userLoc;
  double? _nearestM;
  bool _inside = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final gs = await _svc.loadGeofences();
    final regions = gs
        .map((g) => GeofenceRegion(
              id: g.id,
              center: LatLng(g.latitude, g.longitude),
              radiusMeters: g.radiusM,
              name: g.name,
              type: GeofenceType.site,
            ))
        .toList();

    LatLng? user;
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final granted = perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always;
      if (serviceOn && granted) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        user = LatLng(pos.latitude, pos.longitude);
      }
    } catch (e) {
      Logger.warning('map-card GPS alınamadı: $e');
    }

    double? nearest;
    bool inside = false;
    if (user != null && regions.isNotEmpty) {
      double best = double.infinity;
      for (final r in regions) {
        final d =
            _distance.as(LengthUnit.Meter, user, r.center);
        if (d < best) best = d;
        if (d <= r.radiusMeters) inside = true;
      }
      nearest = best;
    }

    if (!mounted) return;
    setState(() {
      _regions = regions;
      _userLoc = user;
      _nearestM = nearest;
      _inside = inside;
      _hasGeofences = regions.isNotEmpty;
      _loading = false;
    });
  }

  String _fmtDist(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(2)} km' : '${m.round()} m';

  LatLng get _mapCenter {
    if (_userLoc != null && _regions.isNotEmpty) {
      // Kullanıcı ile en yakın geofence merkezinin orta noktası.
      final r = _regions.first.center;
      return LatLng((_userLoc!.latitude + r.latitude) / 2,
          (_userLoc!.longitude + r.longitude) / 2);
    }
    if (_regions.isNotEmpty) return _regions.first.center;
    return _userLoc ?? const LatLng(39.0, 35.0);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.map_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Konum & Kapsam',
                      style: AppTypography.withColor(AppTypography.subhead,
                          AppColors.textPrimary(b))),
                ),
                AppIconButton(icon: Icons.refresh, onPressed: _load),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                child: _loading
                    ? const Center(child: AppLoadingIndicator())
                    : !_hasGeofences
                        ? Center(
                            child: Text('İşyeri tanımlı değil',
                                style: AppTypography.withColor(
                                    AppTypography.footnote,
                                    AppColors.textSecondary(b))))
                        : AppMap(
                            center: _mapCenter,
                            zoom: 14,
                            geofences: _regions,
                            insideGeofenceIds:
                                _inside ? {_regions.first.id} : const {},
                            showUserLocation: _userLoc != null,
                            userLocation: _userLoc,
                            showZoomControls: false,
                            showLayerSelector: false,
                            enableClustering: false,
                          ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(_inside ? Icons.check_circle : Icons.my_location,
                    size: 16,
                    color: _inside ? AppColors.success : AppColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _userLoc == null
                        ? 'GPS konumu alınamadı (izin gerekli)'
                        : _inside
                            ? 'İşyeri kapsamındasınız'
                            : _nearestM != null
                                ? 'İşyerine ${_fmtDist(_nearestM!)} uzaktasınız'
                                : 'Konum hesaplanıyor…',
                    style: AppTypography.withColor(AppTypography.footnote,
                        AppColors.textSecondary(b)),
                  ),
                ),
                if (_regions.isNotEmpty)
                  Text('kapsam ${_fmtDist(_regions.first.radiusMeters)}',
                      style: AppTypography.withColor(AppTypography.caption1,
                          AppColors.tertiaryLabel(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
