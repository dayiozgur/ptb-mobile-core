import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/tenant/screens/tenant_selector_screen.dart';

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
