import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Davet Kabul (Accept Invite) ekranı — deep-link hedefi.
///
/// Web PREFERRED akışını yansıtır:
/// 1. Davet e-postasındaki bağlantı `?token_hash=…&type=invite` taşır.
/// 2. `AuthService.verifyInviteToken(tokenHash)` → tek-kullanımlık oturum kurar
///    (`verifyOtp` / `OtpType.invite`).
/// 3. Kullanıcı güçlü bir şifre belirler → `AuthService.updatePassword(…)`.
/// 4. Uygulamaya girilir (`/main`; tenant/org kurulumu redirect zinciriyle).
///
/// Eski bağlantılar (hash-flow) `#access_token=…&refresh_token=…&type=invite`
/// taşır → `AuthService.setSessionFromRefreshToken(refreshToken)` fallback'i.
///
/// Prefetch-safe: token doğrulaması yalnızca bir kez (initState) tetiklenir.
class AcceptInviteScreen extends StatefulWidget {
  /// `?token_hash=…` (web PREFERRED akışı).
  final String? tokenHash;

  /// `?type=…` (beklenen: `invite`).
  final String? type;

  /// Hash-flow fallback: `#access_token=…`.
  final String? accessToken;

  /// Hash-flow fallback: `#refresh_token=…`.
  final String? refreshToken;

  const AcceptInviteScreen({
    super.key,
    this.tokenHash,
    this.type,
    this.accessToken,
    this.refreshToken,
  });

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

enum _Phase { verifying, setPassword, error }

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Phase _phase = _Phase.verifying;
  bool _submitting = false;
  String? _errorMessage;

  String _t(String key) => sl<LocalizationService>().translate(key);

  @override
  void initState() {
    super.initState();
    // Tek sefer doğrula (link tek-kullanımlık).
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    AuthResult result;

    final tokenHash = widget.tokenHash;
    final refreshToken = widget.refreshToken;

    if (tokenHash != null && tokenHash.isNotEmpty) {
      // Web PREFERRED akışı.
      result = await authService.verifyInviteToken(tokenHash);
    } else if (refreshToken != null && refreshToken.isNotEmpty) {
      // Eski hash-flow fallback.
      result = await authService.setSessionFromRefreshToken(refreshToken);
    } else {
      setState(() {
        _phase = _Phase.error;
        _errorMessage = _t('auth.accept_invite.invalid_link');
      });
      return;
    }

    if (!mounted) return;

    result.when(
      success: (user, session) {
        setState(() => _phase = _Phase.setPassword);
      },
      failure: (error) {
        setState(() {
          _phase = _Phase.error;
          _errorMessage =
              error?.message ?? _t('auth.accept_invite.expired_or_invalid');
        });
      },
    );
  }

  /// Güçlü şifre kuralı (web ile aynı): ≥8 karakter ve harf+rakam karışımı.
  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.length < 8) {
      return _t('auth.accept_invite.password_min');
    }
    final hasLetter = RegExp(r'[A-Za-zĞÜŞİÖÇğüşıöç]').hasMatch(v);
    final hasDigit = RegExp(r'\d').hasMatch(v);
    if (!hasLetter || !hasDigit) {
      return _t('auth.accept_invite.password_weak');
    }
    return null;
  }

  Future<void> _handleSetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final result = await authService.updatePassword(_passwordController.text);
      if (!mounted) return;

      result.when(
        success: (user, session) {
          AppSnackbar.showSuccess(
            context,
            message: _t('auth.accept_invite.success'),
          );
          // Kimlik + oturum hazır; tenant/org kurulumu redirect zinciriyle.
          context.go('/main');
        },
        failure: (error) {
          AppSnackbar.showError(
            context,
            message: error?.message ?? _t('auth.accept_invite.set_password_error'),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _t('auth.accept_invite.title'),
      showBackButton: false,
      child: switch (_phase) {
        _Phase.verifying => _buildVerifying(),
        _Phase.error => _buildError(),
        _Phase.setPassword => _buildSetPassword(),
      },
    );
  }

  Widget _buildVerifying() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppLoadingIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(
            _t('auth.accept_invite.verifying'),
            style: AppTypography.subheadline.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return AppErrorView(
      title: _t('auth.accept_invite.error_title'),
      message: _errorMessage ?? _t('auth.accept_invite.expired_or_invalid'),
      actionLabel: _t('auth.login'),
      onAction: () => context.go('/login'),
    );
  }

  Widget _buildSetPassword() {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.lock_outline, size: 40, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _t('auth.accept_invite.set_password_heading'),
              style: AppTypography.largeTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _t('auth.accept_invite.set_password_subheading'),
              style: AppTypography.subheadline.copyWith(
                color: AppColors.secondaryLabel(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            AppPasswordField(
              controller: _passwordController,
              label: _t('auth.accept_invite.password'),
              enabled: !_submitting,
              validator: _validatePassword,
            ),
            const SizedBox(height: AppSpacing.md),

            AppPasswordField(
              controller: _confirmController,
              label: _t('auth.accept_invite.confirm_password'),
              enabled: !_submitting,
              validator: (value) {
                if (value != _passwordController.text) {
                  return _t('auth.accept_invite.password_mismatch');
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            AppButton(
              label: _t('auth.accept_invite.submit'),
              onPressed: _submitting ? null : _handleSetPassword,
              isLoading: _submitting,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
