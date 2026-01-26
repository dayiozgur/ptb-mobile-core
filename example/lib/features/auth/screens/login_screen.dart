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
          // Router will handle redirect based on tenant state
          context.go('/tenant-select');
        },
        failure: (error) {
          AppSnackbar.showError(
            context,
            message: error?.message ?? 'Giriş başarısız',
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    final isAvailable = await authService.isBiometricAvailable();
    if (!isAvailable) {
      if (mounted) {
        AppSnackbar.showInfo(
          context,
          message: 'Biyometrik doğrulama kullanılamıyor',
        );
      }
      return;
    }

    final result = await authService.authenticateWithBiometric(
      reason: 'Uygulamaya giriş yapmak için doğrulayın',
    );

    if (result.isSuccess) {
      // Restore previous session
      final sessionResult = await authService.restoreSession();
      if (mounted) {
        sessionResult.when(
          success: (user, session) {
            context.go('/tenant-select');
          },
          failure: (error) {
            AppSnackbar.showError(
              context,
              message: 'Oturum geri yüklenemedi',
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Giriş Yap',
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
                    Icons.rocket_launch,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Title
              Text(
                'Hoş Geldiniz',
                style: AppTypography.largeTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Devam etmek için giriş yapın',
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
                    'Şifremi Unuttum',
                    style: AppTypography.footnote.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Login button
              AppButton(
                label: 'Giriş Yap',
                onPressed: _isLoading ? null : _handleLogin,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.md),

              // Biometric login
              FutureBuilder<bool>(
                future: authService.isBiometricAvailable(),
                builder: (context, snapshot) {
                  if (snapshot.data != true) return const SizedBox.shrink();

                  return Column(
                    children: [
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
                        label: 'Biyometrik ile Giriş',
                        variant: AppButtonVariant.secondary,
                        icon: Icons.fingerprint,
                        onPressed: _isLoading ? null : _handleBiometricLogin,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hesabınız yok mu? ',
                    style: AppTypography.footnote.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : () => context.push('/register'),
                    child: Text(
                      'Kayıt Ol',
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
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
          title: 'Şifre Sıfırlama',
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Email adresinizi girin, size şifre sıfırlama linki göndereceğiz.',
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppEmailField(controller: emailController),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Sıfırlama Linki Gönder',
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
                          message: result.message ?? 'Email gönderildi',
                        );
                      } else {
                        AppSnackbar.showError(
                          context,
                          message: result.error?.message ?? 'Hata oluştu',
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
