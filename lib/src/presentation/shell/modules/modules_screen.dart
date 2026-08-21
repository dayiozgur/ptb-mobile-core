import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// DB-menü ağacının tam gezgini — sabit alt-nav sekmesi ("Modüller").
///
/// Eski modelde entity-yaprakları alt-nav'a tıkıştırılıyordu; bu ekran onların
/// yerine geçer: aktif platformun `platform_menu_items` ağacını (coarse rol
/// filtreli) baştan sona gösterir. Ağaç yalnızca mobil ekranı ÇÖZÜLEBİLEN
/// öğelere budanır (bkz. [_pruneToScreens]) — böylece web-admin "Yakında"
/// placeholder'larıyla dolmaz.
///
/// Platform değişince (platform switch) menü canlı yeniden yüklenir.
class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  /// Rol-filtreli + ekrana-budanmış üst seviye menü ağacı.
  List<MenuItem> _tree = [];
  bool _loading = true;

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

  String _t(String key) => sl<LocalizationService>().translate(key);

  Future<void> _loadMenu({bool forceRefresh = false}) async {
    if (mounted) setState(() => _loading = true);
    List<MenuItem> tree;
    try {
      final role = await sl<PermissionService>().getCoarseRole();
      final platformId = sl<PlatformContext>().activePlatformId;
      tree = await sl<MobileMenuService>().loadMenu(
        platformId: platformId,
        coarseRole: role,
        forceRefresh: forceRefresh,
      );
    } catch (_) {
      tree = const [];
    }

    // Yalnızca mobil ekranı OLAN öğelere buda (main_shell ile aynı semantik).
    final pruned = _pruneToScreens(tree);

    if (!mounted) return;
    setState(() {
      _tree = pruned;
      _loading = false;
    });
  }

  /// Ağacı yalnızca mobil ekranı OLAN öğelere buda: bir düğüm kendi ekranına
  /// çözülürse VEYA budandıktan sonra çocuğu kalırsa tutulur; aksi halde
  /// (ör. ekranı olmayan grup başlığı / yaprak) çıkarılır. main_shell_screen
  /// `_pruneToScreens` ile birebir aynıdır.
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

  /// Bir yaprağı aç: menü öğesini mobil ekrana çözüp yeni route'a it.
  void _openLeaf(MenuItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ScreenResolver.resolve(item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Modüller',
        showBackButton: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_tree.isEmpty) {
      return const AppScaffold(
        title: 'Modüller',
        showBackButton: false,
        child: Center(child: Text('Modül bulunamadı')),
      );
    }

    return AppScaffold(
      title: 'Modüller',
      showBackButton: false,
      child: ListView(
        children: _tree.map(_buildNode).toList(),
      ),
    );
  }

  /// Üst seviye düğüm: çocuğu varsa [ExpansionTile], yoksa yaprak [ListTile].
  Widget _buildNode(MenuItem item) {
    if (item.hasChildren) {
      return ExpansionTile(
        leading: Icon(BootstrapIconMap.resolve(item.icon)),
        title: Text(_t(item.title)),
        childrenPadding: const EdgeInsets.only(left: 16),
        children: [
          // Grubun kendi ekranı da varsa onu da bir yaprak olarak göster.
          if (item.hasPath && ScreenResolver.hasScreen(item.path))
            _buildLeaf(item),
          ...item.children.map(_buildLeaf),
        ],
      );
    }
    return _buildLeaf(item);
  }

  /// Yaprak öğe → tıklanınca ekranını yeni route olarak açar.
  Widget _buildLeaf(MenuItem item) {
    final hasScreen = item.hasPath && ScreenResolver.hasScreen(item.path);
    return ListTile(
      leading: Icon(BootstrapIconMap.resolve(item.icon)),
      title: Text(_t(item.title)),
      trailing: hasScreen ? const Icon(Icons.chevron_right) : null,
      enabled: hasScreen && !item.disabled,
      onTap: hasScreen && !item.disabled ? () => _openLeaf(item) : null,
    );
  }
}
