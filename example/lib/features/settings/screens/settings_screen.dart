import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;
  late AppThemeMode _themeMode;
  final String _selectedLanguage = 'tr';

  final _languages = [
    {'code': 'tr', 'name': 'Turkce', 'flag': 'TR'},
    {'code': 'en', 'name': 'English', 'flag': 'EN'},
    {'code': 'de', 'name': 'Deutsch', 'flag': 'DE'},
  ];

  @override
  void initState() {
    super.initState();
    // ThemeService'den mevcut tema modunu al
    _themeMode = themeService.themeMode;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final biometric = await authService.isBiometricLoginEnabled();
    setState(() {
      _biometricEnabled = biometric;
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cikis Yap'),
        content: const Text('Cikis yapmak istediginizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Iptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cikis Yap'),
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

  Future<void> _handleSwitchTenant() async {
    await tenantService.clearTenant();
    if (mounted) {
      context.go('/tenant-select');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final tenant = tenantService.currentTenant;

    return AppScaffold(
      title: 'Ayarlar',
      showBackButton: true,
      onBack: () => context.go('/home'),
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile section
            const AppSectionHeader(title: 'Profil'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              onTap: () => context.push('/profile'),
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Row(
                  children: [
                    AppAvatar(
                      imageUrl: user?.userMetadata?['avatar_url'] as String?,
                      name: user?.email ?? 'User',
                      size: AppAvatarSize.large,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.userMetadata?['full_name'] as String? ??
                                'Kullanici',
                            style: AppTypography.headline,
                          ),
                          Text(
                            user?.email ?? '',
                            style: AppTypography.subheadline.copyWith(
                              color: AppColors.secondaryLabel(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Tenant section
            const AppSectionHeader(title: 'Tenant Yonetimi'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: AppAvatar(
                      imageUrl: tenant?.logoUrl,
                      name: tenant?.name ?? 'Org',
                      size: AppAvatarSize.medium,
                    ),
                    title: tenant?.name ?? 'Organizasyon',
                    subtitle: (tenant?.plan)?.name.toUpperCase() ?? 'FREE',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showTenantSettingsSheet(),
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.swap_horiz, color: AppColors.primary),
                    ),
                    title: 'Tenant Degistir',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _handleSwitchTenant,
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.people, color: Colors.purple),
                    ),
                    title: 'Uyeler ve Davetler',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/members'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Security section
            const AppSectionHeader(title: 'Guvenlik'),
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
                    title: 'Sifre Degistir',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showChangePasswordDialog(),
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  FutureBuilder<bool>(
                    future: authService.isBiometricAvailable(),
                    builder: (context, snapshot) {
                      if (snapshot.data != true) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: [
                          AppListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.fingerprint,
                                  color: Colors.green),
                            ),
                            title: 'Biyometrik Giris',
                            subtitle: 'Face ID veya parmak izi ile giris',
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
                          ),
                          Divider(
                              height: 1, color: AppColors.separator(context)),
                        ],
                      );
                    },
                  ),
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.devices, color: Colors.orange),
                    ),
                    title: 'Aktif Oturumlar',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AppSnackbar.showInfo(
                        context,
                        message: 'Oturum yonetimi yakinda',
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Preferences section
            const AppSectionHeader(title: 'Tercihler'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.palette, color: Colors.indigo),
                    ),
                    title: 'Tema',
                    subtitle: _getThemeName(_themeMode),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showThemeSelector(),
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.language, color: Colors.blue),
                    ),
                    title: 'Dil',
                    subtitle: _getLanguageName(_selectedLanguage),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/language'),
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          const Icon(Icons.notifications, color: Colors.red),
                    ),
                    title: 'Bildirimler',
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

            // Data section
            const AppSectionHeader(title: 'Veri Yonetimi'),
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
                    title: 'Onbellegi Temizle',
                    subtitle: 'Gecici verileri sil',
                    onTap: () async {
                      await cacheManager.clear();
                      if (context.mounted) {
                        AppSnackbar.showSuccess(
                          context,
                          message: 'Onbellek temizlendi',
                        );
                      }
                    },
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.download, color: Colors.cyan),
                    ),
                    title: 'Verilerimi Indir',
                    subtitle: 'Tum verilerinizi disa aktarin',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AppSnackbar.showInfo(
                        context,
                        message: 'Veri indirme yakinda',
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // About section
            const AppSectionHeader(title: 'Hakkinda'),
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
                    title: 'Versiyon',
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
                      child: const Icon(Icons.description_outlined,
                          color: Colors.grey),
                    ),
                    title: 'Kullanim Kosullari',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.privacy_tip_outlined,
                          color: Colors.grey),
                    ),
                    title: 'Gizlilik Politikasi',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          const Icon(Icons.help_outline, color: Colors.grey),
                    ),
                    title: 'Yardim & Destek',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Developer Tools
            const AppSectionHeader(title: 'Gelistirici'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.palette_outlined,
                          color: Colors.deepPurple),
                    ),
                    title: 'Bilesen Katalogu',
                    subtitle: 'Tum UI bilesenlerini kesfet',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/showcase'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Logout button
            AppButton(
              label: 'Cikis Yap',
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

  String _getThemeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'Sistem';
      case AppThemeMode.light:
        return 'Acik';
      case AppThemeMode.dark:
        return 'Koyu';
    }
  }

  String _getLanguageName(String code) {
    final lang = _languages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => _languages.first,
    );
    return lang['name'] as String;
  }

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AppBottomSheet(
        title: 'Tema Sec',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOption(
              icon: Icons.brightness_auto,
              title: 'Sistem',
              subtitle: 'Cihaz ayarlarini kullan',
              isSelected: _themeMode == AppThemeMode.system,
              onTap: () async {
                await themeService.setThemeMode(AppThemeMode.system);
                setState(() => _themeMode = AppThemeMode.system);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            Divider(height: 1, color: AppColors.separator(context)),
            _ThemeOption(
              icon: Icons.light_mode,
              title: 'Acik',
              subtitle: 'Her zaman acik tema',
              isSelected: _themeMode == AppThemeMode.light,
              onTap: () async {
                await themeService.setThemeMode(AppThemeMode.light);
                setState(() => _themeMode = AppThemeMode.light);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            Divider(height: 1, color: AppColors.separator(context)),
            _ThemeOption(
              icon: Icons.dark_mode,
              title: 'Koyu',
              subtitle: 'Her zaman koyu tema',
              isSelected: _themeMode == AppThemeMode.dark,
              onTap: () async {
                await themeService.setThemeMode(AppThemeMode.dark);
                setState(() => _themeMode = AppThemeMode.dark);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }


  void _showTenantSettingsSheet() {
    final tenant = tenantService.currentTenant;
    if (tenant == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AppBottomSheet(
        title: 'Tenant Ayarlari',
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tenant info
              Center(
                child: Column(
                  children: [
                    AppAvatar(
                      imageUrl: tenant.logoUrl,
                      name: tenant.name,
                      size: AppAvatarSize.xl,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      tenant.name,
                      style: AppTypography.title2,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppBadge(
                          label: (tenant.plan ?? SubscriptionPlan.free)
                              .name
                              .toUpperCase(),
                          variant: _getPlanVariant(
                              tenant.plan ?? SubscriptionPlan.free),
                        ),
                        if (tenant.isTrial) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const AppBadge(
                            label: 'Deneme',
                            variant: AppBadgeVariant.warning,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Plan info
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plan Bilgileri',
                        style: AppTypography.subheadline.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _InfoRow(
                        label: 'Mevcut Plan',
                        value: (tenant.plan ?? SubscriptionPlan.free).name,
                      ),
                      if (tenant.isTrial) ...[
                        const SizedBox(height: AppSpacing.xs),
                        const _InfoRow(
                          label: 'Durum',
                          value: 'Deneme Sürümü',
                          valueColor: AppColors.warning,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      _InfoRow(
                        label: 'Durum',
                        value: tenant.active ? 'Aktif' : 'Pasif',
                        valueColor:
                            tenant.active ? AppColors.success : AppColors.error,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Actions
              AppButton(
                label: 'Plani Yukselt',
                icon: Icons.upgrade,
                onPressed: () {
                  Navigator.pop(context);
                  AppSnackbar.showInfo(
                    context,
                    message: 'Plan yukseltme yakinda',
                  );
                },
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  AppBadgeVariant _getPlanVariant(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return AppBadgeVariant.secondary;
      case SubscriptionPlan.basic:
        return AppBadgeVariant.info;
      case SubscriptionPlan.professional:
        return AppBadgeVariant.primary;
      case SubscriptionPlan.enterprise:
        return AppBadgeVariant.success;
    }
  }


  /// Şifre değişikliği sonucunu (başarı hariç) okunabilir metne çevirir.
  /// Rate-limit ve ağ/diğer hatalar ASLA "yanlış şifre" olarak gösterilmez.
  String _passwordChangeError(PasswordChangeOutcome outcome) {
    switch (outcome) {
      case PasswordChangeOutcome.wrongCurrentPassword:
        return sl<LocalizationService>().tr('settings.current_password_wrong');
      case PasswordChangeOutcome.samePassword:
        return sl<LocalizationService>()
            .tr('settings.password_same_as_current');
      case PasswordChangeOutcome.weakPassword:
        return sl<LocalizationService>().tr('settings.password_weak');
      case PasswordChangeOutcome.rateLimited:
        return sl<LocalizationService>().tr('settings.password_rate_limited');
      case PasswordChangeOutcome.reauthenticationNeeded:
        return sl<LocalizationService>()
            .tr('profile.password_reauth_required');
      case PasswordChangeOutcome.mfaRequired:
        return sl<LocalizationService>()
            .tr('account.security.password.mfa_required');
      case PasswordChangeOutcome.mfaCodeInvalid:
        return sl<LocalizationService>()
            .tr('auth.mfa.email_error_invalid_code');
      case PasswordChangeOutcome.success:
      case PasswordChangeOutcome.networkError:
      case PasswordChangeOutcome.sessionMissing:
      case PasswordChangeOutcome.failed:
        return sl<LocalizationService>().tr('settings.password_update_failed');
    }
  }

  /// Self-servis şifre değişikliği: mevcut şifre zorunlu ve sunucuya karşı
  /// doğrulanır (`changePasswordVerified`, CRA F-108).
  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? currentError;
    String? newError;
    String? formError;
    bool submitting = false;
    // MFA (authenticator) step-up: shown only after the server answered
    // `insufficient_aal` for this account (verified TOTP + AAL1 session).
    final mfaController = TextEditingController();
    bool needMfa = false;
    String? mfaError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: AppBottomSheet(
            title: sl<LocalizationService>().tr('settings.change_password'),
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPasswordField(
                      key: const Key('settings.password.current'),
                      controller: currentController,
                      label: sl<LocalizationService>()
                          .tr('settings.current_password'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return sl<LocalizationService>()
                              .tr('settings.current_password_required');
                        }
                        return currentError;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppPasswordField(
                      key: const Key('settings.password.new'),
                      controller: newController,
                      label:
                          sl<LocalizationService>().tr('settings.new_password'),
                      validator: (value) {
                        final base = Validators.password()(value);
                        if (base != null) return base;
                        if (value == currentController.text) {
                          return _passwordChangeError(
                              PasswordChangeOutcome.samePassword);
                        }
                        return newError;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppPasswordField(
                      key: const Key('settings.password.confirm'),
                      controller: confirmController,
                      label: sl<LocalizationService>()
                          .tr('settings.new_password_confirm'),
                      validator: (value) {
                        if (value != newController.text) {
                          return sl<LocalizationService>()
                              .tr('settings.passwords_not_match');
                        }
                        return null;
                      },
                    ),
                    if (needMfa) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        key: const Key('settings.password.mfa_code'),
                        controller: mfaController,
                        label: sl<LocalizationService>()
            .tr('auth.mfa.code_label'),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return sl<LocalizationService>()
            .tr('account.security.password.mfa_code_required');
                          }
                          return mfaError;
                        },
                      ),
                    ],
                    if (formError != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        formError!,
                        style: TextStyle(
                            color: Theme.of(sheetContext).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: sl<LocalizationService>()
                          .tr('settings.update_password'),
                      isLoading: submitting,
                      onPressed: submitting
                          ? null
                          : () async {
                              setSheetState(() {
                                currentError = null;
                                newError = null;
                                formError = null;
                                mfaError = null;
                              });
                              if (!(formKey.currentState?.validate() ??
                                  false)) {
                                return;
                              }
                              setSheetState(() => submitting = true);
                              final result = needMfa
                                  ? await authService.changePasswordVerified(
                                      currentPassword: currentController.text,
                                      newPassword: newController.text,
                                      mfaCode: mfaController.text.trim(),
                                    )
                                  : await authService.changePasswordVerified(
                                      currentPassword: currentController.text,
                                      newPassword: newController.text,
                                    );
                              if (!sheetContext.mounted) return;
                              setSheetState(() => submitting = false);
                              switch (result.outcome) {
                                case PasswordChangeOutcome.success:
                                  Navigator.pop(sheetContext);
                                  if (!mounted) return;
                                  AppSnackbar.showSuccess(
                                    context,
                                    message: sl<LocalizationService>()
                                        .tr('settings.password_updated'),
                                  );
                                case PasswordChangeOutcome.wrongCurrentPassword:
                                  currentError =
                                      _passwordChangeError(result.outcome);
                                  formKey.currentState?.validate();
                                case PasswordChangeOutcome.samePassword:
                                case PasswordChangeOutcome.weakPassword:
                                  newError =
                                      _passwordChangeError(result.outcome);
                                  formKey.currentState?.validate();
                                case PasswordChangeOutcome.mfaRequired:
                                  // Ask for the authenticator code and let the
                                  // user submit again (nothing was changed).
                                  setSheetState(() {
                                    needMfa = true;
                                    formError =
                                        _passwordChangeError(result.outcome);
                                  });
                                case PasswordChangeOutcome.mfaCodeInvalid:
                                  mfaError =
                                      _passwordChangeError(result.outcome);
                                  formKey.currentState?.validate();
                                case PasswordChangeOutcome.reauthenticationNeeded:
                                case PasswordChangeOutcome.rateLimited:
                                case PasswordChangeOutcome.networkError:
                                case PasswordChangeOutcome.sessionMissing:
                                case PasswordChangeOutcome.failed:
                                  setSheetState(() => formError =
                                      _passwordChangeError(result.outcome));
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.caption1.copyWith(
            color: AppColors.secondaryLabel(context),
          ),
        ),
        Text(
          value,
          style: AppTypography.subheadline.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
