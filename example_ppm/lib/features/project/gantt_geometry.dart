import 'dart:math' as math;

/// PPM Gantt için **saf** zaman-çizelgesi geometrisi — widget'tan bağımsız,
/// birim-test edilebilir. Salt-okuma hesap, Flutter/Material bağımlılığı yok.
///
/// Bar konumu iki kesirle ifade edilir: [GanttBar.left] (sol ofset, 0..1) ve
/// [GanttBar.width] (genişlik, 0..1) — çizim katmanı bunları piksel genişliğiyle
/// çarpar.
class GanttBar {
  /// Sol ofset kesri (0..1).
  final double left;

  /// Genişlik kesri (0..1).
  final double width;

  const GanttBar(this.left, this.width);
}

/// task durumunun kaba sınıfı — renk eşlemesi çizim katmanında yapılır, böylece
/// sınıflandırma mantığı (TR+EN anahtar eşleşmesi) saf ve test edilebilir kalır.
enum GanttStatusKind { done, inProgress, blocked, neutral }

/// PPM Gantt geometrisi + durum sınıflandırması (hepsi statik, saf).
class GanttGeometry {
  const GanttGeometry._();

  /// task başlangıcı: `created_at` bitişten (`due`) önceyse o kullanılır; değilse
  /// (created yok ya da bitişten sonra) bitiş − 3 gün varsayılır.
  static DateTime startOf(DateTime due, DateTime? created) {
    if (created != null && created.isBefore(due)) return created;
    return due.subtract(const Duration(days: 3));
  }

  /// Bar sol-ofset ve genişlik kesirlerini hesaplar (0..1).
  ///
  /// **Crash-güvenli:** sol ofset 1'e çok yakın olsa bile genişlik-clamp aralığı
  /// daima geçerli kalır (`lower <= upper`). Ham `.clamp(0.02, 1.0 - left)`
  /// kullanımı `left > 0.98` iken `lower > upper` olduğundan `ArgumentError`
  /// fırlatırdı; burada üst-sınır `max(0.02, 1.0 - left)` ile korunur.
  static GanttBar bar(
    DateTime start,
    DateTime due,
    DateTime minD,
    int totalDays,
  ) {
    final days = math.max(1, totalDays);
    final left = (start.difference(minD).inDays / days).clamp(0.0, 1.0);
    final maxWidth = math.max(0.02, 1.0 - left); // daima >= alt sınır (0.02)
    final width = (due.difference(start).inDays / days).clamp(0.02, maxWidth);
    return GanttBar(left, width);
  }

  /// Durum metnini kaba bir [GanttStatusKind]'e eşler (TR+EN, büyük/küçük harf
  /// duyarsız). Boş/bilinmeyen → [GanttStatusKind.neutral].
  static GanttStatusKind classifyStatus(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.contains('done') || s.contains('complete') || s.contains('tamam')) {
      return GanttStatusKind.done;
    }
    if (s.contains('progress') || s.contains('devam')) {
      return GanttStatusKind.inProgress;
    }
    if (s.contains('block') || s.contains('engel')) {
      return GanttStatusKind.blocked;
    }
    return GanttStatusKind.neutral;
  }
}
