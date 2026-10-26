import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'priority_model.dart';

/// Alarm öncelik kataloğu — web `alarm-priorities.service.ts`
/// (`platformPriorities` / `resolvePlatformPriority`) ile birebir kurallar:
///
/// - `priorities` GLOBAL tablodur; platform satırları `vendor IS NULL`
///   (critical/high/medium/low/technical + pasif UNDEFINED), üretici satırları
///   (`vendor = 'carel'`) içe aktarıcıların değişkenlere damgaladığı satırlardır.
/// - UI yalnız `vendor IS NULL AND active = true` satırları sunar (filtre çipleri).
/// - Bir alarmın `priority_id`'si üretici satırıysa, önce satırın AÇIK
///   eşlemesi `platform_priority_id` kullanılır (Carel TECHNICAL → teknik).
///   Eşleme yoksa `vendor_level` (yoksa `level`) eşit olan platform satırına,
///   o da yoksa teknik sınıf satırlar platform teknik satırına düşer.
/// - Etiket `alarm.priority.<code>`, renk `priorities.color`. UUID / severity
///   sabiti YOK.
class PriorityCatalog {
  PriorityCatalog(Iterable<Priority> rows)
      : _rows = {for (final r in rows) r.id: r} {
    _platform = _rows.values
        .where((r) => r.vendor == null && r.explicitlyActive)
        .toList()
      ..sort(_compare);
  }

  /// Boş katalog (yükleme öncesi).
  static final PriorityCatalog empty = PriorityCatalog(const []);

  final Map<String, Priority> _rows;
  late final List<Priority> _platform;

  /// Web sıralaması: severity satırları level'a göre, ardından teknik satırlar.
  static int _compare(Priority a, Priority b) {
    final ca = a.isTechnical ? 1 : 0;
    final cb = b.isTechnical ? 1 : 0;
    if (ca != cb) return ca - cb;
    final la = a.level ?? 1 << 30;
    final lb = b.level ?? 1 << 30;
    if (la != lb) return la - lb;
    return (a.code ?? '').compareTo(b.code ?? '');
  }

  /// [resolvedMap] değerlerinden tekil + web sırasıyla liste (filtre çipleri).
  static List<Priority> distinctSorted(Iterable<Priority> items) =>
      {for (final p in items) p.id: p}.values.toList()..sort(_compare);

  /// UI'da sunulan platform öncelikleri (filtre çipleri, özetler).
  List<Priority> get platform => List.unmodifiable(_platform);

  bool get isEmpty => _rows.isEmpty;

  /// Ham satır (vendor dahil).
  Priority? raw(String? id) => id == null ? null : _rows[id];

  /// Saklanan `priority_id`'nin karşılık geldiği platform önceliği.
  Priority? resolve(String? priorityId) {
    final row = raw(priorityId);
    if (row == null) return null;
    if (row.vendor == null) {
      for (final p in _platform) {
        if (p.id == row.id) return p;
      }
      return null;
    }
    final mapped = row.platformPriorityId;
    if (mapped != null) {
      for (final p in _platform) {
        if (p.id == mapped) return p;
      }
    }
    final lvl = row.vendorLevel ?? row.level;
    if (lvl != null) {
      for (final p in _platform) {
        if (p.level == lvl && !p.isTechnical) return p;
      }
    }
    if (row.isTechnical) {
      for (final p in _platform) {
        if (p.isTechnical) return p;
      }
    }
    return null;
  }

  /// Ham `priority_id` → çözülen platform önceliği eşlemesi (vendor satırları
  /// dahil). `Map<String, Priority>` bekleyen widget'lara (grafikler, listeler)
  /// verilir; böylece her yerde platform etiketi/rengi görünür.
  Map<String, Priority> resolvedMap() {
    final out = <String, Priority>{};
    for (final id in _rows.keys) {
      final p = resolve(id);
      if (p != null) out[id] = p;
    }
    return out;
  }

  /// Çözülen platform önceliğinin rengi; çözülemezse nötr gri.
  Color colorOf(String? priorityId) =>
      resolve(priorityId)?.displayColor ?? AppColors.systemGray;

  /// `alarm.priority.<code>` etiketi; çözülemezse `alarm.priority.undefined`.
  String labelOf(String? priorityId, String Function(String key) translate) {
    final p = resolve(priorityId);
    if (p != null) return p.localizedLabel(translate);
    final key = priorityLabelKey(null);
    return translate(key);
  }

  /// Platform önceliği [platformId] seçiliyken alarmın eşleşip eşleşmediği.
  bool matches(String? alarmPriorityId, String platformId) =>
      resolve(alarmPriorityId)?.id == platformId;
}
