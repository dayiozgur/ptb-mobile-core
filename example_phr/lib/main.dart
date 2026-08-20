import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'app.dart';
import 'config/environment.dart';
import 'config/phr_screens.dart';

/// PHR platform kimliği (canlı DB). Bu app DAİMA PHR platformunda açılır —
/// menü + entity'ler bu platformdan yüklenir (WindowsOS: core + platform-app).
const String kPhrPlatformId = 'c1a1a1a1-0000-4000-8000-000000000001';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    Environment.validate();
  } catch (e) {
    Logger.warning('Environment not configured');
    runApp(const ProviderScope(
      child: _PhrErrorApp(message: 'Yapılandırma eksik (.env)'),
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
      child: _PhrErrorApp(message: result.errorMessage ?? 'Başlatılamadı'),
    ));
    return;
  }

  // Bu app PHR platformudur — çekirdek shell menü/entity'leri PHR'dan yükler.
  sl<PlatformContext>().setActivePlatform(kPhrPlatformId, code: 'PHR');

  // PHR domain (ESS) ekranlarını çekirdek ScreenResolver'a kaydet
  // (ilk shell render'ından ÖNCE).
  registerPhrScreens();

  // DB-driven markalama: PHR platform tabanını yükle ve temaya uygula.
  // (Tenant override login sonrası tenant bilindiğinde yeniden yüklenebilir:
  //  sl<BrandingService>().load(kPhrPlatformId, tenantId: <tenant>).)
  await sl<BrandingService>().load(kPhrPlatformId);
  final branding = sl<BrandingService>().current;
  if (branding != null) {
    sl<ThemeService>().applyBranding(branding);
  }

  Logger.info('PHR initialized in ${result.duration.inMilliseconds}ms');
  Logger.info('Session restored: ${result.sessionRestored}');

  runApp(const ProviderScope(child: PHRApp()));
}

/// Başlatma/yapılandırma hatasında gösterilen basit ekran.
class _PhrErrorApp extends StatelessWidget {
  final String message;
  const _PhrErrorApp({required this.message});

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
