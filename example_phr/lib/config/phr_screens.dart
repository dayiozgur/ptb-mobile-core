import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../features/ess/screens/hr_profile_screen.dart';
import '../features/ess/screens/kvkk_screen.dart';
import '../features/ess/screens/leave_approvals_screen.dart';
import '../features/ess/screens/leave_calendar_screen.dart';
import '../features/ess/screens/my_data_screen.dart';
import '../features/ess/screens/my_documents_screen.dart';
import '../features/ess/screens/my_goals_screen.dart';
import '../features/ess/screens/my_hr_screen.dart';
import '../features/ess/screens/my_leave_screen.dart';
import '../features/ess/screens/my_onboarding_screen.dart';
import '../features/ess/screens/my_payslips_screen.dart';
import '../features/ess/screens/my_pdks_screen.dart';
import '../features/ess/screens/my_reviews_screen.dart';
import '../features/ess/screens/review_queue_screen.dart';
import '../features/expense/scan_expense_screen.dart';
// PHR admin (yönetim) ekranları
import '../features/admin/screens/admin_arge_reports_screen.dart';
import '../features/admin/screens/admin_attendance_screen.dart';
import '../features/admin/screens/admin_competencies_screen.dart';
import '../features/admin/screens/admin_holidays_screen.dart';
import '../features/admin/screens/admin_hr_analytics_screen.dart';
import '../features/admin/screens/admin_kvkk_screen.dart';
import '../features/admin/screens/admin_leave_requests_screen.dart';
import '../features/admin/screens/admin_leave_types_screen.dart';
import '../features/admin/screens/admin_offboarding_screen.dart';
import '../features/admin/screens/admin_onboarding_screen.dart';
import '../features/admin/screens/admin_org_rollup_screen.dart';
import '../features/admin/screens/admin_organizations_screen.dart';
import '../features/admin/screens/admin_payroll_adjustments_screen.dart';
import '../features/admin/screens/admin_payroll_cost_summary_screen.dart';
import '../features/admin/screens/admin_payroll_parameters_screen.dart';
import '../features/admin/screens/admin_payroll_pushable_screen.dart';
import '../features/admin/screens/admin_payroll_runs_screen.dart';
import '../features/admin/screens/admin_payroll_salaries_screen.dart';
import '../features/admin/screens/admin_pdks_screen.dart';
import '../features/admin/screens/admin_pdks_shifts_screen.dart';
import '../features/admin/screens/admin_perf_cycles_screen.dart';
import '../features/admin/screens/admin_perf_reviews_screen.dart';
import '../features/admin/screens/admin_positions_screen.dart';
import '../features/admin/screens/admin_puantaj_approvals_screen.dart';
import '../features/admin/screens/admin_puantaj_screen.dart';
import '../features/admin/screens/admin_recruitment_candidates_screen.dart';
import '../features/admin/screens/admin_recruitment_pipeline_screen.dart';
import '../features/admin/screens/admin_recruitment_postings_screen.dart';
import '../features/admin/screens/admin_tesvik_rules_screen.dart';
import '../features/admin/screens/admin_tesvik_screen.dart';

/// PHR domain (çalışan-self-servis / ESS) ekran çözümleyicisi.
///
/// Menü yolunu PHR-ESS ekranına çevirir. Nötr yollar (settings/organization/
/// entity) çekirdek [ScreenResolver]'da çözülür; burada YALNIZ PHR-ESS yolları.
/// Yolu tanımıyorsa `null` → çekirdek entity/ComingSoon'a düşürür.
Widget? phrResolve(MenuItem item) {
  final path = item.path;
  if (path == null || path.isEmpty) return null;
  final p = path.toLowerCase();

  // İK Profilim (self-servis, salt-okuma) + İK Özetim hub
  if (p == '/hr/profile') {
    return const HrProfileScreen();
  }
  if (p == '/hr/my-hr') {
    return const MyHrScreen();
  }

  // İzin — bakiye / talep sekmeleri
  if (p == '/hr/leave/my-balance') {
    return const MyLeaveScreen(initialTab: 0);
  }
  if (p == '/hr/leave/my-requests') {
    return const MyLeaveScreen(initialTab: 1);
  }

  // İzin takvimi (self + takım, RLS-kapsamlı)
  if (p == '/hr/leave/calendar') {
    return const LeaveCalendarScreen();
  }

  // İzin onayları (+ genel workflow onayları)
  if (p == '/hr/leave/approvals') {
    return const LeaveApprovalsScreen();
  }
  // Generic workflow onay-gate'i (izin + masraf/avans + askıya-alınan her workflow)
  // — çekirdekte hazır ekran, yalnız route bağlanmamıştı.
  if (p == '/workflow/approvals') {
    return const ApprovalsInboxScreen();
  }

  // Bordro
  if (p == '/hr/payroll/my-payslips') {
    return const MyPayslipsScreen();
  }

  // Puantaj (PDKS)
  if (p == '/hr/pdks') {
    return const MyPdksScreen();
  }

  // Performans self-servis — hedefler / değerlendirmeler (salt-okuma)
  // DB menü (platform_menu_items, phr-self grubu) yollarıyla birebir.
  if (p == '/hr/performance/my-goals') {
    return const MyGoalsScreen();
  }
  if (p == '/hr/performance/my-reviews') {
    return const MyReviewsScreen();
  }
  // Değerlendirme kuyruğu (yönetici — salt-okuma v1)
  if (p == '/hr/performance/review-queue') {
    return const ReviewQueueScreen();
  }

  // Belgelerim + Verilerim (KVKK) + KVKK onamları
  if (p == '/hr/my-documents') {
    return const MyDocumentsScreen();
  }
  if (p == '/my-data') {
    return const MyDataScreen();
  }
  if (p == '/hr/expense/scan') {
    return const ScanExpenseScreen();
  }
  if (p == '/hr/kvkk') {
    return const KvkkScreen();
  }

  // Oryantasyon
  if (p == '/my-onboarding') {
    return const MyOnboardingScreen();
  }

  // ============================================================
  // PHR ADMIN (yönetim) — salt-okuma viewer'lar (v1). Tüm eşleşme
  // exact `==` olduğundan alt-yol/üst-yol gölgelemesi YOK.
  // ============================================================
  // İzin yönetimi
  if (p == '/admin/leave/requests') return const AdminLeaveRequestsScreen();
  if (p == '/admin/leave/types') return const AdminLeaveTypesScreen();
  if (p == '/admin/leave/holidays') return const AdminHolidaysScreen();
  // Performans yönetimi
  if (p == '/admin/performance/cycles') return const AdminPerfCyclesScreen();
  if (p == '/admin/performance/reviews') return const AdminPerfReviewsScreen();
  if (p == '/admin/competencies') return const AdminCompetenciesScreen();
  // Bordro yönetimi
  if (p == '/admin/payroll/runs') return const AdminPayrollRunsScreen();
  if (p == '/admin/payroll/salaries') return const AdminPayrollSalariesScreen();
  if (p == '/admin/payroll/parameters') {
    return const AdminPayrollParametersScreen();
  }
  if (p == '/admin/payroll/adjustments') {
    return const AdminPayrollAdjustmentsScreen();
  }
  if (p == '/admin/payroll/pushable') {
    return const AdminPayrollPushableScreen();
  }
  if (p == '/admin/payroll/cost-summary') {
    return const AdminPayrollCostSummaryScreen();
  }
  // Org yapısı + onboarding/offboarding
  if (p == '/admin/positions') return const AdminPositionsScreen();
  if (p == '/admin/organizations') return const AdminOrganizationsScreen();
  if (p == '/admin/org-rollup') return const AdminOrgRollupScreen();
  if (p == '/admin/onboarding') return const AdminOnboardingScreen();
  if (p == '/admin/offboarding') return const AdminOffboardingScreen();
  // PDKS / Puantaj / Devam
  if (p == '/admin/pdks') return const AdminPdksScreen();
  if (p == '/admin/pdks/shifts') return const AdminPdksShiftsScreen();
  if (p == '/admin/attendance') return const AdminAttendanceScreen();
  if (p == '/admin/puantaj') return const AdminPuantajScreen();
  if (p == '/admin/puantaj/approvals') return const AdminPuantajApprovalsScreen();
  // İşe alım (ATS) + İK analitik
  if (p == '/admin/recruitment/postings') {
    return const AdminRecruitmentPostingsScreen();
  }
  if (p == '/admin/recruitment/candidates') {
    return const AdminRecruitmentCandidatesScreen();
  }
  if (p == '/admin/recruitment/pipeline') {
    return const AdminRecruitmentPipelineScreen();
  }
  if (p == '/admin/hr-analytics') return const AdminHrAnalyticsScreen();
  // Teşvik / Ar-Ge / KVKK (org-geneli) yönetim
  if (p == '/admin/tesvik/rules') return const AdminTesvikRulesScreen();
  if (p == '/admin/tesvik') return const AdminTesvikScreen();
  if (p == '/admin/arge-reports') return const AdminArgeReportsScreen();
  if (p == '/admin/kvkk') return const AdminKvkkScreen();

  // PHR-ESS dışı yol → çekirdek çözer (entity-engine / ComingSoon)
  return null;
}

bool _done = false;

/// PHR domain ekranlarını çekirdek [ScreenResolver]'a kaydet (bir kez).
/// İlk shell render'ından ÖNCE `main()` içinde çağrılmalı.
void registerPhrScreens() {
  if (_done) return;
  ScreenResolver.addResolver(phrResolve);
  registerMicrosoftFilesSection(); // OneDrive/SharePoint dosya kartı (tüm tipler)
  _done = true;
}
