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

  // Sidebar LinkedIn-tarzı profil kartı için kimlik.
  UserProfile? _profile;
  String? _avatarUrl;
  StreamSubscription<UserProfile?>? _profileSub;

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
    _loadProfile();
    _profileSub = sl<ProfileService>().profileStream.listen((p) {
      if (p != null) _applyProfile(p);
    });
    _platformSub = sl<PlatformContext>().platformStream.listen((_) {
      _loadMenu(forceRefresh: true);
    });
  }

  Future<void> _loadProfile() async {
    final p = await sl<ProfileService>().getProfileBundle();
    if (p != null) await _applyProfile(p);
  }

  Future<void> _applyProfile(UserProfile p) async {
    final avatar = await sl<FileStorageService>().getAvatarUrl(p.avatarUrl);
    if (!mounted) return;
    setState(() {
      _profile = p;
      _avatarUrl = avatar;
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
    _profileSub?.cancel();
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
    final tiles = <Widget>[
      _buildProfileHeader(brightness),
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
    }

    return Drawer(child: SafeArea(child: ListView(children: tiles)));
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

  /// Sidebar başlığı = LinkedIn-tarzı profil kartı (avatar + ad + headline +
  /// "Profili görüntüle"). Dokununca Profil sekmesine geçer.
  Widget _buildProfileHeader(Brightness brightness) {
    final name = _profile?.displayName ?? '';
    return Material(
      color: AppColors.primary,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          _select(2); // Profil sekmesi
        },
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 12, 16),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: _avatarUrl,
                  name: name.isEmpty ? 'U' : name,
                  size: AppAvatarSize.large,
                  showBorder: true,
                  borderColor: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name.isEmpty ? '...' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headline.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _drawerHeadline(_profile),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.footnote
                            .copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Profili görüntüle',
                              style: AppTypography.caption1
                                  .copyWith(color: Colors.white)),
                          const Icon(Icons.chevron_right,
                              size: 16, color: Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _drawerHeadline(UserProfile? p) {
    if (p == null) return '';
    final bio = (p.bio ?? '').trim();
    if (bio.isNotEmpty) return bio;
    final role = _roleLabelShort(p.coarseRole);
    final tenant = (p.tenantName ?? '').trim();
    if (role.isNotEmpty && tenant.isNotEmpty) return '$role · $tenant';
    if (role.isNotEmpty) return role;
    return p.email;
  }

  String _roleLabelShort(String? r) {
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
}
