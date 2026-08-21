import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Ana Sayfa (Home) — sabit alt-nav'ın ilk sekmesi.
///
/// Temiz, dashboard tarzı bir karşılama ekranı:
///   1. Selamlama kartı (imzalı avatar + "Merhaba, {ad}" + rol · organizasyon)
///   2. Hızlı istatistik satırı (okunmamış bildirim + aktif alarm — opsiyonel)
///   3. Modül ızgarası (aktif platformun DB menüsünden ekran-çözülebilir öğeler)
///
/// Platform switch'e reaktiftir: [PlatformContext.platformStream] dinlenir ve
/// değişimde modüller + istatistikler yeniden yüklenir. Tüm servis çağrıları
/// null/hata güvenli — eksik/başarısız servis ekranı çökertmez.
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

  int _unreadCount = 0;

  /// Aktif alarm sayısı. null → alarm servisi yok/erişilemedi (kart gizlenir).
  int? _alarmCount;

  /// Modül ızgarası — ekrana çözülebilen (tapable) menü öğeleri.
  List<MenuItem> _modules = const [];

  StreamSubscription<String>? _platformSub;

  @override
  void initState() {
    super.initState();
    // Aktif platform değişince modülleri + istatistikleri yeniden kur.
    try {
      _platformSub = sl<PlatformContext>().platformStream.listen((_) {
        _loadModules();
        _loadStats();
      });
    } catch (_) {
      // PlatformContext kayıtlı değilse sessizce atla — ekran yine çalışır.
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
      _loadModules(),
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

  Future<void> _loadModules() async {
    try {
      final role = await sl<PermissionService>().getCoarseRole();
      final platformId = sl<PlatformContext>().activePlatformId;

      List<MenuItem> tree;
      try {
        tree = await sl<MobileMenuService>()
            .loadMenu(platformId: platformId, coarseRole: role);
      } catch (_) {
        tree = const [];
      }

      final modules = _collectModules(tree);
      if (!mounted) return;
      setState(() => _modules = modules);
    } catch (_) {
      if (mounted) setState(() => _modules = const []);
    }
  }

  Future<void> _loadStats() async {
    // Okunmamış bildirim sayısı.
    try {
      final profileId = authService.currentUser?.id;
      if (profileId != null) {
        final count = await sl<NotificationService>().getUnreadCount(profileId);
        if (mounted) setState(() => _unreadCount = count);
      }
    } catch (_) {
      // Bildirim sayısı alınamazsa 0 kalır.
    }

    // Aktif alarm sayısı — alarm servisi varsa (opsiyonel, PMS-benzeri
    // platformlar). Servis yoksa/hata alırsa kart gizlenir.
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

  /// Menü ağacından modül ızgarası öğelerini topla.
  ///
  /// Kural: üst seviye öğe kendi ekranına çözülüyorsa onu ekle; aksi halde
  /// (grup başlığı) ekrana çözülen ilk-seviye çocuklarını ekle. Sonuç düz,
  /// tıklanabilir (ScreenResolver.hasScreen=true) öğeler listesidir.
  List<MenuItem> _collectModules(List<MenuItem> tree) {
    final out = <MenuItem>[];
    final seen = <String>{};

    void add(MenuItem item) {
      if (!item.hasPath || !ScreenResolver.hasScreen(item.path)) return;
      if (seen.add(item.itemKey)) out.add(item);
    }

    for (final item in tree) {
      if (item.hasPath && ScreenResolver.hasScreen(item.path)) {
        add(item);
      } else {
        for (final child in item.children) {
          add(child);
        }
      }
    }
    return out;
  }

  // ============================================
  // ACTIONS
  // ============================================

  void _openModule(MenuItem item) {
    if (!item.hasPath || !ScreenResolver.hasScreen(item.path)) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ScreenResolver.resolve(item)),
    );
  }

  String _t(String key) {
    try {
      return sl<LocalizationService>().translate(key);
    } catch (_) {
      return key;
    }
  }

  /// AppBar başlığı: aktif platform kodu/adı, yoksa 'Ana Sayfa'.
  String _title() {
    try {
      final code = sl<PlatformContext>().activePlatformCode;
      if (code != null && code.trim().isNotEmpty) return code.trim();
    } catch (_) {}
    return 'Ana Sayfa';
  }

  /// Selamlama alt-satırı: rol · organizasyon (varsa).
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
      // Gömülü değilken platform değiştirici (embedded'da global üst-bar'da).
      actions: widget.embedded
          ? null
          : [
              IconButton(
                icon: const Icon(Icons.apps),
                tooltip: 'Platform Değiştir',
                onPressed: () => showPlatformSwitcher(context),
              ),
            ],
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
                    const SizedBox(height: AppSpacing.lg),
                    _buildStats(context),
                    const SizedBox(height: AppSpacing.lg),
                    _buildModules(context),
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

  // 2) Hızlı istatistik satırı
  Widget _buildStats(BuildContext context) {
    final cards = <Widget>[
      Expanded(
        child: MetricCard(
          title: 'Bildirim',
          value: '$_unreadCount',
          subtitle: 'Okunmamış',
          icon: Icons.notifications_outlined,
          color: AppColors.primary,
        ),
      ),
    ];

    if (_alarmCount != null) {
      cards.add(const SizedBox(width: AppSpacing.md));
      cards.add(
        Expanded(
          child: MetricCard(
            title: 'Alarm',
            value: '${_alarmCount!}',
            subtitle: 'Aktif',
            icon: Icons.warning_amber_outlined,
            color: AppColors.error,
          ),
        ),
      );
    }

    // IntrinsicHeight ŞART: SingleChildScrollView içinde dikey sınır yok →
    // `CrossAxisAlignment.stretch` çocukları sonsuz yüksekliğe zorlar (geçersiz
    // BoxConstraints → tüm ağaç layout-fail + semantics kaskadı). IntrinsicHeight
    // Row'a sınırlı yükseklik verir, böylece stretch (eşit-yükseklik kart) çalışır.
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cards),
    );
  }

  // 3) Modül ızgarası
  Widget _buildModules(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Modüller', padding: EdgeInsets.zero),
        const SizedBox(height: AppSpacing.sm),
        if (_modules.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.grid_view_outlined,
                      color: AppColors.secondaryLabel(context)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Görüntülenecek modül yok',
                      style: AppTypography.subhead.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.95,
            children: _modules.map(_buildModuleTile).toList(),
          ),
      ],
    );
  }

  Widget _buildModuleTile(MenuItem item) {
    final label = _t(item.title);
    return AppCard(
      onTap: () => _openModule(item),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              BootstrapIconMap.resolve(item.icon),
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption1,
          ),
        ],
      ),
    );
  }
}
