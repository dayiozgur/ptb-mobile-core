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

  /// Aktif alarm sayısı. null → alarm servisi yok/erişilemedi (kart gizlenir).
  int? _alarmCount;

  /// Modül bölümleri — menü gruplarına göre kategorize (Kayıtlar/Self/Yönetim).
  List<_ModuleGroup> _groups = const [];

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

      final groups = _collectGroups(tree);
      if (!mounted) return;
      setState(() => _groups = groups);
    } catch (_) {
      if (mounted) setState(() => _groups = const []);
    }
  }

  Future<void> _loadStats() async {
    // Bildirim sayısı üst-bar'da (shell) yüklenir — burada tekrar edilmez.
    //
    // Aktif alarm = SCADA/IoT `alarms` tablosu (site/controller/variable
    // kapsamlı) → YALNIZ izleme (monitoring) platformlarında (PMS) anlamlı.
    // AlarmService çekirdekte TÜM app'lere kayıtlı olduğundan, platform-kapısı
    // olmadan PHR gibi izleme-DIŞI platformlarda alakasız PMS alarmları
    // görünüyordu (leftover). İzleme-dışı platformda kartı hiç yükleme →
    // `_alarmCount` null kalır → kart gizlenir.
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
  /// İzleme-dışı platformlar (PHR/CRM/PPM/PEM…) alarmı göstermez.
  static const Set<String> _kMonitoringPlatforms = {'PMS'};

  /// Aktif platform bir izleme platformu mu?
  bool _isMonitoringPlatform() {
    try {
      final code = sl<PlatformContext>().activePlatformCode?.trim().toUpperCase();
      if (code == null || code.isEmpty) return false;
      return _kMonitoringPlatforms.contains(code);
    } catch (_) {
      return false;
    }
  }

  /// Menü ağacından **kategorize** modül bölümleri topla.
  ///
  /// Kural: her üst-seviye grup (kendi ekranı olmayan başlık) → bir bölüm;
  /// ekrana çözülen çocukları o bölümün öğeleridir. Üst-seviyede doğrudan
  /// ekrana çözülen öğeler "Hızlı Erişim" bölümünde toplanır. Böylece Ana
  /// Sayfa, web sidebar'ındaki grup yapısını (Kayıtlar/Self-Servis/Yönetim)
  /// yansıtır — düz 60-öğe ızgarasından çok daha gezilebilir.
  List<_ModuleGroup> _collectGroups(List<MenuItem> tree) {
    final groups = <_ModuleGroup>[];
    final general = <MenuItem>[];
    final seen = <String>{};

    bool resolvable(MenuItem i) =>
        i.hasPath && ScreenResolver.hasScreen(i.path);

    for (final item in tree) {
      if (resolvable(item)) {
        if (seen.add(item.itemKey)) general.add(item);
      } else {
        final kids = <MenuItem>[];
        for (final c in item.children) {
          if (resolvable(c) && seen.add(c.itemKey)) kids.add(c);
        }
        if (kids.isNotEmpty) groups.add(_ModuleGroup(_t(item.title), kids));
      }
    }
    if (general.isNotEmpty) {
      groups.insert(0, _ModuleGroup('Hızlı Erişim', general));
    }
    return groups;
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
                    // Bildirim istatistiği KALDIRILDI — üst-bar'daki çan
                    // rozetinde zaten var (tekrarı önlemek için). Alarm kartı
                    // yalnız alarm servisi olan platformlarda gösterilir.
                    if (_alarmCount != null) ...[
                      _buildStats(context),
                      const SizedBox(height: AppSpacing.lg),
                    ],
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

  // 2) Hızlı istatistik — yalnız aktif alarm (alarm servisi olan platformlarda).
  // Bildirim kartı kaldırıldı (üst-bar çan rozetinde var). Çağıran taraf zaten
  // `_alarmCount != null` guard'ıyla sarar.
  Widget _buildStats(BuildContext context) {
    return MetricCard(
      title: 'Alarm',
      value: '${_alarmCount ?? 0}',
      subtitle: 'Aktif',
      icon: Icons.warning_amber_outlined,
      color: AppColors.error,
    );
  }

  // 3) Modül bölümleri — kategori başlığı + renkli ikon ızgarası
  Widget _buildModules(BuildContext context) {
    if (_groups.isEmpty) {
      return AppCard(
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
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var gi = 0; gi < _groups.length; gi++) ...[
          Padding(
            padding: EdgeInsets.only(top: gi == 0 ? 0 : AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: AppSectionHeader(
                    title: _groups[gi].title,
                    padding: EdgeInsets.zero,
                  ),
                ),
                Text(
                  '${_groups[gi].items.length}',
                  style: AppTypography.caption1.copyWith(
                    color: AppColors.tertiaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.92,
            children: _groups[gi].items.map(_buildModuleTile).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildModuleTile(MenuItem item) {
    final label = _t(item.title);
    final color = _moduleColor(item);
    return AppCard(
      onTap: () => _openModule(item),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.xs,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(_moduleIcon(item), color: color, size: 25),
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

  // ============================================
  // MODÜL GÖRSELLİĞİ (renk + anlamlı ikon)
  // ============================================

  /// Modül accent paleti — her modüle stabil, ayırt edici bir renk atar
  /// (monoton tek-renk yerine). Alpha 0.14 zemin + tam-renk ikon iki temada da
  /// okunur.
  static const List<Color> _palette = [
    Color(0xFF6366F1), // indigo
    Color(0xFF0EA5E9), // sky
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFEF4444), // red
    Color(0xFF8B5CF6), // violet
    Color(0xFF14B8A6), // teal
    Color(0xFFEC4899), // pink
    Color(0xFF0891B2), // cyan
    Color(0xFF84CC16), // lime
  ];

  /// Öğe anahtarından stabil renk (aynı modül → hep aynı renk).
  Color _moduleColor(MenuItem item) {
    var h = 0;
    for (final c in item.itemKey.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  /// Anlamlı ikon: önce yol+başlık anahtar-kelimesinden türet (İK modülleri
  /// için ikonu boş olan öğelerin jenerik daire yerine anlamlı ikon almasını
  /// sağlar), bulunamazsa DB bootstrap ikonuna düş.
  IconData _moduleIcon(MenuItem item) {
    final kw = _keywordIcon('${item.path ?? ''} ${item.title}'.toLowerCase());
    if (kw != null) return kw;
    return BootstrapIconMap.resolve(item.icon);
  }

  IconData? _keywordIcon(String h) {
    bool has(String s) => h.contains(s);
    if (has('masraf') || has('expense')) return Icons.receipt_long;
    if (has('avans') || has('advance')) return Icons.payments;
    if (has('zimmet') || has('asset')) return Icons.inventory_2;
    if (has('eğitim') || has('egitim') || has('training')) return Icons.school;
    if (has('disiplin')) return Icons.gavel;
    if (has('sözleş') || has('sozles') || has('contract')) {
      return Icons.description;
    }
    if (has('ayrıl') || has('ayril') || has('offboard') || has('exit')) {
      return Icons.logout;
    }
    if (has('yetenek') || has('talent')) return Icons.workspace_premium;
    if (has('anket') || has('survey')) return Icons.poll;
    if (has('ziyaret') || has('visitor')) return Icons.badge;
    if (has('puantaj') ||
        has('timesheet') ||
        has('mesai') ||
        has('pdks') ||
        has('attendance')) {
      return Icons.schedule;
    }
    if (has('takvim') || has('calendar')) return Icons.calendar_month;
    if (has('izin') || has('leave')) return Icons.beach_access;
    if (has('bordro') ||
        has('payslip') ||
        has('payroll') ||
        has('maaş') ||
        has('maas')) {
      return Icons.request_quote;
    }
    if (has('kvkk') || has('/my-data') || has('consent') || has('veriler')) {
      return Icons.privacy_tip;
    }
    if (has('belge') || has('document')) return Icons.folder_shared;
    if (has('performans') ||
        has('değerlend') ||
        has('degerlend') ||
        has('review') ||
        has('hedef') ||
        has('goal')) {
      return Icons.trending_up;
    }
    if (has('onboard') || has('oryant')) return Icons.checklist;
    if (has('/hr/profile') || has('profilim') || has('my-hr')) {
      return Icons.badge_outlined;
    }
    if (has('kullanıc') || has('kullanic') || has('user')) return Icons.group;
    if (has('rol') || has('rbac')) return Icons.admin_panel_settings;
    if (has('departman') || has('department') || has('org')) {
      return Icons.account_tree;
    }
    if (has('rapor') || has('report') || has('analiz') || has('analytic')) {
      return Icons.bar_chart;
    }
    if (has('bildirim') || has('notification')) return Icons.notifications;
    if (has('onay') || has('approval')) return Icons.fact_check;
    if (has('ayar') || has('setting')) return Icons.settings;
    if (has('özet') ||
        has('ozet') ||
        has('dashboard') ||
        has('panel') ||
        has('panom')) {
      return Icons.dashboard;
    }
    return null;
  }
}

/// Ana Sayfa modül bölümü (menü grubu) — başlık + tıklanabilir öğeler.
class _ModuleGroup {
  final String title;
  final List<MenuItem> items;
  const _ModuleGroup(this.title, this.items);
}
