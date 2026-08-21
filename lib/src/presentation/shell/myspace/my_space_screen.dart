import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// "My Space" — kullanıcının KİŞİSEL / self-servis merkezi (sabit alt-nav sekmesi).
///
/// Web karşılığı `my-space` (personal ESS landing). Aktif kullanıcının kendi
/// self-servis öğelerini (izin, bordro, PDKS, onboarding, onaylar, avans/masraf
/// vb.) dostane bir kişisel panoda yüzeye çıkarır.
///
/// Öğeler DB-menüden (`platform_menu_items` + entity sentezi) türetilir:
///   1. Önce itemKey/başlığı 'self'|'kendim'|'ess'|'my-space'|'benim' ile eşleşen
///      bir menü GRUBUNUN altındaki (ekrana çözülebilen) öğeler,
///   2. yoksa yolu (`my-`, `/self`, `leave/my`, `payroll/my`, `pdks`, `izin`,
///      `bordro`, `onboarding`, `approvals`, `/mesai` …) eşleşen yapraklar,
///   3. o da yoksa ekrana çözülebilen TÜM yapraklar (sekme asla boş kalmasın).
///
/// Embedded (`embedded == true`): dış shell zaten AppBar/drawer/bottomNav sağlar;
/// bu durumda kendi AppBar'ımızı GÖSTERMEYİZ (`showAppBar: !embedded`).
class MySpaceScreen extends StatefulWidget {
  const MySpaceScreen({super.key, this.embedded = false});

  /// Dış shell içinde gömülü mü render ediliyor? true → kendi AppBar'ı yok.
  final bool embedded;

  @override
  State<MySpaceScreen> createState() => _MySpaceScreenState();
}

class _MySpaceScreenState extends State<MySpaceScreen> {
  /// itemKey / title bu anahtarlardan birini içeren düğüm = self-servis GRUP.
  static const List<String> _groupKeywords = [
    'self',
    'kendim',
    'ess',
    'my-space',
    'benim',
  ];

  /// Yol (path) bu parçalardan birini içeren yaprak = self-servis öğe (fallback).
  static const List<String> _pathHints = [
    'my-',
    '/self',
    'leave/my',
    'payroll/my',
    'my-payslip',
    'pdks',
    'onboarding',
    'approvals',
    '/mesai',
    'izin',
    'bordro',
  ];

  bool _loading = true;
  UserProfile? _profile;
  String? _avatarUrl;
  List<MenuItem> _items = const [];

  StreamSubscription<String>? _platformSub;

  @override
  void initState() {
    super.initState();
    // Platform değişince (platform switch) kişisel öğeleri yeniden yükle.
    _platformSub = sl<PlatformContext>().platformStream.listen((_) {
      _load(forceRefresh: true);
    });
    _load();
  }

  @override
  void dispose() {
    _platformSub?.cancel();
    super.dispose();
  }

  String _t(String key) {
    try {
      return sl<LocalizationService>().translate(key);
    } catch (_) {
      return key;
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (mounted) setState(() => _loading = true);

    // 1) Kişilik başlığı — Profil Hub ile aynı kaynak: bundle + signed avatar.
    UserProfile? profile;
    String? avatar;
    try {
      profile = await profileService.getProfileBundle(forceRefresh: forceRefresh);
      avatar = await fileStorageService.getAvatarUrl(profile?.avatarUrl);
    } catch (_) {
      profile = null;
      avatar = null;
    }

    // 2) DB-menü → self-servis öğe seçimi.
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

    final selected = _selectSelfServiceItems(tree);

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _avatarUrl = avatar;
      _items = selected;
      _loading = false;
    });
  }

  /// Menü ağacından kişisel/self-servis öğeleri seç (bkz. sınıf dokümanı).
  List<MenuItem> _selectSelfServiceItems(List<MenuItem> tree) {
    // (a) self-servis GRUBU altındaki çözülebilen öğeler.
    final grouped = <MenuItem>[];
    void scanGroups(List<MenuItem> items) {
      for (final it in items) {
        if (_matchesGroupKeyword(it)) {
          grouped.addAll(_collectResolvable(it));
        }
        if (it.hasChildren) scanGroups(it.children);
      }
    }

    scanGroups(tree);
    final byGroup = _dedupe(grouped);
    if (byGroup.isNotEmpty) return byGroup;

    // (b) fallback: yolu ipuçlarından birini içeren çözülebilen yapraklar.
    final all = _dedupe(_collectResolvable(_wrap(tree)));
    final byPath = all.where((it) {
      final p = (it.path ?? '').toLowerCase();
      return _pathHints.any((h) => p.contains(h));
    }).toList();
    if (byPath.isNotEmpty) return byPath;

    // (c) son çare: ekrana çözülebilen TÜM öğeler (sekme boş kalmasın).
    return all;
  }

  /// Bir düğümü ve alt ağacını sarmalayan sanal kök (tek çağrıda hepsini gez).
  MenuItem _wrap(List<MenuItem> children) =>
      MenuItem(itemKey: '__root__', title: '', children: children);

  /// [item] itemKey ya da başlığı self-servis anahtarlarından birini içeriyor mu?
  bool _matchesGroupKeyword(MenuItem item) {
    final key = item.itemKey.toLowerCase();
    final title = item.title.toLowerCase();
    // Menü başlığı çoğunlukla i18n anahtarı; çözülmüş metnini de dene.
    final translated = _t(item.title).toLowerCase();
    return _groupKeywords.any(
      (k) => key.contains(k) || title.contains(k) || translated.contains(k),
    );
  }

  /// [item] alt ağacındaki, mobil ekrana ÇÖZÜLEBİLEN öğeleri topla
  /// (kendisi de yola sahip ve çözülebilirse dahil).
  List<MenuItem> _collectResolvable(MenuItem item) {
    final out = <MenuItem>[];
    if (item.hasPath &&
        !item.disabled &&
        ScreenResolver.hasScreen(item.path)) {
      out.add(item);
    }
    for (final child in item.children) {
      out.addAll(_collectResolvable(child));
    }
    return out;
  }

  /// itemKey + path'e göre tekilleştir (sırayı koru).
  List<MenuItem> _dedupe(List<MenuItem> items) {
    final seen = <String>{};
    final out = <MenuItem>[];
    for (final it in items) {
      final id = '${it.itemKey}|${it.path}';
      if (seen.add(id)) out.add(it);
    }
    return out;
  }

  void _open(MenuItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ScreenResolver.resolve(item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showAppBar: !widget.embedded,
      title: 'My Space',
      showBackButton: false,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(forceRefresh: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreeting(context),
                    const SizedBox(height: AppSpacing.lg),
                    if (_items.isEmpty)
                      _buildEmptyState(context)
                    else
                      _buildItemsGrid(context),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
    );
  }

  /// Kişilik başlığı: signed avatar + "Merhaba, {displayName}".
  Widget _buildGreeting(BuildContext context) {
    final name = _profile?.displayName ??
        authService.currentUser?.email ??
        'Kullanıcı';
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            AppAvatar(
              imageUrl: _avatarUrl,
              name: name,
              size: AppAvatarSize.large,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Merhaba,',
                    style: AppTypography.subheadline.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Self-servis öğe grid'i. GridView shrinkWrap + NeverScrollable — scroll view
  /// içinde sınırsız-yükseklik Flex hatasından kaçınır.
  Widget _buildItemsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Kişisel'),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.05,
          children: _items.map((it) => _buildItemCard(context, it)).toList(),
        ),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, MenuItem item) {
    return AppCard(
      onTap: () => _open(item),
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                BootstrapIconMap.resolve(item.icon),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _t(item.title),
              style: AppTypography.subheadline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Icon(Icons.inbox_outlined,
                color: AppColors.secondaryLabel(context)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Kişisel öğe bulunamadı',
                style: AppTypography.subheadline.copyWith(
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
