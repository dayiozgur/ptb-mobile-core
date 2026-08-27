import 'worklog_service.dart';

/// Burndown grafiğinin tek noktası: gün-indeksi, o gün-sonu **gerçek** kalan iş
/// ve aynı gün için **ideal** (doğrusal) kalan.
class BurndownPoint {
  final int dayIndex;
  final double remaining;
  final double ideal;

  const BurndownPoint({
    required this.dayIndex,
    required this.remaining,
    required this.ideal,
  });
}

/// **PPM ilerleme metrikleri — SAF hesap.** Girdi listeleri → metrik; RPC/UI'dan
/// bağımsız olduğu için kolay ve deterministik test edilir. (Sunucu tarafında
/// `fn_ppm_scope_burndown` / `fn_ppm_sprint_capacity` benzeri hesapların
/// istemci-tarafı, bağlantısız çalışan karşılığı.)
///
/// VARSAYIMLAR: "efor" saat cinsindendir (`WorklogEntry.hoursSpent`); "kapasite"
/// hikâye-puanı (story point) cinsindendir. Sprint/story alan adları belirsiz
/// olduğundan fonksiyonlar ham sayı listeleri (puan/saat) alır — çağıran ince-app
/// gerçek alanları buraya map eder.
class PpmMetrics {
  const PpmMetrics._();

  /// Toplam loglanan efor (saat). Null saatler 0 sayılır.
  static double totalLogged(Iterable<WorklogEntry> logs) =>
      logs.fold(0.0, (s, w) => s + (w.hoursSpent ?? 0));

  /// Kalan iş = `totalEstimate - loglanan`. Aşımda (negatif) 0'a kırpılır.
  static double remainingWork({
    required num totalEstimate,
    required Iterable<WorklogEntry> logs,
  }) {
    final r = totalEstimate.toDouble() - totalLogged(logs);
    return r < 0 ? 0.0 : r;
  }

  /// Tamamlanma oranı [0..1]. `totalEstimate <= 0` → 0.
  static double completionRatio({
    required num totalEstimate,
    required Iterable<WorklogEntry> logs,
  }) {
    final t = totalEstimate.toDouble();
    if (t <= 0) return 0.0;
    return (totalLogged(logs) / t).clamp(0.0, 1.0);
  }

  /// Ortalama hız (velocity) = kapanan story-puanı / sprint sayısı. Boş → 0.
  static double velocity(Iterable<num> completedPointsPerSprint) {
    final list = completedPointsPerSprint.toList();
    if (list.isEmpty) return 0.0;
    final sum = list.fold(0.0, (s, p) => s + p.toDouble());
    return sum / list.length;
  }

  /// Burndown serisi: [dailyRemaining] gün-sonu **gerçek** kalan iş; ideal çizgi
  /// [totalScope]'tan 0'a doğrusal iner. Boş girdi → boş liste. Tek gün →
  /// ideal 0 (kapanış günü).
  static List<BurndownPoint> burndown({
    required num totalScope,
    required List<num> dailyRemaining,
  }) {
    final n = dailyRemaining.length;
    if (n == 0) return const [];
    final scope = totalScope.toDouble();
    final step = n > 1 ? scope / (n - 1) : scope;
    return List.generate(n, (i) {
      final ideal = n > 1 ? scope - step * i : 0.0;
      return BurndownPoint(
        dayIndex: i,
        remaining: dailyRemaining[i].toDouble(),
        ideal: ideal < 0 ? 0.0 : ideal,
      );
    });
  }
}
