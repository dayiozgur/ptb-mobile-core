import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class SettingsScreen extends StatefulWidget {
  /// Shell sekmesi olarak gömülüyse kendi AppBar'ını çizmez (global chrome).
  final bool embedded;
  const SettingsScreen({super.key, this.embedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;
  late AppThemeMode _themeMode;
  UserProfile? _profile;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _themeMode = themeService.themeMode;
    _loadSettings();
    _loadProfile();
  }

  Future<void> _loadSettings() async {
    final biometric = await authService.isBiometricLoginEnabled();
    setState(() {
      _biometricEnabled = biometric;
    });
  }

  /// Profil kimliğini Profil Hub ile aynı kaynaktan yükler: bundle + signed
  /// avatar URL (ham `avatar_url` public-URL'de 403 döner).
  Future<void> _loadProfile() async {
    final profile = await sl<ProfileService>().getProfileBundle();
    final avatar =
        await sl<FileStorageService>().getAvatarUrl(profile?.avatarUrl);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _avatarUrl = avatar;
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sl<LocalizationService>().translate('settings.logout')),
        content: Text(sl<LocalizationService>()
            .translate('settings.logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(sl<LocalizationService>().translate('common.cancel_ascii')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(sl<LocalizationService>().translate('settings.logout')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CoreInitializer.signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;

    return AppScaffold(
      title: sl<LocalizationService>().translate('settings.title'),
      showAppBar: !widget.embedded,
      showBackButton: !widget.embedded,
      onBack: widget.embedded ? null : () => context.go('/main'),
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile section
            AppSectionHeader(
                title: sl<LocalizationService>().translate('profile.title')),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileHubScreen(),
                  ),
                ),
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Row(
                    children: [
                      AppAvatar(
                        imageUrl: _avatarUrl,
                        name: _profile?.displayName ?? user?.email ?? 'User',
                        size: AppAvatarSize.large,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _profile?.displayName ??
                                  user?.email ??
                                  sl<LocalizationService>()
                                      .translate('settings.user_fallback'),
                              style: AppTypography.headline,
                            ),
                            Text(
                              _profile?.email ?? user?.email ?? '',
                              style: AppTypography.subheadline.copyWith(
                                color: AppColors.secondaryLabel(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.chevron_right,
                          color: AppColors.secondaryLabel(context)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Security section
            const AppSectionHeader(title: 'Güvenlik'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.lock_outline, color: AppColors.primary),
                    ),
                    title: 'Şifre Değiştir',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showChangePasswordDialog(),
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  FutureBuilder<bool>(
                    future: authService.isBiometricAvailable(),
                    builder: (context, snapshot) {
                      if (snapshot.data != true) return const SizedBox.shrink();
                      return AppListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fingerprint, color: Colors.green),
                        ),
                        title: sl<LocalizationService>()
                            .translate('settings.biometric_login'),
                        subtitle: sl<LocalizationService>()
                            .translate('settings.biometric_subtitle'),
                        trailing: Switch.adaptive(
                          value: _biometricEnabled,
                          onChanged: (value) async {
                            if (value) {
                              await authService.enableBiometricLogin();
                            } else {
                              await authService.disableBiometricLogin();
                            }
                            setState(() => _biometricEnabled = value);
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Preferences section
            AppSectionHeader(
                title:
                    sl<LocalizationService>().translate('settings.preferences')),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.language, color: Colors.blue),
                    ),
                    title: _languageLabel(),
                    subtitle: sl<LocalizationService>().currentLocale.displayName,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await showLanguagePicker(context);
                      if (mounted) setState(() {});
                    },
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.palette, color: Colors.indigo),
                    ),
                    title: sl<LocalizationService>().translate('settings.theme'),
                    subtitle: _getThemeName(_themeMode),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showThemeSelector(),
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.notifications, color: Colors.red),
                    ),
                    title:
                        sl<LocalizationService>().translate('settings.notifications'),
                    trailing: Switch.adaptive(
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                      },
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Data Management
            AppSectionHeader(
                title: sl<LocalizationService>()
                    .translate('settings.data_management')),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.cached, color: Colors.teal),
                    ),
                    title: sl<LocalizationService>()
                        .translate('settings.clear_cache_ascii'),
                    subtitle: sl<LocalizationService>()
                        .translate('settings.clear_cache_subtitle'),
                    onTap: () async {
                      await cacheManager.clear();
                      if (mounted) {
                        AppSnackbar.showSuccess(
                          context,
                          message: sl<LocalizationService>()
                              .translate('settings.clear_cache_success_ascii'),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // About
            AppSectionHeader(
                title:
                    sl<LocalizationService>().translate('settings.about_ascii')),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.info_outline, color: AppColors.primary),
                    ),
                    title: sl<LocalizationService>().translate('settings.version'),
                    subtitle: '1.0.0 (Build 1)',
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.help_outline, color: Colors.grey),
                    ),
                    title: sl<LocalizationService>()
                        .translate('settings.help_support'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AppSnackbar.showInfo(context,
                          message: sl<LocalizationService>()
                              .translate('settings.help_coming_soon'));
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Logout button
            AppButton(
              label: sl<LocalizationService>().translate('settings.logout'),
              variant: AppButtonVariant.destructive,
              icon: Icons.logout,
              onPressed: _handleLogout,
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  /// "Dil / Language" satır etiketi — DB keyword'ü varsa onu, yoksa 'Dil'
  /// fallback'ini kullanır (keyword henüz eklenmemişse ham anahtar sızmasın).
  String _languageLabel() {
    const key = 'settings.language';
    final value = sl<LocalizationService>().translate(key);
    return value == key ? 'Dil' : value;
  }

  String _getThemeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return sl<LocalizationService>().translate('settings.theme_system');
      case AppThemeMode.light:
        return sl<LocalizationService>().translate('settings.theme_light_ascii');
      case AppThemeMode.dark:
        return sl<LocalizationService>().translate('settings.theme_dark');
    }
  }

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AppBottomSheet(
        title: sl<LocalizationService>().translate('settings.theme_select'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOption(
              icon: Icons.brightness_auto,
              title: sl<LocalizationService>().translate('settings.theme_system'),
              subtitle: sl<LocalizationService>()
                  .translate('settings.theme_system_subtitle'),
              isSelected: _themeMode == AppThemeMode.system,
              onTap: () async {
                await themeService.setThemeMode(AppThemeMode.system);
                setState(() => _themeMode = AppThemeMode.system);
                if (mounted) Navigator.pop(context);
              },
            ),
            Divider(height: 1, color: AppColors.separator(context)),
            _ThemeOption(
              icon: Icons.light_mode,
              title:
                  sl<LocalizationService>().translate('settings.theme_light_ascii'),
              subtitle: sl<LocalizationService>()
                  .translate('settings.theme_light_subtitle'),
              isSelected: _themeMode == AppThemeMode.light,
              onTap: () async {
                await themeService.setThemeMode(AppThemeMode.light);
                setState(() => _themeMode = AppThemeMode.light);
                if (mounted) Navigator.pop(context);
              },
            ),
            Divider(height: 1, color: AppColors.separator(context)),
            _ThemeOption(
              icon: Icons.dark_mode,
              title: sl<LocalizationService>().translate('settings.theme_dark'),
              subtitle: sl<LocalizationService>()
                  .translate('settings.theme_dark_subtitle'),
              isSelected: _themeMode == AppThemeMode.dark,
              onTap: () async {
                await themeService.setThemeMode(AppThemeMode.dark);
                setState(() => _themeMode = AppThemeMode.dark);
                if (mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AppBottomSheet(
          title:
              sl<LocalizationService>().translate('settings.change_password'),
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPasswordField(
                    controller: newController,
                    label: sl<LocalizationService>()
                        .translate('settings.new_password'),
                    validator: Validators.password(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: confirmController,
                    label: sl<LocalizationService>()
                        .translate('settings.new_password_confirm'),
                    validator: (value) {
                      if (value != newController.text) {
                        return sl<LocalizationService>()
                            .translate('settings.passwords_not_match');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: sl<LocalizationService>()
                        .translate('settings.update_password'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final result = await authService.updatePassword(
                        newController.text,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);

                        result.when(
                          success: (_, __) {
                            AppSnackbar.showSuccess(
                              context,
                              message: sl<LocalizationService>()
                                  .translate('settings.password_updated'),
                            );
                          },
                          failure: (error) {
                            AppSnackbar.showError(
                              context,
                              message: error?.message ??
                                  sl<LocalizationService>()
                                      .translate('settings.password_update_failed'),
                            );
                          },
                        );
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isSelected ? AppColors.primary : Colors.grey).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppColors.primary : Colors.grey,
        ),
      ),
      title: title,
      subtitle: subtitle,
      trailing: isSelected ? Icon(Icons.check, color: AppColors.primary) : null,
      onTap: onTap,
    );
  }
}
