import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../organization/screens/organization_selector_screen.dart';
import '../../site/screens/site_selector_screen.dart';
import 'unit_selector_screen.dart';

class UnitFormScreen extends StatefulWidget {
  final String? unitId;
  final String? parentId;

  const UnitFormScreen({
    super.key,
    this.unitId,
    this.parentId,
  });

  bool get isEditing => unitId != null;

  @override
  State<UnitFormScreen> createState() => _UnitFormScreenState();
}

class _UnitFormScreenState extends State<UnitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _floorController = TextEditingController();
  final _capacityController = TextEditingController();
  final _areaController = TextEditingController();

  UnitCategory _selectedCategory = UnitCategory.room;
  String? _selectedParentId;
  List<Unit> _availableParents = [];
  bool _isLoading = false;
  bool _isLoadingData = true;
  Unit? _existingUnit;

  @override
  void initState() {
    super.initState();
    _selectedParentId = widget.parentId;
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _floorController.dispose();
    _capacityController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);

    try {
      final siteId = siteService.currentSiteId;
      if (siteId == null) {
        setState(() => _isLoadingData = false);
        return;
      }

      // Mevcut unitleri yükle (parent seçimi için)
      final units = await unitService.getUnits(siteId);
      _availableParents = units;

      // Düzenleme modunda mevcut unit'i yükle
      if (widget.isEditing) {
        final unit = await unitService.getUnitById(widget.unitId!);
        if (unit != null) {
          _existingUnit = unit;
          _nameController.text = unit.name;
          _codeController.text = unit.code ?? '';
          _descriptionController.text = unit.description ?? '';
          _floorController.text = unit.floor?.toString() ?? '';
          _capacityController.text = unit.capacity?.toString() ?? '';
          _areaController.text = unit.areaSqm?.toString() ?? '';
          _selectedCategory = unit.category;
          _selectedParentId = unit.parentUnitId;

          // Kendisini ve alt elemanlarını parent listesinden çıkar
          _availableParents = _availableParents.where((u) {
            if (u.id == widget.unitId) return false;
            // Alt elemanları da kontrol et
            return !_isDescendant(u.id, widget.unitId!, units);
          }).toList();
        }
      }

      setState(() => _isLoadingData = false);
    } catch (e) {
      Logger.error('Failed to load data', e);
      setState(() => _isLoadingData = false);
    }
  }

  bool _isDescendant(String unitId, String ancestorId, List<Unit> allUnits) {
    final unit = allUnits.firstWhere((u) => u.id == unitId, orElse: () => allUnits.first);
    if (unit.parentUnitId == null) return false;
    if (unit.parentUnitId == ancestorId) return true;
    return _isDescendant(unit.parentUnitId!, ancestorId, allUnits);
  }

  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final siteId = siteService.currentSiteId;
      final tenantId = tenantService.currentTenantId;
      final userId = authService.currentUser?.id;

      if (siteId == null || tenantId == null || userId == null) {
        AppSnackbar.showError(context, message: 'Oturum bilgisi eksik');
        setState(() => _isLoading = false);
        return;
      }

      final name = _nameController.text.trim();
      final code = _codeController.text.trim();
      final description = _descriptionController.text.trim();
      final floor = int.tryParse(_floorController.text.trim());
      final capacity = int.tryParse(_capacityController.text.trim());
      final area = double.tryParse(_areaController.text.trim());

      Unit? result;

      if (widget.isEditing) {
        // Güncelle
        result = await unitService.updateUnit(
          unitId: widget.unitId!,
          name: name,
          code: code.isNotEmpty ? code : null,
          description: description.isNotEmpty ? description : null,
          category: _selectedCategory,
          parentUnitId: _selectedParentId,
          floor: floor,
          capacity: capacity,
          areaSqm: area,
        );
      } else {
        // Oluştur
        result = await unitService.createUnit(
          siteId: siteId,
          tenantId: tenantId,
          name: name,
          category: _selectedCategory,
          code: code.isNotEmpty ? code : null,
          description: description.isNotEmpty ? description : null,
          parentUnitId: _selectedParentId,
          floor: floor,
          capacity: capacity,
          areaSqm: area,
          createdBy: userId,
        );
      }

      if (mounted) {
        if (result != null) {
          AppSnackbar.showSuccess(
            context,
            message: widget.isEditing ? 'Alan güncellendi' : 'Alan oluşturuldu',
          );
          context.go('/units/${result.id}');
        } else {
          AppSnackbar.showError(
            context,
            message: widget.isEditing ? 'Alan güncellenemedi' : 'Alan oluşturulamadı',
          );
        }
      }
    } catch (e) {
      Logger.error('Failed to save unit', e);
      if (mounted) {
        AppSnackbar.showError(context, message: 'Bir hata oluştu');
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
      title: widget.isEditing ? 'Alanı Düzenle' : 'Yeni Alan',
      showBackButton: true,
      onBack: () {
        if (widget.isEditing) {
          context.go('/units/${widget.unitId}');
        } else {
          context.go('/units');
        }
      },
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
            onPressed: _saveUnit,
            child: const Text('Kaydet'),
          ),
      ],
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoadingData) {
      return const Center(child: AppLoadingIndicator());
    }

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Temel Bilgiler
            AppSectionHeader(title: 'Temel Bilgiler'),
            const SizedBox(height: AppSpacing.sm),

            AppTextField(
              controller: _nameController,
              label: 'Alan Adı',
              placeholder: 'Örn: Toplantı Odası 1',
              prefixIcon: Icons.space_dashboard,
              validator: Validators.required('Alan adı zorunludur'),
              textCapitalization: TextCapitalization.words,
              enabled: !_isLoading,
            ),

            const SizedBox(height: AppSpacing.md),

            AppTextField(
              controller: _codeController,
              label: 'Kod (Opsiyonel)',
              placeholder: 'Örn: TR-001',
              prefixIcon: Icons.qr_code,
              enabled: !_isLoading,
            ),

            const SizedBox(height: AppSpacing.md),

            // Kategori seçimi
            _CategorySelector(
              selectedCategory: _selectedCategory,
              onCategoryChanged: (category) {
                setState(() => _selectedCategory = category);
              },
              enabled: !_isLoading,
            ),

            const SizedBox(height: AppSpacing.md),

            // Parent seçimi
            _ParentSelector(
              selectedParentId: _selectedParentId,
              availableParents: _availableParents,
              onParentChanged: (parentId) {
                setState(() => _selectedParentId = parentId);
              },
              enabled: !_isLoading,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Ek Bilgiler
            AppSectionHeader(title: 'Ek Bilgiler'),
            const SizedBox(height: AppSpacing.sm),

            AppTextField(
              controller: _descriptionController,
              label: 'Açıklama (Opsiyonel)',
              placeholder: 'Alan hakkında notlar...',
              prefixIcon: Icons.description,
              maxLines: 3,
              enabled: !_isLoading,
            ),

            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _floorController,
                    label: 'Kat',
                    placeholder: '0',
                    prefixIcon: Icons.layers,
                    keyboardType: TextInputType.number,
                    enabled: !_isLoading,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    controller: _capacityController,
                    label: 'Kapasite',
                    placeholder: '10',
                    prefixIcon: Icons.people,
                    keyboardType: TextInputType.number,
                    enabled: !_isLoading,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            AppTextField(
              controller: _areaController,
              label: 'Alan (m\u00b2)',
              placeholder: '25',
              prefixIcon: Icons.square_foot,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !_isLoading,
            ),

            const SizedBox(height: AppSpacing.xl),

            // Kaydet butonu (mobil için)
            AppButton(
              label: widget.isEditing ? 'Güncelle' : 'Oluştur',
              onPressed: _isLoading ? null : _saveUnit,
              isLoading: _isLoading,
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  final UnitCategory selectedCategory;
  final ValueChanged<UnitCategory> onCategoryChanged;
  final bool enabled;

  const _CategorySelector({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori',
          style: AppTypography.subheadline.copyWith(
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: UnitCategory.values.map((category) {
            final isSelected = category == selectedCategory;
            return FilterChip(
              label: Text(category.displayName),
              selected: isSelected,
              onSelected: enabled ? (_) => onCategoryChanged(category) : null,
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ParentSelector extends StatelessWidget {
  final String? selectedParentId;
  final List<Unit> availableParents;
  final ValueChanged<String?> onParentChanged;
  final bool enabled;

  const _ParentSelector({
    required this.selectedParentId,
    required this.availableParents,
    required this.onParentChanged,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Üst Alan (Opsiyonel)',
          style: AppTypography.subheadline.copyWith(
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          onTap: enabled ? () => _showParentPicker(context) : null,
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Row(
              children: [
                Icon(
                  Icons.account_tree,
                  color: AppColors.secondaryLabel(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    selectedParentId != null
                        ? availableParents
                            .firstWhere(
                              (u) => u.id == selectedParentId,
                              orElse: () => availableParents.first,
                            )
                            .name
                        : 'Üst alan seçin (opsiyonel)',
                    style: AppTypography.subheadline.copyWith(
                      color: selectedParentId != null
                          ? null
                          : AppColors.tertiaryLabel(context),
                    ),
                  ),
                ),
                if (selectedParentId != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: enabled ? () => onParentChanged(null) : null,
                    iconSize: 20,
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.tertiaryLabel(context),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showParentPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: AppSpacing.screenPadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Üst Alan Seç', style: AppTypography.headline),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: availableParents.length,
                itemBuilder: (context, index) {
                  final unit = availableParents[index];
                  final isSelected = unit.id == selectedParentId;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.folder,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(unit.name),
                    subtitle: Text(unit.category.displayName),
                    trailing: isSelected
                        ? Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      onParentChanged(unit.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
