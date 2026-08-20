import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'config/environment.dart';
import 'config/router.dart';

/// PHR (Protoolbag HR) uygulama kök widget'ı — paylaşılan çekirdek shell'i
/// PHR platform bağlamıyla render eder.
class PHRApp extends ConsumerWidget {
  const PHRApp({super.key});

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
