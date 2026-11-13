import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// Honest placeholder for a path that has no mobile screen — never a 404, a
/// crash or a blank page.
///
/// Two wordings:
///  * default — "coming soon on mobile" (a menu path the app has not built yet);
///  * [webOnly] — "this page is in the web app" (a path that is deliberately
///    web-only: builders, setup wizards, the Microsoft 365 hub pages…).
///
/// Both offer **Open on the web** when the app knows its web origin
/// ([InAppRoute.webOrigin]); otherwise they only explain. [titleKey] is the
/// menu title's i18n key (resolved through [LocalizationService]).
class ComingSoonScreen extends StatelessWidget {
  /// Menü başlığı (i18n anahtarı veya düz metin).
  final String titleKey;

  /// Web yolu (web'de aç düğmesinin hedefi).
  final String? path;

  /// İkon (bootstrap `bi-*` sınıfı) — çözümlenip gösterilir.
  final String? icon;

  /// The path is known to be web-only (not "coming soon").
  final bool webOnly;

  const ComingSoonScreen({
    super.key,
    required this.titleKey,
    this.path,
    this.icon,
    this.webOnly = false,
  });

  /// Open [url] in a browser. Android: an in-app browser tab — an external
  /// VIEW intent for the app's own verified host would be routed straight back
  /// into the app. iOS: the system does not hand an app its own universal
  /// link, so the external browser is used.
  static Future<bool> openOnWeb(Uri url) async {
    try {
      final android =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      return await launchUrl(
        url,
        mode: android
            ? LaunchMode.inAppBrowserView
            : LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = sl<LocalizationService>();
    final title = loc.translate(titleKey);
    final iconData = webOnly && (icon == null || icon!.isEmpty)
        ? Icons.desktop_windows_outlined
        : BootstrapIconMap.resolve(icon);
    final webUrl = InAppRoute.webUrlFor(path);

    // AppScaffold ŞART: diğer tüm ekranlar gibi Scaffold/Material/AppBar sağlar.
    // Öncesinde salt `Center` dönüyordu → Material atası yoktu → metin "Material
    // yok" debug stilinde (kırmızı + sarı altçizgi) render oluyor ve geri butonu
    // olmuyordu. AppScaffold `showBackButton` (varsayılan true) + pushed-route →
    // otomatik geri butonu + tutarlı tema.
    return AppScaffold(
      title: title,
      child: Center(
        child: SingleChildScrollView(
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
                loc.translate(webOnly
                    ? 'common.web_only.title'
                    : 'common.coming_soon'),
                textAlign: TextAlign.center,
                style: AppTypography.title3,
              ),
              const SizedBox(height: 8),
              Text(
                loc.translate(webOnly
                    ? 'common.web_only.message'
                    : 'common.coming_soon_mobile'),
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryLabel(context),
                ),
              ),
              if (webUrl != null) ...[
                const SizedBox(height: 20),
                AppButton(
                  key: const ValueKey('open-on-web'),
                  label: loc.translate('common.open_on_web'),
                  icon: Icons.open_in_new,
                  isFullWidth: false,
                  variant: webOnly
                      ? AppButtonVariant.primary
                      : AppButtonVariant.secondary,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    final ok = await openOnWeb(webUrl);
                    if (!ok) {
                      messenger?.showSnackBar(SnackBar(
                        content: Text(
                            loc.translate('common.web_only.open_failed')),
                      ));
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  webUrl.host,
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.tertiaryLabel(context),
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
