import 'payslip.dart';

/// "İK Özetim" (ESS hub) toplu görünüm modeli.
///
/// Web `MyHrHubComponent` tek RPC (`fn_hr_my_ess_summary`) ile beslenir; mobilde
/// aynı bilgi mevcut ESS servis metodlarından (leaveBalance / myLeaveRequests /
/// myPayslips / myOnboardingTasks) toplanır. Her parça bağımsız çözülür, biri
/// başarısız olsa da özet nazikçe (0 / null) döner.
class HrSummary {
  /// Tüm izin türleri için kalan gün toplamı.
  final num leaveRemainingDays;

  /// Kullanıcının bekleyen (`pending`) izin talebi sayısı.
  final int pendingLeaveRequests;

  /// En güncel bordro (dönem gösterimi için); yoksa `null`.
  final Payslip? latestPayslip;

  /// Toplam oryantasyon görevi sayısı.
  final int onboardingTotal;

  /// Tamamlanmış oryantasyon görevi sayısı.
  final int onboardingDone;

  const HrSummary({
    this.leaveRemainingDays = 0,
    this.pendingLeaveRequests = 0,
    this.latestPayslip,
    this.onboardingTotal = 0,
    this.onboardingDone = 0,
  });

  /// Oryantasyon ilerleme yüzdesi (0–100). Görev yoksa 0.
  int get onboardingProgressPct {
    if (onboardingTotal <= 0) return 0;
    return ((onboardingDone / onboardingTotal) * 100).round();
  }

  /// Hiç oryantasyon görevi atanmış mı?
  bool get hasOnboarding => onboardingTotal > 0;
}
