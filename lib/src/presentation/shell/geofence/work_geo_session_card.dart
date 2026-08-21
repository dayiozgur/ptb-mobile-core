import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// FixFlow **on-site süre takibi** kartı — bir iş kaydının (work_request)
/// yapıldığı işyeri geofence'ine göre oturum **Başlat / Bitir**; süre sunucu
/// tarafında `worklogs`'a otomatik yazılır.
///
/// Yalnız worklog-etkin entity detayında gösterilir. FixFlow geofence tanımlı
/// değilse (ya da hiç yoksa) kendini gizler (`SizedBox.shrink`).
class WorkGeoSessionCard extends StatefulWidget {
  final String workRequestId;
  final String? siteId;

  const WorkGeoSessionCard({
    super.key,
    required this.workRequestId,
    this.siteId,
  });

  @override
  State<WorkGeoSessionCard> createState() => _WorkGeoSessionCardState();
}

class _WorkGeoSessionCardState extends State<WorkGeoSessionCard> {
  WorkGeoSessionService get _svc => sl<WorkGeoSessionService>();

  bool _loading = true;
  bool _busy = false;
  bool _hasFixflowGeofences = false;
  WorkGeoSession? _active;
  NearestGeofence? _near;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    // Açık oturum süresini canlı güncelle.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _active != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final geofences = await _svc.loadFixflowGeofences();
    if (!mounted) return;
    if (geofences.isEmpty) {
      setState(() {
        _hasFixflowGeofences = false;
        _loading = false;
      });
      return;
    }
    final active = await _svc.activeSession(widget.workRequestId);
    NearestGeofence? near;
    // Konum çözümlemesi izin/GPS gerektirir; hata olursa sessiz geç.
    try {
      near = await _svc.resolveNearest(preferSiteId: widget.siteId);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _hasFixflowGeofences = true;
      _active = active;
      _near = near;
      _loading = false;
    });
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    final r = await _svc.start(widget.workRequestId, preferSiteId: widget.siteId);
    if (!mounted) return;
    if (r.ok) {
      await _load();
    }
    setState(() => _busy = false);
    _snack(r.ok
        ? 'Oturum başladı ✓'
        : _errMsg(r.error));
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    final r = await _svc.stop(widget.workRequestId,
        geofenceId: _active?.geofenceId, preferSiteId: widget.siteId);
    if (!mounted) return;
    if (r.ok) {
      await _load();
    }
    setState(() => _busy = false);
    _snack(r.ok
        ? (r.durationMinutes != null
            ? 'Oturum bitti ✓ (${r.durationMinutes} dk worklog)'
            : 'Oturum bitti ✓')
        : _errMsg(r.error));
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _errMsg(String? code) {
    switch (code) {
      case 'out_of_range':
        return 'İş konumunun dışındasınız.';
      case 'no_geofence':
        return 'Bu iş için konum tanımlı değil.';
      case 'no_session':
        return 'Açık oturum bulunamadı.';
      case 'no_staff':
        return 'Personel kaydı bulunamadı.';
      case 'already_open':
        return 'Zaten açık bir oturumunuz var.';
      default:
        return 'İşlem başarısız.';
    }
  }

  String _elapsed(DateTime from) {
    final mins = DateTime.now().difference(from).inMinutes;
    if (mins < 60) return '$mins dk';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$h sa' : '$h sa $m dk';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_hasFixflowGeofences) return const SizedBox.shrink();
    final b = Theme.of(context).brightness;
    final active = _active;
    final inRange = _near?.inRange ?? false;
    final gfName = _near?.geofence?.name ?? active?.geofenceId;

    final Color statusColor;
    final IconData statusIcon;
    final String statusText;
    if (active != null) {
      statusColor = AppColors.success;
      statusIcon = Icons.timer;
      statusText = 'Oturum açık · ${_elapsed(active.startedAt)}';
    } else if (inRange) {
      statusColor = AppColors.success;
      statusIcon = Icons.location_on;
      statusText = 'İş konumundasınız: ${gfName ?? "-"}';
    } else if (_near?.geofence != null) {
      statusColor = AppColors.warning;
      statusIcon = Icons.my_location_outlined;
      final d = _near?.distanceM;
      statusText = d != null
          ? 'İş konumuna ${d.round()} m uzaktasınız'
          : 'İş konumunun dışındasınız';
    } else {
      statusColor = AppColors.textSecondary(b);
      statusIcon = Icons.location_searching;
      statusText = 'Konum alınıyor…';
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
                  child: Text('Konum-tabanlı süre takibi',
                      style: AppTypography.withColor(AppTypography.subhead,
                          AppColors.textPrimary(b))),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(statusText,
                style: AppTypography.withColor(
                    AppTypography.footnote, AppColors.textSecondary(b))),
            const Divider(height: AppSpacing.lg),
            if (active != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _stop,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Oturumu Bitir'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _start,
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Oturum Başlat'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
