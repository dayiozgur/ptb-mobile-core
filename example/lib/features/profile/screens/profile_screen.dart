import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  final _titleController = TextEditingController();

  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  String? _avatarUrl;
  File? _selectedImage;

  // Notification settings
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _smsNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = authService.currentUser;
    if (user == null) return;

    final metadata = user.userMetadata ?? {};

    setState(() {
      _fullNameController.text = metadata['full_name'] as String? ?? '';
      _phoneController.text = metadata['phone'] as String? ?? '';
      _companyController.text = metadata['company'] as String? ?? '';
      _titleController.text = metadata['title'] as String? ?? '';
      _avatarUrl = metadata['avatar_url'] as String?;

      // Load notification preferences
      _emailNotifications = metadata['email_notifications'] as bool? ?? true;
      _pushNotifications = metadata['push_notifications'] as bool? ?? true;
      _smsNotifications = metadata['sms_notifications'] as bool? ?? false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        await _uploadAvatar();
      }
    } catch (e) {
      Logger.error('Failed to pick image', e);
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Resim seçilemedi',
        );
      }
    }
  }

  Future<void> _uploadAvatar() async {
    if (_selectedImage == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final user = authService.currentUser;
      if (user == null) throw Exception('User not found');

      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await _selectedImage!.readAsBytes();

      // Upload to Supabase Storage
      final path = await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // Update user metadata
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'avatar_url': publicUrl,
          },
        ),
      );

      setState(() {
        _avatarUrl = publicUrl;
        _selectedImage = null;
      });

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Profil fotoğrafı güncellendi',
        );
      }
    } catch (e) {
      Logger.error('Failed to upload avatar', e);
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Fotoğraf yüklenemedi',
        );
      }
    } finally {
      setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = authService.currentUser;
      if (user == null) throw Exception('User not found');

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'full_name': _fullNameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'company': _companyController.text.trim(),
            'title': _titleController.text.trim(),
            'email_notifications': _emailNotifications,
            'push_notifications': _pushNotifications,
            'sms_notifications': _smsNotifications,
          },
        ),
      );

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Profil güncellendi',
        );
      }
    } catch (e) {
      Logger.error('Failed to save profile', e);
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Profil güncellenemedi',
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AppBottomSheet(
        title: 'Profil Fotoğrafı',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.camera_alt, color: AppColors.primary),
              ),
              title: 'Kamera',
              subtitle: 'Fotoğraf çek',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            Divider(height: 1, color: AppColors.separator(context)),
            AppListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library, color: Colors.purple),
              ),
              title: 'Galeri',
              subtitle: 'Mevcut fotoğraflardan seç',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_avatarUrl != null) ...[
              Divider(height: 1, color: AppColors.separator(context)),
              AppListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete, color: AppColors.error),
                ),
                title: 'Fotoğrafı Kaldır',
                onTap: () async {
                  Navigator.pop(context);
                  await _removeAvatar();
                },
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Future<void> _removeAvatar() async {
    setState(() => _isUploadingAvatar = true);

    try {
      final user = authService.currentUser;
      if (user == null) throw Exception('User not found');

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'avatar_url': null,
          },
        ),
      );

      setState(() => _avatarUrl = null);

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Profil fotoğrafı kaldırıldı',
        );
      }
    } catch (e) {
      Logger.error('Failed to remove avatar', e);
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Fotoğraf kaldırılamadı',
        );
      }
    } finally {
      setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;

    return AppScaffold(
      title: 'Profil',
      showBackButton: true,
      onBack: () => context.go('/settings'),
      actions: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          TextButton(
            onPressed: _saveProfile,
            child: const Text('Kaydet'),
          ),
      ],
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar section
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showImagePickerOptions,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.separator(context),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: _selectedImage != null
                                  ? Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    )
                                  : _avatarUrl != null
                                      ? Image.network(
                                          _avatarUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _buildAvatarPlaceholder(),
                                        )
                                      : _buildAvatarPlaceholder(),
                            ),
                          ),
                          if (_isUploadingAvatar)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          else
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      user?.email ?? '',
                      style: AppTypography.subheadline.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Personal info section
              AppSectionHeader(title: 'Kişisel Bilgiler'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _fullNameController,
                        label: 'Ad Soyad',
                        placeholder: 'Örn: Ahmet Yılmaz',
                        prefixIcon: Icons.person,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _phoneController,
                        label: 'Telefon',
                        placeholder: 'Örn: +90 532 123 4567',
                        prefixIcon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _companyController,
                        label: 'Şirket',
                        placeholder: 'Şirket adı',
                        prefixIcon: Icons.business,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _titleController,
                        label: 'Ünvan',
                        placeholder: 'Örn: Proje Yöneticisi',
                        prefixIcon: Icons.work,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Notification settings
              AppSectionHeader(title: 'Bildirim Tercihleri'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    AppListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.email, color: Colors.blue),
                      ),
                      title: 'E-posta Bildirimleri',
                      subtitle: 'Önemli güncellemeler için e-posta al',
                      trailing: Switch.adaptive(
                        value: _emailNotifications,
                        onChanged: (value) {
                          setState(() => _emailNotifications = value);
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                    Divider(height: 1, color: AppColors.separator(context)),
                    AppListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.notifications, color: Colors.orange),
                      ),
                      title: 'Push Bildirimleri',
                      subtitle: 'Anlık bildirimler al',
                      trailing: Switch.adaptive(
                        value: _pushNotifications,
                        onChanged: (value) {
                          setState(() => _pushNotifications = value);
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                    Divider(height: 1, color: AppColors.separator(context)),
                    AppListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.sms, color: Colors.green),
                      ),
                      title: 'SMS Bildirimleri',
                      subtitle: 'Kritik uyarılar için SMS al',
                      trailing: Switch.adaptive(
                        value: _smsNotifications,
                        onChanged: (value) {
                          setState(() => _smsNotifications = value);
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Account info
              AppSectionHeader(title: 'Hesap Bilgileri'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    AppListTile(
                      leading: Icon(Icons.email_outlined, color: AppColors.primary),
                      title: 'E-posta',
                      subtitle: user?.email ?? '',
                    ),
                    Divider(height: 1, color: AppColors.separator(context)),
                    AppListTile(
                      leading: Icon(Icons.calendar_today, color: AppColors.primary),
                      title: 'Kayıt Tarihi',
                      subtitle: _formatDate(user?.createdAt),
                    ),
                    Divider(height: 1, color: AppColors.separator(context)),
                    AppListTile(
                      leading: Icon(Icons.access_time, color: AppColors.primary),
                      title: 'Son Giriş',
                      subtitle: _formatDate(user?.lastSignInAt),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Danger zone
              AppSectionHeader(title: 'Tehlikeli Bölge'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    AppListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.delete_forever, color: AppColors.error),
                      ),
                      title: 'Hesabı Sil',
                      subtitle: 'Bu işlem geri alınamaz',
                      onTap: _showDeleteAccountDialog,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    final user = authService.currentUser;
    final initials = _getInitials(user?.email ?? 'U');

    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Center(
        child: Text(
          initials,
          style: AppTypography.title1.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split('@').first.split(RegExp(r'[._]'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
          'Hesabınızı silmek istediğinizden emin misiniz? '
          'Bu işlem geri alınamaz ve tüm verileriniz kalıcı olarak silinecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AppSnackbar.showInfo(
                context,
                message: 'Hesap silme işlemi için destek ekibiyle iletişime geçin',
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );
  }
}
