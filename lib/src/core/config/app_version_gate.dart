import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../localization/localization_service.dart';
import '../utils/logger.dart';

/// Result of the minimum-supported-version check (CRA A-08).
class AppVersionStatus {
  /// Installed app version (`x.y.z`, build number stripped).
  final String current;

  /// Backend-configured minimum, or null when none is configured.
  final String? minimum;

  const AppVersionStatus({required this.current, this.minimum});

  /// True when a minimum is configured and the installed version is lower.
  bool get updateRequired =>
      minimum != null && AppVersionGate.compare(current, minimum!) < 0;
}

/// **Minimum supported app version gate** (CRA A-08, code side).
///
/// Reads the minimum from the platform's `platform_app_configs` row (key
/// [configKey]). The read uses `select()` (all columns) on purpose: until the
/// column exists the key is simply absent and the gate is a no-op — the app
/// never breaks with 42703 on an unknown column.
///
/// TODO(backend): add `platform_app_configs.min_mobile_app_version text NULL`
/// (semantic version, e.g. `1.4.0`; NULL = no minimum). Mobile already reads
/// it; nothing else to change client-side. Store links can follow in
/// `platform_app_configs.mobile_store_url` (optional, also read if present).
///
/// Fail-open: a network/RLS error never locks users out (logged as warning);
/// the server remains authoritative for anything security-relevant.
class AppVersionGate {
  AppVersionGate._();

  /// Column/key holding the minimum supported mobile version.
  static const String configKey = 'min_mobile_app_version';

  /// Optional column with the store/update URL shown on the blocking screen.
  static const String storeUrlKey = 'mobile_store_url';

  /// Compares two dotted versions numerically (`1.10.0` > `1.9.3`). Build
  /// metadata (`+12`) and pre-release suffixes (`-beta`) are ignored; missing
  /// segments count as 0. Returns <0, 0, >0.
  static int compare(String a, String b) {
    List<int> parts(String v) => v
        .split('+')
        .first
        .split('-')
        .first
        .trim()
        .split('.')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();
    final x = parts(a), y = parts(b);
    final n = x.length > y.length ? x.length : y.length;
    for (var i = 0; i < n; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }

  /// Pure evaluation of a `platform_app_configs` row (for tests).
  static AppVersionStatus evaluate(
    String currentVersion,
    Map<String, dynamic>? configRow,
  ) {
    final raw = configRow?[configKey];
    final min = raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
    return AppVersionStatus(current: currentVersion, minimum: min);
  }

  /// Checks the installed version against the platform's configured minimum.
  static Future<({AppVersionStatus status, String? storeUrl})> check(
    SupabaseClient supabase,
    String platformId,
  ) async {
    var current = '0.0.0';
    try {
      current = (await PackageInfo.fromPlatform()).version;
    } catch (e) {
      Logger.warning('AppVersionGate: package info unavailable: $e');
    }
    try {
      final rows = await supabase
          .from('platform_app_configs')
          .select()
          .eq('platform_id', platformId)
          .eq('active', true)
          .limit(1)
          // Açılışı bekletmesin: çevrimdışı/yavaş ağda fail-open.
          .timeout(const Duration(seconds: 5));
      final row = (rows as List).isEmpty
          ? null
          : Map<String, dynamic>.from(rows.first as Map);
      final status = evaluate(current, row);
      final url = row?[storeUrlKey];
      if (status.updateRequired) {
        Logger.warning(
            'AppVersionGate: $current < minimum ${status.minimum} → update required');
      }
      return (status: status, storeUrl: url is String && url.isNotEmpty ? url : null);
    } catch (e) {
      Logger.warning('AppVersionGate: check skipped (fail-open): $e');
      return (status: AppVersionStatus(current: current), storeUrl: null);
    }
  }
}

/// Blocking screen shown when the installed version is below the minimum.
class AppUpdateRequiredApp extends StatelessWidget {
  final AppVersionStatus status;
  final VoidCallback? onUpdate;

  const AppUpdateRequiredApp({super.key, required this.status, this.onUpdate});

  String _t(String key, {Map<String, dynamic>? params}) =>
      sl.isRegistered<LocalizationService>()
          ? sl<LocalizationService>().translate(key, params: params)
          : key;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.system_update, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _t('app.update_required.title'),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('app.update_required.message', params: {
                      'current': status.current,
                      'minimum': status.minimum ?? '',
                    }),
                    textAlign: TextAlign.center,
                  ),
                  if (onUpdate != null) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: onUpdate,
                      child: Text(_t('app.update_required.action')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
