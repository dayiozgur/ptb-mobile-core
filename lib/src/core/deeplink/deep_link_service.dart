import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../menu/menu_item.dart';
import '../utils/logger.dart';
import '../../presentation/shell/screen_resolver.dart';

/// **DeepLinkService** — reusable kernel host for mobile deep / universal links
/// (STORY-0083). ONE instance per app, initialized once after `runApp`.
///
/// Handles two link families that land on the app's single Activity / Scene:
///
///  1. **Universal (https) app links** — `https://app.<code>.protoolbag.com/<path…>`.
///     The `<path…>` is extracted and dispatched to an in-app screen: shell
///     top-level routes go through go_router (`context.go`), everything else is
///     resolved via [ScreenResolver] and pushed onto the root navigator. Unknown
///     paths fall back to a logged no-op (never a crash).
///
///  2. **Custom-scheme OAuth callbacks** — e.g. `ptbcrm://oauth-callback`. These
///     are the return leg of the Microsoft connect flow. The service does NOT
///     navigate for them; it simply surfaces the callback (default: log) so the
///     host — or the integration screen's `AppLifecycleState.resumed` refresh —
///     can react. This service is the `app_links` listener that
///     `MicrosoftIntegrationScreen` documents the host must provide.
///
/// The service is intentionally **defensive**: a malformed or foreign link is
/// logged and ignored, never thrown. It owns exactly one stream subscription,
/// disposed via [dispose].
///
/// ```dart
/// final deepLinks = DeepLinkService();
/// await deepLinks.init(
///   navigatorKey: rootNavigatorKey,
///   appHosts: const {'app.crm.protoolbag.com'},
/// );
/// // …later, on teardown:
/// deepLinks.dispose();
/// ```
class DeepLinkService {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  // Wiring captured at init().
  GlobalKey<NavigatorState>? _navigatorKey;
  void Function(Uri uri)? _onLink;
  void Function(Uri uri)? _onOAuthCallback;
  Set<String> _appHosts = const {};
  Set<String> _oauthHosts = const {'oauth-callback'};
  Set<String> _shellRoutes = const {};

  /// Default go_router top-level routes that must be dispatched with
  /// `context.go(...)` rather than a Navigator push (mirrors example_crm's
  /// push-notification bridge). Callers may override via [init]'s `shellRoutes`.
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

  /// Is the service listening?
  bool get isInitialized => _initialized;

  /// Wire the service to the running app and start consuming links.
  ///
  /// Provide either [navigatorKey] (the service dispatches to screens itself
  /// using [ScreenResolver] + go_router) OR [onLink] (the host handles every
  /// non-OAuth link). If both are given, [onLink] wins for app links.
  ///
  /// - [appHosts]: the https hosts this app owns, e.g.
  ///   `{'app.crm.protoolbag.com'}`. An https link whose host is not in this
  ///   set is ignored (defends against foreign / spoofed links). Empty = accept
  ///   any https host (not recommended for production).
  /// - [onOAuthCallback]: invoked for custom-scheme callbacks (e.g.
  ///   `ptbcrm://oauth-callback`). Defaults to a log; the integration screen
  ///   also refreshes on `AppLifecycleState.resumed`.
  /// - [oauthCallbackHosts]: custom-scheme hosts treated as OAuth returns
  ///   (default `{'oauth-callback'}`).
  /// - [shellRoutes]: go_router top-level routes (default [kDefaultShellRoutes]).
  ///
  /// Safe to call once; a second call is a no-op (logged).
  Future<void> init({
    GlobalKey<NavigatorState>? navigatorKey,
    void Function(Uri uri)? onLink,
    void Function(Uri uri)? onOAuthCallback,
    Set<String>? appHosts,
    Set<String>? oauthCallbackHosts,
    Set<String>? shellRoutes,
  }) async {
    if (_initialized) {
      Logger.warning('[deeplink] init called twice — ignoring');
      return;
    }
    _navigatorKey = navigatorKey;
    _onLink = onLink;
    _onOAuthCallback = onOAuthCallback;
    _appHosts = appHosts ?? const {};
    _oauthHosts = oauthCallbackHosts ?? const {'oauth-callback'};
    _shellRoutes = shellRoutes ?? kDefaultShellRoutes;
    _initialized = true;

    // Cold-start: the link that launched the app (if any).
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        Logger.info('[deeplink] initial link: $initial');
        _handleUri(initial);
      }
    } catch (e) {
      Logger.warning('[deeplink] getInitialLink failed: $e');
    }

    // Warm links while the app is already running.
    try {
      _sub = _appLinks.uriLinkStream.listen(
        _handleUri,
        onError: (Object e) => Logger.warning('[deeplink] stream error: $e'),
      );
    } catch (e) {
      Logger.warning('[deeplink] uriLinkStream subscribe failed: $e');
    }
  }

  /// Parse + dispatch a single incoming link. NEVER throws.
  void _handleUri(Uri uri) {
    try {
      final scheme = uri.scheme.toLowerCase();
      final isHttp = scheme == 'https' || scheme == 'http';

      // 1) Custom-scheme OAuth callback (e.g. ptbcrm://oauth-callback).
      if (!isHttp) {
        if (_oauthHosts.contains(uri.host.toLowerCase()) ||
            uri.path.toLowerCase().contains('oauth-callback')) {
          Logger.info('[deeplink] OAuth callback: $uri');
          if (_onOAuthCallback != null) {
            _onOAuthCallback!(uri);
          }
          // No navigation: MicrosoftIntegrationScreen refreshes on resume.
          return;
        }
        Logger.warning('[deeplink] unhandled custom-scheme link: $uri');
        return;
      }

      // 2) Universal (https) app link — must be a host we own.
      if (_appHosts.isNotEmpty &&
          !_appHosts.contains(uri.host.toLowerCase())) {
        Logger.warning('[deeplink] ignoring foreign https host: ${uri.host}');
        return;
      }

      final path = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
      if (path.isEmpty || path == '/') {
        Logger.info('[deeplink] app link with no path — ignoring: $uri');
        return;
      }

      // Host-provided handler takes over app-link dispatch entirely.
      if (_onLink != null) {
        _onLink!(uri);
        return;
      }

      _navigateToPath(path);
    } catch (e) {
      // Defensive: a malformed link must never crash the app.
      Logger.warning('[deeplink] failed to handle "$uri": $e');
    }
  }

  /// Map an in-app path to a screen. Shell routes → go_router; resolvable paths
  /// → [ScreenResolver] push; unknown → logged no-op.
  void _navigateToPath(String path) {
    final base = path.split('?').first;
    final navState = _navigatorKey?.currentState;
    final navContext = _navigatorKey?.currentContext;

    // Shell top-level routes are owned by go_router.
    if (path.startsWith('/') && _shellRoutes.contains(base)) {
      if (navContext != null) {
        navContext.go(path);
      } else {
        Logger.warning('[deeplink] no navigator context for shell route: $path');
      }
      return;
    }

    // Resolvable (domain / entity / neutral) screen → push on root navigator.
    if (ScreenResolver.hasScreen(path)) {
      if (navState != null) {
        navState.push(
          MaterialPageRoute<void>(
            builder: (_) => ScreenResolver.resolve(
              MenuItem(itemKey: '', title: '', path: path),
            ),
          ),
        );
      } else {
        Logger.warning('[deeplink] no navigator state for path: $path');
      }
      return;
    }

    // Unknown path → no-op (never a crash / 404).
    Logger.warning('[deeplink] no in-app screen for path: $path (ignored)');
  }

  /// Cancel the link subscription. Idempotent.
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
