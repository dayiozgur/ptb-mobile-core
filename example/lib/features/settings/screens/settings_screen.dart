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
  bool _darkModeEnabled = false;

  @override
  void initState() {
    super.initState();
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
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Çıkış Yap'),
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
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile section
            AppSectionHeader(title: 'Profil'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Row(
                  children: [
                    AppAvatar(
                      name: user?.email ?? 'User',
                      size: AppAvatarSize.large,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.userMetadata?['full_name'] ?? 'Kullanıcı',
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
                    AppIconButton(
                      icon: Icons.edit,
                      onPressed: () {
                        AppSnackbar.showInfo(
                          context,
                          message: 'Profil düzenleme yakında',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Organization section
            AppSectionHeader(title: 'Organizasyon'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: AppAvatar(
                      name: tenant?.name ?? 'Org',
                      size: AppAvatarSize.medium,
                    ),
                    title: tenant?.name ?? 'Organizasyon',
                    subtitle: tenant?.plan.name.toUpperCase() ?? 'FREE',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AppSnackbar.showInfo(
                        context,
                        message: 'Organizasyon detayları yakında',
                      );
                    },
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Icon(Icons.swap_horiz, color: AppColors.primary),
                    title: 'Organizasyon Değiştir',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _handleSwitchTenant,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Security section
            AppSectionHeader(title: 'Güvenlik'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Icon(Icons.lock_outline, color: AppColors.primary),
                    title: 'Şifre Değiştir',
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
                            leading: Icon(Icons.fingerprint, color: AppColors.primary),
                            title: 'Biyometrik Giriş',
                            subtitle: 'Face ID veya parmak izi ile giriş',
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
                          Divider(height: 1, color: AppColors.separator(context)),
                        ],
                      );
                    },
                  ),
                  AppListTile(
                    leading: Icon(Icons.devices, color: AppColors.primary),
                    title: 'Aktif Oturumlar',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AppSnackbar.showInfo(
                        context,
                        message: 'Oturum yönetimi yakında',
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
                    leading: Icon(Icons.dark_mode, color: AppColors.primary),
                    title: 'Karanlık Mod',
                    trailing: Switch.adaptive(
                      value: _darkModeEnabled,
                      onChanged: (value) {
                        setState(() => _darkModeEnabled = value);
                        AppSnackbar.showInfo(
                          context,
                          message: 'Tema değişikliği sistem ayarlarından yapılabilir',
                        );
                      },
                      activeColor: AppColors.primary,
                    ),
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Icon(Icons.notifications_outlined, color: AppColors.primary),
                    title: 'Bildirimler',
                    trailing: Switch.adaptive(
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                      },
                      activeColor: AppColors.primary,
                    ),
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Icon(Icons.language, color: AppColors.primary),
                    title: 'Dil',
                    subtitle: 'Türkçe',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AppSnackbar.showInfo(
                        context,
                        message: 'Dil seçimi yakında',
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // About section
            AppSectionHeader(title: 'Hakkında'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: Icon(Icons.info_outline, color: AppColors.primary),
                    title: 'Versiyon',
                    subtitle: '1.0.0 (Build 1)',
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Icon(Icons.description_outlined, color: AppColors.primary),
                    title: 'Kullanım Koşulları',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                    title: 'Gizlilik Politikası',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  Divider(height: 1, color: AppColors.separator(context)),
                  AppListTile(
                    leading: Icon(Icons.help_outline, color: AppColors.primary),
                    title: 'Yardım & Destek',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Logout button
            AppButton(
              label: 'Çıkış Yap',
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
          title: 'Şifre Değiştir',
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
                    label: 'Mevcut Şifre',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: newController,
                    label: 'Yeni Şifre',
                    validator: Validators.password(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPasswordField(
                    controller: confirmController,
                    label: 'Yeni Şifre (Tekrar)',
                    validator: (value) {
                      if (value != newController.text) {
                        return 'Şifreler eşleşmiyor';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Şifreyi Güncelle',
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
                              message: 'Şifre başarıyla güncellendi',
                            );
                          },
                          failure: (error) {
                            AppSnackbar.showError(
                              context,
                              message: error?.message ?? 'Şifre güncellenemedi',
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
