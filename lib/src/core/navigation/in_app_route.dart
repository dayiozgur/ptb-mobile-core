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
  static String? _webOrigin;

  /// Etkin shell rotaları.
  static Set<String> get shellRoutes => _shellRoutes;

  /// Uygulamanın sahip olduğu https host'ları (küçük harf).
  static Set<String> get appHosts => _appHosts;

  /// Origin of the app's WEB counterpart (`https://app.<code>.protoolbag.com`),
  /// used by the "open on the web" action of screens that have no mobile
  /// equivalent. Explicit [configure] value, else derived from the first
  /// [appHosts] entry; null when the app configured neither.
  static String? get webOrigin {
    final explicit = _webOrigin;
    if (explicit != null) return explicit;
    return _appHosts.isEmpty ? null : 'https://${_appHosts.first}';
  }

  /// The web URL of an in-app [path] (`/report/my` →
  /// `https://app.crm.protoolbag.com/report/my`), or null when the app has no
  /// web origin or [path] is not an in-app path.
  static Uri? webUrlFor(String? path) {
    final origin = webOrigin;
    final p = path?.trim();
    if (origin == null || p == null || p.isEmpty) return null;
    // Only relative in-app paths — never an absolute / scheme-relative URL.
    if (!p.startsWith('/') || p.startsWith('//') || p.contains('\\')) return null;
    return Uri.tryParse('$origin$p');
  }

  /// App yapılandırması. Verilmeyen alan mevcut değerini korur.
  ///
  /// [webOrigin] must be an `https://` origin without a path (anything else is
  /// ignored).
  static void configure({
    Set<String>? shellRoutes,
    Set<String>? appHosts,
    String? webOrigin,
  }) {
    if (shellRoutes != null) _shellRoutes = Set.unmodifiable(shellRoutes);
    if (appHosts != null) {
      _appHosts = Set.unmodifiable(appHosts.map((h) => h.toLowerCase()));
    }
    if (webOrigin != null) {
      final u = Uri.tryParse(webOrigin.trim());
      if (u != null && u.scheme == 'https' && u.host.isNotEmpty) {
        _webOrigin = 'https://${u.host.toLowerCase()}${u.hasPort ? ':${u.port}' : ''}';
      } else {
        Logger.warning('[in-app-route] ignoring invalid webOrigin');
      }
    }
  }

  /// Varsayılanlara dön (testler için).
  static void resetConfig() {
    _shellRoutes = kDefaultShellRoutes;
    _appHosts = const {};
    _webOrigin = null;
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

    // canOpen = has a menu screen OR a direct-only screen (reachable by link
    // but deliberately not in the menu, e.g. `/m365/mail`).
    if (requireScreen && !ScreenResolver.canOpen(route)) {
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

  /// Open the honest "this page lives in the web app" screen for [route] — for
  /// a link the OS handed to the app (universal / app link) that has no
  /// in-app screen. Without it the tap would silently do nothing, and the user
  /// could not reach the web page either (the app owns the link).
  static bool openWebOnly(
    String route, {
    GlobalKey<NavigatorState>? navigatorKey,
    BuildContext? context,
  }) {
    if (route.isEmpty || route == '/') return false;
    final nav = navigatorKey?.currentState ??
        (context == null ? null : Navigator.maybeOf(context, rootNavigator: true));
    if (nav == null) {
      Logger.warning('[in-app-route] no navigator for web-only: $route');
      return false;
    }
    nav.push(MaterialPageRoute<void>(
        builder: (_) => ScreenResolver.webOnlyScreen(route)));
    return true;
  }
}
