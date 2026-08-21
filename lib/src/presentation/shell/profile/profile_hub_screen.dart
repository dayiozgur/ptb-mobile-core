import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/core_initializer.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/tenant/tenant_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/user/user_profile.dart';
import '../../widgets/cards/app_card.dart';
import '../../widgets/display/app_avatar.dart';
import '../organization/organization_selector_screen.dart';
import '../settings/settings_screen.dart';
import 'profile_edit_screen.dart';

/// Profil Hub — LinkedIn tarzı kişisel profil ekranı.
///
/// **Nötr çekirdek** (tüm platformlar tüketir). `ProfileService.getProfileBundle`
/// kimliği (ad/headline/rol/organizasyon/avatar) tek round-trip'te getirir;
/// avatar `FileStorageService.getAvatarUrl` ile signed-URL'e çözülür (ham
/// `profiles.avatar_url` path'i public-URL'de 403 döner). Foto değiştirme
/// `image_picker` → `uploadAvatar` → `updateAvatar` akışıyla.
class ProfileHubScreen extends StatefulWidget {
  /// Shell sekmesi olarak gömülüyse kendi AppBar'ını çizmez (global chrome).
  final bool embedded;
  const ProfileHubScreen({super.key, this.embedded = false});

  @override
  State<ProfileHubScreen> createState() => _ProfileHubScreenState();
}

class _ProfileHubScreenState extends State<ProfileHubScreen> {
  UserProfile? _profile;
  String? _avatarUrl;
  bool _loading = true;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    if (mounted) setState(() => _loading = _profile == null);
    final profile = await profileService.getProfileBundle(forceRefresh: force);
    final avatar = await fileStorageService.getAvatarUrl(profile?.avatarUrl);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _avatarUrl = avatar;
      _loading = false;
    });
  }

  // ============================================
  // AVATAR
  // ============================================

  Future<void> _changeAvatar() async {
    final profile = _profile;
    if (profile == null) return;

    final source = await showModalBottomSheet<_AvatarAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden Seç'),
              onTap: () => Navigator.pop(ctx, _AvatarAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Fotoğraf Çek'),
              onTap: () => Navigator.pop(ctx, _AvatarAction.camera),
            ),
            if (profile.hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Fotoğrafı Kaldır',
                    style: TextStyle(color: AppColors.error)),
                onTap: () => Navigator.pop(ctx, _AvatarAction.remove),
              ),
          ],
        ),
      ),
    );
    if (source == null) return;

    if (source == _AvatarAction.remove) {
      await _saveAvatar(profile.id, '');
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source == _AvatarAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    if (mounted) setState(() => _uploadingAvatar = true);
    try {
      final result = await fileStorageService.uploadAvatar(
        userId: profile.id,
        file: File(picked.path),
      );
      if (!result.success || result.path == null) {
        _toast('Fotoğraf yüklenemedi: ${result.error ?? ''}', error: true);
        return;
      }
      await _saveAvatar(profile.id, result.path!);
    } catch (e) {
      _toast('Fotoğraf yüklenemedi', error: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _saveAvatar(String userId, String path) async {
    await profileService.updateAvatar(userId, path);
    await profileService.invalidateCache(userId);
    await _load(force: true);
    _toast(path.isEmpty ? 'Fotoğraf kaldırıldı' : 'Profil fotoğrafı güncellendi');
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileEditScreen(profile: profile),
      ),
    );
    if (changed == true) await _load(force: true);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await CoreInitializer.signOut();
      if (mounted) context.go('/login');
    }
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.groupedBackground(context),
      // Shell sekmesi (embedded) → AppBar yok (global chrome). Push edildiyse
      // (Settings/derin-link) geri-oklu AppBar.
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Profilim'),
              automaticallyImplyLeading: false,
              leading: Navigator.of(context).canPop()
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  : null,
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: () => _load(force: true),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      _buildHeader(brightness),
                      const SizedBox(height: AppSpacing.md),
                      _buildContactCard(brightness),
                      _buildAccountCard(brightness),
                      if ((_profile!.bio ?? '').trim().isNotEmpty)
                        _buildAboutCard(brightness),
                      _buildWorkspaceCard(brightness),
                      _buildActionsCard(brightness),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined,
                  size: 48, color: AppColors.secondaryLabel(context)),
              const SizedBox(height: 12),
              const Text('Profil yüklenemedi'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _load(force: true),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );

  // ---- Header (LinkedIn tarzı kapak + avatar) ----
  Widget _buildHeader(Brightness brightness) {
    final p = _profile!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface(brightness),
          ),
          child: Column(
            children: [
              // Kapak şeridi
              Container(
                height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
              // Ad + headline + rol
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.displayName, style: AppTypography.title2),
                    const SizedBox(height: 4),
                    Text(
                      _headline(p),
                      style: AppTypography.subheadline.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _roleChip(p),
                        const SizedBox(width: 8),
                        if ((p.tenantName ?? '').isNotEmpty)
                          Flexible(
                            child: Row(
                              children: [
                                Icon(Icons.apartment_outlined,
                                    size: 14,
                                    color: AppColors.secondaryLabel(context)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    p.tenantName!,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.footnote.copyWith(
                                      color: AppColors.secondaryLabel(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _editProfile,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Profili Düzenle'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Avatar (kapağa taşan) + kamera rozeti
        Positioned(
          left: 20,
          top: 48,
          child: GestureDetector(
            onTap: _uploadingAvatar ? null : _changeAvatar,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.surface(brightness), width: 3),
                  ),
                  child: AppAvatar(
                    imageUrl: _avatarUrl,
                    name: p.displayName,
                    size: AppAvatarSize.xl,
                  ),
                ),
                if (_uploadingAvatar)
                  const Positioned.fill(
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.surface(brightness), width: 2),
                    ),
                    child: const Icon(Icons.photo_camera,
                        size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _headline(UserProfile p) {
    final bio = (p.bio ?? '').trim();
    if (bio.isNotEmpty) return bio;
    return p.email.isNotEmpty ? p.email : _roleLabel(p.coarseRole);
  }

  Widget _buildContactCard(Brightness brightness) {
    final p = _profile!;
    return _section('İletişim', [
      _infoRow(Icons.mail_outline, 'E-posta', p.email.isEmpty ? '—' : p.email),
      if (p.hasPhone)
        _infoRow(Icons.phone_outlined, 'Telefon', p.phone!),
    ]);
  }

  Widget _buildAccountCard(Brightness brightness) {
    final p = _profile!;
    return _section('Hesap', [
      _infoRow(Icons.badge_outlined, 'Rol', _roleLabel(p.coarseRole)),
      if ((p.tenantName ?? '').isNotEmpty)
        _infoRow(Icons.apartment_outlined, 'Organizasyon', p.tenantName!),
      if (p.createdAt != null)
        _infoRow(Icons.event_outlined, 'Üyelik', _fmtDate(p.createdAt!)),
      if (p.lastLogin != null)
        _infoRow(Icons.login_outlined, 'Son giriş', _fmtDate(p.lastLogin!)),
      _infoRow(Icons.fingerprint, 'Kullanıcı ID', p.id, mono: true),
    ]);
  }

  Widget _buildAboutCard(Brightness brightness) {
    return _section('Hakkımda', [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(_profile!.bio!.trim(), style: AppTypography.body),
      ),
    ]);
  }

  /// Çalışma alanı: organizasyon + tenant/kiracı değiştirme (web'de topbar'da
  /// olan workspace-switcher'ın mobil karşılığı).
  Widget _buildWorkspaceCard(Brightness brightness) {
    final p = _profile!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text('Çalışma Alanı',
                style: AppTypography.footnote.copyWith(
                  color: AppColors.secondaryLabel(context),
                  fontWeight: FontWeight.w600,
                )),
          ),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: const Text('Organizasyon Değiştir'),
                  subtitle: (p.tenantName ?? '').isNotEmpty
                      ? Text(p.tenantName!,
                          maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: const Icon(Icons.swap_horiz, size: 20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const OrganizationSelectorScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.apartment_outlined),
                  title: const Text('Kiracı (Tenant) Değiştir'),
                  trailing: const Icon(Icons.swap_horiz, size: 20),
                  onTap: () async {
                    await sl<TenantService>().clearTenant();
                    if (mounted) context.go('/tenant-select');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(Brightness brightness) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: AppCard(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Ayarlar'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title:
                  const Text('Çıkış Yap', style: TextStyle(color: AppColors.error)),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  // ---- Ortak parçalar ----
  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(title,
                style: AppTypography.footnote.copyWith(
                  color: AppColors.secondaryLabel(context),
                  fontWeight: FontWeight.w600,
                )),
          ),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 4),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.secondaryLabel(context)),
          const SizedBox(width: 12),
          Text(label,
              style: AppTypography.subheadline
                  .copyWith(color: AppColors.secondaryLabel(context))),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: mono
                  ? AppTypography.caption1.copyWith(fontFamily: 'monospace')
                  : AppTypography.subheadline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(UserProfile p) {
    final color = _roleColor(p.coarseRole);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _roleLabel(p.coarseRole),
        style: AppTypography.caption1
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'ROLE_ADMIN':
        return 'Yönetici';
      case 'ROLE_MANAGER':
        return 'Müdür';
      case 'ROLE_USER':
        return 'Kullanıcı';
      case 'ROLE_CUSTOMER':
        return 'Müşteri';
      default:
        return 'Kullanıcı';
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'ROLE_ADMIN':
        return const Color(0xFFDC2626);
      case 'ROLE_MANAGER':
        return const Color(0xFFD97706);
      case 'ROLE_CUSTOMER':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF059669);
    }
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

enum _AvatarAction { gallery, camera, remove }
