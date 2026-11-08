import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'app.dart';
import 'config/environment.dart';
import 'config/ppm_screens.dart';
import 'config/router.dart';

/// PPM (Proje Yönetimi) platform kimliği (canlı DB, code=PMP). Bu app DAİMA PPM
/// platformunda açılır — menü + entity'ler bu platformdan yüklenir.
const String kPpmPlatformId = '491ba5ba-7aee-4d19-8bca-b655e3010f83';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    Environment.validate();
  } catch (e) {
    Logger.warning('Environment not configured');
    runApp(const ProviderScope(
      child: _PpmErrorApp(message: 'Yapılandırma eksik (.env)'),
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
      child: _PpmErrorApp(message: result.errorMessage ?? 'Başlatılamadı'),
    ));
    return;
  }

  // Bu app PPM platformudur (code=PMP) — shell menü/entity'leri PMP'den yükler.
  sl<PlatformContext>().setActivePlatform(kPpmPlatformId, code: 'PMP');

  registerPpmScreens();


  // CRA A-08: minimum desteklenen sürüm (platform_app_configs.min_mobile_app_version;
  // kolon yoksa no-op, hata olursa fail-open).
  final versionGate = await AppVersionGate.check(supabase, kPpmPlatformId);
  if (versionGate.status.updateRequired) {
    final url = versionGate.storeUrl;
    runApp(AppUpdateRequiredApp(
      status: versionGate.status,
      onUpdate: url == null ? null : () => UrlActions.openUrl(url),
    ));
    return;
  }

  await sl<BrandingService>().load(kPpmPlatformId);
  final branding = sl<BrandingService>().current;
  if (branding != null) {
    sl<ThemeService>().applyBranding(branding);
  }

  // Bu app DeepLinkService kullanmıyor → shell rotalarını doğrudan kaydet.
  InAppRoute.configure(shellRoutes: _kShellRoutes);
  _wirePushDeepLinking();

  Logger.info('PPM initialized in ${result.duration.inMilliseconds}ms');

  runApp(const ProviderScope(child: PPMApp()));
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

void _wirePushDeepLinking() {
  // `action_url` → route/deep_link/screen; tam URL yalnız kendi host'umuzsa.
  // Açma kuralı uygulama-içi bildirim listesiyle ortak (çekirdek [InAppRoute]).
  sl<PushNotificationService>().onNotificationTap = (n) {
    final route = InAppRoute.fromPayload(n.data);
    if (route == null) return;
    InAppRoute.open(route, navigatorKey: rootNavigatorKey);
  };
}

class _PpmErrorApp extends StatelessWidget {
  final String message;
  const _PpmErrorApp({required this.message});

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
