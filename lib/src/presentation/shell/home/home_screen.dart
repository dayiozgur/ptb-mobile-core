import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'home_widgets_section.dart';

/// Ana Sayfa (Home) — kişisel pano ("Panom").
///
/// Modüller alt-nav sekmesine, profil ise Panom'daki **Profil Kartım**
/// widget'ına taşındığından Ana Sayfa artık YALIN: (izleme platformunda aktif
/// alarm kartı) + kullanıcının widget panosu ([HomeWidgetsSection]). Böylece
/// karşılama ekranı = kişiselleştirilebilir dashboard.
class HomeScreen extends StatefulWidget {
  /// Shell sekmesi olarak gömülüyse kendi AppBar'ını çizmez.
  final bool embedded;
  const HomeScreen({super.key, this.embedded = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;

  /// Aktif alarm sayısı. null → izleme-dışı platform / servis yok (kart gizli).
  int? _alarmCount;

  StreamSubscription<String>? _platformSub;

  @override
  void initState() {
    super.initState();
    try {
      _platformSub =
          sl<PlatformContext>().platformStream.listen((_) => _loadStats());
    } catch (_) {
      // PlatformContext kayıtlı değilse sessizce atla.
    }
    _load();
  }

  @override
  void dispose() {
    _platformSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await _loadStats();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadStats() async {
    // Aktif alarm = SCADA/IoT `alarms` → YALNIZ izleme platformlarında (PMS).
    if (!_isMonitoringPlatform()) return;
    try {
      if (sl.isRegistered<AlarmService>()) {
        final alarmSvc = sl<AlarmService>();
        try {
          final orgId = organizationService.currentOrganizationId;
          if (orgId != null) alarmSvc.setOrganization(orgId);
        } catch (_) {}
        final alarms = await alarmSvc.getActiveAlarms();
        if (mounted) setState(() => _alarmCount = alarms.length);
      }
    } catch (_) {
      // Alarm servisi erişilemedi → kartı gösterme.
    }
  }

  /// SCADA/IoT izleme yapan platformlar (aktif alarm kartı YALNIZ burada).
  static const Set<String> _kMonitoringPlatforms = {'PMS'};

  bool _isMonitoringPlatform() {
    try {
      final code =
          sl<PlatformContext>().activePlatformCode?.trim().toUpperCase();
      if (code == null || code.isEmpty) return false;
      return _kMonitoringPlatforms.contains(code);
    } catch (_) {
      return false;
    }
  }

  /// AppBar başlığı: aktif platform kodu/adı, yoksa 'Ana Sayfa'.
  String _title() {
    try {
      final code = sl<PlatformContext>().activePlatformCode;
      if (code != null && code.trim().isNotEmpty) return code.trim();
    } catch (_) {}
    return 'Ana Sayfa';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _title(),
      showAppBar: !widget.embedded,
      showBackButton: false,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_alarmCount != null) ...[
                      _buildAlarm(context),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    const HomeWidgetsSection(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
    );
  }

  // Aktif alarm istatistiği (yalnız izleme platformları).
  Widget _buildAlarm(BuildContext context) {
    return MetricCard(
      title: 'Alarm',
      value: '${_alarmCount ?? 0}',
      subtitle: 'Aktif',
      icon: Icons.warning_amber_outlined,
      color: AppColors.error,
    );
  }
}
