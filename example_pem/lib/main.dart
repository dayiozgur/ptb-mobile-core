import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'package:go_router/go_router.dart';

import 'app.dart';
import 'config/environment.dart';
import 'config/pem_screens.dart';
import 'config/router.dart';

/// PEM platform kimliği (canlı DB: `platforms.code = 'PEM'`). Bu app DAİMA PEM
/// platformunda açılır — menü + entity'ler bu platformdan yüklenir
/// (WindowsOS: core + platform-app).
const String kPemPlatformId = 'a7704e2f-a330-4bbc-bdda-96a8a4f31d8c';

/// Bu app'in sahibi olduğu universal-link host'u (assetlinks / AASA bu host'ta
/// barındırılır; `platforms.app_base_url`). `https://app.pem.protoolbag.com/<path…>`
/// → uygulama-içi ekran.
const String kPemAppLinkHost = 'app.pem.protoolbag.com';

/// Deep / universal link host servisi (STORY-0083). Uygulama ömrü boyunca tekil;
/// `runApp` sonrası ilk frame'de [DeepLinkService.init] ile bağlanır.
final DeepLinkService _deepLinks = DeepLinkService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    Environment.validate();
  } catch (e) {
    Logger.warning('Environment not configured');
    runApp(const ProviderScope(
      child: _PemErrorApp(message: 'Yapılandırma eksik (.env)'),
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
      child: _PemErrorApp(message: result.errorMessage ?? 'Başlatılamadı'),
    ));
    return;
  }

  // Bu app PEM platformudur — çekirdek shell menü/entity'leri PEM'den yükler.
  sl<PlatformContext>().setActivePlatform(kPemPlatformId, code: 'PEM');

  // PEM domain ekranlarını çekirdek ScreenResolver'a kaydet (ilk render'dan ÖNCE).
  registerPemScreens();

  // CRA A-08: minimum desteklenen sürüm (platform_app_configs.min_mobile_app_version;
  // kolon yoksa no-op, hata olursa fail-open).
  final versionGate = await AppVersionGate.check(supabase, kPemPlatformId);
  if (versionGate.status.updateRequired) {
    final url = versionGate.storeUrl;
    runApp(AppUpdateRequiredApp(
      status: versionGate.status,
      onUpdate: url == null ? null : () => UrlActions.openUrl(url),
    ));
    return;
  }

  // DB-driven markalama: PEM platform tabanını yükle ve temaya uygula.
  await sl<BrandingService>().load(kPemPlatformId);
  final branding = sl<BrandingService>().current;
  if (branding != null) {
    sl<ThemeService>().applyBranding(branding);
  }

  _wirePushDeepLinking();

  Logger.info('PEM initialized in ${result.duration.inMilliseconds}ms');
  Logger.info('Session restored: ${result.sessionRestored}');

  runApp(const ProviderScope(child: PEMApp()));

  // Deep / universal link köprüsünü ilk frame'den SONRA bağla (navigator hazır
  // olsun). Host'umuz: https://app.pem.protoolbag.com/<path…>. (PEM'de MS OAuth
  // akışı yok; custom-scheme kaydedilmedi — callback yalnız loglanır.)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _deepLinks.init(
      navigatorKey: rootNavigatorKey,
      appHosts: const {kPemAppLinkHost},
      shellRoutes: _kShellRoutes,
      onOAuthCallback: (uri) =>
          Logger.info('OAuth callback received (screen self-refreshes): $uri'),
    );
  });
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
class _PemErrorApp extends StatelessWidget {
  final String message;
  const _PemErrorApp({required this.message});

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
