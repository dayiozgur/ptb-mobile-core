import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// İş Talebi Form Ekranı
///
/// Yeni iş talebi oluşturma ve mevcut talepleri düzenleme formu.
class WorkRequestFormScreen extends StatefulWidget {
  final String? requestId;

  const WorkRequestFormScreen({
    super.key,
    this.requestId,
  });

  bool get isEditing => requestId != null;

  @override
  State<WorkRequestFormScreen> createState() => _WorkRequestFormScreenState();
}

class _WorkRequestFormScreenState extends State<WorkRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Form fields
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _estimatedDurationController = TextEditingController();
  final _estimatedCostController = TextEditingController();

  WorkRequestType _selectedType = WorkRequestType.general;
  WorkRequestPriority _selectedPriority = WorkRequestPriority.normal;
  DateTime? _expectedCompletionDate;

  // Konum seçimi
  String? _selectedSiteId;
  String? _selectedSiteName;
  String? _selectedUnitId;
  String? _selectedUnitName;

  WorkRequest? _existingRequest;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadExistingRequest();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedDurationController.dispose();
    _estimatedCostController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingRequest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      workRequestService.setTenant(tenantId);
    }

    try {
      final request = await workRequestService.getById(widget.requestId!);

      if (request != null && mounted) {
        setState(() {
          _existingRequest = request;
          _titleController.text = request.title;
          _descriptionController.text = request.description ?? '';
          _selectedType = request.type;
          _selectedPriority = request.priority;
          _expectedCompletionDate = request.expectedCompletionDate;
          _selectedSiteId = request.siteId;
          _selectedSiteName = request.siteName;
          _selectedUnitId = request.unitId;
          _selectedUnitName = request.unitName;

          if (request.estimatedDuration != null) {
            _estimatedDurationController.text = request.estimatedDuration.toString();
          }
          if (request.estimatedCost != null) {
            _estimatedCostController.text = request.estimatedCost!.toStringAsFixed(2);
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load work request', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'İş talebi yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final tenantId = tenantService.currentTenantId;
      if (tenantId == null) {
        throw Exception('Tenant seçili değil');
      }

      final userId = authService.currentUser?.id;
      if (userId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      if (widget.isEditing && _existingRequest != null) {
        // Güncelleme
        await workRequestService.update(
          widget.requestId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          type: _selectedType,
          priority: _selectedPriority,
          expectedCompletionDate: _expectedCompletionDate,
          siteId: _selectedSiteId,
          unitId: _selectedUnitId,
          estimatedDuration: int.tryParse(_estimatedDurationController.text),
          estimatedCost: double.tryParse(_estimatedCostController.text),
        );

        if (mounted) {
          AppSnackbar.success(context, message: 'İş talebi güncellendi');
          context.go('/work-requests/${widget.requestId}');
        }
      } else {
        // Yeni oluştur
        final request = await workRequestService.create(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          type: _selectedType,
          priority: _selectedPriority,
          expectedCompletionDate: _expectedCompletionDate,
          siteId: _selectedSiteId,
          unitId: _selectedUnitId,
          estimatedDuration: int.tryParse(_estimatedDurationController.text),
          estimatedCost: double.tryParse(_estimatedCostController.text),
        );

        if (mounted) {
          AppSnackbar.success(context, message: 'İş talebi oluşturuldu');
          context.go('/work-requests/${request.id}');
        }
      }
    } catch (e) {
      Logger.error('Failed to save work request', e);
      if (mounted) {
        AppSnackbar.error(context, message: 'İş talebi kaydedilemedi');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectExpectedDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedCompletionDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _expectedCompletionDate = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: widget.isEditing ? 'Talebi Düzenle' : 'Yeni İş Talebi',
      onBack: () => widget.isEditing
          ? context.go('/work-requests/${widget.requestId}')
          : context.go('/work-requests'),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? Center(
                  child: AppErrorView(
                    message: _errorMessage!,
                    onRetry: _loadExistingRequest,
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

                        // Sınıflandırma
                        _buildSectionHeader('Sınıflandırma', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildClassificationSection(brightness),

                        const SizedBox(height: AppSpacing.lg),

                        // Konum
                        _buildSectionHeader('Konum', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildLocationSection(brightness),

                        const SizedBox(height: AppSpacing.lg),

                        // Zamanlama ve Maliyet
                        _buildSectionHeader('Zamanlama ve Maliyet', brightness),
                        const SizedBox(height: AppSpacing.sm),
                        _buildScheduleSection(brightness),

                        const SizedBox(height: AppSpacing.xl),

                        // Kaydet butonu
                        AppButton(
                          label: widget.isEditing ? 'Güncelle' : 'Oluştur',
                          icon: widget.isEditing ? Icons.save : Icons.add,
                          isLoading: _isSaving,
                          onPressed: _saveRequest,
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
            // Başlık
            AppTextField(
              controller: _titleController,
              label: 'Talep Başlığı',
              placeholder: 'Örn: Klima arızası bildirimi',
              prefixIcon: Icons.title,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Başlık zorunludur';
                }
                if (value.trim().length < 5) {
                  return 'Başlık en az 5 karakter olmalıdır';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // Açıklama
            AppTextField(
              controller: _descriptionController,
              label: 'Açıklama',
              placeholder: 'Talep detaylarını açıklayın...',
              prefixIcon: Icons.description_outlined,
              maxLines: 4,
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
            // Talep Tipi
            Text(
              'Talep Tipi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: WorkRequestType.values.map((type) {
                final isSelected = _selectedType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.systemGray6,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTypeIcon(type),
                          size: 16,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary(brightness),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          type.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary(brightness),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Öncelik
            Text(
              'Öncelik',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: WorkRequestPriority.values.map((priority) {
                final isSelected = _selectedPriority == priority;
                final color = _getPriorityColor(priority);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPriority = priority),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: priority != WorkRequestPriority.critical
                            ? AppSpacing.xs
                            : 0,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : AppColors.systemGray6,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(
                          color: isSelected ? color : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            priority.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? color : AppColors.textSecondary(brightness),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            // Site Seçimi
            InkWell(
              onTap: _selectSite,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.systemGray6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_city,
                      color: _selectedSiteId != null
                          ? AppColors.primary
                          : AppColors.textSecondary(brightness),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Site',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                          Text(
                            _selectedSiteName ?? 'Site seçin',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _selectedSiteId != null
                                  ? AppColors.textPrimary(brightness)
                                  : AppColors.textSecondary(brightness),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.systemGray,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Unit Seçimi
            InkWell(
              onTap: _selectedSiteId != null ? _selectUnit : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.systemGray6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.space_dashboard_outlined,
                      color: _selectedUnitId != null
                          ? AppColors.primary
                          : AppColors.textSecondary(brightness),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alan',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                          Text(
                            _selectedUnitName ?? 'Alan seçin',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _selectedUnitId != null
                                  ? AppColors.textPrimary(brightness)
                                  : AppColors.textSecondary(brightness),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.systemGray,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            // Beklenen Tarih
            InkWell(
              onTap: _selectExpectedDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.systemGray6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      color: _expectedCompletionDate != null
                          ? AppColors.primary
                          : AppColors.textSecondary(brightness),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Beklenen Tamamlanma Tarihi',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                          Text(
                            _expectedCompletionDate != null
                                ? '${_expectedCompletionDate!.day}/${_expectedCompletionDate!.month}/${_expectedCompletionDate!.year}'
                                : 'Tarih seçin',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _expectedCompletionDate != null
                                  ? AppColors.textPrimary(brightness)
                                  : AppColors.textSecondary(brightness),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_expectedCompletionDate != null)
                      IconButton(
                        icon: Icon(Icons.clear, color: AppColors.systemGray),
                        onPressed: () => setState(() => _expectedCompletionDate = null),
                      )
                    else
                      Icon(Icons.chevron_right, color: AppColors.systemGray),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Tahmini Süre
            AppTextField(
              controller: _estimatedDurationController,
              label: 'Tahmini Süre (dakika)',
              placeholder: 'Örn: 120',
              prefixIcon: Icons.timer_outlined,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: AppSpacing.md),

            // Tahmini Maliyet
            AppTextField(
              controller: _estimatedCostController,
              label: 'Tahmini Maliyet (TRY)',
              placeholder: 'Örn: 500.00',
              prefixIcon: Icons.attach_money,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectSite() async {
    // TODO: Site seçici göster
    // Şimdilik mevcut site'ı kullan
    final currentSite = siteService.currentSite;
    if (currentSite != null) {
      setState(() {
        _selectedSiteId = currentSite.id;
        _selectedSiteName = currentSite.name;
        // Site değiştiğinde unit'i temizle
        _selectedUnitId = null;
        _selectedUnitName = null;
      });
    } else {
      AppSnackbar.info(context, message: 'Önce bir site seçmeniz gerekiyor');
    }
  }

  Future<void> _selectUnit() async {
    // TODO: Unit seçici göster
    // Şimdilik mevcut unit'i kullan
    final currentUnit = unitService.currentUnit;
    if (currentUnit != null) {
      setState(() {
        _selectedUnitId = currentUnit.id;
        _selectedUnitName = currentUnit.name;
      });
    } else {
      AppSnackbar.info(context, message: 'Mevcut alan yok, liste ekranından seçebilirsiniz');
    }
  }

  IconData _getTypeIcon(WorkRequestType type) {
    switch (type) {
      case WorkRequestType.breakdown:
        return Icons.warning_amber_rounded;
      case WorkRequestType.maintenance:
        return Icons.build_outlined;
      case WorkRequestType.service:
        return Icons.support_agent;
      case WorkRequestType.inspection:
        return Icons.search;
      case WorkRequestType.installation:
        return Icons.add_box_outlined;
      case WorkRequestType.modification:
        return Icons.edit_note;
      case WorkRequestType.general:
        return Icons.assignment_outlined;
    }
  }

  Color _getPriorityColor(WorkRequestPriority priority) {
    switch (priority) {
      case WorkRequestPriority.low:
        return AppColors.systemGray;
      case WorkRequestPriority.normal:
        return AppColors.info;
      case WorkRequestPriority.high:
        return AppColors.warning;
      case WorkRequestPriority.urgent:
        return Colors.orange;
      case WorkRequestPriority.critical:
        return AppColors.error;
    }
  }
}
