import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/tenant/screens/tenant_selector_screen.dart';
import '../features/shell/screens/main_shell_screen.dart';
import '../features/controllers/screens/controllers_screen.dart';
import '../features/controllers/screens/controller_detail_screen.dart';
import '../features/variables/screens/variables_screen.dart';
import '../features/variables/screens/variable_detail_screen.dart';
import '../features/alarms/screens/alarm_dashboard_screen.dart';
import '../features/alarms/screens/active_alarms_screen.dart';
import '../features/alarms/screens/alarm_history_screen.dart';
import '../features/logs/screens/log_viewer_screen.dart';
import '../features/logs/screens/log_analytics_screen.dart';
import '../features/providers/screens/providers_screen.dart';
import '../features/providers/screens/provider_landing_screen.dart';
import '../features/organization/screens/organization_selector_screen.dart';
import '../features/site/screens/site_selector_screen.dart';
import '../features/site/screens/site_landing_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/map/screens/site_map_screen.dart';

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,

    // Redirect logic based on auth state
    redirect: (context, state) {
      final isAuthenticated = authService.isAuthenticated;
      final hasTenant = tenantService.hasTenant;
      final hasOrganization = organizationService.currentOrganizationId != null;

      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login';
      final isTenantRoute = loc == '/tenant-select';
      final isOrgRoute = loc == '/organizations';
      final isSetupRoute = isAuthRoute || isTenantRoute || isOrgRoute;

      // Not authenticated -> go to login
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Authenticated but no tenant selected -> go to tenant select
      if (isAuthenticated && !hasTenant && !isTenantRoute && !isAuthRoute) {
        return '/tenant-select';
      }

      // Tenant selected but no organization -> go to organizations
      if (isAuthenticated && hasTenant && !hasOrganization && !isSetupRoute) {
        return '/organizations';
      }

      // Everything set, redirect away from auth route
      if (isAuthenticated && hasTenant && hasOrganization && isAuthRoute) {
        return '/main';
      }

      // No redirect needed
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
        title: 'Sayfa Bulunamadi',
        message: 'Aradiginiz sayfa mevcut degil: ${state.matchedLocation}',
        actionLabel: 'Dashboard\'a Git',
        onAction: () => context.go('/main'),
      ),
    ),
  );
});
