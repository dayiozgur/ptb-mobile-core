/// İK analitik özeti — yönetim panosunun (`/admin/hr-analytics`) KPI kartlarını
/// besleyen, servis katmanında toparlanmış birkaç basit metrik.
///
/// Web PHR İK-analitik panosunun (`HrAnalyticsService`) mobil v1 salt-okuma
/// karşılığı; ağır dimensional/zaman-serisi RPC'leri yerine dört ana KPI'ı
/// (headcount, açık pozisyon, işe alım aktivitesi, izin) doğrudan sayımla
/// üretir. [turnoverRate] mevcutsa `fn_hr_headcount_trend` (trailing 12 ay)
/// çıkışlarından türetilir; RPC başarısız olursa `null` (kart "—" gösterir).
class HrAnalyticsSnapshot {
  /// Toplam personel (`staffs`).
  final int totalHeadcount;

  /// Aktif personel (`staffs.active = true`).
  final int activeHeadcount;

  /// Açık ilan sayısı (`job_postings.status = 'open'`).
  final int openPositions;

  /// Toplam başvuru sayısı (`job_applications`) — işe alım aktivitesi.
  final int totalApplications;

  /// Bekleyen izin talebi sayısı (`leave_requests.status = 'pending'`).
  final int pendingLeave;

  /// İşten ayrılma oranı % (trailing 12 ay çıkış / aktif headcount) —
  /// `fn_hr_headcount_trend`'den; hesaplanamazsa `null`.
  final double? turnoverRate;

  const HrAnalyticsSnapshot({
    this.totalHeadcount = 0,
    this.activeHeadcount = 0,
    this.openPositions = 0,
    this.totalApplications = 0,
    this.pendingLeave = 0,
    this.turnoverRate,
  });

  static const HrAnalyticsSnapshot empty = HrAnalyticsSnapshot();
}
