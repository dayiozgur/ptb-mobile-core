import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'fixflow_app_screens.dart';

/// go_router'ın sahip olduğu üst-seviye shell rotaları — bunlar `context.go`
/// ile, diğer tüm yollar [ScreenResolver] + kök Navigator push ile açılır.
const Set<String> kFixflowShellRoutes = {
  '/login',
  '/request-access',
  '/tenant-select',
  '/organizations',
  '/main',
  '/dashboard',
  '/portal',
  '/settings',
};

/// Push payload'ından (APNs userInfo → [PushNotificationData.data]) uygulama-içi
/// yolu çıkar.
///
/// Öncelik: `action_url` (notifications satırının hedefi, ör.
/// `/fixflow/tickets/<id>`) → `route` / `deep_link` / `screen` → yoksa
/// `entityType` ticket ise `/fixflow/tickets/<entityId>`. Tam URL
/// (`https://app.fixflow.protoolbag.com/...`) ise yalnız yol+query alınır;
/// yabancı host → null. Başında `/` yoksa eklenir.
String? fixflowNotificationRoute(Map<String, dynamic>? data) {
  if (data == null) return null;
  for (final key in const [
    'action_url',
    'actionUrl',
    'route',
    'deep_link',
    'screen',
  ]) {
    final v = data[key];
    if (v is String && v.trim().isNotEmpty) {
      return normalizeFixflowRoute(v.trim());
    }
  }
  final type = (data['entityType'] ?? data['entity_type'])?.toString();
  final id = (data['entityId'] ?? data['entity_id'])?.toString();
  if (id != null && id.isNotEmpty && (type == 'ticket' || type == 'tickets')) {
    return '/fixflow/tickets/$id';
  }
  return null;
}

/// Ham bağlantıyı uygulama-içi yola çevir (bkz. [fixflowNotificationRoute]).
String? normalizeFixflowRoute(String raw) {
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.toLowerCase() != kFixflowAppLinkHost) {
      return null;
    }
    final path = uri.path.isEmpty ? '/' : uri.path;
    return uri.hasQuery ? '$path?${uri.query}' : path;
  }
  return raw.startsWith('/') ? raw : '/$raw';
}

/// Yol bir go_router shell rotası mı (query hariç)?
bool isFixflowShellRoute(String route) =>
    kFixflowShellRoutes.contains(route.split('?').first);

/// Shell dışı bir yolun ekranı (domain → nötr çekirdek → ComingSoon).
Widget fixflowScreenForRoute(String route) =>
    ScreenResolver.resolve(MenuItem(itemKey: '', title: '', path: route));

/// Bildirim tap'ini aç: shell rotası → `go`, diğerleri → kök Navigator push.
void openFixflowRoute(String route, GlobalKey<NavigatorState> navigatorKey) {
  if (route.isEmpty || route == '/') return;
  if (isFixflowShellRoute(route)) {
    navigatorKey.currentContext?.go(route);
    return;
  }
  navigatorKey.currentState?.push(
    MaterialPageRoute<void>(builder: (_) => fixflowScreenForRoute(route)),
  );
}
