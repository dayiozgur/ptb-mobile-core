import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'package:go_router/go_router.dart';

import 'app.dart';
import 'config/environment.dart';
import 'config/crm_screens.dart';
import 'config/router.dart';

/// CRM platform kimliği (canlı DB). Bu app DAİMA CRM platformunda açılır —
/// menü + entity'ler bu platformdan yüklenir (WindowsOS: core + platform-app).
const String kCrmPlatformId = 'f8a415b2-ba45-4246-98f5-b406b0c8b860';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    Environment.validate();
  } catch (e) {
    Logger.warning('Environment not configured');
    runApp(const ProviderScope(
      child: _CrmErrorApp(message: 'Yapılandırma eksik (.env)'),
    ));
    return;
  }

  final result = await CoreInitializer.initialize(
    config: CoreConfig(
      supabaseUrl: Environment.supabaseUrl,
      supabaseAnonKey: Environment.supabaseAnonKey,
      apiBaseUrl: Environment.apiBaseUrl,
      debugMode: Environment.isDebugMode,
    ),
    onProgress: (step) => Logger.debug('Initializing: $step'),
  );

  if (!result.isSuccess) {
    runApp(ProviderScope(
      child: _CrmErrorApp(message: result.errorMessage ?? 'Başlatılamadı'),
    ));
    return;
  }

  // Bu app CRM platformudur — çekirdek shell menü/entity'leri CRM'dan yükler.
  sl<PlatformContext>().setActivePlatform(kCrmPlatformId, code: 'CRM');

  // CRM domain ekranlarını çekirdek ScreenResolver'a kaydet (ilk render'dan ÖNCE).
  registerCrmScreens();

  // DB-driven markalama: CRM platform tabanını yükle ve temaya uygula.
  await sl<BrandingService>().load(kCrmPlatformId);
  final branding = sl<BrandingService>().current;
  if (branding != null) {
    sl<ThemeService>().applyBranding(branding);
  }

  _wirePushDeepLinking();

  Logger.info('CRM initialized in ${result.duration.inMilliseconds}ms');
  Logger.info('Session restored: ${result.sessionRestored}');

  runApp(const ProviderScope(child: CRMApp()));
}

const Set<String> _kShellRoutes = {
  '/login',
  '/request-access',
  '/tenant-select',
  '/organizations',
  '/main',
  '/dashboard',
  '/portal',
  '/settings',
};

/// Push-bildirim tap → navigasyon köprüsünü kur (additive).
void _wirePushDeepLinking() {
  sl<PushNotificationService>().onNotificationTap = (n) {
    if (!n.hasNavigationData) return;
    final route = n.navigationRoute!;
    if (route.isEmpty) return;

    final navState = rootNavigatorKey.currentState;
    final navContext = rootNavigatorKey.currentContext;

    final base = route.split('?').first;
    if (route.startsWith('/') && _kShellRoutes.contains(base)) {
      if (navContext != null) navContext.go(route);
      return;
    }

    navState?.push(
      MaterialPageRoute<void>(
        builder: (_) => ScreenResolver.resolve(
          MenuItem(itemKey: '', title: '', path: route),
        ),
      ),
    );
  };
}

/// Başlatma/yapılandırma hatasında gösterilen basit ekran.
class _CrmErrorApp extends StatelessWidget {
  final String message;
  const _CrmErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Başlatma Hatası',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
