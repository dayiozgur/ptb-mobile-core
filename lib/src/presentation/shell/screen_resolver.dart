import 'package:flutter/material.dart';

import '../../core/menu/menu_item.dart';
import '../page_viewer/page_viewer_screen.dart';
import '../report_viewer/report_viewer_screen.dart';
import 'announcements/announcement_detail_screen.dart';
import 'announcements/announcements_list_screen.dart';
import 'orgchart/org_chart_screen.dart';
import 'admin/audit_log_screen.dart';
import 'admin/bug_reports_screen.dart';
import 'admin/integrations_screen.dart';
import 'admin/notifications_hub_screen.dart';
import 'notifications/notifications_screen.dart';
import 'admin/roles_screen.dart';
import 'admin/subscription_screen.dart';
import 'admin/menu_builder_screen.dart';
import 'admin/staff_roster_screen.dart';
import 'dashboard/personal_dashboard_screen.dart';
import 'admin/user_management_screen.dart';
import 'settings/security_screen.dart';
import 'workflow/approvals_inbox_screen.dart';
import 'account/account_hub_screen.dart';
import 'coming_soon_screen.dart';
import 'entities/entity_list_screen.dart';
import 'mailbox/ms_mailbox_screen.dart';
import 'organization/organization_selector_screen.dart';
import 'settings/settings_screen.dart';

/// Menü yolu (`platform_menu_items.path`) → mobil ekran çözümleyici.
///
/// **Nötr çekirdek** yalnız platform-bağımsız ekranları bilir: settings,
/// organization seçimi ve **entity-engine** (`/…/entities/<type>` veya
/// `?type=<type>`). Domain ekranları (PMS: alarm/controller…, PHR: ESS…)
/// her app tarafından [addResolver] ile KAYDEDİLİR — böylece çekirdek
/// platform-nötr kalır. Çözülemeyen yol → [ComingSoonScreen] (asla 404/crash).
///
/// ÖNEMLİ: app kendi [addResolver] çağrısını ilk shell render'ından ÖNCE
/// yapmalı (aksi halde domain yolları [hasScreen]=false → menüden budanır).
class ScreenResolver {
  ScreenResolver._();

  static final List<Widget? Function(MenuItem item)> _resolvers = [];

  /// Mobilde bilinçli olarak GİZLENEN yollar (normalize: küçük harf, query'siz,
  /// sondaki `/` yok). Nötr yedekten (ör. `/admin*` → ComingSoon) ÖNCE
  /// bakılır: [hasScreen] false döner → menüden budanır.
  static final Set<String> _hidden = {};

  /// App domain çözümleyicisini kaydeder (yolu bilmiyorsa null döndürür).
  static void addResolver(Widget? Function(MenuItem item) resolver) {
    _resolvers.add(resolver);
  }

  /// Domain çözümleyicinin "mobilde ekranı yok, menüde gösterme" dediği
  /// yolları kaydet (ör. web'e özgü yapılandırma ekranları). Kayıtlı bir
  /// çözümleyici yolu yine de çözerse o kazanır; gizleme yalnız nötr yedeği
  /// (ComingSoon) bastırır. Tam-yol eşleşmesi (alt yollar etkilenmez).
  static void hideOnMobile(Iterable<String> paths) {
    _hidden.addAll(paths.map(_normalize).where((p) => p.isNotEmpty));
  }

  /// Yol [hideOnMobile] ile gizlenmiş mi?
  static bool isHiddenOnMobile(String? path) =>
      path != null && path.isNotEmpty && _hidden.contains(_normalize(path));

  static String _normalize(String path) {
    var p = path.split('?').first.trim().toLowerCase();
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  /// Kayıtlı domain çözümleyicileri ve gizli yolları temizle (idempotent
  /// yeniden-kayıt için).
  static void reset() {
    _resolvers.clear();
    _hidden.clear();
  }

  /// Bir menü öğesini mobil ekrana çöz.
  ///
  /// Sıra: domain çözümleyiciler → (gizli değilse) nötr çekirdek →
  /// yalnız-doğrudan ekranlar ([_directOnly]) → dürüst yedek. Yedek asla
  /// 404/crash/boş sayfa değildir: web'e özgü olduğu bilinen yol
  /// ([isWebOnly]) "web uygulamasında aç" ekranına, diğerleri "yakında"
  /// ekranına düşer (ikisi de — web adresi biliniyorsa — web'de açma düğmesi
  /// taşır).
  static Widget resolve(MenuItem item) {
    for (final r in _resolvers) {
      final w = r(item);
      if (w != null) return w;
    }
    // Gizli yol menüde görünmez; yine de açılırsa (eski bağlantı / derin
    // bağlantı) nötr yedeğe düşmez.
    final hidden = isHiddenOnMobile(item.path);
    final neutral = hidden ? null : _neutral(item.path);
    if (neutral != null) return neutral;
    final direct = hidden ? null : _directOnly(item.path);
    if (direct != null) return direct;
    return ComingSoonScreen(
      titleKey: _fallbackTitle(item),
      path: item.path,
      icon: item.icon,
      webOnly: isWebOnly(item.path),
    );
  }

  /// "Bu sayfa web uygulamasında" ekranı — uygulamaya düşen ama mobil ekranı
  /// olmayan bir bağlantı için ([InAppRoute.openWebOnly]).
  static Widget webOnlyScreen(String path) {
    final item = MenuItem(itemKey: '', title: '', path: path);
    return ComingSoonScreen(
      titleKey: _fallbackTitle(item),
      path: path,
      webOnly: true,
    );
  }

  /// Yedek ekran başlığı: menü öğesinin kendi başlığı; yoksa bilinen web
  /// sayfasının anahtarı; o da yoksa genel başlık.
  static String _fallbackTitle(MenuItem item) {
    if (item.title.isNotEmpty) return item.title;
    final p = _normalize(item.path ?? '');
    if (p == '/report/my' || p.startsWith('/report/my/') || p == '/reports/my') {
      return 'breadcrumb.my_reports';
    }
    if (p == '/m365/mail') return 'nav.m365_mail';
    if (p == '/m365/calendar') return 'nav.m365_calendar';
    if (p == '/m365/planner') return 'nav.m365_planner';
    if (p == '/files') return 'files.title';
    return 'common.web_only.title';
  }

  /// Web'e özgü olduğu BİLİNEN yol mu? (mobil ekranı bilinçli olarak yok)
  ///
  ///  * app'in [hideOnMobile] ile gizledikleri (ör. PEM kurulum sihirbazı
  ///    `/admin/energy/setup`),
  ///  * kişisel raporlar `/report/my[/…]` — rapor OLUŞTURUCU; `/report/<kod>`
  ///    görüntüleyicisinin bir rapor kodu DEĞİL,
  ///  * Microsoft 365 merkez sayfaları `/m365/*` (posta hariç: [_directOnly])
  ///    ve web dosya yöneticisi `/files`.
  static bool isWebOnly(String? path) {
    if (path == null || path.isEmpty) return false;
    if (isHiddenOnMobile(path)) return true;
    final p = _normalize(path);
    if (_isPersonalReports(p)) return true;
    if (p == '/m365/mail') return false;
    if (p == '/m365' || p.startsWith('/m365/')) return true;
    if (p == '/files') return true;
    return false;
  }

  /// `/report/my`, `/report/my/new`, `/report/my/<id>/edit`, `/reports/my`.
  static bool _isPersonalReports(String p) =>
      p == '/report/my' ||
      p.startsWith('/report/my/') ||
      p == '/reports/my' ||
      p.startsWith('/reports/my/');

  /// Yalnız DOĞRUDAN açılabilen ekranlar: bağlantıyla (derin bağlantı,
  /// bildirim) ulaşılır ama [hasScreen] false kalır → mobil menüye GİRMEZ.
  ///
  /// `/m365/mail` (web'in platform-nötr Outlook sayfası; menü satırı
  /// `requires_capability = mail.read` taşır): mobil karşılığı çekirdekteki
  /// [MsMailboxScreen]. Menüde gösterilmez — mobilde posta kutusuna Microsoft
  /// 365 ekranından girilir (CRM'in `/crm/mailbox` satırıyla aynı karar) —
  /// ama yol açılırsa boş/“yakında” yerine gerçek ekran gelir. Ekran yeteneği
  /// kendisi denetler: bağlantı yoksa "bağlı değil", `Mail.Read` izni yoksa
  /// "izin eksik" durumunu gösterir (asla boş liste / hata penceresi).
  static Widget? _directOnly(String? path) {
    if (path == null || path.isEmpty) return null;
    final p = _normalize(path);
    if (p == '/m365/mail') return const MsMailboxScreen();
    return null;
  }

  /// Yol uygulama içinde AÇILABİLİR mi? ([hasScreen] ∪ yalnız-doğrudan
  /// ekranlar). Menü budaması [hasScreen] kullanır; bağlantı açma bunu.
  static bool canOpen(String? path) {
    if (hasScreen(path)) return true;
    if (path == null || path.isEmpty || isHiddenOnMobile(path)) return false;
    return _directOnly(path) != null;
  }

  /// Nötr, platform-bağımsız ekranlar (settings / organization / entity).
  static Widget? _neutral(String? path) {
    if (path == null || path.isEmpty) return null;
    final p = path.toLowerCase();
    if (p.startsWith('/account/security') || p.startsWith('/security')) {
      return const SecurityScreen();
    }
    // Hesabım hub (abonelik/krediler/faturalar/kullanım/güvenlik).
    if (p == '/account' || p == '/account/overview' || p == '/hesabim') {
      return const AccountHubScreen(embedded: true);
    }
    if (p.startsWith('/settings')) return const SettingsScreen();
    if (p.startsWith('/organizations') || p.startsWith('/organization')) {
      return const OrganizationSelectorScreen();
    }
    // Generic workflow onay-inbox. `/workflow/approvals` = PMS/CRM/FixFlow DB
    // menülerinin onay öğesi (canlı platform_menu_items yolu); domain resolver
    // (ör. PHR izin onayı) bu yolu kendisi kaydederse ÖNCE o kazanır.
    // `/fixflow/approvals` FixFlow modülünün kendi kaydıdır — burada YOK.
    // Birleşik onay satırı (web'in bir sonraki sürümü): yolu kesinleşene dek
    // olası adların hepsi aynı gelen kutusuna çözülür.
    final a = _normalize(path);
    if (a == '/workflow/inbox' ||
        a == '/workflow/approvals' ||
        a == '/approvals' ||
        a == '/approvals/inbox' ||
        a == '/my-approvals' ||
        a == '/workflow/my-approvals') {
      return const ApprovalsInboxScreen();
    }
    // Kişisel pano (widget ekle/çıkar/sırala). /my-space bottom-nav tab'i ayrı.
    if (p == '/dashboard/personal' ||
        p == '/my-dashboard' ||
        p == '/panom') {
      return const PersonalDashboardScreen();
    }
    final t = _parseEntityType(path);
    if (t != null && t.isNotEmpty) return EntityListScreen(typeCode: t);
    // Kişisel raporlar (`/report/my[/…]`) web'in rapor OLUŞTURUCUSUDUR —
    // "my" bir rapor kodu değildir; görüntüleyiciye düşürme (bkz. [isWebOnly]).
    if (_isPersonalReports(_normalize(path))) return null;
    // Report viewer (db-driven analitik/dashboard) — /report/<code> | /reports/<code>
    if (p.startsWith('/report/') || p.startsWith('/reports/')) {
      final code = _lastSegment(path);
      if (code != null) return ReportViewerScreen(reportCode: code);
    }
    // Page viewer (db-driven sayfa) — /page/<code> | /pages/<code>
    if (p.startsWith('/page/') || p.startsWith('/pages/')) {
      final code = _lastSegment(path);
      if (code != null) return PageViewerScreen(pageCode: code);
    }
    // Duyurular — detay (/announcements/<id>) liste (/announcements)'ten ÖNCE.
    if (p.startsWith('/announcements/')) {
      final id = _lastSegment(path);
      if (id != null) return AnnouncementDetailScreen(id: id);
    }
    if (p == '/announcements' || p == '/duyurular') {
      return const AnnouncementsListScreen();
    }
    // Bildirim gelen-kutusu — /notifications | /bildirimler (push deep-link
    // hedefi; şimdiye kadar yalnız shell zil ikonundan imperatif açılıyordu).
    if (p == '/notifications' || p == '/bildirimler') {
      return const NotificationsScreen();
    }
    // Admin/yönetim yolları — mobilde henüz özel ekran yok, ama menüde
    // GÖRÜNMELİ (aksi halde _pruneToScreens admin grubunu tümden gizliyordu →
    // admin kullanıcı admin menülerini göremiyordu). ComingSoon'a çöz: menüde
    // yer alır + dokununca "yakında" gösterir (domain resolver ileride gerçek
    // ekran verirse onu kullanır — bu yalnız nötr fallback).
    // Gerçek admin ekranları (spesifik yollar generic /admin fallback'inden ÖNCE).
    if (p.startsWith('/admin/user-management') ||
        p.startsWith('/admin/users')) {
      return const UserManagementScreen();
    }
    // Organizasyon şeması (org + departman ağacı — genişletilebilir chart).
    if (p.startsWith('/admin/org-chart') ||
        p.startsWith('/admin/departments') ||
        p == '/org-chart') {
      return const OrgChartScreen();
    }
    if (p.startsWith('/admin/staff-roster')) {
      return const StaffRosterScreen();
    }
    if (p.startsWith('/admin/roles') || p.startsWith('/admin/rbac')) {
      return const RolesScreen();
    }
    if (p.startsWith('/admin/bug-reports')) {
      return const BugReportsScreen();
    }
    if (p.startsWith('/admin/menu-builder')) {
      return const MenuBuilderScreen();
    }
    if (p.startsWith('/admin/integrations')) {
      return const IntegrationsScreen();
    }
    if (p.startsWith('/admin/audit-log') || p.startsWith('/admin/audit')) {
      return const AuditLogScreen();
    }
    if (p.startsWith('/admin/notifications-hub')) {
      return const NotificationsHubScreen();
    }
    if (p.startsWith('/admin/subscription') ||
        p.startsWith('/account/subscription')) {
      return const SubscriptionScreen();
    }
    // Diğer admin yolları — henüz özel ekran yok → ComingSoon (menüde görünür).
    if (p.startsWith('/admin')) {
      return ComingSoonScreen(
        titleKey: 'nav.admin',
        path: path,
        icon: 'bi-gear',
      );
    }
    return null;
  }

  /// Yolun (query'siz) son boş-olmayan segmenti.
  static String? _lastSegment(String path) {
    final noQuery = path.split('?').first;
    final seg = noQuery.split('/').where((s) => s.isNotEmpty).toList();
    return seg.isEmpty ? null : seg.last;
  }

  /// Bir yolun mobil karşılığı VAR MI? (domain resolver'lar + nötr çekirdek)
  static bool hasScreen(String? path) {
    if (path == null || path.isEmpty) return false;
    final item = MenuItem(itemKey: '', title: '', path: path);
    for (final r in _resolvers) {
      if (r(item) != null) return true;
    }
    if (isHiddenOnMobile(path)) return false;
    return _neutral(path) != null;
  }

  /// Yoldan entity tipini çıkar: `.../entities/<type>` ya da `?type=<type>`.
  /// Bulunamazsa null (entity yolu değil).
  static String? _parseEntityType(String path) {
    // Query formu: `?type=<type>`
    final uri = Uri.tryParse(path);
    final queryType = uri?.queryParameters['type'];
    if (queryType != null && queryType.isNotEmpty) return queryType;

    // Path formu: `.../entities/<type>`
    final noQuery = path.split('?').first;
    const marker = '/entities/';
    final idx = noQuery.toLowerCase().indexOf(marker);
    if (idx >= 0) {
      final rest = noQuery.substring(idx + marker.length);
      final seg = rest.split('/').firstWhere(
            (s) => s.isNotEmpty,
            orElse: () => '',
          );
      if (seg.isNotEmpty) return seg;
    }
    return null;
  }
}
