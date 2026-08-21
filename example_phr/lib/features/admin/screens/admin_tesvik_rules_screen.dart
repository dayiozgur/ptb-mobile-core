import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';
import 'admin_tesvik_screen.dart'
    show tesvikRuleCodeLabel, tesvikRegimeLabel, tesvikTitleCategoryLabel;

/// PHR yönetim "Teşvik Kuralları" görüntüleyici (salt-okuma, v1).
///
/// `/admin/tesvik/rules` → versiyonlu teşvik oran kurallarını (`tesvik_rules`)
/// listeler: kural kalemi (regime + rule_code + title_category), oran (%),
/// destek tavanı, yürürlük penceresi, aktif rozeti, global (paylaşımlı) rozeti.
/// Veri kaynağı [AdminTesvikKvkkService.tesvikRules] (web `TesvikService.listRules`).
///
/// ⚠️ Oranlar `tesvik_rules` versiyonlu yapılandırmasından okunur — mobil
/// yalnız görüntüler, ASLA hesaplama/oran gömmez.
class AdminTesvikRulesScreen extends StatefulWidget {
  const AdminTesvikRulesScreen({super.key});

  @override
  State<AdminTesvikRulesScreen> createState() => _AdminTesvikRulesScreenState();
}

class _AdminTesvikRulesScreenState extends State<AdminTesvikRulesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<TesvikRuleRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rows = await adminTesvikKvkkService.tesvikRules();
      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminTesvikRulesScreen yükleme hatası', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('tesvik.rules.title', 'Teşvik Kuralları'),
      showBackButton: true,
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: RefreshIndicator(
        onRefresh: _load,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(message: _errorMessage!, onRetry: _load),
      );
    }
    if (_rows.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.rule_outlined,
                title: essT('tesvik.rules.empty', 'Teşvik kuralı bulunamadı'),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _RuleCard(row: _rows[i]),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final TesvikRuleRow row;

  const _RuleCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final effLabel = essDateRange(row.effectiveFrom, row.effectiveTo);
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tesvikRuleCodeLabel(row.ruleCode),
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  row.ratePercentLabel,
                  style: AppTypography.headline
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${tesvikRegimeLabel(row.regime)} · ${tesvikTitleCategoryLabel(row.titleCategory)}',
              style: AppTypography.footnote
                  .copyWith(color: AppColors.secondaryLabel(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.date_range_outlined,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    effLabel,
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.secondaryLabel(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (row.capPct != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${essT('tesvik.rules.cap', 'Tavan')}: %${(row.capPct! * 100).round()}',
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.tertiaryLabel(context)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                AppBadge(
                  label: row.active
                      ? essT('common.active', 'Aktif')
                      : essT('common.inactive', 'Pasif'),
                  variant: row.active
                      ? AppBadgeVariant.success
                      : AppBadgeVariant.neutral,
                  size: AppBadgeSize.small,
                ),
                const SizedBox(width: AppSpacing.xs),
                if (row.isGlobal)
                  AppBadge(
                    label: essT('tesvik.rules.global', 'Global'),
                    variant: AppBadgeVariant.info,
                    size: AppBadgeSize.small,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
