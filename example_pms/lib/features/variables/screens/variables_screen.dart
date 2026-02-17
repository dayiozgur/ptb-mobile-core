import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class VariablesScreen extends StatefulWidget {
  const VariablesScreen({super.key});

  @override
  State<VariablesScreen> createState() => _VariablesScreenState();
}

class _VariablesScreenState extends State<VariablesScreen> {
  bool _isLoading = true;
  List<Variable> _variables = [];
  String? _errorMessage;
  String _searchQuery = '';
  VariableDataType? _filterType;

  @override
  void initState() {
    super.initState();
    _loadVariables();
  }

  Future<void> _loadVariables() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tenantId = tenantService.currentTenantId;
      if (tenantId != null) {
        variableService.setTenant(tenantId);
      }

      final variables = await variableService.getAll();
      if (mounted) {
        setState(() => _variables = variables);
      }
    } catch (e) {
      Logger.error('Failed to load variables', e);
      if (mounted) {
        setState(() => _errorMessage = 'Degiskenler yuklenemedi');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Variable> get _filteredVariables {
    var result = _variables;

    if (_searchQuery.isNotEmpty) {
      result = result.where((v) =>
          v.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (v.address?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)).toList();
    }

    if (_filterType != null) {
      result = result.where((v) => v.dataType == _filterType).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Degiskenler',
      onBack: () => context.go('/dashboard'),
      actions: [
        AppIconButton(
          icon: Icons.filter_list,
          onPressed: () => _showFilterSheet(),
        ),
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadVariables,
        ),
      ],
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppSearchField(
              placeholder: 'Degisken ara...',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Content
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_errorMessage != null) {
      return AppErrorView(
        title: 'Hata',
        message: _errorMessage!,
        actionLabel: 'Tekrar Dene',
        onAction: _loadVariables,
      );
    }

    final filtered = _filteredVariables;

    if (filtered.isEmpty) {
      if (_variables.isEmpty) {
        return AppEmptyState(
          icon: Icons.data_object,
          title: 'Degisken Bulunamadi',
          message: 'Henuz tanimlanmis degisken yok.',
        );
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.tertiaryLabel(context)),
            const SizedBox(height: AppSpacing.md),
            Text('Sonuc Bulunamadi', style: AppTypography.headline),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVariables,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final variable = filtered[index];
          return _VariableCard(
            variable: variable,
            onTap: () => context.push(
              '/variables/${variable.id}?name=${Uri.encodeComponent(variable.name)}',
            ),
          );
        },
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AppBottomSheet(
        title: 'Filtrele',
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Veri Tipi', style: AppTypography.subheadline),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  FilterChip(
                    label: const Text('Tumu'),
                    selected: _filterType == null,
                    onSelected: (_) {
                      setState(() => _filterType = null);
                      Navigator.pop(context);
                    },
                  ),
                  ...VariableDataType.values.map((type) => FilterChip(
                    label: Text(type.label),
                    selected: _filterType == type,
                    onSelected: (_) {
                      setState(() => _filterType = type);
                      Navigator.pop(context);
                    },
                  )),
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

class _VariableCard extends StatelessWidget {
  final Variable variable;
  final VoidCallback onTap;

  const _VariableCard({
    required this.variable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getTypeColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getTypeIcon(),
                color: _getTypeColor(),
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          variable.name,
                          style: AppTypography.headline,
                        ),
                      ),
                      AppBadge(
                        label: variable.dataType.label,
                        variant: AppBadgeVariant.info,
                        size: AppBadgeSize.small,
                      ),
                    ],
                  ),
                  if (variable.address != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      variable.address!,
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      _ValueDisplay(variable: variable),
                      const Spacer(),
                      if (!variable.isWritable)
                        Icon(
                          Icons.lock,
                          size: 14,
                          color: AppColors.tertiaryLabel(context),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor() {
    if (variable.isBoolean) return Colors.purple;
    if (variable.isNumeric) return Colors.blue;
    switch (variable.dataType) {
      case VariableDataType.string:
        return Colors.green;
      case VariableDataType.datetime:
        return Colors.orange;
      case VariableDataType.json:
        return Colors.teal;
      case VariableDataType.binary:
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getTypeIcon() {
    if (variable.isBoolean) return Icons.toggle_on;
    if (variable.isNumeric) return Icons.numbers;
    switch (variable.dataType) {
      case VariableDataType.string:
        return Icons.text_fields;
      case VariableDataType.datetime:
        return Icons.schedule;
      case VariableDataType.json:
        return Icons.data_object;
      case VariableDataType.binary:
        return Icons.memory;
      default:
        return Icons.tag;
    }
  }
}

class _ValueDisplay extends StatelessWidget {
  final Variable variable;

  const _ValueDisplay({required this.variable});

  @override
  Widget build(BuildContext context) {
    final value = variable.value;

    if (value == null || value.isEmpty) {
      return Text(
        'Deger yok',
        style: AppTypography.caption2.copyWith(
          color: AppColors.tertiaryLabel(context),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (variable.isBoolean) {
      final boolValue = variable.booleanValue ?? false;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: boolValue ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            boolValue ? 'ON' : 'OFF',
            style: AppTypography.caption1.copyWith(
              fontWeight: FontWeight.w600,
              color: boolValue ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      );
    }

    return Text(
      variable.formattedValue,
      style: AppTypography.caption1.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
    );
  }
}
