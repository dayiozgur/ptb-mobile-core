import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/iot/screens/iot_dashboard_screen.dart';
import '../features/iot/screens/controllers_screen.dart';
import '../features/iot/screens/providers_screen.dart';
import '../features/iot/screens/variables_screen.dart';
import '../features/iot/screens/workflows_screen.dart';
import '../features/iot/screens/alarm_dashboard_screen.dart';
import '../features/iot/screens/active_alarms_screen.dart';
import '../features/iot/screens/reset_alarms_screen.dart';
import '../features/iot/screens/controller_logs_screen.dart';
import '../features/iot/screens/global_alarms_screen.dart';
import '../features/iot/screens/provider_landing_screen.dart';
import '../features/members/screens/members_screen.dart';
import '../features/site/screens/site_landing_screen.dart';
import '../features/organization/screens/organization_selector_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/site/screens/site_selector_screen.dart';
import '../features/tenant/screens/tenant_selector_screen.dart';
import '../features/unit/screens/unit_selector_screen.dart';
import '../features/unit/screens/unit_detail_screen.dart';
import '../features/unit/screens/unit_form_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/showcase/screens/component_showcase_screen.dart';
import '../features/work_request/screens/work_requests_screen.dart';
import '../features/work_request/screens/work_request_detail_screen.dart';
import '../features/work_request/screens/work_request_form_screen.dart';
import '../features/calendar/screens/calendar_screen.dart';
import '../features/calendar/screens/calendar_event_detail_screen.dart';
import '../features/calendar/screens/calendar_event_form_screen.dart';
import '../features/search/screens/global_search_screen.dart';
import '../features/activity/screens/activity_log_screen.dart';
import '../features/settings/screens/language_settings_screen.dart';
import '../features/reports/screens/reports_dashboard_screen.dart';

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,

    // Redirect logic based on auth state
    redirect: (context, state) {
      final isAuthenticated = authService.isAuthenticated;
      final hasTenant = tenantService.hasTenant;

      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isTenantRoute = state.matchedLocation == '/tenant-select';

      // Not authenticated -> go to login
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Authenticated but no tenant selected -> go to tenant select
      if (isAuthenticated && !hasTenant && !isTenantRoute && !isAuthRoute) {
        return '/tenant-select';
      }

      // Authenticated with tenant but still on auth route -> go to home
      if (isAuthenticated && hasTenant && isAuthRoute) {
        return '/home';
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
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
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
      // Site Selection & Landing
      // ==================
      GoRoute(
        path: '/sites',
        name: 'sites',
        builder: (context, state) => const SiteSelectorScreen(),
      ),
      GoRoute(
        path: '/sites/:id',
        name: 'site-landing',
        builder: (context, state) {
          final siteId = state.pathParameters['id']!;
          return SiteLandingScreen(siteId: siteId);
        },
      ),

      // ==================
      // Unit Management
      // ==================
      GoRoute(
        path: '/units',
        name: 'units',
        builder: (context, state) => const UnitSelectorScreen(),
      ),
      GoRoute(
        path: '/units/new',
        name: 'unit-new',
        builder: (context, state) {
          final parentId = state.uri.queryParameters['parentId'];
          return UnitFormScreen(parentId: parentId);
        },
      ),
      GoRoute(
        path: '/units/:id',
        name: 'unit-detail',
        builder: (context, state) {
          final unitId = state.pathParameters['id']!;
          return UnitDetailScreen(unitId: unitId);
        },
      ),
      GoRoute(
        path: '/units/:id/edit',
        name: 'unit-edit',
        builder: (context, state) {
          final unitId = state.pathParameters['id']!;
          return UnitFormScreen(unitId: unitId);
        },
      ),

      // ==================
      // Main App Routes
      // ==================
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/members',
        name: 'members',
        builder: (context, state) => const MembersScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // ==================
      // UI Showcase
      // ==================
      GoRoute(
        path: '/showcase',
        name: 'showcase',
        builder: (context, state) => const ComponentShowcaseScreen(),
      ),

      // ==================
      // IoT Routes
      // ==================
      GoRoute(
        path: '/iot',
        name: 'iot',
        builder: (context, state) => const IotDashboardScreen(),
      ),
      GoRoute(
        path: '/iot/controllers',
        name: 'iot-controllers',
        builder: (context, state) => const ControllersScreen(),
      ),
      GoRoute(
        path: '/iot/providers',
        name: 'iot-providers',
        builder: (context, state) => const ProvidersScreen(),
      ),
      GoRoute(
        path: '/iot/providers/:id',
        name: 'provider-landing',
        builder: (context, state) {
          final providerId = state.pathParameters['id']!;
          return ProviderLandingScreen(providerId: providerId);
        },
      ),
      GoRoute(
        path: '/iot/variables',
        name: 'iot-variables',
        builder: (context, state) => const VariablesScreen(),
      ),
      GoRoute(
        path: '/iot/workflows',
        name: 'iot-workflows',
        builder: (context, state) => const WorkflowsScreen(),
      ),
      GoRoute(
        path: '/iot/alarms',
        name: 'iot-alarms',
        builder: (context, state) => const AlarmDashboardScreen(),
      ),
      GoRoute(
        path: '/iot/alarms/global',
        name: 'global-alarms',
        builder: (context, state) => const GlobalAlarmsScreen(),
      ),
      GoRoute(
        path: '/iot/alarms/active',
        name: 'active-alarms',
        builder: (context, state) => const ActiveAlarmsScreen(),
      ),
      GoRoute(
        path: '/iot/alarms/history',
        name: 'alarm-history',
        builder: (context, state) => const ResetAlarmsScreen(),
      ),
      GoRoute(
        path: '/iot/controllers/:id/logs',
        name: 'controller-logs',
        builder: (context, state) {
          final controllerId = state.pathParameters['id']!;
          final controllerName = state.uri.queryParameters['name'];
          return ControllerLogsScreen(
            controllerId: controllerId,
            controllerName: controllerName,
          );
        },
      ),

      // ==================
      // Work Request Routes
      // ==================
      GoRoute(
        path: '/work-requests',
        name: 'work-requests',
        builder: (context, state) => const WorkRequestsScreen(),
      ),
      GoRoute(
        path: '/work-requests/new',
        name: 'work-request-new',
        builder: (context, state) => const WorkRequestFormScreen(),
      ),
      GoRoute(
        path: '/work-requests/:id',
        name: 'work-request-detail',
        builder: (context, state) {
          final requestId = state.pathParameters['id']!;
          return WorkRequestDetailScreen(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/work-requests/:id/edit',
        name: 'work-request-edit',
        builder: (context, state) {
          final requestId = state.pathParameters['id']!;
          return WorkRequestFormScreen(requestId: requestId);
        },
      ),

      // ==================
      // Calendar Routes
      // ==================
      GoRoute(
        path: '/calendar',
        name: 'calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/calendar/new',
        name: 'calendar-event-new',
        builder: (context, state) => const CalendarEventFormScreen(),
      ),
      GoRoute(
        path: '/calendar/:id',
        name: 'calendar-event-detail',
        builder: (context, state) {
          final eventId = state.pathParameters['id']!;
          return CalendarEventDetailScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: '/calendar/:id/edit',
        name: 'calendar-event-edit',
        builder: (context, state) {
          final eventId = state.pathParameters['id']!;
          return CalendarEventFormScreen(eventId: eventId);
        },
      ),

      // ==================
      // Search Routes
      // ==================
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const GlobalSearchScreen(),
      ),

      // ==================
      // Activity Routes
      // ==================
      GoRoute(
        path: '/activity',
        name: 'activity',
        builder: (context, state) => const ActivityLogScreen(),
      ),

      // ==================
      // Reports Routes
      // ==================
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsDashboardScreen(),
      ),

      // ==================
      // Language Settings Route
      // ==================
      GoRoute(
        path: '/settings/language',
        name: 'language-settings',
        builder: (context, state) => const LanguageSettingsScreen(),
      ),
    ],

    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: AppErrorView(
        title: 'Sayfa Bulunamadı',
        message: 'Aradığınız sayfa mevcut değil: ${state.matchedLocation}',
        actionLabel: 'Ana Sayfaya Git',
        onAction: () => context.go('/home'),
      ),
    ),
  );
});
