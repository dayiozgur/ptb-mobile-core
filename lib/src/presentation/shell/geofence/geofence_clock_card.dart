import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

String _t(String key, [Map<String, dynamic>? params]) =>
    sl.isRegistered<LocalizationService>()
        ? sl<LocalizationService>().translate(key, params: params)
        : key;

/// PDKS **Giriş/Çıkış** kartı — geofence tabanlı otomatik PDKS'i açıp kapatır,
/// işyeri-içinde olup olmadığını gösterir ve manuel giriş/çıkış sağlar.
///
/// [GeofenceAttendanceService]'i sürücü olarak kullanır. Otomatik mod açıkken
/// konum takibi başlar; işyeri geofence'ine girince otomatik giriş, çıkınca
/// otomatik çıkış punch'ı atılır (sunucu-taraflı doğrulamalı).
class GeofenceClockCard extends StatefulWidget {
  const GeofenceClockCard({super.key});

  @override
  State<GeofenceClockCard> createState() => _GeofenceClockCardState();
}

class _GeofenceClockCardState extends State<GeofenceClockCard> {
  GeofenceAttendanceService get _svc => sl<GeofenceAttendanceService>();

  bool _busy = false;
  int _geofenceCount = 0;
  StreamSubscription<GeoPunchResult>? _sub;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _sub = _svc.punchStream.listen(_onPunch);
    // Bildirim iznini ekran açılışında iste → punch anında izin hazır olsun
    // (aksi halde ilk punch bildirimi sessizce düşer).
    unawaited(sl<LocalNotificationService>().requestPermission());
    _load();
    // Otomatik mod açıkken on-site durumu değişebilir → periyodik tazele.
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _svc.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _statusTimer?.cancel();
    // Servisi DURDURMA: otomatik mod açıksa ekran kapansa da takip sürsün.
    super.dispose();
  }

  Future<void> _load() async {
    final gs = await _svc.loadGeofences();
    if (mounted) setState(() => _geofenceCount = gs.length);
  }

  void _onPunch(GeoPunchResult r) {
    if (!mounted) return;
    setState(() {});
    final String msg;
    if (r.isNoop) {
      // Sessiz geçme: kullanıcı neden punch olmadığını anlasın.
      final reason = r.raw['reason']?.toString();
      msg = reason == 'already_in'
          ? _t('geo.clock.already_in_skipped')
          : reason == 'no_open_punch'
              ? _t('geo.clock.no_open_punch_skipped')
              : _t('geo.clock.no_change');
    } else {
      msg = r.ok
          ? (r.event.contains('in')
              ? _t('geo.clock.clocked_in')
              : _t('geo.clock.clocked_out'))
          : _errMsg(r.error);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtDist(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  String _errMsg(String? code) {
    switch (code) {
      case 'out_of_range':
        return _t('geo.error.out_of_range');
      case 'no_staff':
        return _t('geo.error.no_staff');
      case 'geofence_not_found':
        return _t('geo.error.geofence_not_found');
      case 'no_position':
        return _t('geo.error.no_position');
      default:
        return _t('geo.error.failed');
    }
  }

  Future<void> _toggleAuto(bool v) async {
    setState(() => _busy = true);
    if (v) {
      // Giriş/çıkış bildirimleri için izin iste ve BEKLE → ilk enter punch'ından
      // önce izin çözülsün (aksi halde ilk bildirim düşmez).
      await sl<LocalNotificationService>().requestPermission();
      final ok = await _svc.start();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_t('geo.location_permission_required'))));
      }
    } else {
      _svc.stop();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _manual(String event) async {
    setState(() => _busy = true);
    unawaited(sl<LocalNotificationService>().requestPermission());
    final r = event == 'in'
        ? await _svc.manualClockIn()
        : await _svc.manualClockOut();
    if (mounted) {
      setState(() => _busy = false);
      if (!r.isNoop) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(r.ok
                ? (event == 'in'
                    ? _t('geo.clock.manual_in')
                    : _t('geo.clock.manual_out'))
                : _errMsg(r.error))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(event == 'in'
                ? _t('geo.clock.already_in')
                : _t('geo.clock.no_open_punch'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final auto = _svc.isRunning;
    final onSite = auto && _svc.isOnSite;
    final gf = _svc.currentGeofence;

    final Color statusColor;
    final IconData statusIcon;
    final String statusText;
    if (!auto) {
      statusColor = AppColors.textSecondary(b);
      statusIcon = Icons.location_off_outlined;
      statusText = _geofenceCount > 0
          ? _t('geo.clock.auto_off', {'count': _geofenceCount})
          : _t('geo.clock.no_workplace');
    } else if (onSite) {
      statusColor = AppColors.success;
      statusIcon = Icons.location_on;
      statusText = _t('geo.clock.on_site', {'name': gf?.name ?? '-'});
    } else {
      statusColor = AppColors.warning;
      statusIcon = Icons.my_location_outlined;
      final dist = _svc.nearestDistanceM;
      statusText = dist != null
          ? _t('geo.clock.off_site_nearest', {'distance': _fmtDist(dist)})
          : _t('geo.clock.off_site_waiting');
    }

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(statusText,
                      style: AppTypography.withColor(
                          AppTypography.subhead, AppColors.textPrimary(b))),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(_t('geo.clock.auto_toggle'),
                      style: AppTypography.withColor(
                          AppTypography.footnote, AppColors.textSecondary(b))),
                ),
                Switch(
                  value: auto,
                  onChanged:
                      (_busy || _geofenceCount == 0) ? null : _toggleAuto,
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _manual('in'),
                    icon: const Icon(Icons.login, size: 18),
                    label: Text(_t('geo.clock.in')),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _manual('out'),
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(_t('geo.clock.out')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
