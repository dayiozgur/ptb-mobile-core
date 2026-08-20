import 'package:flutter/material.dart';

import '../../core/menu/menu_item.dart';
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
    if (p.startsWith('/settings')) return const SettingsScreen();
    if (p.startsWith('/organizations') || p.startsWith('/organization')) {
      return const OrganizationSelectorScreen();
    }
    final t = _parseEntityType(path);
    if (t != null && t.isNotEmpty) return EntityListScreen(typeCode: t);
    return null;
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
