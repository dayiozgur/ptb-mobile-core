import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// MainShellScreen sekme index'ini alt widget'lardan değiştirmek için.
class MainShellScope extends InheritedWidget {
  final void Function(int tabIndex) switchTab;

  const MainShellScope({
    super.key,
    required this.switchTab,
    required super.child,
  });

  static MainShellScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainShellScope>();
  }

  @override
  bool updateShouldNotify(MainShellScope oldWidget) => false;
}

/// Global app-shell (WindowsOS mobil modeli).
///
/// **Global chrome shell'e ait** (her sekme aynı üst-bar + sidebar'ı paylaşır):
/// - Üst-bar: hamburger (dinamik sidebar) · arama · AI · bildirim(rozet) · platform.
/// - Sidebar (drawer): **web gibi dinamik** DB-menü ağacı (`platform_menu_items`).
/// - Alt-nav: **Ana Sayfa · My Space · Profil · Ayarlar** (config-liste — ileride
///   DB/kullanıcı-seçimiyle dinamikleştirilebilir).
/// - Sekmeler `embedded:true` → kendi AppBar'ını çizmez (global chrome tek).
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

/// Alt-nav hedefi (config — dinamikleştirmeye hazır).
class _NavDest {
  final IconData icon;

  /// Keyword key of the label (translated when drawn, so a language change
  /// applies without rebuilding the list).
  final String label;
  final Widget Function() build;
  const _NavDest(this.icon, this.label, this.build);
}

class _MainShellScreenState extends State<MainShellScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _tabsKey = GlobalKey();
  int _currentIndex = 0;

  int _unreadCount = 0;
  StreamSubscription<int>? _unreadSub;

  List<MenuItem> _tree = [];
  StreamSubscription<String>? _platformSub;

  // Çalışma alanı (drawer altı): aktif tenant/organizasyon + değiştirilebilir mi.
  String? _tenantName;
  String? _orgName;
  List<Tenant> _tenants = const [];
  List<Organization> _orgs = const [];
  StreamSubscription<Tenant?>? _tenantSub;
  StreamSubscription<Organization?>? _orgSub;

  // Lisans durumu (platform-context `license.accessState`): read_only → bant,
  // locked → ürün ekranları yerine kilit ekranı (hesap/çıkış açık).
  EntitlementService? _entitlement;
  LicenseAccessState _access = LicenseAccessState.full;
  bool _licenseBusy = false;

  // Alt-nav hedefleri (sabit çekirdek; ileride DB/kullanıcı-seçimi ile dinamik).
  late final List<_NavDest> _dests = [
    _NavDest(Icons.home_outlined, 'nav.home',
        () => const HomeScreen(embedded: true)),
    _NavDest(Icons.workspaces_outline, 'nav.my_space',
        () => const MySpaceScreen(embedded: true)),
    _NavDest(Icons.grid_view_outlined, 'nav.modules',
        () => const ModulesScreen(embedded: true)),
    _NavDest(Icons.settings_outlined, 'nav.settings',
        () => const SettingsScreen(embedded: true)),
  ];

  @override
  void initState() {
    super.initState();
    _loadRole();
    _initUnread();
    _loadMenu();
    _loadWorkspace();
    // Duyuru realtime bildirimi: yeni yayınlanan duyuruda yerel-bildirim tetikler.
    _startAnnouncementNotifier();
    _platformSub = sl<PlatformContext>().platformStream.listen((_) {
      _loadMenu(forceRefresh: true);
    });
    _startEntitlement();
    // Tenant/org değişince (switcher veya başka akış) drawer'daki adları tazele
    // + duyuru bildiricisini yeni tenant'a bağla.
    _tenantSub = tenantService.tenantStream.listen((_) {
      _loadWorkspace();
      _startAnnouncementNotifier();
      _entitlement?.refresh(force: true);
    });
    _orgSub = organizationService.organizationStream.listen((_) {
      if (mounted) {
        setState(
            () => _orgName = organizationService.currentOrganization?.name);
      }
    });
  }

  /// Duyuru realtime bildiricisini aktif tenant'a bağla (login/tenant-değişimi)
  /// + APNs push kaydını başlat (izin + token → user_devices).
  void _startAnnouncementNotifier() {
    final tid = tenantService.currentTenantId;
    if (tid != null) {
      announcementNotifier.start(tid);
      apnsRegistrar.register();
    }
  }

  /// Drawer çalışma-alanı bilgisini yükle: aktif tenant/org adları + kaç seçenek
  /// olduğu (tek seçenek → "değiştir" devre dışı). Aktif tenant/org [CoreInitializer]
  /// tarafından profil-bundle'dan set edilir (yeni mekanizma).
  Future<void> _loadWorkspace() async {
    if (mounted) {
      setState(() {
        _tenantName = tenantService.currentTenant?.name;
        _orgName = organizationService.currentOrganization?.name;
      });
    }
    try {
      // forceRefresh: switchable durumu (kaç tenant/org) DB'nin GÜNCEL halini
      // yansıtmalı — cache'lenmiş liste üyelik değişince (ör. bir tenant
      // üyeliği kaldırılınca) yanıltıcı "değiştirilebilir" gösterebilir.
      final uid = authService.currentUser?.id;
      if (uid != null) {
        final tenants =
            await tenantService.getUserTenants(uid, forceRefresh: true);
        if (mounted) setState(() => _tenants = tenants);
      }
      final tid = tenantService.currentTenantId;
      if (tid != null) {
        final orgs =
            await organizationService.getOrganizations(tid, forceRefresh: true);
        if (mounted) setState(() => _orgs = orgs);
      }
    } catch (_) {
      // Sayı çözülemezse switcher yine de aktif isim(ler)i gösterir.
    }
  }

  /// Lisans servisini başlat (giriş sonrası ilk yenileme + platform/resume/yazma-reddi
  /// dinleyicileri servis içinde).
  void _startEntitlement() {
    if (!sl.isRegistered<EntitlementService>()) return;
    final svc = sl<EntitlementService>();
    _entitlement = svc;
    _access = svc.accessState;
    svc.accessStateListenable.addListener(_onAccessChanged);
    svc.start();
  }

  void _onAccessChanged() {
    final next = _entitlement?.accessState ?? LicenseAccessState.full;
    if (!mounted || next == _access) return;
    setState(() => _access = next);
  }

  Future<void> _retryLicense() async {
    final svc = _entitlement;
    if (svc == null || _licenseBusy) return;
    setState(() => _licenseBusy = true);
    try {
      await svc.refresh(force: true);
    } finally {
      if (mounted) setState(() => _licenseBusy = false);
    }
  }

  Future<void> _signOutFromLocked() async {
    await CoreInitializer.signOut();
    if (mounted) context.go('/login');
  }

  String? _graceUntilText() {
    final until = _entitlement?.license?.graceUntil;
    if (until == null) return null;
    final local = until.toLocal();
    try {
      return DateFormat.yMMMd(
              sl<LocalizationService>().currentLocale.languageCode)
          .format(local);
    } catch (_) {
      return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _loadRole() async {
    try {
      final role = await sl<PermissionService>().getCoarseRole();
      sessionCoarseRole.value = role;
    } catch (_) {}
  }

  Future<void> _initUnread() async {
    final uid = authService.currentUser?.id;
    if (uid == null) return;
    try {
      final count = await sl<NotificationService>().getUnreadCount(uid);
      if (mounted) setState(() => _unreadCount = count);
      sl<PushNotificationService>().setBadgeCount(count); // app-icon senkron
      await sl<NotificationService>().startListening(uid);
    } catch (_) {}
    _unreadSub = sl<NotificationService>().unreadCountStream.listen((c) {
      if (mounted) setState(() => _unreadCount = c);
      // Okunmamış sayısı değişince app-icon rozetini de güncelle (okundu →
      // azalır → 0'da kaybolur). In-app zil rozeti zaten _unreadCount ile bağlı.
      sl<PushNotificationService>().setBadgeCount(c);
    });
  }

  /// Dinamik sidebar için DB-menü ağacı (ekranı olan öğelere budanmış).
  Future<void> _loadMenu({bool forceRefresh = false}) async {
    try {
      final role = await sl<PermissionService>().getCoarseRole();
      final platformId = sl<PlatformContext>().activePlatformId;
      final tree = await sl<MobileMenuService>().loadMenu(
        platformId: platformId,
        coarseRole: role,
        forceRefresh: forceRefresh,
      );
      final pruned = _pruneToScreens(tree);
      if (mounted) setState(() => _tree = pruned.isNotEmpty ? pruned : tree);
    } catch (_) {
      // Menü yüklenemezse sidebar boş kalır (shell çalışmaya devam eder).
    }
  }

  List<MenuItem> _pruneToScreens(List<MenuItem> items) {
    final out = <MenuItem>[];
    for (final it in items) {
      final prunedChildren = _pruneToScreens(it.children);
      final ownScreen = it.hasPath && ScreenResolver.hasScreen(it.path);
      if (ownScreen || prunedChildren.isNotEmpty) {
        out.add(it.copyWith(children: prunedChildren));
      }
    }
    return out;
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    _platformSub?.cancel();
    _tenantSub?.cancel();
    _orgSub?.cancel();
    _entitlement?.accessStateListenable.removeListener(_onAccessChanged);
    _entitlement?.stop();
    announcementNotifier.stop();
    super.dispose();
  }

  void _select(int index) {
    setState(() => _currentIndex = index.clamp(0, _dests.length - 1));
  }

  String _t(String key) => sl<LocalizationService>().translate(key);

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final locked = _access == LicenseAccessState.locked;
    final readOnly = _access == LicenseAccessState.readOnly;
    // GlobalKey: bant eklenip kalkınca (ağaç yapısı değişir) sekme state'i korunur.
    final Widget tabs = IndexedStack(
      key: _tabsKey,
      index: _currentIndex,
      children: [for (final d in _dests) d.build()],
    );
    final Widget body;
    if (locked) {
      // Ürün ekranları kapalı; hesap/abonelik, tekrar dene ve çıkış açık.
      body = LicenseLockedView(
        translate: _t,
        busy: _licenseBusy,
        onBilling: () => _push(const AccountHubScreen()),
        onRetry: _retryLicense,
        onSignOut: _signOutFromLocked,
      );
    } else if (readOnly) {
      body = Column(
        children: [
          ReadOnlyLicenseBanner(
            translate: _t,
            graceUntilText: _graceUntilText(),
            onBilling: () => _push(const AccountHubScreen()),
          ),
          Expanded(child: tabs),
        ],
      );
    } else {
      body = tabs;
    }
    // Yasal onay kapısı (web consentActiveGuard): eksik zorunlu onay → onay
    // ekranı; aksi/hata → shell (fail-open).
    return ConsentGate(
      service: sl<ConsentService>(),
      userId: () => authService.currentUser?.id,
      tenantId: () => tenantService.currentTenantId,
      platformId: () => sl<PlatformContext>().activePlatformId,
      translate: _t,
      onSignOut: _signOutFromLocked,
      child: MainShellScope(
        switchTab: _select,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background(brightness),
          appBar: AppBar(
            backgroundColor: AppColors.surface(brightness),
            elevation: 0,
            scrolledUnderElevation: 0.5,
            centerTitle: false,
            title: Text(
              locked
                  ? _t(LicenseKeys.lockedTitle)
                  : _t(_dests[_currentIndex].label),
              style: AppTypography.headline
                  .copyWith(color: AppColors.textPrimary(brightness)),
            ),
            actions: [
              if (!locked) ...[
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Ara',
                  onPressed: () => _push(const GlobalSearchScreen()),
                ),
                IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'AI Asistan',
                  onPressed: () => _push(const AiAssistantScreen()),
                ),
                IconButton(
                  icon: Badge.count(
                    count: _unreadCount,
                    isLabelVisible: _unreadCount > 0,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  tooltip: 'Bildirimler',
                  onPressed: () => _push(const NotificationsScreen()),
                ),
              ],
              // Platform değiştir kilitliyken de açık: kullanıcı lisanslı başka bir
              // platforma geçebilir.
              IconButton(
                icon: const Icon(Icons.apps),
                tooltip: _t('platform.switch_title'),
                onPressed: () => showPlatformSwitcher(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          drawer: _buildDrawer(brightness, locked: locked),
          body: body,
          bottomNavigationBar: locked
              ? null
              : AppBottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: _select,
                  items: [
                    for (var i = 0; i < _dests.length; i++)
                      AppBottomNavItem(
                          icon: _dests[i].icon, label: _t(_dests[i].label)),
                  ],
                ),
        ),
      ),
    );
  }

  // ============================================
  // DİNAMİK SIDEBAR (web-benzeri DB-menü ağacı)
  // ============================================

  Widget _buildDrawer(Brightness brightness, {bool locked = false}) {
    // Mobilde devre-dışı gruplar (ör. "Yönetim"/`admin` = konsol/builder işleri;
    // web konsolunda yönetilir) sidebar'dan gizlenir. Lisans kilitliyken ürün
    // menüsü gösterilmez (yalnız Hesabım + çalışma alanı).
    final groups = locked
        ? const <MenuItem>[]
        : _tree
            .where((it) => !_kMobileDisabledGroupKeys.contains(it.itemKey))
            .toList();

    final tiles = <Widget>[
      // Modüller — tüm modül ızgarasına hızlı erişim (profil kartı kaldırıldı).
      if (!locked)
        ListTile(
          leading: Icon(Icons.grid_view_rounded, color: AppColors.primary),
          title: Text(_t('nav.modules')),
          onTap: () {
            Navigator.of(context).pop();
            _push(const ModulesScreen());
          },
        ),
      // Hesabım — abonelik/krediler/faturalar/kullanım/güvenlik hub'ı.
      ListTile(
        leading: Icon(Icons.account_circle_outlined, color: AppColors.primary),
        title: Text(_t('nav.my_account')),
        onTap: () {
          Navigator.of(context).pop();
          _push(const AccountHubScreen());
        },
      ),
      const Divider(height: 1),
    ];

    for (final item in groups) {
      if (item.hasChildren) {
        tiles.add(ExpansionTile(
          leading: Icon(BootstrapIconMap.resolve(item.icon)),
          title: Text(_t(item.title)),
          childrenPadding: const EdgeInsets.only(left: 16),
          children: [
            if (item.hasPath && ScreenResolver.hasScreen(item.path))
              _drawerLeaf(item),
            ...item.children
                .where((c) => c.hasPath && ScreenResolver.hasScreen(c.path))
                .map(_drawerLeaf),
          ],
        ));
      } else if (item.hasPath && ScreenResolver.hasScreen(item.path)) {
        tiles.add(_drawerLeaf(item));
      }
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: tiles),
            ),
            const Divider(height: 1),
            // Çalışma alanı — aktif Tenant + Organizasyon (adları görünür).
            // Tek seçenek varsa "değiştir" DEVRE DIŞI (seçilemez).
            _workspaceTile(
              icon: Icons.apartment_outlined,
              label: 'Tenant',
              value: _tenantName,
              switchable: _tenants.length > 1,
              onTap: _showTenantSwitcher,
            ),
            _workspaceTile(
              icon: Icons.business_outlined,
              label: 'Organizasyon',
              value: _orgName,
              switchable: _orgs.length > 1,
              onTap: _showOrgSwitcher,
            ),
            const Divider(height: 1),
            // Protoolbag logosu (sidebar altı).
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Image.asset(
                'assets/brand/ptb_logo.png',
                package: 'protoolbag_core',
                height: 26,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerLeaf(MenuItem item) {
    return ListTile(
      leading: Icon(BootstrapIconMap.resolve(item.icon)),
      title: Text(_t(item.title)),
      enabled: !item.disabled,
      onTap: item.disabled
          ? null
          : () {
              Navigator.of(context).pop(); // drawer'ı kapat
              _push(ScreenResolver.resolve(item));
            },
    );
  }

  /// Drawer altı çalışma-alanı satırı: aktif değeri ALT-SATIRDA gösterir. Tek
  /// seçenek varsa devre dışıdır (soluk, chevron yok, tıklanamaz).
  Widget _workspaceTile({
    required IconData icon,
    required String label,
    required String? value,
    required bool switchable,
    required VoidCallback onTap,
  }) {
    final brightness = Theme.of(context).brightness;
    final shown = (value == null || value.trim().isEmpty) ? '—' : value.trim();
    return ListTile(
      dense: true,
      enabled: switchable,
      leading: Icon(icon,
          color: switchable ? null : AppColors.tertiaryLabel(context)),
      title: Text(label,
          style: AppTypography.footnote
              .copyWith(color: AppColors.secondaryLabel(context))),
      subtitle: Text(
        shown,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.subhead.copyWith(
          fontWeight: FontWeight.w600,
          color: switchable
              ? AppColors.textPrimary(brightness)
              : AppColors.tertiaryLabel(context),
        ),
      ),
      trailing: switchable ? const Icon(Icons.unfold_more, size: 18) : null,
      onTap: switchable ? onTap : null,
    );
  }

  void _showTenantSwitcher() {
    Navigator.of(context).pop(); // drawer'ı kapat
    _showWorkspaceSwitcher<Tenant>(
      title: _t('workspace.select_tenant'),
      items: _tenants,
      activeId: tenantService.currentTenantId,
      idOf: (t) => t.id,
      nameOf: (t) => t.name,
      onSelect: (t) async {
        final ok = await CoreInitializer.switchTenant(t.id);
        if (ok) {
          await _loadMenu(forceRefresh: true);
          await _loadRole();
          await _loadWorkspace();
        }
        return ok;
      },
    );
  }

  void _showOrgSwitcher() {
    Navigator.of(context).pop();
    _showWorkspaceSwitcher<Organization>(
      title: _t('org.select_title'),
      items: _orgs,
      activeId: organizationService.currentOrganizationId,
      idOf: (o) => o.id,
      nameOf: (o) => o.name,
      onSelect: (o) async {
        final ok = await CoreInitializer.switchOrganization(o.id);
        if (ok) await _loadWorkspace();
        return ok;
      },
    );
  }

  /// Ortak çalışma-alanı seçici (bottom-sheet). Aktif öğe işaretli; farklı öğeye
  /// dokununca [onSelect] çağrılır (yeni mekanizma: CoreInitializer.switch*).
  void _showWorkspaceSwitcher<T>({
    required String title,
    required List<T> items,
    required String? activeId,
    required String Function(T) idOf,
    required String Function(T) nameOf,
    required Future<bool> Function(T) onSelect,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: AppTypography.headline),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: items.map((it) {
                  final active = idOf(it) == activeId;
                  return ListTile(
                    leading: Icon(
                      active
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: active ? AppColors.primary : null,
                    ),
                    title: Text(nameOf(it)),
                    trailing: active
                        ? Text('Aktif',
                            style: AppTypography.caption1
                                .copyWith(color: AppColors.primary))
                        : null,
                    onTap: () async {
                      Navigator.of(sheetCtx).pop();
                      if (active) return;
                      final ok = await onSelect(it);
                      if (!mounted) return;
                      if (ok) {
                        AppSnackbar.showSuccess(context,
                            message: sl<LocalizationService>().translate(
                                'workspace.selected',
                                params: {'name': nameOf(it)}));
                      } else {
                        AppSnackbar.showError(context,
                            message: _t('workspace.switch_failed'));
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Mobilde gizlenen üst-seviye menü grupları (item_key). `admin` = "Yönetim"
/// (konsol/builder işleri: sayfa/rapor/iş-akışı tasarımcısı, roller, entegrasyon,
/// audit…) → web konsolunda yönetilir, mobilde gösterilmez.
const Set<String> _kMobileDisabledGroupKeys = {'admin'};
