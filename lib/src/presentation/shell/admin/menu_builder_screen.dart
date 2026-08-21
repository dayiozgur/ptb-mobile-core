import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Admin — Menü Düzenleyici (sürükle-bırak yeniden sıralama) ekranı.
///
/// Web portal `menu-builder` özelliğinin reorder yolunun mobil karşılığı. Etkin
/// platformun ÜST SEVİYE `platform_menu_items` öğelerini listeler; sürükle-bırak
/// ile sıra değiştirildiğinde `sort_order` değerleri eşit aralıklı ((i+1)*10)
/// yeniden numaralandırılır ve DOĞRUDAN UPDATE ile kalıcılaştırılır (web ile aynı
/// yazma yolu; RPC/EF yok). RLS `pmi_update = fn_is_admin()` — yazma admin-kapılı.
///
/// UX: optimistik güncelleme + hata durumunda geri alma + SnackBar. Kalıcılaştırma
/// başarısız olursa (RLS/ağ) liste eski sırasına döner.
class MenuBuilderScreen extends StatefulWidget {
  const MenuBuilderScreen({super.key});

  @override
  State<MenuBuilderScreen> createState() => _MenuBuilderScreenState();
}

class _MenuBuilderScreenState extends State<MenuBuilderScreen> {
  /// Yalnızca üst seviye öğeler (reorder kapsamı).
  List<AdminMenuRow> _items = [];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _t(String key) => sl<LocalizationService>().translate(key);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await sl<MobileMenuService>()
          .listMenuItemsForAdmin(platformContext.activePlatformId);
      // Üst seviye öğeler, sort_order sıralı (servis zaten sıralı döndürür).
      final topLevel = rows.where((r) => r.isTopLevel).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (!mounted) return;
      setState(() {
        _items = topLevel;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Menü öğeleri yüklenemedi';
        _loading = false;
      });
    }
  }

  /// Sürükle-bırak sonrası: yerel listeyi taşı, eşit aralıklı ((i+1)*10) yeniden
  /// numaralandır ve kalıcılaştır. Başarısızlıkta önceki sıraya geri dön.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_saving) return;
    // ReorderableListView index düzeltmesi.
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    final previous = List<AdminMenuRow>.from(_items);

    final reordered = List<AdminMenuRow>.from(_items);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    // Eşit aralıklı yeniden numaralandırma (backlog deseni): (index+1)*10.
    final renumbered = <AdminMenuRow>[];
    final updates = <AdminMenuOrderUpdate>[];
    for (var i = 0; i < reordered.length; i++) {
      final newOrder = (i + 1) * 10;
      renumbered.add(reordered[i].copyWith(sortOrder: newOrder));
      updates.add(AdminMenuOrderUpdate(id: reordered[i].id, sortOrder: newOrder));
    }

    // Optimistik.
    setState(() {
      _items = renumbered;
      _saving = true;
    });

    try {
      await sl<MobileMenuService>().reorderMenuItems(updates);
      // Cache'i geçersiz kıl — sidebar bir sonraki yüklemede yeni sırayı okur.
      await sl<MobileMenuService>()
          .invalidateCache(platformContext.activePlatformId);
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Sıra kaydedildi');
    } catch (e) {
      if (!mounted) return;
      // Geri al.
      setState(() {
        _items = previous;
        _saving = false;
      });
      _showSnack('Sıra kaydedilemedi');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Menü Düzenleyici',
      showBackButton: true,
      // CRITICAL: ReorderableListView (bounded) doğrudan scaffold body — kaydırma
      // içinde unbounded Flex/Row(stretch) YOK.
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildMessage(context, Icons.error_outline, _error!, retry: true);
    }
    if (_items.isEmpty) {
      return _buildMessage(context, Icons.menu_open, 'Öğe yok');
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _items.length,
      onReorder: _onReorder,
      itemBuilder: (context, i) => _buildTile(context, _items[i], i),
    );
  }

  Widget _buildTile(BuildContext context, AdminMenuRow item, int index) {
    // Her çocuğun benzersiz Key'i olmalı (ReorderableListView zorunluluğu).
    return Padding(
      key: ValueKey(item.id),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        variant: AppCardVariant.outlined,
        child: Row(
          children: [
            // Sıra numarası rozeti.
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.secondaryLabel(context).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${index + 1}',
                style: AppTypography.subhead.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              BootstrapIconMap.resolve(item.icon),
              size: 20,
              color: AppColors.textPrimary(Theme.of(context).brightness),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _t(item.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: item.active
                          ? AppColors.textPrimary(Theme.of(context).brightness)
                          : AppColors.secondaryLabel(context),
                    ),
                  ),
                  if (item.path != null && item.path!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.path!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.secondaryLabel(context)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Sürükle tutamacı (index → ReorderableDragStartListener).
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: AppColors.secondaryLabel(context),
                semanticLabel: 'Sıra',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(BuildContext context, IconData icon, String message,
      {bool retry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.secondaryLabel(context)),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTypography.body
                .copyWith(color: AppColors.secondaryLabel(context)),
          ),
          if (retry) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: _load, child: const Text('Tekrar dene')),
          ],
        ],
      ),
    );
  }
}
