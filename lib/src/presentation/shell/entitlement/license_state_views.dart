import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Çeviri fonksiyonu (shell `LocalizationService.translate` geçirir; testte sahte).
typedef LicenseTranslate = String Function(String key);

/// Lisans durum görünümlerinin kullandığı anahtarlar. Hepsi `keywords` tablosunda
/// web shell ile ORTAK (web `ReadOnlyBannerComponent` / not-licensed sayfası).
class LicenseKeys {
  LicenseKeys._();

  static const readOnlyTitle = 'entitlement.read_only.title';
  static const readOnlyDetail = 'entitlement.read_only.detail';
  static const readOnlyUntil = 'entitlement.read_only.until';
  static const readOnlyBilling = 'entitlement.read_only.billing';

  static const lockedTitle = 'not_licensed.title';
  static const lockedMessage = 'not_licensed.message';
  static const lockedBilling = 'not_licensed.billing';
  static const lockedRetry = 'not_licensed.retry';
  static const lockedSignOut = 'not_licensed.sign_out';
}

/// Salt-okunur (grace) bandı: lisans bitti, veriler güvende ve okunabilir, yazma
/// sunucuda reddedilir; fatura/abonelik bir dokunuş uzakta.
class ReadOnlyLicenseBanner extends StatelessWidget {
  final LicenseTranslate translate;

  /// Biçimlendirilmiş grace bitiş tarihi (yoksa gösterilmez).
  final String? graceUntilText;
  final VoidCallback? onBilling;

  const ReadOnlyLicenseBanner({
    super.key,
    required this.translate,
    this.graceUntilText,
    this.onBilling,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final detail = StringBuffer(translate(LicenseKeys.readOnlyDetail));
    if (graceUntilText != null && graceUntilText!.isNotEmpty) {
      detail.write(' ${translate(LicenseKeys.readOnlyUntil)} $graceUntilText');
    }
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        key: const Key('license-read-only-banner'),
        color: AppColors.warning.withValues(alpha: 0.14),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.lock_clock_outlined,
                      size: 20, color: AppColors.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translate(LicenseKeys.readOnlyTitle),
                        style: AppTypography.subhead.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail.toString(),
                        style: AppTypography.footnote.copyWith(
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onBilling != null)
                  TextButton(
                    onPressed: onBilling,
                    child: Text(translate(LicenseKeys.readOnlyBilling)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kilitli lisans ekranı: ürün ekranlarının yerini alır. Hesap/abonelik, tekrar
/// deneme ve çıkış her zaman erişilebilir kalır (ödemek isteyen müşteri çıkışsız
/// bir sayfaya kapatılmaz).
class LicenseLockedView extends StatelessWidget {
  final LicenseTranslate translate;
  final VoidCallback? onBilling;
  final VoidCallback? onRetry;
  final VoidCallback? onSignOut;

  /// Yenileme sürüyor mu (tekrar dene butonu meşgul).
  final bool busy;

  const LicenseLockedView({
    super.key,
    required this.translate,
    this.onBilling,
    this.onRetry,
    this.onSignOut,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      key: const Key('license-locked-view'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  size: 56, color: AppColors.warning),
              const SizedBox(height: 16),
              Text(
                translate(LicenseKeys.lockedTitle),
                textAlign: TextAlign.center,
                style: AppTypography.title3.copyWith(
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                translate(LicenseKeys.lockedMessage),
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryLabel(context),
                ),
              ),
              const SizedBox(height: 24),
              if (onBilling != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onBilling,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: Text(translate(LicenseKeys.lockedBilling)),
                  ),
                ),
              if (onRetry != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onRetry,
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(translate(LicenseKeys.lockedRetry)),
                  ),
                ),
              ],
              if (onSignOut != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout),
                  label: Text(translate(LicenseKeys.lockedSignOut)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
