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
      final variables = await variableService.getAll();
      if (mounted) {
        setState(() => _variables = variables);
      }
    } catch (e) {
      Logger.error('Failed to load variables', e);
      if (mounted) {
        setState(() => _errorMessage = 'Değişkenler yüklenemedi');
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
      title: 'Değişkenler',
      onBack: () => context.go('/iot'),
      actions: [
        AppIconButton(
          icon: Icons.filter_list,
          onPressed: () => _showFilterSheet(),
        ),
        AppIconButton(
          icon: Icons.add,
          onPressed: () => _showAddVariableDialog(),
        ),
      ],
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppSearchField(
              placeholder: 'Değişken ara...',
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
      return const Center(child: CircularProgressIndicator());
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
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.data_object, size: 64, color: AppColors.tertiaryLabel(context)),
              const SizedBox(height: AppSpacing.md),
              Text('Değişken Bulunamadı', style: AppTypography.headline),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Henüz tanımlanmış değişken yok',
                style: AppTypography.subheadline.copyWith(color: AppColors.secondaryLabel(context)),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Değişken Ekle',
                onPressed: () => _showAddVariableDialog(),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.tertiaryLabel(context)),
            const SizedBox(height: AppSpacing.md),
            Text('Sonuç Bulunamadı', style: AppTypography.headline),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Arama kriterlerinize uygun değişken yok',
              style: AppTypography.subheadline.copyWith(color: AppColors.secondaryLabel(context)),
            ),
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
            onTap: () => _showVariableDetail(variable),
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
                  _FilterChip(
                    label: 'Tümü',
                    isSelected: _filterType == null,
                    onSelected: () {
                      setState(() => _filterType = null);
                      Navigator.pop(context);
                    },
                  ),
                  ...VariableDataType.values.map((type) => _FilterChip(
                        label: type.label,
                        isSelected: _filterType == type,
                        onSelected: () {
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

  void _showAddVariableDialog() {
    AppSnackbar.showInfo(
      context,
      message: 'Değişken ekleme özelliği yakında eklenecek',
    );
  }

  void _showVariableDetail(Variable variable) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _VariableDetailSheet(variable: variable),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
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
    final value = variable.currentValue;

    if (value == null) {
      return Text(
        'Değer yok',
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

class _VariableDetailSheet extends StatelessWidget {
  final Variable variable;

  const _VariableDetailSheet({required this.variable});

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: variable.name,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current value
            AppCard(
              variant: AppCardVariant.filled,
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    Text(
                      'Mevcut Değer',
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _LargeValueDisplay(variable: variable),
                    if (variable.lastUpdatedAt != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Son güncelleme: ${_formatDate(variable.lastUpdatedAt!)}',
                        style: AppTypography.caption2.copyWith(
                          color: AppColors.tertiaryLabel(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Variable info
            AppSectionHeader(title: 'Değişken Bilgileri'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(label: 'Veri Tipi', value: variable.dataType.label),
                    _InfoRow(label: 'Adres', value: variable.address ?? '-'),
                    _InfoRow(label: 'Birim', value: variable.unit ?? '-'),
                    _InfoRow(label: 'Erişim', value: variable.accessMode.label),
                  ],
                ),
              ),
            ),

            if (variable.hasAlarmLimits) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: 'Alarm Limitleri'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Column(
                    children: [
                      if (variable.hiHiLimit != null)
                        _InfoRow(label: 'Çok Yüksek', value: variable.hiHiLimit.toString()),
                      if (variable.hiLimit != null)
                        _InfoRow(label: 'Yüksek', value: variable.hiLimit.toString()),
                      if (variable.loLimit != null)
                        _InfoRow(label: 'Düşük', value: variable.loLimit.toString()),
                      if (variable.loLoLimit != null)
                        _InfoRow(label: 'Çok Düşük', value: variable.loLoLimit.toString()),
                    ],
                  ),
                ),
              ),
            ],

            if (variable.description != null && variable.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: 'Açıklama'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Text(variable.description!, style: AppTypography.body),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Actions
            if (variable.isWritable)
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Değer Yaz',
                      icon: Icons.edit,
                      onPressed: () {
                        Navigator.pop(context);
                        AppSnackbar.showInfo(
                          context,
                          message: 'Değer yazma özelliği yakında eklenecek',
                        );
                      },
                    ),
                  ),
                ],
              ),

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _LargeValueDisplay extends StatelessWidget {
  final Variable variable;

  const _LargeValueDisplay({required this.variable});

  @override
  Widget build(BuildContext context) {
    final value = variable.currentValue;

    if (value == null) {
      return Text(
        '-',
        style: AppTypography.largeTitle.copyWith(
          color: AppColors.tertiaryLabel(context),
        ),
      );
    }

    if (variable.isBoolean) {
      final boolValue = variable.booleanValue ?? false;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: (boolValue ? AppColors.success : AppColors.error).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          boolValue ? 'ON' : 'OFF',
          style: AppTypography.largeTitle.copyWith(
            fontWeight: FontWeight.bold,
            color: boolValue ? AppColors.success : AppColors.error,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          variable.formattedValue,
          style: AppTypography.largeTitle.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.subheadline.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
          ),
          Text(value, style: AppTypography.subheadline),
        ],
      ),
    );
  }
}
