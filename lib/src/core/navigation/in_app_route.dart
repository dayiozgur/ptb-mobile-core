import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../menu/menu_item.dart';
import '../utils/logger.dart';
import '../../presentation/shell/screen_resolver.dart';

/// Uygulama-içi yol çözümü + açma — push tap'i, uygulama-içi bildirim listesi
/// ve deep link aynı kuralı kullanır.
///
/// Kural:
///  * Ham bağlantı ([normalize]): `/fixflow/tickets/<id>` gibi göreli yol
///    olduğu gibi (başında `/` yoksa eklenir); tam URL
///    (`https://app.<code>.protoolbag.com/...`) yalnız host [appHosts]
///    içindeyse yol+query'ye indirgenir, aksi halde null (yabancı host).
///  * Açma ([open]): go_router shell rotası ([shellRoutes]) → `go`, diğer
///    yollar [ScreenResolver] ile çözülüp kök navigator'a push edilir.
///
/// App, başlangıçta [configure] ile kendi host/shell rotalarını verir
/// ([DeepLinkService.init] bunu otomatik yapar).
class InAppRoute {
  InAppRoute._();

  /// go_router'ın sahip olduğu varsayılan üst-seviye shell rotaları.
  static const Set<String> kDefaultShellRoutes = {
    '/login',
    '/request-access',
    '/tenant-select',
    '/organizations',
    '/main',
    '/dashboard',
    '/portal',
    '/settings',
  };

  /// Bildirim / push payload'ında hedef yolu taşıyan anahtarlar (öncelik
  /// sırasıyla). `action_url` = `notifications.action_url`.
  static const List<String> kPayloadRouteKeys = [
    'action_url',
    'actionUrl',
    'route',
    'deep_link',
    'screen',
  ];

  static Set<String> _shellRoutes = kDefaultShellRoutes;
  static Set<String> _appHosts = const {};

  /// Etkin shell rotaları.
  static Set<String> get shellRoutes => _shellRoutes;

  /// Uygulamanın sahip olduğu https host'ları (küçük harf).
  static Set<String> get appHosts => _appHosts;

  /// App yapılandırması. Verilmeyen alan mevcut değerini korur.
  static void configure({Set<String>? shellRoutes, Set<String>? appHosts}) {
    if (shellRoutes != null) _shellRoutes = Set.unmodifiable(shellRoutes);
    if (appHosts != null) {
      _appHosts = Set.unmodifiable(appHosts.map((h) => h.toLowerCase()));
    }
  }

  /// Varsayılanlara dön (testler için).
  static void resetConfig() {
    _shellRoutes = kDefaultShellRoutes;
    _appHosts = const {};
  }

  /// Ham bağlantıyı uygulama-içi yola çevir; çevrilemezse null.
  static String? normalize(String? raw, {Set<String>? appHosts}) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;
    final lower = v.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final hosts = appHosts ?? _appHosts;
      final uri = Uri.tryParse(v);
      if (uri == null || !hosts.contains(uri.host.toLowerCase())) return null;
      final path = uri.path.isEmpty ? '/' : uri.path;
      return uri.hasQuery ? '$path?${uri.query}' : path;
    }
    return v.startsWith('/') ? v : '/$v';
  }

  /// Payload'dan ([kPayloadRouteKeys] sırasıyla) ilk dolu değeri yola çevir.
  static String? fromPayload(Map<String, dynamic>? data,
      {Set<String>? appHosts}) {
    if (data == null) return null;
    for (final key in kPayloadRouteKeys) {
      final v = data[key];
      if (v is String && v.trim().isNotEmpty) {
        return normalize(v, appHosts: appHosts);
      }
    }
    return null;
  }

  /// Yol bir go_router shell rotası mı (query hariç)?
  static bool isShellRoute(String route) =>
      route.startsWith('/') && _shellRoutes.contains(route.split('?').first);

  /// Shell dışı bir yolun ekranı (domain → nötr çekirdek → ComingSoon).
  static Widget screenFor(String route) =>
      ScreenResolver.resolve(MenuItem(itemKey: '', title: '', path: route));

  /// Yolu aç. [navigatorKey] (kök navigator) ya da [context] verilir.
  ///
  /// [requireScreen] true ise [ScreenResolver.hasScreen] false olan yol açılmaz
  /// (ComingSoon'a düşmek yerine no-op). Navigasyon yapıldıysa true döner.
  static bool open(
    String route, {
    GlobalKey<NavigatorState>? navigatorKey,
    BuildContext? context,
    bool requireScreen = false,
  }) {
    if (route.isEmpty || route == '/') return false;
    final ctx = navigatorKey?.currentContext ?? context;

    if (isShellRoute(route)) {
      final router = ctx == null ? null : GoRouter.maybeOf(ctx);
      if (router == null) {
        Logger.warning('[in-app-route] no router for shell route: $route');
        return false;
      }
      router.go(route);
      return true;
    }

    if (requireScreen && !ScreenResolver.hasScreen(route)) {
      Logger.warning('[in-app-route] no in-app screen for: $route');
      return false;
    }

    final nav = navigatorKey?.currentState ??
        (context == null ? null : Navigator.maybeOf(context, rootNavigator: true));
    if (nav == null) {
      Logger.warning('[in-app-route] no navigator for: $route');
      return false;
    }
    nav.push(MaterialPageRoute<void>(builder: (_) => screenFor(route)));
    return true;
  }
}
