import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

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
    if (r.isNoop) return;
    final msg = r.ok
        ? (r.event.contains('in') ? 'Giriş yapıldı ✓' : 'Çıkış yapıldı ✓')
        : _errMsg(r.error);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _errMsg(String? code) {
    switch (code) {
      case 'out_of_range':
        return 'İşyeri sınırının dışındasınız.';
      case 'no_staff':
        return 'Personel kaydı bulunamadı.';
      case 'geofence_not_found':
        return 'İşyeri tanımı bulunamadı.';
      case 'no_position':
        return 'Konum alınamadı.';
      default:
        return 'İşlem başarısız.';
    }
  }

  Future<void> _toggleAuto(bool v) async {
    setState(() => _busy = true);
    if (v) {
      final ok = await _svc.start();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Konum izni gerekli (Ayarlar → Konum).')));
      }
    } else {
      _svc.stop();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _manual(String event) async {
    setState(() => _busy = true);
    final r = event == 'in'
        ? await _svc.manualClockIn()
        : await _svc.manualClockOut();
    if (mounted) {
      setState(() => _busy = false);
      if (!r.isNoop) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(r.ok
                ? (event == 'in' ? 'Manuel giriş yapıldı ✓' : 'Manuel çıkış yapıldı ✓')
                : _errMsg(r.error))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(event == 'in'
                ? 'Zaten açık bir girişiniz var.'
                : 'Açık giriş bulunamadı.')));
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
          ? 'Otomatik PDKS kapalı · $_geofenceCount işyeri tanımlı'
          : 'İşyeri tanımlı değil (yönetici tanımlamalı)';
    } else if (onSite) {
      statusColor = AppColors.success;
      statusIcon = Icons.location_on;
      statusText = 'İşyerindesiniz: ${gf?.name ?? "-"}';
    } else {
      statusColor = AppColors.warning;
      statusIcon = Icons.my_location_outlined;
      statusText = 'İşyeri dışındasınız (konum izleniyor)';
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
                  child: Text('Otomatik giriş/çıkış (konum)',
                      style: AppTypography.withColor(AppTypography.footnote,
                          AppColors.textSecondary(b))),
                ),
                Switch(
                  value: auto,
                  onChanged: (_busy || _geofenceCount == 0) ? null : _toggleAuto,
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
                    label: const Text('Giriş'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _manual('out'),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Çıkış'),
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
