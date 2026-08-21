import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../hr/hr_ess_service.dart';
import '../map/map_models.dart';
import '../map/map_service.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';

/// Bir işletmenin geofence tanımı (`work_geofences`).
class WorkGeofence {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusM;
  final String? siteId;
  final String? organizationId;

  const WorkGeofence({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    this.siteId,
    this.organizationId,
  });

  factory WorkGeofence.fromJson(Map<String, dynamic> j) => WorkGeofence(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'İşyeri',
        latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
        radiusM: (j['radius_m'] as num?)?.toDouble() ?? 150,
        siteId: j['site_id']?.toString(),
        organizationId: j['organization_id']?.toString(),
      );
}

/// Bir geo-punch sonucu (UI'a yansıtmak için).
class GeoPunchResult {
  final bool ok;
  final String event; // 'in' | 'out' | 'manual_in' | 'manual_out'
  final Map<String, dynamic> raw;
  const GeoPunchResult({required this.ok, required this.event, this.raw = const {}});

  bool get isNoop => raw['noop'] == true;
  String? get error => raw['error']?.toString();
}

/// **Geofence tabanlı otomatik PDKS** — mobil konum motorunu (`MapService`)
/// işletme geofence'lerine bağlar; sınıra girince otomatik giriş, çıkınca
/// otomatik çıkış punch'ı atar (sunucu-taraflı doğrulamalı `fn_pdks_geo_punch`),
/// ve giriş anında konum-bazlı hava durumunu (`capture-weather` EF) kaydeder.
///
/// Ek olarak **manuel giriş/çıkış** fallback'i sağlar (geofence dışıysa veya GPS
/// yoksa; doğrudan `attendance_records` insert, `source='manual'`, RLS izinli).
///
/// Ön-plan (foreground) çalışır; arka-plan geofence (uygulama kapalı) iOS'ta
/// Always izni + background modes gerektirir → sonraki faz.
class GeofenceAttendanceService {
  final SupabaseClient _supabase;

  GeofenceAttendanceService({required SupabaseClient supabase})
      : _supabase = supabase;

  MapService get _map => sl<MapService>();
  TenantService get _tenant => sl<TenantService>();
  HrEssService get _ess => sl<HrEssService>();

  final List<WorkGeofence> _geofences = [];
  StreamSubscription<GeofenceEvent>? _sub;
  bool _running = false;

  final _punchController = StreamController<GeoPunchResult>.broadcast();

  /// Punch olayları (UI dinler → snackbar / durum güncelle).
  Stream<GeoPunchResult> get punchStream => _punchController.stream;

  bool get isRunning => _running;
  List<WorkGeofence> get geofences => List.unmodifiable(_geofences);

  /// Şu an herhangi bir işyeri geofence'i içinde miyiz?
  bool get isOnSite => _geofences.any((g) => _map.isInsideRegion(g.id));

  /// İçinde bulunduğumuz geofence (yoksa null).
  WorkGeofence? get currentGeofence {
    for (final g in _geofences) {
      if (_map.isInsideRegion(g.id)) return g;
    }
    return null;
  }

  /// Kullanıcının tenant'ına ait aktif işyeri geofence'leri (RLS kapsamlı).
  Future<List<WorkGeofence>> loadGeofences() async {
    try {
      final res = await _supabase
          .from('work_geofences')
          .select('id, name, latitude, longitude, radius_m, site_id, organization_id')
          .eq('active', true)
          .inFilter('kind', ['attendance', 'both']);
      final list = (res as List)
          .map((e) => WorkGeofence.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _geofences
        ..clear()
        ..addAll(list);
      return list;
    } catch (e) {
      Logger.error('work_geofences yüklenemedi', e);
      return [];
    }
  }

  /// Oto-PDKS'i başlat: izin + geofence'leri yükle + motora ekle + takip + dinle.
  Future<bool> start() async {
    if (_running) return true;
    final ok = await _map.checkLocationPermission();
    if (!ok) {
      Logger.warning('geofence-pdks: konum izni yok');
      return false;
    }
    await loadGeofences();
    _map.clearGeofences();
    for (final g in _geofences) {
      _map.addGeofence(GeofenceRegion(
        id: g.id,
        center: LatLng(g.latitude, g.longitude),
        radiusMeters: g.radiusM,
        name: g.name,
        type: GeofenceType.site,
        metadata: {'geofence_id': g.id, 'site_id': g.siteId},
      ));
    }
    _sub = _map.geofenceEventStream.listen(_onEvent);
    await _map.startLocationTracking(distanceFilter: 15);
    _running = true;
    Logger.info('geofence-pdks: başladı (${_geofences.length} işyeri)');
    return true;
  }

  /// Oto-PDKS'i durdur.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _map.stopLocationTracking();
    _map.clearGeofences();
    _running = false;
    Logger.info('geofence-pdks: durdu');
  }

  Future<void> _onEvent(GeofenceEvent ev) async {
    WorkGeofence? g;
    for (final x in _geofences) {
      if (x.id == ev.regionId) {
        g = x;
        break;
      }
    }
    if (g == null) return;
    final event = ev.eventType == GeofenceEventType.enter ? 'in' : 'out';
    await _geoPunch(g, event, ev.position.latitude, ev.position.longitude);
    if (event == 'in') {
      unawaited(_captureWeather(g));
    }
  }

  /// Geofence-doğrulamalı punch (sunucu mesafe kontrolü yapar).
  Future<GeoPunchResult> _geoPunch(
    WorkGeofence g,
    String event,
    double lat,
    double lon, {
    double? accuracy,
  }) async {
    try {
      final res = await _supabase.rpc('fn_pdks_geo_punch', params: {
        'p_geofence_id': g.id,
        'p_event': event,
        'p_lat': lat,
        'p_lon': lon,
        if (accuracy != null) 'p_accuracy': accuracy,
      });
      final map =
          res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      final result = GeoPunchResult(ok: map['ok'] == true, event: event, raw: map);
      _punchController.add(result);
      return result;
    } catch (e) {
      Logger.error('fn_pdks_geo_punch hata', e);
      final r = GeoPunchResult(ok: false, event: event, raw: {'error': '$e'});
      _punchController.add(r);
      return r;
    }
  }

  /// UI'dan tetiklenen geofence punch: mevcut konumu alıp doğrulamalı punch atar.
  Future<GeoPunchResult> punchHere(WorkGeofence g, String event) async {
    final pos = _map.currentPosition;
    if (pos == null) {
      final r = GeoPunchResult(ok: false, event: event, raw: {'error': 'no_position'});
      _punchController.add(r);
      return r;
    }
    return _geoPunch(g, event, pos.latitude, pos.longitude);
  }

  Future<void> _captureWeather(WorkGeofence g) async {
    try {
      await _supabase.functions.invoke('capture-weather', body: {
        'geofence_id': g.id,
        'lat': g.latitude,
        'lon': g.longitude,
        if (g.siteId != null) 'site_id': g.siteId,
      });
    } catch (e) {
      Logger.warning('capture-weather hata: $e');
    }
  }

  // ── Manuel fallback (geofence dışı / GPS yok) — doğrudan insert, source=manual ──

  Future<GeoPunchResult> manualClockIn() async {
    try {
      final staffId = await _ess.currentStaffId();
      if (staffId == null) {
        return GeoPunchResult(ok: false, event: 'manual_in', raw: {'error': 'no_staff'});
      }
      final today = _todayStr();
      final open = await _supabase
          .from('attendance_records')
          .select('id')
          .eq('staff_id', staffId)
          .eq('work_date', today)
          .filter('exit_time', 'is', null)
          .limit(1);
      if ((open as List).isNotEmpty) {
        return GeoPunchResult(ok: true, event: 'manual_in', raw: {'noop': true, 'reason': 'already_in'});
      }
      final uid = _supabase.auth.currentUser?.id;
      await _supabase.from('attendance_records').insert({
        'tenant_id': _tenant.currentTenantId,
        'staff_id': staffId,
        'work_date': today,
        'entry_time': DateTime.now().toUtc().toIso8601String(),
        'source': 'manual',
        'created_by': uid,
        'updated_by': uid,
      });
      final r = GeoPunchResult(ok: true, event: 'manual_in', raw: const {});
      _punchController.add(r);
      return r;
    } catch (e) {
      Logger.error('manualClockIn hata', e);
      return GeoPunchResult(ok: false, event: 'manual_in', raw: {'error': '$e'});
    }
  }

  Future<GeoPunchResult> manualClockOut() async {
    try {
      final staffId = await _ess.currentStaffId();
      if (staffId == null) {
        return GeoPunchResult(ok: false, event: 'manual_out', raw: {'error': 'no_staff'});
      }
      final today = _todayStr();
      final open = await _supabase
          .from('attendance_records')
          .select('id')
          .eq('staff_id', staffId)
          .eq('work_date', today)
          .filter('exit_time', 'is', null)
          .order('entry_time', ascending: false)
          .limit(1)
          .maybeSingle();
      if (open == null) {
        return GeoPunchResult(ok: true, event: 'manual_out', raw: {'noop': true, 'reason': 'no_open_punch'});
      }
      final uid = _supabase.auth.currentUser?.id;
      await _supabase.from('attendance_records').update({
        'exit_time': DateTime.now().toUtc().toIso8601String(),
        'updated_by': uid,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', open['id']);
      final r = GeoPunchResult(ok: true, event: 'manual_out', raw: const {});
      _punchController.add(r);
      return r;
    } catch (e) {
      Logger.error('manualClockOut hata', e);
      return GeoPunchResult(ok: false, event: 'manual_out', raw: {'error': '$e'});
    }
  }

  String _todayStr() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  void dispose() {
    stop();
    _punchController.close();
  }
}
