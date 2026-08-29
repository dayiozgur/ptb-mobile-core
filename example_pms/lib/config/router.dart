import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

// Nötr shell ekranları (login/tenant/main-shell/settings/org/portal/entity) +
// RouteAccess çekirdek barrel'dan gelir (Faz-0). PMS-domain ekranları local:
import '../features/controllers/screens/controllers_screen.dart';
import '../features/controllers/screens/controller_detail_screen.dart';
import '../features/variables/screens/variables_screen.dart';
import '../features/variables/screens/variable_detail_screen.dart';
import '../features/alarms/screens/alarm_dashboard_screen.dart';
import '../features/alarms/screens/active_alarms_screen.dart';
import '../features/alarms/screens/alarm_history_screen.dart';
import '../features/logs/screens/log_viewer_screen.dart';
import '../features/logs/screens/log_analytics_screen.dart';
import '../features/kpi/screens/kpi_screen.dart';
import '../features/providers/screens/providers_screen.dart';
import '../features/providers/screens/provider_landing_screen.dart';
import '../features/site/screens/site_selector_screen.dart';
import '../features/site/screens/site_landing_screen.dart';
import '../features/map/screens/site_map_screen.dart';

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,

    // Coarse-role çözülünce (shell menüyü yükledikten sonra) redirect'i
    // yeniden çalıştır → rol-bazlı gating uygulanır.
    refreshListenable: Listenable.merge([
      sessionCoarseRole,
      MfaGate.instance.revision,
    ]),

    // Redirect: auth → tenant/org kurulum → coarse-role erişim guard'ı.
    redirect: (context, state) {
      final isAuthenticated = authService.isAuthenticated;
      final loc = state.matchedLocation;

      // 0) Accept-invite deep-link: kimlik durumundan bağımsız DAİMA erişilebilir.
      // Ekran kendi akışını yönetir (verifyOtp/OtpType.invite → güçlü şifre →
      // /main). Guard'ın allowlist'inde — /login'e zorlanmamalı.
      if (loc.startsWith('/auth/accept-invite')) {
        return null;
      }

      // Kimlik doğrulama gerektirmeyen (unauth) rotalar.
      final isAuthRoute = loc == '/login' || loc == '/request-access';

      // 1) Kimlik doğrulama
      if (!isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }

      // 1b) MFA politika zorlaması (web step-up guard paritesi). FAIL-OPEN:
      // MfaGate yalnız POZİTİF (politika rol için MFA istiyor VE oturum aal1)
      // doğrulandığında state != none olur → '/mfa-gate'. Kapıdayken diğer
      // guard'lar (customer→portal, tenant/org) bounce etmesin diye kısa-devre.
      final mfaRedirect = MfaGate.instance.redirectFor(loc);
      if (mfaRedirect != null) return mfaRedirect;
      if (loc.startsWith('/mfa-gate')) return null;

      final role = sessionCoarseRole.value;

      // 2) CUSTOMER → yalnız portal (operatör ekranları görünmez)
      if (role == CoarseRoles.customer) {
        return loc.startsWith(RouteAccess.portalPath)
            ? null
            : RouteAccess.portalPath;
      }

      // Müşteri-dışı roller portal'a girmesin
      if (loc.startsWith(RouteAccess.portalPath)) {
        return '/main';
      }

      // 3) Tenant / organization kurulumu
      final hasTenant = tenantService.hasTenant;
      final hasOrganization =
          organizationService.currentOrganizationId != null;
      final isTenantRoute = loc == '/tenant-select';
      final isOrgRoute = loc == '/organizations';
      final isSetupRoute = isAuthRoute || isTenantRoute || isOrgRoute;

      if (!hasTenant && !isTenantRoute && !isAuthRoute) {
        return '/tenant-select';
      }
      if (hasTenant && !hasOrganization && !isSetupRoute) {
        return '/organizations';
      }
      if (hasTenant && hasOrganization && isAuthRoute) {
        return '/main';
      }

      // 4) Coarse-role erişim guard'ı (admin-only menü yolları).
      // Menü rol filtresiyle aynı vokabüler — SoT: platform_menu_items.roles.
      if (!RouteAccess.canAccess(role, loc)) {
        return RouteAccess.deniedRedirect(role);
      }

      return null;
    },

    routes: [
      // ==================
      // Auth Routes
      // ==================
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Erişim talebi (waitlist) — açık kayıt yerine invite-only kapı.
      GoRoute(
        path: '/request-access',
        name: 'request-access',
        builder: (context, state) => const RequestAccessScreen(),
      ),

      // Davet kabul (deep-link hedefi).
      //
      // Davet e-postasındaki bağlantı `<APP_BASE>/auth/accept-invite` biçimindedir
      // ve `?token_hash=…&type=invite` sorgu parametreleri taşır (eski linkler
      // `#access_token=…&refresh_token=…` hash-flow'u taşır). go_router yerleşik
      // deep-link desteği URL'yi buraya yönlendirir.
      //
      // TODO(deeplink-native): İşletim sisteminin universal/app-link'i bu
      // uygulamaya teslim etmesi için native kayıt GEREKİR ve bu bir owner/native
      // build adımıdır (bu görevde native dosyalara dokunulmaz):
      //   - iOS:     ios/Runner/Info.plist + Associated Domains
      //              (applinks:app.pms.protoolbag.com) + apple-app-site-association
      //   - Android: android/app/src/main/AndroidManifest.xml intent-filter
      //              (android:autoVerify + <data> host app.pms.protoolbag.com) +
      //              assetlinks.json
      // Kayıt yapılana kadar rota yalnızca uygulama-içi navigasyonla erişilebilir.
      GoRoute(
        path: '/auth/accept-invite',
        name: 'accept-invite',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          // Hash-flow fallback: bazı istemciler token'ları fragment (#) olarak
          // taşır; go_router bunları query'e taşımadığından fragment'ı da okuruz.
          final frag = Uri.splitQueryString(state.uri.fragment);
          return AcceptInviteScreen(
            tokenHash: q['token_hash'] ?? frag['token_hash'],
            type: q['type'] ?? frag['type'],
            accessToken: q['access_token'] ?? frag['access_token'],
            refreshToken: q['refresh_token'] ?? frag['refresh_token'],
          );
        },
      ),

      // ==================
      // Tenant Selection
      // ==================
      GoRoute(
        path: '/tenant-select',
        name: 'tenant-select',
        builder: (context, state) => const TenantSelectorScreen(),
      ),

      // ==================
      // Organization Selection
      // ==================
      GoRoute(
        path: '/organizations',
        name: 'organizations',
        builder: (context, state) => const OrganizationSelectorScreen(),
      ),

      // ==================
      // Main Shell (Bottom Tabs)
      // ==================
      GoRoute(
        path: '/main',
        name: 'main',
        builder: (context, state) => const MainShellScreen(),
      ),
      GoRoute(
        path: '/mfa-gate',
        name: 'mfa-gate',
        builder: (context, state) => const MfaGateScreen(),
      ),

      // ==================
      // Portal (CUSTOMER kısıtlı açılış)
      // ==================
      GoRoute(
        path: '/portal',
        name: 'portal',
        builder: (context, state) => const PortalLandingScreen(),
      ),

      // ==================
      // Sites
      // ==================
      GoRoute(
        path: '/sites',
        name: 'sites',
        builder: (context, state) => const SiteSelectorScreen(),
      ),
      GoRoute(
        path: '/sites/:id',
        name: 'site-detail',
        builder: (context, state) {
          final siteId = state.pathParameters['id']!;
          return SiteLandingScreen(siteId: siteId);
        },
      ),

      // ==================
      // Dashboard (legacy route, redirects to main)
      // ==================
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const MainShellScreen(),
      ),

      // ==================
      // Controllers
      // ==================
      GoRoute(
        path: '/controllers',
        name: 'controllers',
        builder: (context, state) => const ControllersScreen(),
      ),
      GoRoute(
        path: '/controllers/:id',
        name: 'controller-detail',
        builder: (context, state) {
          final controllerId = state.pathParameters['id']!;
          final controllerName = state.uri.queryParameters['name'];
          return ControllerDetailScreen(
            controllerId: controllerId,
            controllerName: controllerName,
          );
        },
      ),

      // ==================
      // Variables
      // ==================
      GoRoute(
        path: '/variables',
        name: 'variables',
        builder: (context, state) => const VariablesScreen(),
      ),
      GoRoute(
        path: '/variables/:id',
        name: 'variable-detail',
        builder: (context, state) {
          final variableId = state.pathParameters['id']!;
          final variableName = state.uri.queryParameters['name'];
          return VariableDetailScreen(
            variableId: variableId,
            variableName: variableName,
          );
        },
      ),

      // ==================
      // Alarms
      // ==================
      GoRoute(
        path: '/alarms',
        name: 'alarms',
        builder: (context, state) => const AlarmDashboardScreen(),
      ),
      GoRoute(
        path: '/alarms/active',
        name: 'active-alarms',
        builder: (context, state) => const ActiveAlarmsScreen(),
      ),
      GoRoute(
        path: '/alarms/history',
        name: 'alarm-history',
        builder: (context, state) => const AlarmHistoryScreen(),
      ),

      // ==================
      // Logs
      // ==================
      GoRoute(
        path: '/logs',
        name: 'logs',
        builder: (context, state) => const LogViewerScreen(),
      ),
      GoRoute(
        path: '/logs/analytics',
        name: 'log-analytics',
        builder: (context, state) => const LogAnalyticsScreen(),
      ),

      // ==================
      // KPI
      // ==================
      GoRoute(
        path: '/kpi',
        name: 'kpi',
        builder: (context, state) => const KpiScreen(),
      ),

      // ==================
      // Providers
      // ==================
      GoRoute(
        path: '/providers',
        name: 'providers',
        builder: (context, state) => const ProvidersScreen(),
      ),
      GoRoute(
        path: '/providers/:id',
        name: 'provider-detail',
        builder: (context, state) {
          final providerId = state.pathParameters['id']!;
          return ProviderLandingScreen(providerId: providerId);
        },
      ),

      // ==================
      // Map
      // ==================
      GoRoute(
        path: '/map',
        name: 'map',
        builder: (context, state) => const SiteMapScreen(),
      ),

      // ==================
      // Entities (low-code builder entity engine)
      // ==================
      // Statik `create` rotası, `:id` tarafından yakalanmaması için ondan
      // ÖNCE tanımlanır.
      GoRoute(
        path: '/entities/:type/create',
        name: 'entity-create',
        builder: (context, state) => EntityFormScreen(
          typeCode: state.pathParameters['type']!,
        ),
      ),
      GoRoute(
        path: '/entities/:type/:id/edit',
        name: 'entity-edit',
        builder: (context, state) => EntityFormScreen(
          typeCode: state.pathParameters['type']!,
          id: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/entities/:type/:id',
        name: 'entity-detail',
        builder: (context, state) => EntityDetailScreen(
          typeCode: state.pathParameters['type']!,
          id: state.pathParameters['id']!,
        ),
      ),

      // ==================
      // Settings
      // ==================
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],

    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: AppErrorView(
        title: 'Sayfa Bulunamadı',
        message: 'Aradığınız sayfa mevcut değil: ${state.matchedLocation}',
        actionLabel: 'Dashboard\'a Git',
        onAction: () => context.go('/main'),
      ),
    ),
  );
});
