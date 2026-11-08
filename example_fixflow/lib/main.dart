import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'app.dart';
import 'config/environment.dart';
import 'config/fixflow_app_screens.dart';
import 'config/push_routing.dart';
import 'config/router.dart';

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
      child: _FixflowErrorApp(message: 'Yapılandırma eksik (.env)'),
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
      child: _FixflowErrorApp(message: result.errorMessage ?? 'Başlatılamadı'),
    ));
    return;
  }

  // Bu app FIXFLOW platformudur — çekirdek shell menü/entity'leri FIXFLOW'dan yükler.
  sl<PlatformContext>()
      .setActivePlatform(kFixflowPlatformId, code: kFixflowPlatformCode);

  // FixFlow teknisyen ekranlarını çekirdek ScreenResolver'a kaydet (ilk render'dan ÖNCE).
  registerFixflowAppScreens();

  // CRA A-08: minimum desteklenen sürüm (platform_app_configs.min_mobile_app_version;
  // kolon yoksa no-op, hata olursa fail-open).
  final versionGate = await AppVersionGate.check(supabase, kFixflowPlatformId);
  if (versionGate.status.updateRequired) {
    final url = versionGate.storeUrl;
    runApp(AppUpdateRequiredApp(
      status: versionGate.status,
      onUpdate: url == null ? null : () => UrlActions.openUrl(url),
    ));
    return;
  }

  // DB-driven markalama: FIXFLOW platform tabanını yükle ve temaya uygula.
  await sl<BrandingService>().load(kFixflowPlatformId);
  final branding = sl<BrandingService>().current;
  if (branding != null) {
    sl<ThemeService>().applyBranding(branding);
  }

  _wirePushDeepLinking();

  Logger.info('FixFlow initialized in ${result.duration.inMilliseconds}ms');
  Logger.info('Session restored: ${result.sessionRestored}');

  runApp(const ProviderScope(child: FixflowApp()));

  // Deep / universal link köprüsünü ilk frame'den SONRA bağla (navigator hazır
  // olsun). Host: https://app.fixflow.protoolbag.com/<path…>. Custom-scheme
  // ptbfixflow://oauth-callback → OAuth dönüşü (MS entegrasyon ekranı resume'da
  // kendini tazeler; bu servis o app_links dinleyicisini SAĞLAR).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _deepLinks.init(
      navigatorKey: rootNavigatorKey,
      appHosts: const {kFixflowAppLinkHost},
      shellRoutes: kFixflowShellRoutes,
      onOAuthCallback: (uri) =>
          Logger.info('OAuth callback received (screen self-refreshes): $uri'),
    );
  });
}

/// Push-bildirim tap → navigasyon köprüsü. `action_url` (ör.
/// `/fixflow/tickets/<id>`) varsa onu, yoksa `route`'u açar; bkz.
/// [fixflowNotificationRoute].
void _wirePushDeepLinking() {
  sl<PushNotificationService>().onNotificationTap = (n) {
    final route = fixflowNotificationRoute(n.data);
    if (route == null || route.isEmpty) return;
    openFixflowRoute(route, rootNavigatorKey);
  };
}

/// Başlatma/yapılandırma hatasında gösterilen basit ekran.
class _FixflowErrorApp extends StatelessWidget {
  final String message;
  const _FixflowErrorApp({required this.message});

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
