import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';


/// MainShellScreen tab index'ini alt widget'lardan degistirmek icin
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

/// DB-menü sürücülü ana kabuk (Windows-OS modeli).
///
/// Bottom-nav ve drawer, `platform_menu_items`'tan (aktif platform + coarse
/// rol filtresi) türetilir. Hardcoded 5 tab KALDIRILDI. Menü boş/başarısız
/// olursa çekirdek ekranlara (fallback) düşer — uygulama çalışır kalır.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Rol-filtreli üst seviye menü ağacı (drawer için).
  List<MenuItem> _tree = [];

  /// Yol'u olan (navigasyon edilebilir) düz öğe listesi (nav index kaynağı).
  List<MenuItem> _navItems = [];

  int _currentIndex = 0;
  bool _initialTabDone = false;
  final Set<int> _visited = {0};
  bool _loading = true;
  String? _coarseRole;

  int _activeAlarmCount = 0;
  StreamSubscription<String>? _platformSub;

  @override
  void initState() {
    super.initState();
    // Aktif platform değişince menüyü yeniden kur (platform switch).
    _platformSub = sl<PlatformContext>().platformStream.listen((_) {
      _loadMenu(forceRefresh: true);
    });
    _loadMenu();
  }

  @override
  void dispose() {
    _platformSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMenu({bool forceRefresh = false}) async {
    if (mounted) setState(() => _loading = true);
    try {
      final role = await sl<PermissionService>().getCoarseRole();
      final platformId = sl<PlatformContext>().activePlatformId;

      List<MenuItem> tree;
      try {
        tree = await sl<MobileMenuService>().loadMenu(
          platformId: platformId,
          coarseRole: role,
          forceRefresh: forceRefresh,
        );
      } catch (_) {
        tree = const [];
      }

      if (tree.isEmpty) tree = _fallbackMenu();

      // Mobil = salt-okuma monitoring viewer: mobil ekranı olmayan web-admin
      // öğelerini (configuration/management/mail-system/… → "Yakında") menüden
      // çıkar. Budama her şeyi eleyecek olursa ham ağacı koru (güvenlik).
      final pruned = _pruneToScreens(tree);
      if (pruned.isNotEmpty) tree = pruned;

      final nav = _flattenNavigable(tree);

      // Router guard'ı için rolü yayınla (senkron okunur).
      _coarseRole = role;
      sessionCoarseRole.value = role;

      if (!mounted) return;
      setState(() {
        _tree = tree;
        _navItems = nav;
        // Varsayılan sekme: ilk menü öğesi (çoğunlukla my-space ComingSoon)
        // yerine Gösterge Paneli. Yalnız İLK yüklemede uygulanır; platform
        // değişiminde kullanıcının seçtiği sekme korunur.
        if (!_initialTabDone) {
          final dashIdx = nav.indexWhere((m) => m.path == '/dashboard');
          if (dashIdx >= 0) _currentIndex = dashIdx;
          _initialTabDone = true;
        }
        _currentIndex = _currentIndex.clamp(0, (nav.length - 1).clamp(0, 999));
        _visited.add(_currentIndex);
        _loading = false;
      });

      _loadAlarmCount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tree = _fallbackMenu();
        _navItems = _flattenNavigable(_tree);
        _loading = false;
      });
    }
  }

  /// Ağacı, mobil ekranı OLAN öğelerin düz (depth-first) listesine indir.
  /// Kendi yolu ekrana çözülmeyen (yalnız çocukları için tutulan) grup
  /// başlıkları nav'a eklenmez — aksi halde ComingSoon placeholder'ı olurdu.
  List<MenuItem> _flattenNavigable(List<MenuItem> tree) {
    final out = <MenuItem>[];
    void walk(List<MenuItem> items) {
      for (final it in items) {
        if (it.hasPath && ScreenResolver.hasScreen(it.path)) out.add(it);
        if (it.hasChildren) walk(it.children);
      }
    }

    walk(tree);
    return out;
  }

  /// Ağacı yalnızca mobil ekranı OLAN öğelere buda: ekranı olmayan yapraklar
  /// ve (kendi ekranı da olmayan) boş gruplar çıkarılır. Böylece mobil menü
  /// web-admin "Yakında" placeholder'larıyla dolmaz.
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

  /// DB menüsü yoksa çekirdek PMS ekranları (uygulama çalışır kalsın).
  List<MenuItem> _fallbackMenu() {
    return const [
      MenuItem(
          itemKey: 'dashboard',
          title: 'nav.dashboard',
          icon: 'bi-speedometer',
          path: '/dashboard'),
      MenuItem(
          itemKey: 'alarm',
          title: 'nav.alarm',
          icon: 'bi-bell',
          path: '/alarm'),
      MenuItem(
          itemKey: 'sites',
          title: 'nav.sites',
          icon: 'bi-building',
          path: '/sites'),
      MenuItem(
          itemKey: 'global-map',
          title: 'nav.global_map',
          icon: 'bi-geo-alt',
          path: '/globalmap'),
      MenuItem(
          itemKey: 'settings',
          title: 'nav.settings',
          icon: 'bi-gear',
          path: '/settings'),
    ];
  }

  Future<void> _loadAlarmCount() async {
    try {
      final orgId = organizationService.currentOrganizationId;
      if (orgId != null) {
        alarmService.setOrganization(orgId);
      }
      final alarms = await alarmService.getActiveAlarms();
      if (mounted) {
        setState(() => _activeAlarmCount = alarms.length);
      }
    } catch (_) {}
  }

  void _selectNav(int index) {
    if (index < 0 || index >= _navItems.length) return;
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
    if (_navItems[index].path == '/alarm' ||
        _navItems[index].path == '/dashboard') {
      _loadAlarmCount();
    }
  }

  void _switchTab(int index) => _selectNav(index);

  String _t(String key) => sl<LocalizationService>().translate(key);

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_navItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_t('nav.dashboard'))),
        body: Center(child: Text(_t('common.no_data'))),
      );
    }

    final activeItem = _navItems[_currentIndex];

    return MainShellScope(
      switchTab: _switchTab,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(_t(activeItem.title)),
          actions: [
            IconButton(
              icon: const Icon(Icons.apps),
              tooltip: _t('platform.switch'),
              onPressed: _showPlatformSwitcher,
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(_navItems.length, (i) {
            if (!_visited.contains(i)) return const SizedBox.shrink();
            return ScreenResolver.resolve(_navItems[i]);
          }),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    final total = _navItems.length;
    final hasMore = total > 5;
    final bottomCount = hasMore ? 4 : total;

    final items = <AppBottomNavItem>[];
    for (var i = 0; i < bottomCount; i++) {
      final item = _navItems[i];
      final isAlarm = item.path == '/alarm' || item.path == '/alarms';
      items.add(AppBottomNavItem(
        icon: BootstrapIconMap.resolve(item.icon),
        label: _t(item.title),
        badgeCount:
            isAlarm && _activeAlarmCount > 0 ? _activeAlarmCount : null,
        showBadge: isAlarm && _activeAlarmCount > 0,
      ));
    }
    if (hasMore) {
      items.add(AppBottomNavItem(
        icon: Icons.more_horiz,
        label: _t('common.more'),
      ));
    }

    // "More" seçiliyken bottom bar'da geçerli index'i sınırla.
    final navIndex = _currentIndex < bottomCount ? _currentIndex : 0;

    return AppBottomNavigationBar(
      currentIndex: navIndex,
      onTap: (index) {
        if (hasMore && index == bottomCount) {
          _scaffoldKey.currentState?.openDrawer();
          return;
        }
        _selectNav(index);
      },
      items: items,
    );
  }

  Widget _buildDrawer() {
    final tiles = <Widget>[
      _buildDrawerHeader(),
    ];

    for (final item in _tree) {
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
      // yol'u ve çocuğu olmayan (ör. bölüm başlığı) öğeler atlanır.
    }

    return Drawer(child: SafeArea(child: ListView(children: tiles)));
  }

  Widget _drawerLeaf(MenuItem item) {
    final index = _navItems.indexWhere((n) => n.itemKey == item.itemKey);
    final selected = index == _currentIndex;
    return ListTile(
      leading: Icon(BootstrapIconMap.resolve(item.icon)),
      title: Text(_t(item.title)),
      selected: selected,
      enabled: !item.disabled,
      onTap: item.disabled
          ? null
          : () {
              Navigator.of(context).pop();
              if (index >= 0) _selectNav(index);
            },
    );
  }

  Widget _buildDrawerHeader() {
    final code = sl<PlatformContext>().activePlatformCode ?? 'PMS';
    return DrawerHeader(
      decoration: BoxDecoration(color: AppColors.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.grid_view, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            code,
            style: AppTypography.title2.copyWith(color: Colors.white),
          ),
          Text(
            _coarseRole ?? '',
            style: AppTypography.footnote.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ============================================
  // PLATFORM SWITCHER
  // ============================================

  Future<void> _showPlatformSwitcher() async {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: FutureBuilder<List<PlatformCatalogEntry>>(
            future: sl<PlatformCatalogService>().getOwnedPlatforms(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final platforms = snap.data ?? const [];
              if (platforms.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_t('platform.none_owned')),
                );
              }
              final activeId = sl<PlatformContext>().activePlatformId;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_t('platform.switch'),
                        style: AppTypography.headline),
                  ),
                  ...platforms.map((p) => ListTile(
                        leading: const Icon(Icons.apps),
                        title: Text(p.name),
                        subtitle: p.code.isNotEmpty ? Text(p.code) : null,
                        trailing: p.platformId == activeId
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : null,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          if (p.platformId != activeId) {
                            sl<PlatformContext>()
                                .setActivePlatform(p.platformId, code: p.code);
                          }
                        },
                      )),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
