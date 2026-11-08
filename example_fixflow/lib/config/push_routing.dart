import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'fixflow_app_screens.dart';

/// go_router'ın sahip olduğu üst-seviye shell rotaları — bunlar `context.go`
/// ile, diğer tüm yollar [ScreenResolver] + kök Navigator push ile açılır.
/// (Çekirdek varsayılanı ile aynı; [DeepLinkService.init] ile [InAppRoute]'a
/// kaydedilir.)
const Set<String> kFixflowShellRoutes = InAppRoute.kDefaultShellRoutes;

/// Push payload'ından (APNs userInfo → [PushNotificationData.data]) uygulama-içi
/// yolu çıkar.
///
/// Öncelik: `action_url` (notifications satırının hedefi, ör.
/// `/fixflow/tickets/<id>`) → `actionUrl` / `route` / `deep_link` / `screen`
/// (çekirdek [InAppRoute.fromPayload]) → yoksa `entityType` ticket ise
/// `/fixflow/tickets/<entityId>`. Tam URL (`https://app.fixflow.protoolbag.com/...`)
/// ise yalnız yol+query alınır; yabancı host → null. Başında `/` yoksa eklenir.
String? fixflowNotificationRoute(Map<String, dynamic>? data) {
  if (data == null) return null;
  for (final key in InAppRoute.kPayloadRouteKeys) {
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
String? normalizeFixflowRoute(String raw) =>
    InAppRoute.normalize(raw, appHosts: const {kFixflowAppLinkHost});

/// Yol bir go_router shell rotası mı (query hariç)?
bool isFixflowShellRoute(String route) =>
    kFixflowShellRoutes.contains(route.split('?').first);

/// Shell dışı bir yolun ekranı (domain → nötr çekirdek → ComingSoon).
Widget fixflowScreenForRoute(String route) => InAppRoute.screenFor(route);

/// Bildirim tap'ini aç: shell rotası → `go`, diğerleri → kök Navigator push
/// (ekranı olmayan yol ComingSoon'a düşer — önceki davranış korunur).
void openFixflowRoute(String route, GlobalKey<NavigatorState> navigatorKey) {
  InAppRoute.open(route, navigatorKey: navigatorKey);
}
