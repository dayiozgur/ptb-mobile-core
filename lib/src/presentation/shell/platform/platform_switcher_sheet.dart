import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Platform (Windows-OS "uygulama") değiştirici alt-sayfa.
///
/// Eski in-line switcher iki kusurluydu: (1) kaydırılamaz `Column` → çok
/// platformda RenderFlex overflow; (2) `iconUrl`/`color` çekiliyor ama yok
/// sayılıyor → hepsi aynı gri ikon. Bu sürüm **kaydırılabilir** (maxHeight
/// sınırlı + ListView) ve her platformu kendi **logosu + marka rengiyle**
/// (+ deneme/durum rozeti, aktif işareti) gösterir.
Future<void> showPlatformSwitcher(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PlatformSwitcherSheet(),
  );
}

class _PlatformSwitcherSheet extends StatelessWidget {
  const _PlatformSwitcherSheet();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final maxH = MediaQuery.of(context).size.height * 0.75;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sürükleme tutamacı
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.systemGray4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Platform Değiştir', style: AppTypography.title3),
              ),
            ),
            const Divider(height: 1),
            Flexible(
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
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Erişilebilir platform yok'),
                    );
                  }
                  final activeId = sl<PlatformContext>().activePlatformId;
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: platforms.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (ctx, i) => _tile(
                      ctx,
                      platforms[i],
                      platforms[i].platformId == activeId,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext ctx, PlatformCatalogEntry p, bool active) {
    final color = _hex(p.color) ?? AppColors.primary;
    return ListTile(
      leading: _logo(p, color),
      title: Text(p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.headline),
      subtitle: p.code.isNotEmpty
          ? Text(p.code, style: AppTypography.footnote)
          : null,
      trailing: active
          ? const Icon(Icons.check_circle, color: Color(0xFF16A34A))
          : (p.isTrial
              ? _badge('Deneme', const Color(0xFFD97706))
              : null),
      onTap: () {
        Navigator.of(ctx).pop();
        final activeId = sl<PlatformContext>().activePlatformId;
        if (p.platformId != activeId) {
          sl<PlatformContext>().setActivePlatform(p.platformId, code: p.code);
        }
      },
    );
  }

  /// Platform logosu: iconUrl (http) varsa network, yoksa marka-renkli baş harf.
  Widget _logo(PlatformCatalogEntry p, Color color) {
    Widget fallback() => Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            (p.code.isNotEmpty ? p.code : p.name).characters.first.toUpperCase(),
            style: AppTypography.headline.copyWith(color: color),
          ),
        );
    final url = p.iconUrl;
    if (url != null && url.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      );
    }
    return fallback();
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: AppTypography.caption1
                .copyWith(color: color, fontWeight: FontWeight.w600)),
      );

  /// "#RRGGBB" / "RRGGBB" → Color (geçersizse null).
  Color? _hex(String? raw) {
    if (raw == null) return null;
    var h = raw.trim().replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }
}
