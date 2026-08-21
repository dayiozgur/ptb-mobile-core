import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// **Modüller** — aktif platformun tüm modüllerini kategori bölümleri + renkli
/// ikon ızgarası olarak gösteren gezgin (sidebar'dan açılır).
///
/// Web sidebar'ındaki grup yapısını (Kayıtlar/Self-Servis/…) yansıtır; her
/// modül stabil bir renk + yol/başlıktan türetilen anlamlı ikon alır. Ağaç
/// yalnız mobil ekranı ÇÖZÜLEBİLEN öğelere budanır ([_pruneToScreens]).
///
/// **Yönetim (`admin`) grubu mobilde devre dışı**: konsol/builder işleri (sayfa/
/// rapor/iş-akışı tasarımcısı, roller, entegrasyon, audit…) web konsolunda
/// yönetilir — bu grup mobil menüden gizlenir ([_kMobileDisabledGroupKeys]).
///
/// Platform değişince menü canlı yeniden yüklenir.
class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  List<_ModuleGroup> _groups = const [];
  bool _loading = true;

  StreamSubscription<String>? _platformSub;

  @override
  void initState() {
    super.initState();
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
    final groups = _collectGroups(tree);
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  // ============================================
  // GRUPLAMA
  // ============================================

  /// Menü ağacından kategorize modül bölümleri topla (Ana Sayfa'daki eski
  /// mantığın taşınmış hâli). Mobilde devre-dışı gruplar ([admin]) atlanır.
  List<_ModuleGroup> _collectGroups(List<MenuItem> tree) {
    final groups = <_ModuleGroup>[];
    final general = <MenuItem>[];
    final seen = <String>{};

    bool resolvable(MenuItem i) =>
        i.hasPath && ScreenResolver.hasScreen(i.path);

    for (final item in tree) {
      if (_kMobileDisabledGroupKeys.contains(item.itemKey)) continue;
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

  void _openModule(MenuItem item) {
    if (!item.hasPath || !ScreenResolver.hasScreen(item.path)) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ScreenResolver.resolve(item)),
    );
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Modüller',
      actions: [AppIconButton(icon: Icons.refresh, onPressed: _loadMenu)],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMenu,
              child: _groups.isEmpty
                  ? _emptyState()
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: AppSpacing.screenPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var gi = 0; gi < _groups.length; gi++) ...[
                            Padding(
                              padding: EdgeInsets.only(
                                  top: gi == 0 ? 0 : AppSpacing.lg),
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
                              children:
                                  _groups[gi].items.map(_buildModuleTile).toList(),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
            ),
    );
  }

  Widget _emptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: const Center(
            child: AppEmptyState(
              icon: Icons.grid_view_outlined,
              title: 'Görüntülenecek modül yok',
            ),
          ),
        ),
      ),
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
  // GÖRSELLİK (renk + anlamlı ikon) — Ana Sayfa'dan taşındı
  // ============================================

  static const List<Color> _palette = [
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFEC4899),
    Color(0xFF0891B2),
    Color(0xFF84CC16),
  ];

  Color _moduleColor(MenuItem item) {
    var h = 0;
    for (final c in item.itemKey.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

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

/// Mobilde gizlenen üst-seviye menü grupları (item_key). `admin` = "Yönetim"
/// (konsol/builder işleri) → web konsolunda yönetilir.
const Set<String> _kMobileDisabledGroupKeys = {'admin'};

/// Modül bölümü (menü grubu) — başlık + tıklanabilir öğeler.
class _ModuleGroup {
  final String title;
  final List<MenuItem> items;
  const _ModuleGroup(this.title, this.items);
}
