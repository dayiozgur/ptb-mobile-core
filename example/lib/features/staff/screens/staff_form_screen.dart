import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Personel Form Ekranı
///
/// Yeni personel oluşturma ve mevcut personeli düzenleme formu.
class StaffFormScreen extends StatefulWidget {
  final String? staffId;

  const StaffFormScreen({
    super.key,
    this.staffId,
  });

  bool get isEditing => staffId != null;

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Form fields
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedStaffTypeId;
  List<StaffType> _staffTypes = [];
  bool _isActive = true;

  Staff? _existingStaff;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      staffService.setTenant(tenantId);
    }

    try {
      // Personel tiplerini yükle
      final staffTypes = await staffService.getStaffTypes();

      // Düzenleme modundaysa mevcut personeli yükle
      if (widget.isEditing) {
        final staff = await staffService.getStaff(widget.staffId!);

        if (staff != null && mounted) {
          setState(() {
            _existingStaff = staff;
            _staffTypes = staffTypes;
            _nameController.text = staff.name ?? '';
            _codeController.text = staff.code ?? '';
            _firstNameController.text = staff.firstName ?? '';
            _lastNameController.text = staff.lastName ?? '';
            _emailController.text = staff.email ?? '';
            _phoneController.text = staff.phone ?? '';
            _selectedStaffTypeId = staff.staffTypeId;
            _isActive = staff.isActive;
            _isLoading = false;
          });
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = 'Personel bulunamadı';
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _staffTypes = staffTypes;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      Logger.error('Failed to load staff form data', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Veriler yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final tenantId = tenantService.currentTenantId;
      if (tenantId == null) {
        throw Exception('Tenant seçili değil');
      }

      if (widget.isEditing && _existingStaff != null) {
        // Güncelleme
        await staffService.updateStaff(
          widget.staffId!,
          name: _nameController.text.trim(),
          code: _codeController.text.trim().isNotEmpty
              ? _codeController.text.trim()
              : null,
          firstName: _firstNameController.text.trim().isNotEmpty
              ? _firstNameController.text.trim()
              : null,
          lastName: _lastNameController.text.trim().isNotEmpty
              ? _lastNameController.text.trim()
              : null,
          email: _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          staffTypeId: _selectedStaffTypeId,
          active: _isActive,
        );

        if (mounted) {
          AppSnackbar.success(context, message: 'Personel güncellendi');
          context.go('/staff/${widget.staffId}');
        }
      } else {
        // Yeni oluştur
        final staff = await staffService.createStaff(
          name: _nameController.text.trim(),
          code: _codeController.text.trim().isNotEmpty
              ? _codeController.text.trim()
              : null,
          firstName: _firstNameController.text.trim().isNotEmpty
              ? _firstNameController.text.trim()
              : null,
          lastName: _lastNameController.text.trim().isNotEmpty
              ? _lastNameController.text.trim()
              : null,
          email: _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          staffTypeId: _selectedStaffTypeId,
        );

        if (mounted) {
          AppSnackbar.success(context, message: 'Personel oluşturuldu');
          context.go('/staff/${staff.id}');
        }
      }
    } catch (e) {
      Logger.error('Failed to save staff', e);
      if (mounted) {
        AppSnackbar.error(context, message: 'Personel kaydedilemedi');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: widget.isEditing ? 'Personeli Düzenle' : 'Yeni Personel',
      onBack: () => widget.isEditing
          ? context.go('/staff/${widget.staffId}')
          : context.go('/staff'),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? Center(
                  child: AppErrorView(
                    message: _errorMessage!,
                    onRetry: _loadInitialData,
                  ),
                )
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: AppSpacing.screenPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Temel Bilgiler
                        _buildSectionHeader('Temel Bilgiler', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildBasicInfoSection(brightness),

                        const SizedBox(height: AppSpacing.lg),

                        // İletişim Bilgileri
                        _buildSectionHeader('İletişim Bilgileri', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildContactSection(brightness),

                        const SizedBox(height: AppSpacing.lg),

                        // Personel Tipi
                        _buildSectionHeader('Sınıflandırma', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildClassificationSection(brightness),

                        // Aktif durumu (sadece düzenleme modunda)
                        if (widget.isEditing) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _buildSectionHeader('Durum', brightness),
                          const SizedBox(height: AppSpacing.sm),
                          _buildStatusSection(brightness),
                        ],

                        const SizedBox(height: AppSpacing.xl),

                        // Kaydet butonu
                        AppButton(
                          label: widget.isEditing ? 'Güncelle' : 'Oluştur',
                          icon: widget.isEditing ? Icons.save : Icons.add,
                          isLoading: _isSaving,
                          onPressed: _save,
                        ),

                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, Brightness brightness) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary(brightness),
      ),
    );
  }

  Widget _buildBasicInfoSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            // Ad
            AppTextField(
              controller: _nameController,
              label: 'Ad',
              placeholder: 'Personel adı',
              prefixIcon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ad zorunludur';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // Kod
            AppTextField(
              controller: _codeController,
              label: 'Kod',
              placeholder: 'Personel kodu',
              prefixIcon: Icons.tag,
            ),

            const SizedBox(height: AppSpacing.md),

            // İsim
            AppTextField(
              controller: _firstNameController,
              label: 'İsim',
              placeholder: 'İsim',
              prefixIcon: Icons.badge_outlined,
            ),

            const SizedBox(height: AppSpacing.md),

            // Soyisim
            AppTextField(
              controller: _lastNameController,
              label: 'Soyisim',
              placeholder: 'Soyisim',
              prefixIcon: Icons.badge_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            // E-posta
            AppTextField(
              controller: _emailController,
              label: 'E-posta',
              placeholder: 'ornek@email.com',
              prefixIcon: Icons.email_outlined,
            ),

            const SizedBox(height: AppSpacing.md),

            // Telefon
            AppTextField(
              controller: _phoneController,
              label: 'Telefon',
              placeholder: '+90 5XX XXX XX XX',
              prefixIcon: Icons.phone_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassificationSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personel Tipi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              value: _selectedStaffTypeId,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.category_outlined,
                  color: AppColors.textSecondary(brightness),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: BorderSide(color: AppColors.separator(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: BorderSide(color: AppColors.separator(context)),
                ),
                filled: true,
                fillColor: AppColors.systemGray6,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              hint: Text(
                'Personel tipi seçin',
                style: TextStyle(
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              items: _staffTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type.id,
                  child: Text(type.name ?? '-'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStaffTypeId = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Icon(
              Icons.toggle_on_outlined,
              color: AppColors.textSecondary(brightness),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Aktif',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
            ),
            Switch.adaptive(
              value: _isActive,
              activeColor: AppColors.success,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
