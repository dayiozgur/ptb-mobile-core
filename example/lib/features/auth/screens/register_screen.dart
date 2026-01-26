import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      AppSnackbar.showWarning(
        context,
        message: 'Kullanım koşullarını kabul etmelisiniz',
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      AppSnackbar.showError(
        context,
        message: 'Şifreler eşleşmiyor',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        metadata: {
          'full_name': _nameController.text.trim(),
        },
      );

      if (!mounted) return;

      result.when(
        success: (user, session) {
          Logger.info('Registration successful: ${user.email}');
          AppSnackbar.showSuccess(
            context,
            message: 'Kayıt başarılı! Hoş geldiniz.',
          );
          context.go('/tenant-select');
        },
        failure: (error) {
          AppSnackbar.showError(
            context,
            message: error?.message ?? 'Kayıt başarısız',
          );
        },
      );

      // Email verification pending durumunu kontrol et
      if (result.status == AuthStatus.emailVerificationPending) {
        if (mounted) {
          _showEmailVerificationDialog();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.mark_email_read, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            const Text('Email Doğrulama'),
          ],
        ),
        content: const Text(
          'Kayıt işleminizi tamamlamak için email adresinize gönderilen '
          'doğrulama linkine tıklayın.\n\n'
          'Email gelmedi mi? Spam klasörünüzü kontrol edin.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await authService.resendEmailVerification(
                email: _emailController.text.trim(),
              );
              if (context.mounted) {
                Navigator.pop(context);
                AppSnackbar.showSuccess(
                  context,
                  message: 'Doğrulama emaili tekrar gönderildi',
                );
              }
            },
            child: const Text('Tekrar Gönder'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Kayıt Ol',
      showBackButton: true,
      onBack: () => context.go('/login'),
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // Title
              Text(
                'Hesap Oluştur',
                style: AppTypography.largeTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Bilgilerinizi girerek başlayın',
                style: AppTypography.subheadline.copyWith(
                  color: AppColors.secondaryLabel(context),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xl),

              // Name field
              AppTextField(
                controller: _nameController,
                label: 'Ad Soyad',
                placeholder: 'Adınızı girin',
                prefixIcon: Icons.person_outline,
                enabled: !_isLoading,
                validator: Validators.required('Ad soyad zorunludur'),
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: AppSpacing.md),

              // Email field
              AppEmailField(
                controller: _emailController,
                enabled: !_isLoading,
              ),

              const SizedBox(height: AppSpacing.md),

              // Password field
              AppPasswordField(
                controller: _passwordController,
                label: 'Şifre',
                enabled: !_isLoading,
                validator: Validators.combine([
                  Validators.required('Şifre zorunludur'),
                  Validators.password(),
                ]),
              ),

              const SizedBox(height: AppSpacing.md),

              // Confirm password field
              AppPasswordField(
                controller: _confirmPasswordController,
                label: 'Şifre Tekrar',
                enabled: !_isLoading,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Şifreler eşleşmiyor';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.lg),

              // Terms checkbox
              Row(
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    onChanged: _isLoading
                        ? null
                        : (value) => setState(() => _acceptedTerms = value ?? false),
                    activeColor: AppColors.primary,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () => setState(() => _acceptedTerms = !_acceptedTerms),
                      child: Text.rich(
                        TextSpan(
                          text: 'Okudum ve kabul ediyorum: ',
                          style: AppTypography.footnote,
                          children: [
                            TextSpan(
                              text: 'Kullanım Koşulları',
                              style: AppTypography.footnote.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const TextSpan(text: ' ve '),
                            TextSpan(
                              text: 'Gizlilik Politikası',
                              style: AppTypography.footnote.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Register button
              AppButton(
                label: 'Kayıt Ol',
                onPressed: _isLoading ? null : _handleRegister,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.xl),

              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Zaten hesabınız var mı? ',
                    style: AppTypography.footnote.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : () => context.pop(),
                    child: Text(
                      'Giriş Yap',
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
