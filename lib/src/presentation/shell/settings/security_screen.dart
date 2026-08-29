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

  // ── E-posta 2FA (özel ikinci faktör — TOTP'den bağımsız) ───────────────────
  /// Etkin bir e-posta faktörü var mı? (`mfa_email_factors`).
  bool _emailEnabled = false;

  /// Kod-giriş kutusu görünür mü? (Etkinleştir → kod istendi).
  bool _emailEnrolling = false;

  /// E-posta işlemi (iste/doğrula/kaldır) sürüyor mu?
  bool _emailBusy = false;
  final TextEditingController _emailCodeController = TextEditingController();

  bool get _busy => _enrolling || _verifying || _removingId != null;

  /// Hata nesnesinden okunabilir mesaj (Supabase `AuthException.message`).
  String _msg(Object e) => e is AuthException ? e.message : e.toString();

  /// i18n: anahtar seed edilmemişse (translate ham anahtarı döndürürse)
  /// makul bir yedek metin göster.
  String _t(String key, String fallback) {
    final v = sl<LocalizationService>().translate(key);
    return v == key ? fallback : v;
  }

  /// E-posta 2FA EF hata kodunu (`Exception('CODE')`) okunabilir metne çevirir.
  String _emailErr(Object e) {
    final code = _msg(e).replaceFirst('Exception: ', '').trim();
    switch (code) {
      case 'RATE_LIMITED':
        return _t('account.security.mfa.email_rate_limited',
            'Çok fazla deneme. Lütfen bir süre sonra tekrar deneyin.');
      case 'TOO_SOON':
        return _t('account.security.mfa.email_too_soon',
            'Yeni kod istemek için lütfen biraz bekleyin.');
      case 'NO_EMAIL':
        return _t('account.security.mfa.email_no_email',
            'Hesabınıza bağlı bir e-posta adresi yok.');
      case 'INVALID_CODE':
        return _t('account.security.mfa.email_invalid',
            'Girdiğiniz kod hatalı.');
      case 'NO_CHALLENGE':
        return _t('account.security.mfa.email_no_challenge',
            'Aktif bir kod bulunamadı. Lütfen yeni kod isteyin.');
      case 'TOO_MANY_ATTEMPTS':
        return _t('account.security.mfa.email_too_many',
            'Çok fazla hatalı deneme. Lütfen yeni kod isteyin.');
      default:
        return _msg(e);
    }
  }

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
    _emailCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadFactors() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final factors = await authService.listMfaFactors();
      // E-posta faktörü durumu ayrı bir kaynaktır (mfa_email_factors) ve
      // FAIL-OPEN'dır (hata → false); faktör listesini bloklamamalı.
      final emailEnabled = await authService.emailFactorEnabled();
      if (!mounted) return;
      setState(() {
        _factors = factors;
        _emailEnabled = emailEnabled;
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
        message: _t('account.security.mfa.totp_enabled_success',
            'İki adımlı doğrulama etkinleştirildi.'),
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
        title: Text(_t('account.security.mfa.remove_confirm_title',
            'İki Adımlı Doğrulama')),
        content: Text(
          _t('account.security.mfa.remove_confirm_message',
              'Bu doğrulama yöntemini kaldırmak istediğinize emin misiniz?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('account.security.cancel', 'Vazgec')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('account.security.mfa.remove', 'Kaldır')),
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
      AppSnackbar.showSuccess(context,
          message: _t('account.security.mfa.removed_success',
              'Doğrulama yöntemi kaldırıldı.'));
      await _loadFactors();
    } catch (e) {
      if (!mounted) return;
      setState(() => _removingId = null);
      AppSnackbar.showError(context, message: _msg(e));
    }
  }

  // ── E-posta 2FA: etkinleştir / doğrula / kaldır ────────────────────────────

  /// Etkinleştir → koda-hazır: hesap e-postasına kod gönder, kod kutusunu aç.
  Future<void> _startEmailEnroll() async {
    setState(() => _emailBusy = true);
    try {
      await authService.requestEmailCode();
      if (!mounted) return;
      setState(() {
        _emailBusy = false;
        _emailEnrolling = true;
        _emailCodeController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _emailBusy = false);
      AppSnackbar.showError(context, message: _emailErr(e));
    }
  }

  Future<void> _resendEmailCode() async {
    setState(() => _emailBusy = true);
    try {
      await authService.requestEmailCode();
      if (!mounted) return;
      setState(() => _emailBusy = false);
      AppSnackbar.showSuccess(context,
          message: _t('account.security.mfa.email_resent_success',
              'Yeni kod gönderildi.'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _emailBusy = false);
      AppSnackbar.showError(context, message: _emailErr(e));
    }
  }

  /// Kodu doğrula → ilk başarılı doğrulama faktörü otomatik kaydeder.
  Future<void> _verifyEmailEnroll() async {
    final code = _emailCodeController.text.trim();
    if (code.length != 6) return;
    setState(() => _emailBusy = true);
    try {
      await authService.verifyEmailCode(code);
      if (!mounted) return;
      setState(() {
        _emailBusy = false;
        _emailEnrolling = false;
      });
      AppSnackbar.showSuccess(
        context,
        message: _t('account.security.mfa.email_enabled_success',
            'E-posta ile doğrulama etkinleştirildi.'),
      );
      await _loadFactors();
    } catch (e) {
      if (!mounted) return;
      setState(() => _emailBusy = false);
      AppSnackbar.showError(context, message: _emailErr(e));
    }
  }

  void _cancelEmailEnroll() {
    setState(() {
      _emailEnrolling = false;
      _emailCodeController.clear();
    });
  }

  Future<void> _disableEmail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('account.security.mfa.email_title',
            'E-posta ile Doğrulama')),
        content: Text(
          _t('account.security.mfa.email_disable_confirm_message',
              'E-posta ile doğrulamayı kapatmak istediğinize emin misiniz?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('account.security.cancel', 'Vazgec')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('account.security.mfa.email_disable_confirm_action',
                'Kapat')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _emailBusy = true);
    try {
      await authService.unenrollEmail();
      if (!mounted) return;
      setState(() => _emailBusy = false);
      AppSnackbar.showSuccess(context,
          message: _t('account.security.mfa.email_disabled_success',
              'E-posta ile doğrulama kapatıldı.'));
      await _loadFactors();
    } catch (e) {
      if (!mounted) return;
      setState(() => _emailBusy = false);
      AppSnackbar.showError(context, message: _emailErr(e));
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
          title: _t('account.security.password.change', 'Şifre Değiştir'),
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
                    label: _t('account.security.password.new', 'Yeni Şifre'),
                    obscureText: true,
                    validator: Validators.password(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: confirmController,
                    label: _t('account.security.password.confirm',
                        'Yeni Şifre (Tekrar)'),
                    obscureText: true,
                    validator: (value) {
                      if (value != newController.text) {
                        return _t('account.security.password.mismatch',
                            'Şifreler eşleşmiyor.');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: _t('account.security.password.update',
                        'Şifreyi Güncelle'),
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      final result =
                          await authService.updatePassword(newController.text);
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      result.when(
                        success: (_, __) => AppSnackbar.showSuccess(
                          context,
                          message: _t('account.security.password.updated_success',
                              'Şifreniz güncellendi.'),
                        ),
                        failure: (error) => AppSnackbar.showError(
                          context,
                          message: error?.message ??
                              _t('account.security.password.update_failed',
                                  'Şifre güncellenemedi.'),
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
      title: _t('account.security.title', 'Güvenlik'),
      showBackButton: true,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
                title: _t('account.security.mfa.section_title',
                    'İki Adımlı Doğrulama (2FA)')),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: _build2faBody(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSectionHeader(
                title: _t('account.security.mfa.email_title',
                    'E-posta ile Doğrulama')),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: _buildEmailBody(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSectionHeader(
                title: _t('account.security.password.section_title', 'Şifre')),
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
                title: _t('account.security.password.change', 'Şifre Değiştir'),
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
            label: _t('account.security.retry', 'Tekrar Dene'),
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
            _t('account.security.mfa.totp_hint',
                'Hesabınızı authenticator uygulamasıyla ekstra bir katmanla '
                'koruyun. Girişte 6 haneli bir kod istenir.'),
            style: AppTypography.subheadline
                .copyWith(color: AppColors.secondaryLabel(context)),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: _t('account.security.mfa.totp_enable', 'Etkinleştir'),
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
                      : _t('account.security.mfa.authenticator',
                          'Authenticator'),
                  style: AppTypography.body,
                ),
                Text(
                  '${_t('account.security.mfa.active', 'Etkin')} • '
                  '${factor.factorType.name.toUpperCase()}',
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
                : Text(_t('account.security.mfa.remove', 'Kaldır')),
          ),
        ],
      ),
    );
  }

  /// E-posta 2FA bölümü: etkinse durum + kaldır; kod-giriş açıksa doğrula;
  /// aksi halde açıklama + etkinleştir.
  Widget _buildEmailBody(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Etkin → durum satırı + Kaldır.
    if (_emailEnabled) {
      return Row(
        children: [
          const Icon(Icons.mark_email_read_outlined, color: Colors.green),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('auth.mfa.enroll_choice_email', 'E-posta ile kod'),
                    style: AppTypography.body),
                Text(
                  _t('account.security.mfa.active', 'Etkin'),
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: _emailBusy ? null : _disableEmail,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: _emailBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_t('account.security.mfa.remove', 'Kaldır')),
          ),
        ],
      );
    }

    // Kod-giriş açık → doğrula + yeniden gönder + vazgeç.
    if (_emailEnrolling) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t('account.security.mfa.email_sent_instructions',
                'Hesabınızın e-posta adresine 6 haneli bir kod gönderdik. '
                'Etkinleştirmek için kodu girin.'),
            style: AppTypography.subheadline
                .copyWith(color: AppColors.secondaryLabel(context)),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _emailCodeController,
            label: _t('auth.mfa.code_label', 'Doğrulama kodu'),
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
            label: _t('auth.mfa.verify', 'Doğrula'),
            isLoading: _emailBusy,
            onPressed:
                (_emailBusy || _emailCodeController.text.trim().length != 6)
                    ? null
                    : _verifyEmailEnroll,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: _t('account.security.mfa.email_resend',
                'Kodu yeniden gönder'),
            variant: AppButtonVariant.secondary,
            onPressed: _emailBusy ? null : _resendEmailCode,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _emailBusy ? null : _cancelEmailEnroll,
            child: Text(_t('account.security.cancel', 'Vazgec')),
          ),
        ],
      );
    }

    // Kapalı → açıklama + Etkinleştir.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('account.security.mfa.email_enable_hint',
              'Girişte hesabınızın e-posta adresine gönderilen 6 haneli bir '
              'kodla doğrulama yapın.'),
          style: AppTypography.subheadline
              .copyWith(color: AppColors.secondaryLabel(context)),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: _t('account.security.mfa.email_enable', 'Etkinleştir'),
          icon: Icons.mail_outline,
          isLoading: _emailBusy,
          onPressed: _emailBusy ? null : _startEmailEnroll,
        ),
      ],
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
          _t('account.security.mfa.totp_enroll_instruction',
              'Authenticator uygulamanızla QR kodu tarayın veya gizli anahtarı '
              'elle ekleyin, ardından gösterilen 6 haneli kodu girin.'),
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
            _t('auth.mfa.secret_label', 'Gizli anahtar'),
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
          label: _t('auth.mfa.code_label', 'Doğrulama kodu'),
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
          label: _t('auth.mfa.verify', 'Doğrula'),
          isLoading: _verifying,
          onPressed: (_busy || _codeController.text.trim().length != 6)
              ? null
              : _verifyEnroll,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: _t('account.security.cancel', 'Vazgec'),
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
