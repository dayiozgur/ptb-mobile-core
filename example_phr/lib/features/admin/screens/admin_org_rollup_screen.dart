import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Admin "Organizasyon Kırılımı / Özet" — headcount rollup (salt-okuma, v1).
///
/// Canlı şemada özel rollup RPC bulunmadığından servis `staffs` sayımını
/// `organizations` ile istemcide birleştirir. Üst özet kartı (toplam org +
/// toplam personel) + organizasyon başına headcount barları.
class AdminOrgRollupScreen extends StatefulWidget {
  const AdminOrgRollupScreen({super.key});

  @override
  State<AdminOrgRollupScreen> createState() => _AdminOrgRollupScreenState();
}

class _AdminOrgRollupScreenState extends State<AdminOrgRollupScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<OrgRollupRow> _rows = [];

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
      final rows = await adminOrgService.orgRollup();
      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminOrgRollupScreen yükleme hatası', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  int get _totalHeadcount =>
      _rows.fold<int>(0, (sum, r) => sum + r.headcount);

  int get _maxHeadcount =>
      _rows.fold<int>(0, (m, r) => r.headcount > m ? r.headcount : m);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.org_rollup.title', 'Organizasyon Kırılımı'),
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
                icon: Icons.pie_chart_outline,
                title: essT('hr.org_rollup.empty', 'Organizasyon bulunamadı'),
              ),
            ),
          ),
        ),
      );
    }
    final maxHc = _maxHeadcount;
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _rows.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _SummaryHeader(
            orgCount: _rows.length,
            totalHeadcount: _totalHeadcount,
          );
        }
        return _RollupCard(row: _rows[index - 1], maxHeadcount: maxHc);
      },
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final int orgCount;
  final int totalHeadcount;

  const _SummaryHeader({required this.orgCount, required this.totalHeadcount});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Expanded(
              child: _Metric(
                label: essT('hr.org_rollup.orgs', 'Organizasyon'),
                value: '$orgCount',
                color: AppColors.primary,
              ),
            ),
            Container(
              width: 1,
              height: 36,
              color: AppColors.separator(context),
            ),
            Expanded(
              child: _Metric(
                label: essT('hr.org_rollup.headcount', 'Toplam Personel'),
                value: '$totalHeadcount',
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: AppTypography.title2.copyWith(color: color)),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption1
              .copyWith(color: AppColors.tertiaryLabel(context)),
        ),
      ],
    );
  }
}

class _RollupCard extends StatelessWidget {
  final OrgRollupRow row;
  final int maxHeadcount;

  const _RollupCard({required this.row, required this.maxHeadcount});

  @override
  Widget build(BuildContext context) {
    final ratio =
        maxHeadcount > 0 ? (row.headcount / maxHeadcount).clamp(0.0, 1.0) : 0.0;

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
                    row.organizationName?.trim().isNotEmpty == true
                        ? row.organizationName!
                        : '—',
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${row.headcount}',
                  style: AppTypography.headline
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.toDouble(),
                minHeight: 6,
                backgroundColor: AppColors.separator(context),
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
