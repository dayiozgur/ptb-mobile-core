import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../site/screens/site_selector_screen.dart';
import 'unit_selector_screen.dart';

class UnitDetailScreen extends StatefulWidget {
  final String unitId;

  const UnitDetailScreen({super.key, required this.unitId});

  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> {
  Unit? _unit;
  List<Unit> _children = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUnit();
  }

  Future<void> _loadUnit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final unit = await unitService.getUnitById(widget.unitId);
      if (unit == null) {
        setState(() {
          _error = 'Alan bulunamadı';
          _isLoading = false;
        });
        return;
      }

      // Alt alanları yükle
      final siteId = siteService.currentSiteId;
      List<Unit> children = [];
      if (siteId != null) {
        final allUnits = await unitService.getUnits(siteId);
        children = allUnits.where((u) => u.parentUnitId == widget.unitId).toList();
      }

      setState(() {
        _unit = unit;
        _children = children;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load unit', e);
      setState(() {
        _error = 'Alan yüklenemedi';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUnit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alanı Sil'),
        content: Text(
          _children.isNotEmpty
              ? 'Bu alanın ${_children.length} alt alanı var. Silmek istediğinizden emin misiniz?'
              : 'Bu alanı silmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await unitService.deleteUnit(widget.unitId);
      if (mounted) {
        if (success) {
          AppSnackbar.showSuccess(context, message: 'Alan silindi');
          context.go('/units');
        } else {
          AppSnackbar.showError(context, message: 'Alan silinemedi');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _unit?.name ?? 'Alan Detayı',
      showBackButton: true,
      onBack: () => context.go('/units'),
      actions: [
        if (_unit != null) ...[
          AppIconButton(
            icon: Icons.edit,
            onPressed: () => context.push('/units/${widget.unitId}/edit'),
          ),
          AppIconButton(
            icon: Icons.delete,
            onPressed: _deleteUnit,
          ),
        ],
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
        onAction: _loadUnit,
      );
    }

    if (_unit == null) {
      return const AppEmptyState(
        icon: Icons.space_dashboard_outlined,
        title: 'Alan Bulunamadı',
        message: 'İstenen alan mevcut değil.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUnit,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unit header card
            _UnitHeaderCard(unit: _unit!),

            const SizedBox(height: AppSpacing.lg),

            // Unit info
            AppSectionHeader(title: 'Detaylar'),
            const SizedBox(height: AppSpacing.sm),
            _UnitInfoCard(unit: _unit!),

            const SizedBox(height: AppSpacing.lg),

            // Children
            AppSectionHeader(
              title: 'Alt Alanlar',
              action: TextButton.icon(
                onPressed: () => context.push('/units/new?parentId=${widget.unitId}'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ekle'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ChildrenList(
              children: _children,
              onChildTap: (child) => context.push('/units/${child.id}'),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _UnitHeaderCard extends StatelessWidget {
  final Unit unit;

  const _UnitHeaderCard({required this.unit});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.filled,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _getCategoryColor(unit.category ?? UnitCategory.custom).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(
                  _getCategoryIcon(unit.category ?? UnitCategory.custom),
                  color: _getCategoryColor(unit.category ?? UnitCategory.custom),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.name,
                    style: AppTypography.title2,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      AppBadge(
                        label: unit.categoryLabel,
                        variant: AppBadgeVariant.primary,
                        size: AppBadgeSize.small,
                      ),
                      if (unit.unitType != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        AppBadge(
                          label: unit.unitType!.name,
                          variant: AppBadgeVariant.secondary,
                          size: AppBadgeSize.small,
                        ),
                      ],
                    ],
                  ),
                  if (unit.code != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Kod: ${unit.code}',
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(UnitCategory category) {
    switch (category) {
      case UnitCategory.main:
        return Colors.blue;
      case UnitCategory.floor:
        return Colors.indigo;
      case UnitCategory.section:
        return Colors.purple;
      case UnitCategory.room:
        return Colors.orange;
      case UnitCategory.zone:
        return Colors.teal;
      case UnitCategory.production:
        return Colors.red;
      case UnitCategory.storage:
        return Colors.brown;
      case UnitCategory.service:
        return Colors.cyan;
      case UnitCategory.common:
        return Colors.green;
      case UnitCategory.technical:
        return Colors.grey;
      case UnitCategory.outdoor:
        return Colors.lightGreen;
      case UnitCategory.custom:
        return Colors.pink;
    }
  }

  IconData _getCategoryIcon(UnitCategory category) {
    switch (category) {
      case UnitCategory.main:
        return Icons.home;
      case UnitCategory.floor:
        return Icons.layers;
      case UnitCategory.section:
        return Icons.grid_view;
      case UnitCategory.room:
        return Icons.meeting_room;
      case UnitCategory.zone:
        return Icons.map;
      case UnitCategory.production:
        return Icons.factory;
      case UnitCategory.storage:
        return Icons.warehouse;
      case UnitCategory.service:
        return Icons.build;
      case UnitCategory.common:
        return Icons.people;
      case UnitCategory.technical:
        return Icons.settings;
      case UnitCategory.outdoor:
        return Icons.park;
      case UnitCategory.custom:
        return Icons.extension;
    }
  }
}

class _UnitInfoCard extends StatelessWidget {
  final Unit unit;

  const _UnitInfoCard({required this.unit});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            if (unit.description != null) ...[
              _InfoRow(
                icon: Icons.description,
                label: 'Açıklama',
                value: unit.description!,
              ),
              const Divider(),
            ],
            if (unit.areaSize != null) ...[
              _InfoRow(
                icon: Icons.square_foot,
                label: 'Alan',
                value: unit.areaSizeFormatted,
              ),
              const Divider(),
            ],
            if (unit.createdAt != null) ...[
              _InfoRow(
                icon: Icons.calendar_today,
                label: 'Oluşturulma',
                value: _formatDate(unit.createdAt!),
              ),
            ],
            if (unit.updatedAt != null && unit.updatedAt != unit.createdAt) ...[
              const Divider(),
              _InfoRow(
                icon: Icons.update,
                label: 'Son Güncelleme',
                value: _formatDate(unit.updatedAt!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondaryLabel(context)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.subheadline.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTypography.subheadline,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildrenList extends StatelessWidget {
  final List<Unit> children;
  final Function(Unit) onChildTap;

  const _ChildrenList({
    required this.children,
    required this.onChildTap,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return AppCard(
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.folder_open,
                  size: 40,
                  color: AppColors.tertiaryLabel(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Alt alan yok',
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppCard(
      child: Column(
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          final isLast = index == children.length - 1;

          return Column(
            children: [
              AppListTile(
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
                    size: 20,
                  ),
                ),
                title: child.name,
                subtitle: child.categoryLabel,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onChildTap(child),
              ),
              if (!isLast) Divider(height: 1, color: AppColors.separator(context)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
