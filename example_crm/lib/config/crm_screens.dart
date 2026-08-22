import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

/// CRM domain ekran çözümleyicisi.
///
/// CRM'in çoğu tipi (deal/lead/activity/proposal/product) çekirdek entity-engine
/// ile otomatik gelir; nötr yollar (settings/organization/report/page) çekirdek
/// [ScreenResolver]'da çözülür. Burada YALNIZ CRM-özel domain yolları çözülür
/// (contacts, my-work — Faz-3'te eklenir). Tanınmayan yol → `null` → çekirdek
/// entity/ComingSoon'a düşürür.
Widget? crmResolve(MenuItem item) {
  final path = item.path;
  if (path == null || path.isEmpty) return null;
  // final p = path.toLowerCase();
  // Faz-3: /crm/contacts → ContactsListScreen; /crm/my-work → WorkInboxScreen.
  return null;
}

bool _done = false;

/// CRM domain ekranlarını çekirdek [ScreenResolver]'a kaydet (bir kez).
/// İlk shell render'ından ÖNCE `main()` içinde çağrılmalı.
void registerCrmScreens() {
  if (_done) return;
  ScreenResolver.addResolver(crmResolve);
  _done = true;
}
