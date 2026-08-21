import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../map/map_service.dart';
import '../utils/logger.dart';
import 'geofence_attendance_service.dart' show WorkGeofence;

/// Bir FixFlow (veya worklog-etkin entity) için **konum-tabanlı on-site oturum**.
class WorkGeoSession {
  final String id;
  final String geofenceId;
  final String? workRequestId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;

  const WorkGeoSession({
    required this.id,
    required this.geofenceId,
    required this.startedAt,
    this.workRequestId,
    this.endedAt,
    this.durationMinutes,
  });

  bool get isOpen => endedAt == null;

  factory WorkGeoSession.fromJson(Map<String, dynamic> j) => WorkGeoSession(
        id: j['id']?.toString() ?? '',
        geofenceId: j['geofence_id']?.toString() ?? '',
        workRequestId: j['work_request_id']?.toString(),
        startedAt:
            DateTime.tryParse(j['started_at']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
        endedAt: j['ended_at'] == null
            ? null
            : DateTime.tryParse(j['ended_at'].toString())?.toLocal(),
        durationMinutes: (j['duration_minutes'] as num?)?.toInt(),
      );
}

/// `fn_work_geo_session` sonucu (UI'a yansıtmak için).
class GeoSessionResult {
  final bool ok;
  final String action; // 'start' | 'stop'
  final Map<String, dynamic> raw;
  const GeoSessionResult(
      {required this.ok, required this.action, this.raw = const {}});

  String? get error => raw['error']?.toString();
  int? get durationMinutes => (raw['duration_minutes'] as num?)?.toInt();
}

/// En yakın geofence çözüm sonucu.
class NearestGeofence {
  final WorkGeofence? geofence;
  final double? distanceM;
  final bool inRange;
  const NearestGeofence({this.geofence, this.distanceM, this.inRange = false});
}

/// **FixFlow konum-tabanlı süre takibi** — bir iş kaydının (work_request) yapıldığı
/// mağaza/işyeri geofence'ine girince oturum başlatır, çıkınca bitirir; süre
/// sunucu tarafında `worklogs`'a otomatik yazılır (`fn_work_geo_session`).
///
/// PDKS'ten ([GeofenceAttendanceService]) ayrı bir çekirdek: aynı geofence
/// primitivini (kind `fixflow`/`both`) kullanır ama iş-kaydı süresine bağlar.
/// Sunucu-taraflı mesafe doğrulaması anti-spoof sağlar.
class WorkGeoSessionService {
  final SupabaseClient _supabase;

  WorkGeoSessionService({required SupabaseClient supabase})
      : _supabase = supabase;

  MapService get _map => sl<MapService>();

  static const _distance = Distance();

  /// FixFlow-tipi aktif geofence'ler (kind `fixflow`/`both`), RLS kapsamlı.
  Future<List<WorkGeofence>> loadFixflowGeofences() async {
    try {
      final res = await _supabase
          .from('work_geofences')
          .select(
              'id, name, latitude, longitude, radius_m, site_id, organization_id')
          .eq('active', true)
          .inFilter('kind', ['fixflow', 'both']);
      return (res as List)
          .map((e) => WorkGeofence.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      Logger.error('fixflow work_geofences yüklenemedi', e);
      return [];
    }
  }

  /// Bir iş kaydının açık (bitmemiş) oturumu (varsa). RLS: yalnız kendi kayıtları.
  Future<WorkGeoSession?> activeSession(String workRequestId) async {
    try {
      final res = await _supabase
          .from('work_geo_sessions')
          .select('id, geofence_id, work_request_id, started_at, ended_at, '
              'duration_minutes')
          .eq('work_request_id', workRequestId)
          .filter('ended_at', 'is', null)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return WorkGeoSession.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      Logger.error('activeSession sorgu hata', e);
      return null;
    }
  }

  /// Mevcut konuma en yakın FixFlow geofence'i çöz (isteğe bağlı site tercihi).
  ///
  /// [preferSiteId] verilirse ve o site'a bağlı bir geofence varsa onu seçer;
  /// aksi halde konuma en yakın geofence'i döndürür + menzil-içi olup olmadığını
  /// bildirir.
  Future<NearestGeofence> resolveNearest({String? preferSiteId}) async {
    final ok = await _map.checkLocationPermission();
    if (!ok) return const NearestGeofence();
    final geofences = await loadFixflowGeofences();
    if (geofences.isEmpty) return const NearestGeofence();

    LatLng here;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      here = LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      final cp = _map.currentPosition;
      if (cp == null) return const NearestGeofence();
      here = cp;
    }

    // Site tercihi: iş kaydı bir site'a bağlıysa o geofence'i öne al.
    Iterable<WorkGeofence> candidates = geofences;
    if (preferSiteId != null && preferSiteId.isNotEmpty) {
      final matched =
          geofences.where((g) => g.siteId == preferSiteId).toList();
      if (matched.isNotEmpty) candidates = matched;
    }

    WorkGeofence? best;
    double bestDist = double.infinity;
    for (final g in candidates) {
      final d = _distance.as(
          LengthUnit.Meter, here, LatLng(g.latitude, g.longitude));
      if (d < bestDist) {
        bestDist = d;
        best = g;
      }
    }
    if (best == null) return const NearestGeofence();
    return NearestGeofence(
      geofence: best,
      distanceM: bestDist,
      inRange: bestDist <= best.radiusM,
    );
  }

  /// On-site oturumu başlat (sunucu mesafe doğrulaması yapar).
  Future<GeoSessionResult> start(String workRequestId,
      {String? preferSiteId}) async {
    final near = await resolveNearest(preferSiteId: preferSiteId);
    final g = near.geofence;
    if (g == null) {
      return const GeoSessionResult(
          ok: false, action: 'start', raw: {'error': 'no_geofence'});
    }
    return _call('start', g.id, workRequestId, g);
  }

  /// On-site oturumu bitir (süre otomatik `worklogs`'a yazılır).
  Future<GeoSessionResult> stop(String workRequestId,
      {String? geofenceId, String? preferSiteId}) async {
    String? gid = geofenceId;
    WorkGeofence? g;
    if (gid == null) {
      final open = await activeSession(workRequestId);
      gid = open?.geofenceId;
    }
    final near = await resolveNearest(preferSiteId: preferSiteId);
    // Doğrulama için mevcut konumu kullan; geofence id açık oturumdan gelir.
    g = near.geofence;
    final resolvedGid = gid ?? g?.id;
    if (resolvedGid == null) {
      return const GeoSessionResult(
          ok: false, action: 'stop', raw: {'error': 'no_session'});
    }
    return _call('stop', resolvedGid, workRequestId, g);
  }

  Future<GeoSessionResult> _call(
    String action,
    String geofenceId,
    String workRequestId,
    WorkGeofence? g,
  ) async {
    try {
      double? lat;
      double? lon;
      final cp = _map.currentPosition;
      if (cp != null) {
        lat = cp.latitude;
        lon = cp.longitude;
      } else {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.high),
          );
          lat = pos.latitude;
          lon = pos.longitude;
        } catch (_) {}
      }
      final res = await _supabase.rpc('fn_work_geo_session', params: {
        'p_action': action,
        'p_geofence_id': geofenceId,
        'p_work_request_id': workRequestId,
        if (lat != null) 'p_lat': lat,
        if (lon != null) 'p_lon': lon,
      });
      final map =
          res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      return GeoSessionResult(ok: map['ok'] == true, action: action, raw: map);
    } catch (e) {
      Logger.error('fn_work_geo_session ($action) hata', e);
      return GeoSessionResult(ok: false, action: action, raw: {'error': '$e'});
    }
  }
}
