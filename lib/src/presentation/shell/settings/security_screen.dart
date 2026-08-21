import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, Factor, FactorStatus, AuthMFAEnrollResponse;

/// Hesap → Güvenlik ekranı (web `SecurityComponent` mobil karşılığı).
///
/// İki bölüm:
///  - **İki Adımlı Doğrulama (2FA)**: TOTP faktör kaydı (enroll → QR/secret →
///    doğrula → kaldır). `authService` MFA sarmalayıcılarını kullanır.
///  - **Şifre**: yeni-parola diyaloğu (`authService.updatePassword`).
///
/// Parola birincil kalır; 2FA opt-in ek katmandır.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _loading = true;
  String? _loadError;

  /// Yüklenen tüm faktörler (verified + unverified).
  List<Factor> _factors = const [];

  /// Devam eden kayıt (enroll) — null ise akış başlamamış.
  AuthMFAEnrollResponse? _enrollment;
  final TextEditingController _codeController = TextEditingController();

  bool _enrolling = false;
  bool _verifying = false;
  String? _removingId;

  bool get _busy => _enrolling || _verifying || _removingId != null;

  /// Hata nesnesinden okunabilir mesaj (Supabase `AuthException.message`).
  String _msg(Object e) => e is AuthException ? e.message : e.toString();

  List<Factor> get _verifiedFactors =>
      _factors.where((f) => f.status == FactorStatus.verified).toList();

  @override
  void initState() {
    super.initState();
    _loadFactors();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadFactors() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final factors = await authService.listMfaFactors();
      if (!mounted) return;
      setState(() {
        _factors = factors;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _msg(e);
      });
    }
  }

  // ── 2FA: enroll / verify / remove ─────────────────────────────────────────

  Future<void> _startEnroll() async {
    setState(() => _enrolling = true);
    try {
      // Yarım kalmış (unverified) faktörleri temizle — aksi halde her deneme
      // yeni bir kayıt bırakır (web davranışıyla aynı).
      for (final f in _factors.where((f) => f.status != FactorStatus.verified)) {
        try {
          await authService.unenrollFactor(f.id);
        } catch (_) {
          // yut: temizlik başarısızlığı enroll'u engellememeli
        }
      }
      final enrollment = await authService.enrollTotp();
      if (!mounted) return;
      setState(() {
        _enrollment = enrollment;
        _codeController.clear();
        _enrolling = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _enrolling = false);
      AppSnackbar.showError(context, message: _msg(e));
    }
  }

  Future<void> _cancelEnroll() async {
    final enrollment = _enrollment;
    setState(() => _enrollment = null);
    if (enrollment != null) {
      // Doğrulanmamış faktörü sunucudan da temizle.
      try {
        await authService.unenrollFactor(enrollment.id);
      } catch (_) {}
    }
    await _loadFactors();
  }

  Future<void> _verifyEnroll() async {
    final enrollment = _enrollment;
    if (enrollment == null) return;
    final code = _codeController.text.trim();
    if (code.length != 6) return;

    setState(() => _verifying = true);
    try {
      await authService.verifyTotp(enrollment.id, code);
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _enrollment = null;
      });
      AppSnackbar.showSuccess(
        context,
        message: 'İki adımlı doğrulama etkinleştirildi.',
      );
      await _loadFactors();
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      AppSnackbar.showError(context, message: _msg(e));
    }
  }

  Future<void> _removeFactor(Factor factor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İki Adımlı Doğrulama'),
        content: const Text(
          'Bu doğrulama yöntemini kaldırmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgec'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _removingId = factor.id);
    try {
      await authService.unenrollFactor(factor.id);
      if (!mounted) return;
      setState(() => _removingId = null);
      AppSnackbar.showSuccess(context, message: 'Doğrulama yöntemi kaldırıldı.');
      await _loadFactors();
    } catch (e) {
      if (!mounted) return;
      setState(() => _removingId = null);
      AppSnackbar.showError(context, message: _msg(e));
    }
  }

  // ── Parola değiştir ───────────────────────────────────────────────────────

  void _showChangePasswordDialog() {
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: AppBottomSheet(
          title: 'Şifre Değiştir',
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: newController,
                    label: 'Yeni Şifre',
                    obscureText: true,
                    validator: Validators.password(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: confirmController,
                    label: 'Yeni Şifre (Tekrar)',
                    obscureText: true,
                    validator: (value) {
                      if (value != newController.text) {
                        return 'Şifreler eşleşmiyor.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Şifreyi Güncelle',
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      final result =
                          await authService.updatePassword(newController.text);
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      result.when(
                        success: (_, __) => AppSnackbar.showSuccess(
                          context,
                          message: 'Şifreniz güncellendi.',
                        ),
                        failure: (error) => AppSnackbar.showError(
                          context,
                          message: error?.message ?? 'Şifre güncellenemedi.',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Güvenlik',
      showBackButton: true,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(title: 'İki Adımlı Doğrulama (2FA)'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: _build2faBody(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppSectionHeader(title: 'Şifre'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: AppListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.lock_outline, color: AppColors.primary),
                ),
                title: 'Şifre Değiştir',
                trailing: const Icon(Icons.chevron_right),
                onTap: _showChangePasswordDialog,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _build2faBody(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_loadError!, style: AppTypography.subheadline),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Tekrar Dene',
            variant: AppButtonVariant.secondary,
            onPressed: _loadFactors,
          ),
        ],
      );
    }

    // Kayıt akışı sürüyor → QR + secret + kod alanı.
    if (_enrollment != null) {
      return _buildEnrollBox(context, _enrollment!);
    }

    final verified = _verifiedFactors;
    if (verified.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hesabınızı authenticator uygulamasıyla ekstra bir katmanla '
            'koruyun. Girişte 6 haneli bir kod istenir.',
            style: AppTypography.subheadline
                .copyWith(color: AppColors.secondaryLabel(context)),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Etkinleştir',
            icon: Icons.shield_outlined,
            isLoading: _enrolling,
            onPressed: _busy ? null : _startEnroll,
          ),
        ],
      );
    }

    // Kayıtlı faktörler listesi (+ Kaldır).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in verified) _buildFactorRow(context, f),
      ],
    );
  }

  Widget _buildFactorRow(BuildContext context, Factor factor) {
    final removing = _removingId == factor.id;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.green),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  factor.friendlyName?.isNotEmpty == true
                      ? factor.friendlyName!
                      : 'Authenticator',
                  style: AppTypography.body,
                ),
                Text(
                  'Etkin • ${factor.factorType.name.toUpperCase()}',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: _busy ? null : () => _removeFactor(factor),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: removing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kaldır'),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollBox(BuildContext context, AuthMFAEnrollResponse enrollment) {
    final totp = enrollment.totp;
    final qr = totp?.qrCode;
    final secret = totp?.secret;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Authenticator uygulamanızla QR kodu tarayın veya gizli anahtarı '
          'elle ekleyin, ardından gösterilen 6 haneli kodu girin.',
          style: AppTypography.subheadline
              .copyWith(color: AppColors.secondaryLabel(context)),
        ),
        const SizedBox(height: AppSpacing.md),
        if (qr != null && qr.isNotEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.string(
                _svgFromDataUri(qr),
                width: 200,
                height: 200,
                placeholderBuilder: (_) => const SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ),
        if (secret != null && secret.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Gizli anahtar',
            style: AppTypography.footnote
                .copyWith(color: AppColors.secondaryLabel(context)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.secondarySystemBackground(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              secret,
              style: AppTypography.body.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _codeController,
          label: 'Doğrulama kodu',
          placeholder: '000000',
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Doğrula',
          isLoading: _verifying,
          onPressed: (_busy || _codeController.text.trim().length != 6)
              ? null
              : _verifyEnroll,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Vazgec',
          variant: AppButtonVariant.secondary,
          onPressed: _verifying ? null : _cancelEnroll,
        ),
      ],
    );
  }

  /// `data:image/svg+xml;utf-8,<svg…>` data-URI'sinden ham SVG gövdesini çıkarır.
  /// gotrue qrCode'u zaten bu ön ekle döndürür; gövde URL-encode olabilir.
  String _svgFromDataUri(String value) {
    final commaIdx = value.indexOf(',');
    final body = (value.startsWith('data:') && commaIdx >= 0)
        ? value.substring(commaIdx + 1)
        : value;
    try {
      return Uri.decodeFull(body);
    } catch (_) {
      return body;
    }
  }
}
