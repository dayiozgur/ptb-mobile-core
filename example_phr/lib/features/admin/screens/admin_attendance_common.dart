import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// PHR admin devam/PDKS/puantaj ekranları için ortak görsel yardımcılar.
///
/// PDKS durum kodları web `PdksStatus` ile aynıdır:
/// present | absent | off | leave | holiday.

/// PDKS durum → (Türkçe etiket, rozet varyantı). İzin/tatil bayrakları durum
/// kodundan önce gelir (web `_dayTag` mantığı).
({String label, AppBadgeVariant variant}) pdksStatusTag(
  String? status, {
  bool isHoliday = false,
  bool isLeave = false,
}) {
  final s = status?.toLowerCase();
  if (isHoliday || s == 'holiday') {
    return (
      label: essT('hr.pdks.status_holiday', 'Resmi Tatil'),
      variant: AppBadgeVariant.warning
    );
  }
  if (isLeave || s == 'leave') {
    return (
      label: essT('hr.pdks.status_leave', 'İzinli'),
      variant: AppBadgeVariant.info
    );
  }
  switch (s) {
    case 'present':
      return (
        label: essT('hr.pdks.status_present', 'Geldi'),
        variant: AppBadgeVariant.success
      );
    case 'absent':
      return (
        label: essT('hr.pdks.status_absent', 'Gelmedi'),
        variant: AppBadgeVariant.error
      );
    case 'off':
      return (
        label: essT('hr.pdks.status_off', 'Çalışma dışı'),
        variant: AppBadgeVariant.neutral
      );
    default:
      return (label: status ?? '—', variant: AppBadgeVariant.neutral);
  }
}

/// Küçük ikon + metin rozeti (kart alt satırı için).
Widget pdksChip(
  BuildContext context,
  IconData icon,
  String text,
  Color color,
) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(text, style: AppTypography.caption2.copyWith(color: color)),
    ],
  );
}

/// Kaydırılabilir boş-durum (RefreshIndicator ile pull-to-refresh çalışsın diye).
Widget pdksEmptyScroll({
  required IconData icon,
  required String title,
  String? message,
}) {
  return LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: AppEmptyState(icon: icon, title: title, message: message),
        ),
      ),
    ),
  );
}

/// ISO gün numarası (1=Pzt .. 7=Paz) → kısa Türkçe gün adı.
String pdksDowShort(int iso) {
  const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  if (iso < 1 || iso > 7) return '?';
  return names[iso - 1];
}
