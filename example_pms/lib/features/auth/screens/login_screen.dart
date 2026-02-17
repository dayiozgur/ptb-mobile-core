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

      result.when(
        success: (user, session) {
          Logger.info('Login successful: ${user.email}');

          if (_biometricAvailable && !_biometricEnabled) {
            _showEnableBiometricDialog();
          } else {
            context.go('/tenant-select');
          }
        },
        failure: (error) {
          AppSnackbar.showError(
            context,
            message: error?.message ?? 'Giris basarisiz',
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEnableBiometricDialog() async {
    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Biyometrik Giris'),
        content: const Text(
          'Gelecekte daha hizli giris icin biyometrik dogrulamayi etkinlestirmek ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayir'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet, Etkinlestir'),
          ),
        ],
      ),
    );

    if (shouldEnable == true) {
      await authService.enableBiometricLogin();
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Biyometrik giris etkinlestirildi',
        );
      }
    }

    if (mounted) {
      context.go('/tenant-select');
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (!_biometricEnabled) {
      if (mounted) {
        AppSnackbar.showInfo(
          context,
          message: 'Once email ile giris yapip biyometrik girisi etkinlestirin',
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await authService.authenticateWithBiometric(
        reason: 'Uygulamaya giris yapmak icin dogrulayin',
      );

      if (!mounted) return;

      if (result.isSuccess) {
        final sessionResult = await authService.restoreSession();

        if (!mounted) return;

        sessionResult.when(
          success: (user, session) {
            context.go('/tenant-select');
          },
          failure: (error) {
            authService.disableBiometricLogin();
            setState(() => _biometricEnabled = false);
            AppSnackbar.showError(
              context,
              message: 'Oturum suresi dolmus, lutfen tekrar giris yapin',
            );
          },
        );
      } else {
        AppSnackbar.showError(
          context,
          message: result.errorMessage ?? 'Biyometrik dogrulama basarisiz',
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
      title: 'PMS Giris',
      showBackButton: false,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxl),

              // Logo
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.monitor_heart,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Title
              Text(
                'Protoolbag PMS',
                style: AppTypography.largeTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'IoT Izleme Sistemine Giris Yapin',
                style: AppTypography.subheadline.copyWith(
                  color: AppColors.secondaryLabel(context),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xl),

              // Email field
              AppEmailField(
                controller: _emailController,
                enabled: !_isLoading,
              ),

              const SizedBox(height: AppSpacing.md),

              // Password field
              AppPasswordField(
                controller: _passwordController,
                enabled: !_isLoading,
              ),

              const SizedBox(height: AppSpacing.xs),

              // Forgot password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : () => _showForgotPassword(),
                  child: Text(
                    'Sifremi Unuttum',
                    style: AppTypography.footnote.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Login button
              AppButton(
                label: 'Giris Yap',
                onPressed: _isLoading ? null : _handleLogin,
                isLoading: _isLoading,
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
                        'veya',
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
                  label: 'Biyometrik ile Giris',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.fingerprint,
                  onPressed: _isLoading ? null : _handleBiometricLogin,
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
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
          title: 'Sifre Sifirlama',
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Email adresinizi girin, size sifre sifirlama linki gonderecegiz.',
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppEmailField(controller: emailController),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Sifirlama Linki Gonder',
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
                          message: result.message ?? 'Email gonderildi',
                        );
                      } else {
                        AppSnackbar.showError(
                          context,
                          message: result.error?.message ?? 'Hata olustu',
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
