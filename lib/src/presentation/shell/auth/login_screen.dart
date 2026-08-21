import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  String _t(String key) => sl<LocalizationService>().translate(key);

  /// Aktif locale'i auth_branding_json i18n anahtar formatına çevirir
  /// (ör. tr→'tr-TR', en→'en-US', de→'de-DE', it→'it-IT').
  String get _localeCode {
    final loc = sl<LocalizationService>().currentLocale;
    return '${loc.languageCode}-${loc.countryCode}';
  }

  /// Marka logosu: branding'de tam-URL logo varsa network'ten, yoksa
  /// paketlenmiş Protoolbag logosu, o da yoksa monitor ikonu (fallback).
  Widget _buildBrandLogo() {
    const asset = 'packages/protoolbag_core/assets/brand/ptb_logo.png';
    Widget iconFallback() =>
        Icon(Icons.monitor_heart, size: 48, color: AppColors.primary);
    Widget assetLogo() => Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => iconFallback(),
        );
    final logoUrl = sl<BrandingService>().current?.logoUrl;
    if (logoUrl != null && logoUrl.startsWith('http')) {
      return Image.network(
        logoUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => assetLogo(),
      );
    }
    return assetLogo();
  }

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    final available = await authService.isBiometricAvailable();
    final enabled = await authService.isBiometricLoginEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      bool loginOk = false;
      result.when(
        success: (user, session) {
          Logger.info('Login successful: ${user.email}');
          loginOk = true;
        },
        failure: (error) {
          AppSnackbar.showError(
            context,
            message: error?.message ?? _t('auth.login_failed'),
          );
        },
      );

      if (!loginOk || !mounted) return;

      if (_biometricAvailable && !_biometricEnabled) {
        await _showEnableBiometricDialog();
      } else {
        await _resolveAndGo();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Login sonrası tenant + organization context'ini profile-bundle'dan çöz,
  /// sonra hedefe git. Çözülemezse (gerçekten tenant'sız kullanıcı) tenant-seçim
  /// ekranına düşer. (Bug fix: eskiden doğrudan /tenant-select'e gidiyordu →
  /// tenant/org boş kaldığı için "Organizasyon Bulunamadı" ekranına sıkışıyordu.)
  Future<void> _resolveAndGo() async {
    final ok = await CoreInitializer.resolveSessionContext();
    if (!mounted) return;
    // '/main' = paylaşılan shell girişi (her app router'ında tanımlı). '/' rotası
    // yok → manuel-login sonrası GoException veriyordu; '/main' doğru hedef.
    context.go(ok ? '/main' : '/tenant-select');
  }

  Future<void> _showEnableBiometricDialog() async {
    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('auth.biometric.enable_title')),
        content: Text(_t('auth.biometric.enable_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('common.no')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('auth.biometric.accept')),
          ),
        ],
      ),
    );

    if (shouldEnable == true) {
      await authService.enableBiometricLogin();
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: _t('auth.biometric.enabled_success'),
        );
      }
    }

    if (mounted) {
      await _resolveAndGo();
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (!_biometricEnabled) {
      if (mounted) {
        AppSnackbar.showInfo(
          context,
          message: _t('auth.biometric.enable_first'),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await authService.authenticateWithBiometric(
        reason: _t('auth.biometric.verify_reason'),
      );

      if (!mounted) return;

      if (result.isSuccess) {
        final sessionResult = await authService.restoreSession();

        if (!mounted) return;

        bool bioOk = false;
        sessionResult.when(
          success: (user, session) {
            bioOk = true;
          },
          failure: (error) {
            authService.disableBiometricLogin();
            setState(() => _biometricEnabled = false);
            AppSnackbar.showError(
              context,
              message: _t('auth.biometric.session_expired'),
            );
          },
        );
        if (bioOk && mounted) {
          await _resolveAndGo();
        }
      } else {
        AppSnackbar.showError(
          context,
          message: result.errorMessage ?? _t('auth.biometric.verify_failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      // App-bar başlığı = marka LOGOSU (metin yerine). DB-driven: branding
      // logoUrl (http) → network, yoksa paketlenmiş Protoolbag logosu.
      titleWidget: SizedBox(height: 26, child: _buildBrandLogo()),
      showBackButton: false,
      // Giriş öncesi dil değiştirme: seçili dilin BAYRAĞINI gösterir
      // (jenerik globe yerine) → dokun → DB-güdümlü dil seçici.
      actions: [
        TextButton(
          onPressed: () => showLanguagePicker(context),
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(
            flagEmoji(sl<LocalizationService>().currentLocale.countryCode),
            style: const TextStyle(fontSize: 22),
          ),
        ),
      ],
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // Başlık = aktif platform kodu (ör. "PHR"). Marka logosu artık
              // app-bar'da; ortadaki büyük logo kutusu kaldırıldı.
              Text(
                sl<PlatformContext>().activePlatformCode ??
                    sl<BrandingService>().current?.brandName ??
                    _t('auth.login.app_name'),
                style: AppTypography.largeTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                sl<BrandingService>().current?.taglineFor(_localeCode) ??
                    _t('auth.login.subtitle'),
                style: AppTypography.subheadline.copyWith(
                  color: AppColors.secondaryLabel(context),
                ),
                textAlign: TextAlign.center,
              ),

              // Dinamik slogan karüseli (web login'in auth-branding paneli).
              // Branding'de feature yoksa hiçbir şey çizmez (tagline-only görünüm).
              Builder(builder: (context) {
                final features =
                    sl<BrandingService>().current?.featuresFor(_localeCode) ??
                        const <BrandingFeature>[];
                if (features.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: _SlogansCarousel(
                    key: ValueKey('slogans-$_localeCode-${features.length}'),
                    features: features,
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.lg),

              // Email field
              AppEmailField(
                controller: _emailController,
                label: _t('auth.email'),
                placeholder: _t('auth.login.email_placeholder'),
                enabled: !_isLoading,
              ),

              const SizedBox(height: AppSpacing.md),

              // Password field
              AppPasswordField(
                controller: _passwordController,
                label: _t('auth.password'),
                placeholder: _t('auth.login.password_placeholder'),
                enabled: !_isLoading,
              ),

              const SizedBox(height: AppSpacing.xs),

              // Forgot password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : () => _showForgotPassword(),
                  child: Text(
                    _t('auth.forgot_password'),
                    style: AppTypography.footnote.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Login button — web platform btn-lg paritesi (düz solid primary,
              // tam genişlik, büyük boy).
              AppButton(
                label: _t('auth.login'),
                onPressed: _isLoading ? null : _handleLogin,
                isLoading: _isLoading,
                size: AppButtonSize.large,
              ),

              const SizedBox(height: AppSpacing.md),

              // Biometric login
              if (_biometricAvailable && _biometricEnabled) ...[
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.separator(context))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text(
                        _t('auth.login.or_divider'),
                        style: AppTypography.footnote.copyWith(
                          color: AppColors.secondaryLabel(context),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.separator(context))),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: _t('auth.biometric_login'),
                  variant: AppButtonVariant.secondary,
                  icon: Icons.fingerprint,
                  onPressed: _isLoading ? null : _handleBiometricLogin,
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // Erişim talebi (waitlist) — invite-only kapı.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _t('auth.request_access.no_account'),
                    style: AppTypography.footnote.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => context.push('/request-access'),
                    child: Text(
                      _t('auth.request_access.cta'),
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  void _showForgotPassword() {
    final emailController = TextEditingController(text: _emailController.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AppBottomSheet(
          title: _t('auth.reset.title'),
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _t('auth.reset.instruction'),
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppEmailField(
                  controller: emailController,
                  label: _t('auth.email'),
                  placeholder: _t('auth.login.email_placeholder'),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: _t('auth.reset.send_link'),
                  onPressed: () async {
                    if (emailController.text.isEmpty) return;

                    final result = await authService.sendPasswordResetEmail(
                      email: emailController.text.trim(),
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      if (result.isSuccess) {
                        AppSnackbar.showSuccess(
                          context,
                          message: result.message ?? _t('auth.reset.email_sent'),
                        );
                      } else {
                        AppSnackbar.showError(
                          context,
                          message: result.error?.message ?? _t('common.error'),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dinamik slogan/feature karüseli — web login'in auth-branding panelinin
/// mobil karşılığı. Sabit yükseklikli bir kutuda otomatik dönen [PageView];
/// her sayfa: bootstrap ikon + başlık + açıklama. Altında sayfa noktaları.
class _SlogansCarousel extends StatefulWidget {
  final List<BrandingFeature> features;

  const _SlogansCarousel({super.key, required this.features});

  @override
  State<_SlogansCarousel> createState() => _SlogansCarouselState();
}

class _SlogansCarouselState extends State<_SlogansCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.features.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
        if (!mounted || !_controller.hasClients) return;
        final next = (_index + 1) % widget.features.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final features = widget.features;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 68,
          child: PageView.builder(
            controller: _controller,
            itemCount: features.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final f = features[i];
              // İkon kaldırıldı (kullanıcı isteği) — yalnız başlık + açıklama.
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.title,
                      style: AppTypography.headline,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      f.body,
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (features.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < features.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
