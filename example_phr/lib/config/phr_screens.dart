import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../features/ess/screens/leave_approvals_screen.dart';
import '../features/ess/screens/my_leave_screen.dart';
import '../features/ess/screens/my_onboarding_screen.dart';
import '../features/ess/screens/my_payslips_screen.dart';
import '../features/ess/screens/my_pdks_screen.dart';

/// PHR domain (çalışan-self-servis / ESS) ekran çözümleyicisi.
///
/// Menü yolunu PHR-ESS ekranına çevirir. Nötr yollar (settings/organization/
/// entity) çekirdek [ScreenResolver]'da çözülür; burada YALNIZ PHR-ESS yolları.
/// Yolu tanımıyorsa `null` → çekirdek entity/ComingSoon'a düşürür.
Widget? phrResolve(MenuItem item) {
  final path = item.path;
  if (path == null || path.isEmpty) return null;
  final p = path.toLowerCase();

  // İzin — bakiye / talep sekmeleri
  if (p == '/hr/leave/my-balance') {
    return const MyLeaveScreen(initialTab: 0);
  }
  if (p == '/hr/leave/my-requests') {
    return const MyLeaveScreen(initialTab: 1);
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
