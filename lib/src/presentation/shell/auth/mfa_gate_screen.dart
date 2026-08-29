import 'dart:async';

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
///  - [MfaStepUp.challenge]      : verified TOTP faktörü var → 6-hane kod →
///    verify → oturum aal2'ye yükselir → `/main`.
///  - [MfaStepUp.emailChallenge] : etkin e-posta 2FA faktörü var (TOTP yok) →
///    açılışta e-posta ile kod gönderilir → 6-hane kod → verify → `/main`.
///  - [MfaStepUp.enroll]         : hiç faktör yok → kayıt. Politika e-posta'ya
///    izin veriyorsa TOTP-QR ile "E-posta ile kod" arasında seçtirilir; e-posta
///    yolu ilk doğrulamada otomatik kaydolur. Aksi halde doğrudan TOTP-QR.
///
/// Kullanıcı tamamlayamazsa "çıkış yap" kaçış yolu vardır (kilitlenmesin).
class MfaGateScreen extends StatefulWidget {
  const MfaGateScreen({super.key});

  @override
  State<MfaGateScreen> createState() => _MfaGateScreenState();
}

/// Ekranın o an gösterdiği mod (gate durumundan + kullanıcı seçiminden türer).
enum _ScreenMode {
  /// Hazırlık (spinner).
  loading,

  /// Verified TOTP faktörüyle 6-hane doğrulama.
  totpChallenge,

  /// Yeni TOTP kaydı (QR/secret) + 6-hane doğrulama.
  totpEnroll,

  /// Kayıt yönteminin seçildiği ekran (TOTP-QR vs e-posta).
  enrollChoice,

  /// E-posta ile kod: hem `emailChallenge` hem seçilen e-posta-enroll için
  /// (verifyEmailCode ilk doğrulamada otomatik kaydeder → tek akış).
  email,
}

class _MfaGateScreenState extends State<MfaGateScreen> {
  final TextEditingController _codeController = TextEditingController();

  _ScreenMode _mode = _ScreenMode.loading;
  bool _verifying = false;

  /// E-posta kodu isteniyor/yeniden gönderiliyor.
  bool _requestingCode = false;
  String? _error;

  /// Yeniden-gönder geri sayımı (0 = hazır). Kısa bir istemci-tarafı bekleme,
  /// arka ucun TOO_SOON/RATE_LIMITED hızını yansıtır.
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  /// Kayıt (enroll) akışında dolar; challenge modunda null kalır.
  AuthMFAEnrollResponse? _enrollment;

  /// TOTP doğrulanacak faktör id'si (challenge'da mevcut, enroll'da yeni).
  String? _factorId;

  /// i18n: anahtar seed edilmemişse (translate ham anahtarı döndürürse)
  /// makul bir yedek metin göster.
  String _t(String key, String fallback) {
    final v = sl<LocalizationService>().translate(key);
    return v == key ? fallback : v;
  }

  String _msg(Object e) => e is AuthException ? e.message : e.toString();

  /// E-posta 2FA EF hata kodunu (`Exception('CODE')`) okunabilir metne çevirir.
  String _emailErrorText(Object e) {
    final raw = _msg(e);
    final code = raw.replaceFirst('Exception: ', '').trim();
    switch (code) {
      case 'RATE_LIMITED':
        return _t('auth.mfa.email_error_rate_limited',
            'Çok fazla deneme yapıldı. Lütfen bir süre sonra tekrar deneyin.');
      case 'TOO_SOON':
        return _t('auth.mfa.email_error_too_soon',
            'Yeni kod istemek için lütfen biraz bekleyin.');
      case 'NO_EMAIL':
        return _t('auth.mfa.email_error_no_email',
            'Hesabınıza bağlı bir e-posta adresi yok.');
      case 'INVALID_CODE':
        return _t('auth.mfa.email_error_invalid_code',
            'Girdiğiniz kod hatalı.');
      case 'NO_CHALLENGE':
        return _t('auth.mfa.email_error_no_challenge',
            'Aktif bir kod bulunamadı. Lütfen yeni kod isteyin.');
      case 'TOO_MANY_ATTEMPTS':
        return _t('auth.mfa.email_error_too_many_attempts',
            'Çok fazla hatalı deneme. Lütfen yeni kod isteyin.');
      default:
        return raw;
    }
  }

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  /// Gate durumuna göre başlangıç modunu belirler.
  Future<void> _prepare() async {
    final gate = MfaGate.instance;
    // Kapı temizlendiyse (state=none) burada bulunmamalıyız → güvenli hedef.
    if (gate.state == MfaStepUp.none) {
      if (mounted) context.go('/main');
      return;
    }

    // Verified TOTP challenge: faktör id'si mevcut.
    if (gate.state == MfaStepUp.challenge &&
        gate.challengeFactorId != null &&
        gate.challengeFactorId!.isNotEmpty) {
      setState(() {
        _factorId = gate.challengeFactorId;
        _mode = _ScreenMode.totpChallenge;
      });
      return;
    }

    // E-posta challenge: açılışta otomatik kod gönder.
    if (gate.state == MfaStepUp.emailChallenge) {
      setState(() => _mode = _ScreenMode.email);
      await _sendEmailCode(initial: true);
      return;
    }

    // Enroll: politika e-posta'ya izin veriyorsa yöntem seçtir, aksi halde
    // doğrudan TOTP-QR kaydı başlat.
    if (gate.state == MfaStepUp.enroll && gate.policyAllowsEmail) {
      setState(() => _mode = _ScreenMode.enrollChoice);
      return;
    }

    await _startTotpEnroll();
  }

  // ── TOTP enroll ────────────────────────────────────────────────────────────

  Future<void> _startTotpEnroll() async {
    setState(() {
      _mode = _ScreenMode.loading;
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
        _mode = _ScreenMode.totpEnroll;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mode = _ScreenMode.enrollChoice; // seçim ekranına geri düş (varsa)
        _error = _msg(e);
      });
    }
  }

  Future<void> _verifyTotp() async {
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

  // ── E-posta 2FA (challenge + enroll ortak akışı) ────────────────────────────

  /// E-posta yöntemine geç ve ilk kodu gönder (enroll-choice → "E-posta ile kod").
  Future<void> _chooseEmail() async {
    setState(() {
      _mode = _ScreenMode.email;
      _codeController.clear();
      _error = null;
    });
    await _sendEmailCode(initial: true);
  }

  /// E-posta kodu ister; [initial] değilse "yeniden gönder"dir (cooldown başlatır).
  Future<void> _sendEmailCode({bool initial = false}) async {
    if (_requestingCode) return;
    setState(() {
      _requestingCode = true;
      if (!initial) _error = null;
    });
    try {
      await authService.requestEmailCode();
      if (!mounted) return;
      setState(() => _requestingCode = false);
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _requestingCode = false;
        _error = _emailErrorText(e);
      });
      // TOO_SOON/RATE_LIMITED de olsa kullanıcı bir süre beklemeli.
      _startCooldown();
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCooldown -= 1;
        if (_resendCooldown <= 0) {
          _resendCooldown = 0;
          t.cancel();
        }
      });
    });
  }

  Future<void> _verifyEmail() async {
    final code = _codeController.text.trim();
    if (code.length != 6) return;

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await authService.verifyEmailCode(code);
      // Başarılı → bu oturum için e-posta 2FA tatmin edildi (ilk doğrulama
      // faktörü otomatik kaydeder). Kapıyı temizle ve ana ekrana geç.
      MfaGate.instance.clear();
      if (!mounted) return;
      context.go('/main');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = _emailErrorText(e);
      });
    }
  }

  // ── Kaçış yolu ──────────────────────────────────────────────────────────────

  /// Tamamlayamayan kullanıcı kilitlenmesin.
  Future<void> _signOut() async {
    MfaGate.instance.clear();
    try {
      await authService.signOut();
    } catch (_) {}
    if (mounted) context.go('/login');
  }

  // ── Build ────────────────────────────────────────────────────────────────────

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
    switch (_mode) {
      case _ScreenMode.loading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CircularProgressIndicator(),
          ),
        );
      case _ScreenMode.enrollChoice:
        return _buildEnrollChoice(context);
      case _ScreenMode.email:
        return _buildEmailBody(context);
      case _ScreenMode.totpChallenge:
      case _ScreenMode.totpEnroll:
        return _buildTotpBody(context);
    }
  }

  /// Kayıt yöntemi seçimi (yalnız politika e-posta'ya izin verdiğinde).
  Widget _buildEnrollChoice(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _t('auth.mfa.enroll_choice_instruction',
              'Bir doğrulama yöntemi seçin. Her girişte ikinci bir adım '
              'istenecek.'),
          style: AppTypography.subheadline
              .copyWith(color: AppColors.secondaryLabel(context)),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: AppTypography.footnote.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: _t('auth.mfa.enroll_choice_totp', 'Authenticator uygulaması'),
          icon: Icons.qr_code_2,
          onPressed: _startTotpEnroll,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: _t('auth.mfa.enroll_choice_email', 'E-posta ile kod'),
          icon: Icons.mail_outline,
          variant: AppButtonVariant.secondary,
          onPressed: _chooseEmail,
        ),
      ],
    );
  }

  /// E-posta ile kod akışı (challenge + enroll ortak).
  Widget _buildEmailBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _t('auth.mfa.email_instruction',
              'Hesabınızın e-posta adresine 6 haneli bir kod gönderdik. '
              'Devam etmek için kodu girin.'),
          style: AppTypography.subheadline
              .copyWith(color: AppColors.secondaryLabel(context)),
        ),
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
              : _verifyEmail,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: (_requestingCode || _resendCooldown > 0 || _verifying)
              ? null
              : () => _sendEmailCode(),
          child: Text(
            _resendCooldown > 0
                ? _t('auth.mfa.email_resend_in', 'Yeniden gönder ({s} sn)')
                    .replaceFirst('{s}', '$_resendCooldown')
                : _t('auth.mfa.email_resend', 'Kodu yeniden gönder'),
          ),
        ),
      ],
    );
  }

  /// TOTP akışı (challenge + enroll ortak — enroll'da QR/secret görselleri).
  Widget _buildTotpBody(BuildContext context) {
    final isEnroll = _mode == _ScreenMode.totpEnroll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isEnroll
              ? _t('auth.mfa.enroll_instruction',
                  'Bir authenticator uygulamasıyla QR kodu tarayın veya gizli '
                  'anahtarı elle ekleyin, ardından 6 haneli kodu girin.')
              : _t('auth.mfa.challenge_instruction',
                  'Devam etmek için authenticator uygulamanızdaki 6 haneli '
                  'kodu girin.'),
          style: AppTypography.subheadline
              .copyWith(color: AppColors.secondaryLabel(context)),
        ),
        if (isEnroll && _enrollment != null) ...[
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
              : _verifyTotp,
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
