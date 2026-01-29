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
  String _selectedLanguage = 'tr';

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
            AppSectionHeader(title: 'Profil'),
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
            AppSectionHeader(title: 'Tenant Yonetimi'),
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
                    subtitle: tenant?.plan.name.toUpperCase() ?? 'FREE',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showTenantSettingsSheet(),
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
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
                        color: Colors.purple.withOpacity(0.1),
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
            AppSectionHeader(title: 'Guvenlik'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
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
                                color: Colors.green.withOpacity(0.1),
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
                              activeColor: AppColors.primary,
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
                        color: Colors.orange.withOpacity(0.1),
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
            AppSectionHeader(title: 'Tercihler'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
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
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.language, color: Colors.blue),
                    ),
                    title: 'Dil',
                    subtitle: _getLanguageName(_selectedLanguage),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showLanguageSelector(),
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
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
                      activeColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Data section
            AppSectionHeader(title: 'Veri Yonetimi'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.cached, color: Colors.teal),
                    ),
                    title: 'Onbellegi Temizle',
                    subtitle: 'Gecici verileri sil',
                    onTap: () async {
                      await cacheManager.clear();
                      if (mounted) {
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
                        color: Colors.cyan.withOpacity(0.1),
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
            AppSectionHeader(title: 'Hakkinda'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
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
                        color: Colors.grey.withOpacity(0.1),
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
                        color: Colors.grey.withOpacity(0.1),
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
                        color: Colors.grey.withOpacity(0.1),
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
            AppSectionHeader(title: 'Gelistirici'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
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
                if (mounted) Navigator.pop(context);
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
                if (mounted) Navigator.pop(context);
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
                if (mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AppBottomSheet(
        title: 'Dil Sec',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._languages.map((lang) {
              final isLast = lang == _languages.last;
              return Column(
                children: [
                  AppListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          lang['flag'] as String,
                          style: AppTypography.subheadline.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: lang['name'] as String,
                    trailing: _selectedLanguage == lang['code']
                        ? Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(
                          () => _selectedLanguage = lang['code'] as String);
                      Navigator.pop(context);
                      AppSnackbar.showInfo(
                        context,
                        message:
                            'Dil degisikligi uygulama yeniden baslatildiginda aktif olacak',
                      );
                    },
                  ),
                  if (!isLast)
                    Divider(height: 1, color: AppColors.separator(context)),
                ],
              );
            }),
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
                          label: tenant.plan.name.toUpperCase(),
                          variant: _getPlanVariant(tenant.plan),
                        ),
                        if (tenant.isTrial) ...[
                          const SizedBox(width: AppSpacing.xs),
                          AppBadge(
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
                        value: tenant.plan.name,
                      ),
                      if (tenant.isTrial) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _InfoRow(
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

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
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
          title: 'Sifre Degistir',
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPasswordField(
                    controller: currentController,
                    label: 'Mevcut Sifre',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: newController,
                    label: 'Yeni Sifre',
                    validator: Validators.password(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: confirmController,
                    label: 'Yeni Sifre (Tekrar)',
                    validator: (value) {
                      if (value != newController.text) {
                        return 'Sifreler eslesmedi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Sifreyi Guncelle',
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
                              message: 'Sifre basariyla guncellendi',
                            );
                          },
                          failure: (error) {
                            AppSnackbar.showError(
                              context,
                              message:
                                  error?.message ?? 'Sifre guncellenemedi',
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
          color: (isSelected ? AppColors.primary : Colors.grey).withOpacity(0.1),
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
