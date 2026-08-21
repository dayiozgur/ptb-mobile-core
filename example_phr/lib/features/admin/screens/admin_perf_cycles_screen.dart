import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// İK yönetim "Performans Dönemleri" görüntüleyici (salt-okuma, v1).
///
/// `/admin/performance/cycles` → tenant'ın `performance_cycles` satırlarını
/// listeler: ad, dönem aralığı, durum rozeti, aktif/pasif. Veri kaynağı
/// [AdminPerformanceService.cycles] (web `PerformanceService.getCycles` ile
/// birebir sözleşme).
class AdminPerfCyclesScreen extends StatefulWidget {
  const AdminPerfCyclesScreen({super.key});

  @override
  State<AdminPerfCyclesScreen> createState() => _AdminPerfCyclesScreenState();
}

class _AdminPerfCyclesScreenState extends State<AdminPerfCyclesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<PerformanceCycle> _cycles = [];

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
      final rows = await adminPerformanceService.cycles();
      if (mounted) {
        setState(() {
          _cycles = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminPerfCyclesScreen yükleme hatası', e);
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
      title: essT('performance.cycles.title', 'Performans Dönemleri'),
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
    if (_cycles.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.event_note_outlined,
                title: essT('performance.cycles.empty', 'Dönem bulunamadı'),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _cycles.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _CycleCard(cycle: _cycles[i]),
    );
  }
}

/// Dönem durum kodu → Türkçe etiket.
String _cycleStatusLabel(String? status) {
  switch (status?.toLowerCase()) {
    case 'draft':
      return essT('performance.cycle_status.draft', 'Taslak');
    case 'active':
      return essT('performance.cycle_status.active', 'Aktif');
    case 'closed':
      return essT('performance.cycle_status.closed', 'Kapalı');
    default:
      return essStatusLabel(status);
  }
}

/// Dönem durum kodu → rozet varyantı.
AppBadgeVariant _cycleStatusVariant(String? status) {
  switch (status?.toLowerCase()) {
    case 'active':
      return AppBadgeVariant.success;
    case 'draft':
      return AppBadgeVariant.info;
    case 'closed':
      return AppBadgeVariant.neutral;
    default:
      return essStatusVariant(status);
  }
}

class _CycleCard extends StatelessWidget {
  final PerformanceCycle cycle;

  const _CycleCard({required this.cycle});

  @override
  Widget build(BuildContext context) {
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
                    cycle.name.isNotEmpty
                        ? cycle.name
                        : essT('performance.common.unknown_cycle', 'Dönem'),
                    style: AppTypography.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: _cycleStatusLabel(cycle.status),
                  variant: _cycleStatusVariant(cycle.status),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.date_range_outlined,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    essDateRange(cycle.periodStart, cycle.periodEnd),
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.secondaryLabel(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!cycle.active) ...[
                  const SizedBox(width: AppSpacing.sm),
                  AppBadge(
                    label: essT('common.inactive', 'Pasif'),
                    variant: AppBadgeVariant.neutral,
                    size: AppBadgeSize.small,
                  ),
                ],
              ],
            ),
            if (cycle.description != null &&
                cycle.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                cycle.description!,
                style: AppTypography.caption1
                    .copyWith(color: AppColors.tertiaryLabel(context)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
