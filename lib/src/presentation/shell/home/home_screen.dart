import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Ana Sayfa (Home) — sabit alt-nav'ın ilk sekmesi.
///
/// Sade, dashboard-tarzı karşılama:
///   1. Selamlama kartı (imzalı avatar + "Merhaba, {ad}" + rol · organizasyon)
///   2. Aktif alarm istatistiği — YALNIZ izleme platformlarında (PMS)
///   3. "Modüller" hızlı-erişim kartı → tüm modül ızgarası [ModulesScreen]'de
///
/// Modül ızgarası bilinçli olarak Ana Sayfa'dan **[ModulesScreen]'e taşındı**
/// (sidebar → Modüller); Ana Sayfa artık yalın bir karşılama ekranıdır.
class HomeScreen extends StatefulWidget {
  /// Shell sekmesi olarak gömülüyse (global üst-bar/drawer shell'de) kendi
  /// AppBar'ını çizmez — `showAppBar:false`.
  final bool embedded;
  const HomeScreen({super.key, this.embedded = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;

  UserProfile? _profile;
  String? _avatarUrl;

  /// Aktif alarm sayısı. null → izleme-dışı platform / servis yok (kart gizli).
  int? _alarmCount;

  StreamSubscription<String>? _platformSub;

  @override
  void initState() {
    super.initState();
    try {
      _platformSub = sl<PlatformContext>().platformStream.listen((_) {
        _loadStats();
      });
    } catch (_) {
      // PlatformContext kayıtlı değilse sessizce atla.
    }
    _load();
  }

  @override
  void dispose() {
    _platformSub?.cancel();
    super.dispose();
  }

  // ============================================
  // LOAD
  // ============================================

  Future<void> _load() async {
    await Future.wait<void>([
      _loadProfile(),
      _loadStats(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await sl<ProfileService>().getProfileBundle();
      String? avatar;
      if (profile != null) {
        avatar = await sl<FileStorageService>().getAvatarUrl(profile.avatarUrl);
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _avatarUrl = avatar;
      });
    } catch (_) {
      // Profil çözülemezse selamlama jenerik kalır (çökme yok).
    }
  }

  Future<void> _loadStats() async {
    // Bildirim sayısı üst-bar'da (shell) yüklenir — burada tekrar edilmez.
    //
    // Aktif alarm = SCADA/IoT `alarms` tablosu → YALNIZ izleme (monitoring)
    // platformlarında (PMS) anlamlı. AlarmService çekirdekte tüm app'lere
    // kayıtlı olduğundan, platform-kapısı olmadan PHR gibi izleme-DIŞI
    // platformlarda alakasız PMS alarmları görünüyordu. İzleme-dışı platformda
    // kartı hiç yükleme → `_alarmCount` null kalır → kart gizlenir.
    if (!_isMonitoringPlatform()) return;
    try {
      if (sl.isRegistered<AlarmService>()) {
        final alarmSvc = sl<AlarmService>();
        try {
          final orgId = organizationService.currentOrganizationId;
          if (orgId != null) alarmSvc.setOrganization(orgId);
        } catch (_) {}
        final alarms = await alarmSvc.getActiveAlarms();
        if (mounted) setState(() => _alarmCount = alarms.length);
      }
    } catch (_) {
      // Alarm servisi erişilemedi → kartı gösterme.
    }
  }

  /// SCADA/IoT izleme yapan platformlar (aktif alarm kartı YALNIZ burada).
  static const Set<String> _kMonitoringPlatforms = {'PMS'};

  bool _isMonitoringPlatform() {
    try {
      final code = sl<PlatformContext>().activePlatformCode?.trim().toUpperCase();
      if (code == null || code.isEmpty) return false;
      return _kMonitoringPlatforms.contains(code);
    } catch (_) {
      return false;
    }
  }

  // ============================================
  // ACTIONS
  // ============================================

  void _openModules() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ModulesScreen()),
    );
  }

  /// AppBar başlığı: aktif platform kodu/adı, yoksa 'Ana Sayfa'.
  String _title() {
    try {
      final code = sl<PlatformContext>().activePlatformCode;
      if (code != null && code.trim().isNotEmpty) return code.trim();
    } catch (_) {}
    return 'Ana Sayfa';
  }

  String _greetingSubtitle(UserProfile p) {
    final role = _roleLabel(p.coarseRole);
    final tenant = (p.tenantName ?? '').trim();
    if (role.isNotEmpty && tenant.isNotEmpty) return '$role · $tenant';
    if (role.isNotEmpty) return role;
    if (tenant.isNotEmpty) return tenant;
    return p.email;
  }

  String _roleLabel(String? r) {
    switch (r) {
      case 'ROLE_ADMIN':
        return 'Yönetici';
      case 'ROLE_MANAGER':
        return 'Müdür';
      case 'ROLE_CUSTOMER':
        return 'Müşteri';
      case 'ROLE_USER':
        return 'Kullanıcı';
      default:
        return '';
    }
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _title(),
      showAppBar: !widget.embedded,
      showBackButton: false,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreeting(context),
                    if (_alarmCount != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _buildStats(context),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _buildModulesCta(context),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
    );
  }

  // 1) Selamlama kartı
  Widget _buildGreeting(BuildContext context) {
    final p = _profile;
    final name = p?.displayName ?? '';
    final subtitle = p != null ? _greetingSubtitle(p) : '';

    return AppCard(
      child: Row(
        children: [
          AppAvatar(
            imageUrl: _avatarUrl,
            name: name.isEmpty ? 'U' : name,
            size: AppAvatarSize.large,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.isEmpty ? 'Merhaba' : 'Merhaba, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.footnote.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2) Aktif alarm istatistiği (yalnız izleme platformları)
  Widget _buildStats(BuildContext context) {
    return MetricCard(
      title: 'Alarm',
      value: '${_alarmCount ?? 0}',
      subtitle: 'Aktif',
      icon: Icons.warning_amber_outlined,
      color: AppColors.error,
    );
  }

  // 3) "Modüller" hızlı-erişim kartı → tüm modül ızgarası ModulesScreen'de
  Widget _buildModulesCta(BuildContext context) {
    return AppCard(
      onTap: _openModules,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.grid_view_rounded,
                color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Modüller', style: AppTypography.headline),
                const SizedBox(height: 2),
                Text(
                  'Tüm modüllere göz at',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.tertiaryLabel(context)),
        ],
      ),
    );
  }
}
