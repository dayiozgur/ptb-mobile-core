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

    // LocalizationBuilder: dil değişince (setLocale → localeStream) tüm ağaç
    // yeniden çizilir → translate() yeni locale'i canlı yansıtır.
    return LocalizationBuilder(
      localizationService: sl<LocalizationService>(),
      builder: (context, locale) {
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
              builder: (context, child) => BrandedSplash(
                color: Environment.brandColor,
                appName: Environment.appName,
                slogan: Environment.slogan,
                child: BiometricLockGate(
                  brandColor: Environment.brandColor,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
