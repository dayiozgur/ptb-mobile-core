import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Bir menü öğesinin henüz mobil ekranı yoksa gösterilen zarif placeholder.
///
/// M1'de DB-menüsü tüm platform öğelerini yüzeye çıkarır; mobil karşılığı
/// olmayan yollar 404/crash yerine buraya düşer. [titleKey] menü başlığının
/// i18n anahtarıdır (LocalizationService ile çözülür).
class ComingSoonScreen extends StatelessWidget {
  /// Menü başlığı (i18n anahtarı veya düz metin).
  final String titleKey;

  /// Web yolu (bilgi amaçlı gösterilir).
  final String? path;

  /// İkon (bootstrap `bi-*` sınıfı) — çözümlenip gösterilir.
  final String? icon;

  const ComingSoonScreen({
    super.key,
    required this.titleKey,
    this.path,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final loc = sl<LocalizationService>();
    final title = loc.translate(titleKey);
    final iconData = BootstrapIconMap.resolve(icon);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconData, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title2,
            ),
            const SizedBox(height: 8),
            Text(
              loc.translate('common.coming_soon'),
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryLabel(context),
              ),
            ),
            if (path != null && path!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  path!,
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
