import 'package:protoolbag_core/protoolbag_core.dart';

import '../shared/pem_backend.dart';
import '../shared/pem_models.dart';

/// Alarm listesi süzgeci.
enum PemAlarmFilter { all, open }

/// Tetiklenen enerji alarmları servisi — web `EnergyAlarmService`
/// (`listFiredAlarms` + `listPriorities`) paritesi. v1 salt-okunur:
/// onay/kapama (alarms UPDATE) mobilde YOK.
class PemAlarmsService {
  PemAlarmsService({PemBackend? backend})
      : _backend = backend ?? SupabasePemBackend();

  final PemBackend _backend;

  /// En yeni [limit] enerji alarmı (öncelik etiketi/rengi çözülmüş).
  /// Alarm okuma hatası YUKARI fırlatılır; öncelik sözlüğü okunamazsa
  /// alarmlar önceliksiz gösterilir.
  Future<List<PemAlarm>> list({int limit = 100}) async {
    Map<String, PemPriority> prio = const {};
    try {
      final rows = await _backend.priorities();
      prio = {
        for (final r in rows)
          if (r['id'] != null) r['id'].toString(): PemPriority.fromRow(r),
      };
    } catch (e) {
      Logger.warning('PEM priorities failed: $e');
    }
    final rows =
        await _backend.energyAlarms(tenantId: _backend.tenantId, limit: limit);
    return rows.map((r) => PemAlarm.fromRow(r, priorities: prio)).toList();
  }

  static List<PemAlarm> apply(List<PemAlarm> all, PemAlarmFilter f) =>
      f == PemAlarmFilter.all ? all : all.where((a) => a.isOpen).toList();
}
