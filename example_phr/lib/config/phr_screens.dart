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
  if (p == '/hr/leave/approvals' || p == '/workflow/approvals') {
    return const LeaveApprovalsScreen();
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
  if (p == '/hr/kvkk') {
    return const KvkkScreen();
  }

  // Oryantasyon
  if (p == '/my-onboarding') {
    return const MyOnboardingScreen();
  }

  // PHR-ESS dışı yol → çekirdek çözer (entity-engine / ComingSoon)
  return null;
}

bool _done = false;

/// PHR domain ekranlarını çekirdek [ScreenResolver]'a kaydet (bir kez).
/// İlk shell render'ından ÖNCE `main()` içinde çağrılmalı.
void registerPhrScreens() {
  if (_done) return;
  ScreenResolver.addResolver(phrResolve);
  _done = true;
}
