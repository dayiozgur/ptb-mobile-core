import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/fixflow/fixflow_models.dart';
import '../../core/localization/localization_service.dart';
import '../../core/priority/priority_model.dart';
import '../widgets/feedback/app_badge.dart';

/// FixFlow keyword çevirisi: DB `keywords` (LocalizationService) → yoksa
/// [fallback]. `{name}` parametreleri desteklenir.
String ffT(String key, String fallback, {Map<String, Object?>? params}) {
  var text = fallback;
  if (sl.isRegistered<LocalizationService>()) {
    final v = sl<LocalizationService>().translate(key);
    if (v.isNotEmpty && v != key) text = v;
  }
  params?.forEach((k, v) => text = text.replaceAll('{$k}', '${v ?? ''}'));
  return text;
}

/// Ham çeviri (anahtar yoksa anahtarın kendisi) — öncelik etiketi gibi
/// "çeviri yoksa DB adına düş" kararını çağıran verir.
String ffRaw(String key) => sl.isRegistered<LocalizationService>()
    ? sl<LocalizationService>().translate(key)
    : key;

/// `alarm.priority.<code>` (web `priorityLabelKey`) → yoksa DB adı → kod.
String fixflowPriorityLabel(String? code, String? name) {
  if ((code == null || code.isEmpty) && (name == null || name.isEmpty)) {
    return '';
  }
  final key = priorityLabelKey(code);
  final t = ffRaw(key);
  if (t.isNotEmpty && t != key) return t;
  return name ?? code ?? '';
}

/// `dd.MM.yyyy` (yerel saat).
String fixflowDate(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year}';
}

/// `dd.MM.yyyy HH:mm` (yerel saat).
String fixflowDateTime(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${fixflowDate(d)} ${two(l.hour)}:${two(l.minute)}';
}

/// Dakika → `1 sa 30 dk` benzeri kısa metin.
String fixflowMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final hs = ffT('fixflow.mobile.unit_hour_short', 'h');
  final ms = ffT('fixflow.mobile.unit_minute_short', 'min');
  if (h == 0) return '$m $ms';
  if (m == 0) return '$h $hs';
  return '$h $hs $m $ms';
}

/// `status_definitions` adı + rengiyle durum rozeti (ham kod gösterilmez).
class FixflowStatusChip extends StatelessWidget {
  final String status;
  final FixflowStatusCatalog catalog;

  const FixflowStatusChip({
    super.key,
    required this.status,
    required this.catalog,
  });

  @override
  Widget build(BuildContext context) {
    // AppBadge içindeki Center gevşek sınırda tüm genişliği kaplar (ListTile
    // trailing / Wrap) → içerik genişliğine sabitle.
    return IntrinsicWidth(
      child: AppBadge(
        label: catalog.nameOf(status),
        variant: AppBadgeVariant.neutral,
        color: catalog.colorOf(status),
        size: AppBadgeSize.small,
      ),
    );
  }
}

/// `priorities.color` + çevrilmiş etiketle öncelik rozeti.
class FixflowPriorityChip extends StatelessWidget {
  final String? code;
  final String? name;
  final String? colorHex;

  const FixflowPriorityChip({super.key, this.code, this.name, this.colorHex});

  @override
  Widget build(BuildContext context) {
    final label = fixflowPriorityLabel(code, name);
    if (label.isEmpty) return const SizedBox.shrink();
    final p = Priority(id: '', code: code, color: colorHex);
    return IntrinsicWidth(
      child: AppBadge(
        label: label,
        variant: AppBadgeVariant.neutral,
        color: colorHex == null ? null : p.displayColor,
        size: AppBadgeSize.small,
      ),
    );
  }
}
