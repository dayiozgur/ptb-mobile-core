import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, AuthMFAEnrollResponse;

/// MFA step-up kapısı (web `mfa-stepup.guard` + step-up ekranı mobil karşılığı).
///
/// [MfaGate] login/cold-start'ta POZİTİF olarak (tenant politikası rol için MFA
/// istiyor VE oturum aal1) doğruladığında router bu ekrana yönlendirir:
///  - [MfaStepUp.challenge] : verified TOTP faktörü var → 6-hane kod → verify →
///    oturum aal2'ye yükselir → `/main`.
///  - [MfaStepUp.enroll]    : verified faktör yok → enroll (QR/secret) → verify →
///    aal2 → `/main`.
///
/// Kullanıcı tamamlayamazsa "çıkış yap" kaçış yolu vardır (kilitlenmesin).
class MfaGateScreen extends StatefulWidget {
  const MfaGateScreen({super.key});

  @override
  State<MfaGateScreen> createState() => _MfaGateScreenState();
}

class _MfaGateScreenState extends State<MfaGateScreen> {
  final TextEditingController _codeController = TextEditingController();

  bool _preparing = true;
  bool _verifying = false;
  String? _error;

  /// Kayıt (enroll) akışı gerektiğinde dolar; challenge modunda null kalır.
  AuthMFAEnrollResponse? _enrollment;

  /// Doğrulanacak faktör id'si — challenge'da mevcut verified faktör,
  /// enroll'da yeni oluşturulan faktör.
  String? _factorId;

  /// Bu ekran enroll akışı mı gösteriyor?
  bool get _isEnroll => _enrollment != null;

  /// i18n: anahtar seed edilmemişse (translate ham anahtarı döndürürse)
  /// makul bir yedek metin göster.
  String _t(String key, String fallback) {
    final v = sl<LocalizationService>().translate(key);
    return v == key ? fallback : v;
  }

  String _msg(Object e) => e is AuthException ? e.message : e.toString();

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Ekran moduna göre hazırlık: challenge → mevcut faktör id'sini al;
  /// enroll → yeni bir TOTP faktörü kaydını başlat (QR/secret).
  Future<void> _prepare() async {
    final gate = MfaGate.instance;
    // Kapı bir şekilde temizlendiyse (state=none) burada bulunmamalıyız →
    // güvenli hedefe dön.
    if (gate.state == MfaStepUp.none) {
      if (mounted) context.go('/main');
      return;
    }

    // Challenge: verified faktör id'si mevcut.
    if (gate.state == MfaStepUp.challenge &&
        gate.challengeFactorId != null &&
        gate.challengeFactorId!.isNotEmpty) {
      setState(() {
        _factorId = gate.challengeFactorId;
        _preparing = false;
      });
      return;
    }

    // Enroll (veya challenge id'si beklenmedik şekilde boş): yeni kayıt başlat.
    await _startEnroll();
  }

  Future<void> _startEnroll() async {
    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      // Yarım kalmış (unverified) faktörleri temizle (security_screen ile aynı).
      try {
        final existing = await authService.listMfaFactors();
        for (final f in existing) {
          if (f.status.name != 'verified') {
            try {
              await authService.unenrollFactor(f.id);
            } catch (_) {}
          }
        }
      } catch (_) {}

      final enrollment = await authService.enrollTotp();
      if (!mounted) return;
      setState(() {
        _enrollment = enrollment;
        _factorId = enrollment.id;
        _preparing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _error = _msg(e);
      });
    }
  }

  Future<void> _verify() async {
    final factorId = _factorId;
    final code = _codeController.text.trim();
    if (factorId == null || code.length != 6) return;

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await authService.verifyTotp(factorId, code);
      // Başarılı → oturum aal2. Kapıyı temizle ve ana ekrana geç.
      MfaGate.instance.clear();
      if (!mounted) return;
      context.go('/main');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = _msg(e);
      });
    }
  }

  /// Kaçış yolu — tamamlayamayan kullanıcı kilitlenmesin.
  Future<void> _signOut() async {
    MfaGate.instance.clear();
    try {
      await authService.signOut();
    } catch (_) {}
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _t('auth.mfa.title', 'İki Adımlı Doğrulama'),
      showBackButton: false,
      actions: [
        TextButton(
          onPressed: _verifying ? null : _signOut,
          child: Text(_t('auth.mfa.sign_out', 'Çıkış Yap')),
        ),
      ],
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Icon(Icons.shield_outlined, size: 48, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              _t('auth.mfa.required_header',
                  'Kuruluşunuz iki adımlı doğrulama gerektiriyor'),
              style: AppTypography.title3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: _buildBody(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_preparing) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isEnroll
              ? _t('auth.mfa.enroll_instruction',
                  'Bir authenticator uygulamasıyla QR kodu tarayın veya gizli '
                  'anahtarı elle ekleyin, ardından 6 haneli kodu girin.')
              : _t('auth.mfa.challenge_instruction',
                  'Devam etmek için authenticator uygulamanızdaki 6 haneli '
                  'kodu girin.'),
          style: AppTypography.subheadline
              .copyWith(color: AppColors.secondaryLabel(context)),
        ),
        if (_isEnroll) ...[
          const SizedBox(height: AppSpacing.md),
          _buildEnrollVisuals(context, _enrollment!),
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
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: AppTypography.footnote.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: _t('auth.mfa.verify', 'Doğrula'),
          isLoading: _verifying,
          onPressed: (_verifying || _codeController.text.trim().length != 6)
              ? null
              : _verify,
        ),
      ],
    );
  }

  Widget _buildEnrollVisuals(
      BuildContext context, AuthMFAEnrollResponse enrollment) {
    final totp = enrollment.totp;
    final qr = totp?.qrCode;
    final secret = totp?.secret;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }

  /// `data:image/svg+xml;utf-8,<svg…>` data-URI'sinden ham SVG gövdesini çıkarır
  /// (security_screen ile aynı işleyiş).
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
