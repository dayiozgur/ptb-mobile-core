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
      child: ErrorApp(message: result.errorMessage ?? 'Başlatma hatası'),
    ));
    return;
  }

  Logger.info('App initialized in ${result.duration.inMilliseconds}ms');
  Logger.info('Session restored: ${result.sessionRestored}');
  Logger.info('Tenant restored: ${result.tenantRestored}');

  runApp(const ProviderScope(child: ExampleApp()));
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
                  'Başlatma Hatası',
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
      title: 'Protoolbag Demo',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const DemoHomeScreen(),
    );
  }
}

/// Demo home screen to showcase widgets
class DemoHomeScreen extends StatelessWidget {
  const DemoHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Protoolbag Core Demo',
      showBackButton: false,
      actions: [
        AppIconButton(
          icon: Icons.info_outline,
          onPressed: () => _showInfoDialog(context),
        ),
      ],
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            AppCard(
              variant: AppCardVariant.filled,
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Column(
                  children: [
                    Icon(
                      Icons.rocket_launch,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Demo Modu',
                      style: AppTypography.title2,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Supabase yapılandırılmadığı için demo modunda çalışıyor.',
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

            // Buttons section
            AppSectionHeader(title: 'Buttons'),
            const SizedBox(height: AppSpacing.sm),

            AppButton(
              label: 'Primary Button',
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Secondary Button',
              variant: AppButtonVariant.secondary,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Destructive Button',
              variant: AppButtonVariant.destructive,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Left',
                    variant: AppButtonVariant.secondary,
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Right',
                    onPressed: () {},
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Input section
            AppSectionHeader(title: 'Inputs'),
            const SizedBox(height: AppSpacing.sm),

            const AppTextField(
              label: 'Text Field',
              placeholder: 'Enter text...',
            ),
            const SizedBox(height: AppSpacing.sm),
            const AppEmailField(),
            const SizedBox(height: AppSpacing.sm),
            const AppPasswordField(),
            const SizedBox(height: AppSpacing.sm),
            const AppSearchField(),

            const SizedBox(height: AppSpacing.lg),

            // Cards section
            AppSectionHeader(title: 'Cards'),
            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Total',
                    value: '1,234',
                    icon: Icons.bar_chart,
                    trend: MetricTrend.up,
                    trendValue: '+12%',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MetricCard(
                    title: 'Active',
                    value: '567',
                    icon: Icons.check_circle,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // List section
            AppSectionHeader(title: 'Lists'),
            const SizedBox(height: AppSpacing.sm),

            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: AppAvatar(name: 'John Doe'),
                    title: 'John Doe',
                    subtitle: 'john@example.com',
                    trailing: AppBadge(label: 'Admin'),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  AppListTile(
                    leading: AppAvatar(name: 'Jane Smith'),
                    title: 'Jane Smith',
                    subtitle: 'jane@example.com',
                    trailing: AppBadge(
                      label: 'Member',
                      variant: AppBadgeVariant.secondary,
                    ),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  AppListTile(
                    leading: AppAvatar(name: 'Bob Wilson'),
                    title: 'Bob Wilson',
                    subtitle: 'bob@example.com',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Feedback section
            AppSectionHeader(title: 'Feedback'),
            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                AppBadge(label: 'Success', variant: AppBadgeVariant.success),
                const SizedBox(width: AppSpacing.xs),
                AppBadge(label: 'Warning', variant: AppBadgeVariant.warning),
                const SizedBox(width: AppSpacing.xs),
                AppBadge(label: 'Error', variant: AppBadgeVariant.error),
                const SizedBox(width: AppSpacing.xs),
                AppBadge(label: 'Info', variant: AppBadgeVariant.info),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AppChip(label: 'Chip 1', selected: true, onTap: () {}),
                AppChip(label: 'Chip 2', onTap: () {}),
                AppChip(label: 'Chip 3', onTap: () {}),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            AppButton(
              label: 'Show Success Snackbar',
              variant: AppButtonVariant.secondary,
              onPressed: () {
                AppSnackbar.showSuccess(
                  context,
                  message: 'İşlem başarıyla tamamlandı!',
                );
              },
            ),

            const SizedBox(height: AppSpacing.sm),

            AppButton(
              label: 'Show Error Snackbar',
              variant: AppButtonVariant.secondary,
              onPressed: () {
                AppSnackbar.showError(
                  context,
                  message: 'Bir hata oluştu!',
                );
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // Progress section
            AppSectionHeader(title: 'Progress'),
            const SizedBox(height: AppSpacing.sm),

            AppProgressBar(value: 0.75, label: '75% Complete'),

            const SizedBox(height: AppSpacing.md),

            const Center(child: AppLoadingIndicator()),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Protoolbag Core'),
        content: const Text(
          'Bu demo, Protoolbag Core kütüphanesinin widget\'larını göstermektedir.\n\n'
          'Tam işlevsellik için .env dosyasını yapılandırın.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}
