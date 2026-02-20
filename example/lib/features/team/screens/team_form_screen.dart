import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Ekip Form Ekranı
///
/// Yeni ekip oluşturma ve mevcut ekipleri düzenleme formu.
class TeamFormScreen extends StatefulWidget {
  final String? teamId;

  const TeamFormScreen({
    super.key,
    this.teamId,
  });

  bool get isEditing => teamId != null;

  @override
  State<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends State<TeamFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Form fields
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _independent = false;
  bool _active = true;

  Team? _existingTeam;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadExistingTeam();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingTeam() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      teamService.setTenant(tenantId);
    }

    try {
      final team = await teamService.getTeam(widget.teamId!);

      if (team != null && mounted) {
        setState(() {
          _existingTeam = team;
          _nameController.text = team.name ?? '';
          _codeController.text = team.code ?? '';
          _descriptionController.text = team.description ?? '';
          _independent = team.independent ?? false;
          _active = team.isActive;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load team', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Ekip yüklenirken hata oluştu';
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

      teamService.setTenant(tenantId);

      if (widget.isEditing && _existingTeam != null) {
        // Güncelleme
        await teamService.updateTeam(
          widget.teamId!,
          name: _nameController.text.trim(),
          code: _codeController.text.trim().isNotEmpty
              ? _codeController.text.trim()
              : null,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          independent: _independent,
          active: _active,
        );

        if (mounted) {
          AppSnackbar.success(context, message: 'Ekip güncellendi');
          context.go('/teams/${widget.teamId}');
        }
      } else {
        // Yeni oluştur
        final team = await teamService.createTeam(
          name: _nameController.text.trim(),
          code: _codeController.text.trim().isNotEmpty
              ? _codeController.text.trim()
              : null,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          independent: _independent,
        );

        if (mounted) {
          AppSnackbar.success(context, message: 'Ekip oluşturuldu');
          context.go('/teams/${team.id}');
        }
      }
    } catch (e) {
      Logger.error('Failed to save team', e);
      if (mounted) {
        AppSnackbar.error(context, message: 'Ekip kaydedilemedi');
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
      title: widget.isEditing ? 'Ekibi Düzenle' : 'Yeni Ekip',
      onBack: () => widget.isEditing
          ? context.go('/teams/${widget.teamId}')
          : context.go('/teams'),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? Center(
                  child: AppErrorView(
                    message: _errorMessage!,
                    onRetry: _loadExistingTeam,
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

                        // Ayarlar
                        _buildSectionHeader('Ayarlar', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildSettingsSection(brightness),

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
              label: 'Ekip Adı',
              placeholder: 'Örn: Bakım Ekibi A',
              prefixIcon: Icons.groups,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ekip adı zorunludur';
                }
                if (value.trim().length < 2) {
                  return 'Ekip adı en az 2 karakter olmalıdır';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // Kod
            AppTextField(
              controller: _codeController,
              label: 'Ekip Kodu',
              placeholder: 'Örn: BKM-A',
              prefixIcon: Icons.tag,
            ),

            const SizedBox(height: AppSpacing.md),

            // Açıklama
            AppTextField(
              controller: _descriptionController,
              label: 'Açıklama',
              placeholder: 'Ekip hakkında kısa açıklama...',
              prefixIcon: Icons.description_outlined,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            // Bağımsız
            Row(
              children: [
                Icon(
                  Icons.work_outline,
                  size: 20,
                  color: AppColors.textSecondary(brightness),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bağımsız Ekip',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                      Text(
                        'Ekip bağımsız olarak çalışır',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _independent,
                  onChanged: (value) => setState(() => _independent = value),
                  activeColor: AppColors.primary,
                ),
              ],
            ),

            if (widget.isEditing) ...[
              Divider(
                height: AppSpacing.lg,
                color: AppColors.separator(context),
              ),

              // Aktif
              Row(
                children: [
                  Icon(
                    Icons.power_settings_new,
                    size: 20,
                    color: AppColors.textSecondary(brightness),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aktif',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(brightness),
                          ),
                        ),
                        Text(
                          'Ekibin aktif/pasif durumu',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(brightness),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _active,
                    onChanged: (value) => setState(() => _active = value),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
