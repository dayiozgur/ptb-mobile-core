import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'config/environment.dart';
import 'config/router.dart';

/// Main PMS application widget
class PMSApp extends ConsumerWidget {
  const PMSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeService = sl<ThemeService>();

    return ThemeBuilder(
      themeService: themeService,
      builder: (context, settings) {
        return MaterialApp.router(
          title: Environment.appName,
          debugShowCheckedModeBanner: false,

          // Theme from ThemeService (dynamic)
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: themeService.flutterThemeMode,

          // Router configuration
          routerConfig: router,
        );
      },
    );
  }
}
