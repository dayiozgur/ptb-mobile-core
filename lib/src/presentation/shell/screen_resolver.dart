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

  /// App domain çözümleyicisini kaydeder (yolu bilmiyorsa null döndürür).
  static void addResolver(Widget? Function(MenuItem item) resolver) {
    _resolvers.add(resolver);
  }

  /// Kayıtlı domain çözümleyicileri temizle (idempotent yeniden-kayıt için).
  static void reset() => _resolvers.clear();

  /// Bir menü öğesini mobil ekrana çöz.
  static Widget resolve(MenuItem item) {
    for (final r in _resolvers) {
      final w = r(item);
      if (w != null) return w;
    }
    final neutral = _neutral(item.path);
    if (neutral != null) return neutral;
    return ComingSoonScreen(
      titleKey: item.title,
      path: item.path,
      icon: item.icon,
    );
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
    // Generic workflow onay-inbox (leave-özel /workflow/approvals'tan ayrı).
    if (p == '/workflow/inbox' || p == '/approvals') {
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
