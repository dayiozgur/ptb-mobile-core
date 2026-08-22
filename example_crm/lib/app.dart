import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'config/environment.dart';
import 'config/router.dart';

/// CRM (Protoolbag Satış) uygulama kök widget'ı — paylaşılan çekirdek shell'i
/// CRM platform bağlamıyla render eder.
class CRMApp extends ConsumerWidget {
  const CRMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeService = sl<ThemeService>();

    return LocalizationBuilder(
      localizationService: sl<LocalizationService>(),
      builder: (context, locale) {
        return ThemeBuilder(
          themeService: themeService,
          builder: (context, settings) {
            return MaterialApp.router(
              title: Environment.appName,
              debugShowCheckedModeBanner: false,
              theme: themeService.lightTheme,
              darkTheme: themeService.darkTheme,
              themeMode: themeService.flutterThemeMode,
              routerConfig: router,
            );
          },
        );
      },
    );
  }
}
