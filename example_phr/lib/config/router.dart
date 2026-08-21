import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Kök navigator anahtarı — go_router'ın kök Navigator'ına kararlı erişim.
/// Push-bildirim deep-link'i (bkz. main.dart `onNotificationTap`) bu anahtar
/// üzerinden `context.go(...)` / `push(...)` yapar; DI hazır olduğunda widget
/// ağacına bağımlı kalmadan navigasyon sağlar.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'phrRootNavigator');

/// PHR router — YALNIZ paylaşılan shell rotaları (login/tenant/org/main/portal/
/// settings/entity). Domain (ESS) ekranları henüz yok; PHR menü yolları
/// çözülemezse çekirdek ScreenResolver ComingSoon'a düşürür. Tüm ekranlar
/// çekirdek `protoolbag_core` barrel'ından gelir (Faz-0 shell çıkarımı).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    debugLogDiagnostics: true,
    refreshListenable: sessionCoarseRole,
    redirect: (context, state) {
      final isAuthenticated = authService.isAuthenticated;
      final loc = state.matchedLocation;

      // Accept-invite deep-link daima erişilebilir (ekran kendi akışını yönetir).
      if (loc.startsWith('/auth/accept-invite')) return null;

      final isAuthRoute = loc == '/login' || loc == '/request-access';

      // 1) Kimlik doğrulama
      if (!isAuthenticated) return isAuthRoute ? null : '/login';

      final role = sessionCoarseRole.value;

      // 2) CUSTOMER → yalnız portal
      if (role == CoarseRoles.customer) {
        return loc.startsWith(RouteAccess.portalPath)
            ? null
            : RouteAccess.portalPath;
      }
      if (loc.startsWith(RouteAccess.portalPath)) return '/main';

      // 3) Tenant / organization kurulumu
      final hasTenant = tenantService.hasTenant;
      final hasOrganization =
          organizationService.currentOrganizationId != null;
      final isTenantRoute = loc == '/tenant-select';
      final isOrgRoute = loc == '/organizations';
      final isSetupRoute = isAuthRoute || isTenantRoute || isOrgRoute;

      if (!hasTenant && !isTenantRoute && !isAuthRoute) return '/tenant-select';
      if (hasTenant && !hasOrganization && !isSetupRoute) return '/organizations';
      if (hasTenant && hasOrganization && isAuthRoute) return '/main';

      // 4) Coarse-role erişim guard'ı
      if (!RouteAccess.canAccess(role, loc)) {
        return RouteAccess.deniedRedirect(role);
      }
      return null;
    },
    routes: [
      // Auth
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/request-access',
        name: 'request-access',
        builder: (context, state) => const RequestAccessScreen(),
      ),
      GoRoute(
        path: '/auth/accept-invite',
        name: 'accept-invite',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final frag = Uri.splitQueryString(state.uri.fragment);
          return AcceptInviteScreen(
            tokenHash: q['token_hash'] ?? frag['token_hash'],
            type: q['type'] ?? frag['type'],
            accessToken: q['access_token'] ?? frag['access_token'],
            refreshToken: q['refresh_token'] ?? frag['refresh_token'],
          );
        },
      ),

      // Tenant / Organization
      GoRoute(
        path: '/tenant-select',
        name: 'tenant-select',
        builder: (context, state) => const TenantSelectorScreen(),
      ),
      GoRoute(
        path: '/organizations',
        name: 'organizations',
        builder: (context, state) => const OrganizationSelectorScreen(),
      ),

      // Main shell (db-menü sürücülü bottom tabs)
      GoRoute(
        path: '/main',
        name: 'main',
        builder: (context, state) => const MainShellScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const MainShellScreen(),
      ),

      // Portal (CUSTOMER kısıtlı açılış)
      GoRoute(
        path: '/portal',
        name: 'portal',
        builder: (context, state) => const PortalLandingScreen(),
      ),

      // Settings
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // Entity engine (create ÖNCE :id)
      GoRoute(
        path: '/entities/:type/create',
        builder: (context, state) =>
            EntityFormScreen(typeCode: state.pathParameters['type']!),
      ),
      GoRoute(
        path: '/entities/:type/:id/edit',
        builder: (context, state) => EntityFormScreen(
          typeCode: state.pathParameters['type']!,
          id: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/entities/:type/:id',
        builder: (context, state) => EntityDetailScreen(
          typeCode: state.pathParameters['type']!,
          id: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});
