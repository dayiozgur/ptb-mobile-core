import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class UnitSelectorScreen extends StatefulWidget {
  const UnitSelectorScreen({super.key});

  @override
  State<UnitSelectorScreen> createState() => _UnitSelectorScreenState();
}

class _UnitSelectorScreenState extends State<UnitSelectorScreen> {
  List<Unit> _units = [];
  UnitTree? _unitTree;
  bool _isLoading = true;
  String? _error;
  bool _showTreeView = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final siteId = siteService.currentSiteId;
      if (siteId == null) {
        setState(() {
          _error = 'Site seçilmemiş';
          _isLoading = false;
        });
        return;
      }

      final units = await unitService.getUnits(siteId);
      final tree = UnitTree.fromList(units);

      setState(() {
        _units = units;
        _unitTree = tree;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load units', e);
      setState(() {
        _error = 'Alanlar yüklenemedi';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectUnit(Unit unit) async {
    final success = await unitService.selectUnit(unit.id);
    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      AppSnackbar.showError(
        context,
        message: 'Alan seçilemedi',
      );
    }
  }

  List<Unit> get _filteredUnits {
    if (_searchQuery.isEmpty) return _units;
    final query = _searchQuery.toLowerCase();
    return _units.where((unit) {
      return unit.name.toLowerCase().contains(query) ||
          (unit.code?.toLowerCase().contains(query) ?? false) ||
          (unit.description?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Alan Seç',
      showBackButton: true,
      onBack: () => context.go('/home'),
      actions: [
        AppIconButton(
          icon: _showTreeView ? Icons.list : Icons.account_tree,
          onPressed: () {
            setState(() => _showTreeView = !_showTreeView);
          },
        ),
      ],
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_error != null) {
      return AppErrorView(
        title: 'Hata',
        message: _error!,
        actionLabel: 'Tekrar Dene',
        onAction: _loadUnits,
      );
    }

    if (_units.isEmpty) {
      return AppEmptyState(
        icon: Icons.space_dashboard_outlined,
        title: 'Alan Bulunamadı',
        message: 'Bu sitede henüz alan tanımlı değil.\n'
            'Yeni bir alan oluşturabilirsiniz.',
        actionLabel: 'Yeni Alan Oluştur',
        onAction: _showCreateUnitDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUnits,
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          // Site info
          _buildSiteInfo(),
          const SizedBox(height: AppSpacing.md),

          // Search
          AppTextField(
            placeholder: 'Alan ara...',
            prefixIcon: Icons.search,
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Stats
          if (_unitTree != null) ...[
            _buildStats(),
            const SizedBox(height: AppSpacing.md),
          ],

          Text(
            'Devam etmek için bir alan seçin',
            style: AppTypography.subheadline.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Unit list
          if (_showTreeView && _unitTree != null && _searchQuery.isEmpty)
            ..._buildTreeView(_unitTree!.rootUnits, 0)
          else
            ..._buildFlatList(),

          const SizedBox(height: AppSpacing.xl),

          // Create new unit button
          AppButton(
            label: 'Yeni Alan Oluştur',
            variant: AppButtonVariant.secondary,
            icon: Icons.add,
            onPressed: _showCreateUnitDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSiteInfo() {
    final site = siteService.currentSite;
    if (site == null) return const SizedBox.shrink();

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Icon(
              Icons.location_city,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    site.name,
                    style: AppTypography.subheadline,
                  ),
                  if (site.address != null)
                    Text(
                      site.address!,
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.go('/sites'),
              child: const Text('Değiştir'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.space_dashboard,
            value: '${_units.length}',
            label: 'Toplam Alan',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.square_foot,
            value: _unitTree?.totalArea.toStringAsFixed(0) ?? '0',
            label: 'm² Alan',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.layers,
            value: '${_unitTree?.rootUnits.length ?? 0}',
            label: 'Kök Alan',
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTreeView(List<Unit> units, int depth) {
    final widgets = <Widget>[];

    for (final unit in units) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(
            left: depth * 20.0,
            bottom: AppSpacing.sm,
          ),
          child: _UnitCard(
            unit: unit,
            onTap: () => _selectUnit(unit),
            isExpanded: unit.hasChildren,
          ),
        ),
      );

      if (unit.hasChildren) {
        widgets.addAll(_buildTreeView(unit.children, depth + 1));
      }
    }

    return widgets;
  }

  List<Widget> _buildFlatList() {
    final units = _filteredUnits;
    return List.generate(units.length, (index) {
      final unit = units[index];
      return Padding(
        padding: EdgeInsets.only(
          bottom: index < units.length - 1 ? AppSpacing.sm : 0,
        ),
        child: _UnitCard(
          unit: unit,
          onTap: () => _selectUnit(unit),
          showPath: true,
        ),
      );
    });
  }

  void _showCreateUnitDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final areaSizeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedParentId;
    String? selectedTypeId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: AppBottomSheet(
            title: 'Yeni Alan',
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: nameController,
                      label: 'Alan Adı',
                      placeholder: 'Örn: Zemin Kat',
                      prefixIcon: Icons.space_dashboard,
                      validator: Validators.required('Alan adı zorunludur'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Parent seçimi
                    if (_units.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        value: selectedParentId,
                        decoration: const InputDecoration(
                          labelText: 'Üst Alan (Opsiyonel)',
                          prefixIcon: Icon(Icons.account_tree),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Kök Alan (Üst alan yok)'),
                          ),
                          ..._units.map((u) => DropdownMenuItem(
                                value: u.id,
                                child: Text(u.name),
                              )),
                        ],
                        onChanged: (value) {
                          setModalState(() => selectedParentId = value);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    AppTextField(
                      controller: areaSizeController,
                      label: 'Alan Boyutu (m²)',
                      placeholder: 'Örn: 100',
                      prefixIcon: Icons.square_foot,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: descriptionController,
                      label: 'Açıklama (Opsiyonel)',
                      placeholder: 'Alan hakkında kısa bilgi',
                      prefixIcon: Icons.description,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Oluştur',
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        final siteId = siteService.currentSiteId;
                        final organizationId =
                            organizationService.currentOrganizationId;
                        final tenantId = tenantService.currentTenantId;
                        final userId = authService.currentUser?.id;

                        if (siteId == null || userId == null) return;

                        final name = nameController.text.trim();
                        final description = descriptionController.text.trim();
                        final areaSize =
                            double.tryParse(areaSizeController.text.trim());

                        final unit = await unitService.createUnit(
                          siteId: siteId,
                          name: name,
                          parentUnitId: selectedParentId,
                          organizationId: organizationId,
                          tenantId: tenantId,
                          description:
                              description.isNotEmpty ? description : null,
                          areaSize: areaSize,
                          unitTypeId: selectedTypeId,
                          createdBy: userId,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);

                          if (unit != null) {
                            AppSnackbar.showSuccess(
                              context,
                              message: 'Alan oluşturuldu',
                            );
                            _loadUnits();
                          } else {
                            AppSnackbar.showError(
                              context,
                              message: 'Alan oluşturulamadı',
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
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              value,
              style: AppTypography.headline.copyWith(
                color: AppColors.primary,
              ),
            ),
            Text(
              label,
              style: AppTypography.caption2.copyWith(
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final Unit unit;
  final VoidCallback onTap;
  final bool isExpanded;
  final bool showPath;

  const _UnitCard({
    required this.unit,
    required this.onTap,
    this.isExpanded = false,
    this.showPath = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getCategoryColor(unit.category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  _getCategoryIcon(unit.category),
                  color: _getCategoryColor(unit.category),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (unit.isMainArea) ...[
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          unit.name,
                          style: AppTypography.subheadline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      if (unit.category != null) ...[
                        AppBadge(
                          label: unit.categoryLabel,
                          variant: AppBadgeVariant.secondary,
                          size: AppBadgeSize.small,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      if (unit.areaSize != null)
                        Text(
                          unit.areaSizeFormatted,
                          style: AppTypography.caption2.copyWith(
                            color: AppColors.secondaryLabel(context),
                          ),
                        ),
                    ],
                  ),
                  if (showPath && unit.parentUnit != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Üst: ${unit.parentUnit!.name}',
                      style: AppTypography.caption2.copyWith(
                        color: AppColors.tertiaryLabel(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Children indicator
            if (isExpanded && unit.hasChildren)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${unit.children.length}',
                    style: AppTypography.caption2.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // Arrow
            Icon(
              Icons.chevron_right,
              color: AppColors.tertiaryLabel(context),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(UnitCategory? category) {
    switch (category) {
      case UnitCategory.main:
        return Icons.home;
      case UnitCategory.floor:
        return Icons.layers;
      case UnitCategory.section:
        return Icons.view_module;
      case UnitCategory.room:
        return Icons.meeting_room;
      case UnitCategory.zone:
        return Icons.grid_view;
      case UnitCategory.production:
        return Icons.precision_manufacturing;
      case UnitCategory.storage:
        return Icons.warehouse;
      case UnitCategory.service:
        return Icons.engineering;
      case UnitCategory.common:
        return Icons.groups;
      case UnitCategory.technical:
        return Icons.electrical_services;
      case UnitCategory.outdoor:
        return Icons.park;
      case UnitCategory.custom:
      case null:
        return Icons.square_foot;
    }
  }

  Color _getCategoryColor(UnitCategory? category) {
    switch (category) {
      case UnitCategory.main:
        return Colors.indigo;
      case UnitCategory.floor:
        return Colors.blue;
      case UnitCategory.section:
        return Colors.teal;
      case UnitCategory.room:
        return Colors.green;
      case UnitCategory.zone:
        return Colors.orange;
      case UnitCategory.production:
        return Colors.purple;
      case UnitCategory.storage:
        return Colors.brown;
      case UnitCategory.service:
        return Colors.grey;
      case UnitCategory.common:
        return Colors.cyan;
      case UnitCategory.technical:
        return Colors.red;
      case UnitCategory.outdoor:
        return Colors.lightGreen;
      case UnitCategory.custom:
      case null:
        return AppColors.primary;
    }
  }
}
