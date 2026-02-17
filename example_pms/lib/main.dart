import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'app.dart';
import 'config/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
    Environment.validate();
  } catch (e) {
    // If .env doesn't exist, use demo mode
    Logger.warning('Environment not configured, running in demo mode');
    runApp(const ProviderScope(child: DemoApp()));
    return;
  }

  // Initialize Protoolbag Core
  final result = await CoreInitializer.initialize(
    config: CoreConfig(
      supabaseUrl: Environment.supabaseUrl,
      supabaseAnonKey: Environment.supabaseAnonKey,
      apiBaseUrl: Environment.apiBaseUrl,
      debugMode: Environment.isDebugMode,
    ),
    onProgress: (step) {
      Logger.debug('Initializing: $step');
    },
  );

  if (!result.isSuccess) {
    Logger.error('Core initialization failed: ${result.errorMessage}');
    runApp(ProviderScope(
      child: ErrorApp(message: result.errorMessage ?? 'Baslatilamadi'),
    ));
    return;
  }

  Logger.info('PMS initialized in ${result.duration.inMilliseconds}ms');
  Logger.info('Session restored: ${result.sessionRestored}');
  Logger.info('Tenant restored: ${result.tenantRestored}');

  runApp(const ProviderScope(child: PMSApp()));
}

/// Error app shown when initialization fails
class ErrorApp extends StatelessWidget {
  final String message;

  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Baslatma Hatasi',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Demo app shown when no .env is configured
class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Protoolbag PMS Demo',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const DemoHomeScreen(),
    );
  }
}

/// Demo home screen
class DemoHomeScreen extends StatelessWidget {
  const DemoHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'PMS Demo',
      showBackButton: false,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              variant: AppCardVariant.filled,
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    Icon(
                      Icons.monitor_heart,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'PMS Demo Modu',
                      style: AppTypography.title2,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Supabase yapilandirilmadigi icin demo modunda calisiyor.',
                      textAlign: TextAlign.center,
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Controllers',
                    value: '12',
                    icon: Icons.developer_board,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricCard(
                    title: 'Alarms',
                    value: '3',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Variables',
                    value: '256',
                    icon: Icons.data_object,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricCard(
                    title: 'Providers',
                    value: '8',
                    icon: Icons.storage,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
