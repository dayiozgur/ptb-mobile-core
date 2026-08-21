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
    final comingSoon = loc.translate('common.coming_soon');
    final iconData = BootstrapIconMap.resolve(icon);

    // AppScaffold ŞART: diğer tüm ekranlar gibi Scaffold/Material/AppBar sağlar.
    // Öncesinde salt `Center` dönüyordu → Material atası yoktu → metin "Material
    // yok" debug stilinde (kırmızı + sarı altçizgi) render oluyor ve geri butonu
    // olmuyordu. AppScaffold `showBackButton` (varsayılan true) + pushed-route →
    // otomatik geri butonu + tutarlı tema.
    return AppScaffold(
      title: title,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(iconData, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                comingSoon,
                textAlign: TextAlign.center,
                style: AppTypography.title3,
              ),
              const SizedBox(height: 8),
              Text(
                'Bu ekran mobilde yakında kullanıma açılacak.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryLabel(context),
                ),
              ),
              if (path != null && path!.isNotEmpty) ...[
                const SizedBox(height: 20),
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
      ),
    );
  }
}
