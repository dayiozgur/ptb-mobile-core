import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Erişim Talebi (Waitlist) ekranı.
///
/// M3 (invite-only): açık kayıt kaldırıldı. Bu ekran artık hesap OLUŞTURMAZ;
/// yalnızca `access_requests` tablosuna bir erişim talebi yazar (status
/// varsayılan 'pending'). Talep, yönetici tarafından incelenir ve onaylanırsa
/// kullanıcıya davet gönderilir.
///
/// NOT: Sınıf adı geriye dönük yönlendirme uyumu için `RegisterScreen` olarak
/// korunmuştur (`/register` rotası artık "erişim talebi" ekranını gösterir).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  String _t(String key) => localizationService.translate(key);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestAccess() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.from('access_requests').insert({
        'email': _emailController.text.trim().toLowerCase(),
        'full_name': _nameController.text.trim(),
        if (_companyController.text.trim().isNotEmpty)
          'company': _companyController.text.trim(),
        if (_phoneController.text.trim().isNotEmpty)
          'phone': _phoneController.text.trim(),
        if (_messageController.text.trim().isNotEmpty)
          'message': _messageController.text.trim(),
        'source': 'mobile',
      });

      if (!mounted) return;
      _showConfirmation();
    } catch (e) {
      Logger.error('Access request failed', e);
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: _t('auth.request_access.error'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.mark_email_read, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(_t('auth.request_access.received_title'))),
          ],
        ),
        content: Text(_t('auth.request_access.received_message')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            child: Text(_t('common.ok')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _t('auth.request_access.title'),
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
              Text(
                _t('auth.request_access.heading'),
                style: AppTypography.largeTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _t('auth.request_access.subheading'),
                style: AppTypography.subheadline.copyWith(
                  color: AppColors.secondaryLabel(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Full name
              AppTextField(
                controller: _nameController,
                label: _t('auth.request_access.full_name'),
                prefixIcon: Icons.person_outline,
                enabled: !_isLoading,
                validator: Validators.required(_t('auth.request_access.full_name_required')),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),

              // Email
              AppEmailField(
                controller: _emailController,
                enabled: !_isLoading,
              ),
              const SizedBox(height: AppSpacing.md),

              // Company (optional)
              AppTextField(
                controller: _companyController,
                label: _t('auth.request_access.company'),
                prefixIcon: Icons.business_outlined,
                enabled: !_isLoading,
              ),
              const SizedBox(height: AppSpacing.md),

              // Phone (optional)
              AppTextField(
                controller: _phoneController,
                label: _t('auth.request_access.phone'),
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                enabled: !_isLoading,
              ),
              const SizedBox(height: AppSpacing.md),

              // Message (optional)
              AppTextField(
                controller: _messageController,
                label: _t('auth.request_access.message'),
                prefixIcon: Icons.message_outlined,
                maxLines: 3,
                enabled: !_isLoading,
              ),
              const SizedBox(height: AppSpacing.lg),

              AppButton(
                label: _t('auth.request_access.submit'),
                onPressed: _isLoading ? null : _handleRequestAccess,
                isLoading: _isLoading,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Back to login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _t('auth.request_access.have_account'),
                    style: AppTypography.footnote.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : () => context.go('/login'),
                    child: Text(
                      _t('auth.login'),
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
