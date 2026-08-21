import 'dart:async';

import 'package:flutter/material.dart';
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
  final String label;
  final Widget Function() build;
  const _NavDest(this.icon, this.label, this.build);
}

class _MainShellScreenState extends State<MainShellScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  int _unreadCount = 0;
  StreamSubscription<int>? _unreadSub;

  List<MenuItem> _tree = [];
  StreamSubscription<String>? _platformSub;

  // Alt-nav hedefleri (sabit çekirdek; ileride DB/kullanıcı-seçimi ile dinamik).
  late final List<_NavDest> _dests = [
    _NavDest(Icons.home_outlined, 'Ana Sayfa',
        () => const HomeScreen(embedded: true)),
    _NavDest(Icons.workspaces_outline, 'My Space',
        () => const MySpaceScreen(embedded: true)),
    _NavDest(Icons.person_outline, 'Profil',
        () => const ProfileHubScreen(embedded: true)),
    _NavDest(Icons.settings_outlined, 'Ayarlar',
        () => const SettingsScreen(embedded: true)),
  ];

  @override
  void initState() {
    super.initState();
    _loadRole();
    _initUnread();
    _loadMenu();
    _platformSub = sl<PlatformContext>().platformStream.listen((_) {
      _loadMenu(forceRefresh: true);
    });
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
      await sl<NotificationService>().startListening(uid);
    } catch (_) {}
    _unreadSub = sl<NotificationService>().unreadCountStream.listen((c) {
      if (mounted) setState(() => _unreadCount = c);
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
    return MainShellScope(
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
            _dests[_currentIndex].label,
            style: AppTypography.headline
                .copyWith(color: AppColors.textPrimary(brightness)),
          ),
          actions: [
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
            IconButton(
              icon: const Icon(Icons.apps),
              tooltip: 'Platform Değiştir',
              onPressed: () => showPlatformSwitcher(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        drawer: _buildDrawer(brightness),
        body: IndexedStack(
          index: _currentIndex,
          children: [for (final d in _dests) d.build()],
        ),
        bottomNavigationBar: AppBottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _select,
          items: [
            for (var i = 0; i < _dests.length; i++)
              AppBottomNavItem(icon: _dests[i].icon, label: _dests[i].label),
          ],
        ),
      ),
    );
  }

  // ============================================
  // DİNAMİK SIDEBAR (web-benzeri DB-menü ağacı)
  // ============================================

  Widget _buildDrawer(Brightness brightness) {
    // Mobilde devre-dışı gruplar (ör. "Yönetim"/`admin` = konsol/builder işleri;
    // web konsolunda yönetilir) sidebar'dan gizlenir.
    final groups = _tree
        .where((it) => !_kMobileDisabledGroupKeys.contains(it.itemKey))
        .toList();

    final tiles = <Widget>[
      // Modüller — tüm modül ızgarasına hızlı erişim (profil kartı kaldırıldı).
      ListTile(
        leading: Icon(Icons.grid_view_rounded, color: AppColors.primary),
        title: const Text('Modüller'),
        onTap: () {
          Navigator.of(context).pop();
          _push(const ModulesScreen());
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
            // Çalışma alanı — Tenant + Organizasyon değiştiriciler.
            ListTile(
              dense: true,
              leading: const Icon(Icons.apartment_outlined),
              title: const Text('Tenant değiştir'),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.of(context).pop();
                _push(const TenantSelectorScreen());
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.business_outlined),
              title: const Text('Organizasyon değiştir'),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.of(context).pop();
                _push(const OrganizationSelectorScreen());
              },
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

}

/// Mobilde gizlenen üst-seviye menü grupları (item_key). `admin` = "Yönetim"
/// (konsol/builder işleri: sayfa/rapor/iş-akışı tasarımcısı, roller, entegrasyon,
/// audit…) → web konsolunda yönetilir, mobilde gösterilmez.
const Set<String> _kMobileDisabledGroupKeys = {'admin'};
