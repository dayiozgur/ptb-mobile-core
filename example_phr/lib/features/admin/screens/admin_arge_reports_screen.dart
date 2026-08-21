import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// PHR yönetim "Ar-Ge Raporları" görüntüleyici (salt-okuma, v1).
///
/// `/admin/arge-reports` → Ar-Ge Puantaj İcmal: Ar-Ge personelinin
/// (`staffs.is_arge_personnel`) aylık `puantaj_sheets` Ar-Ge / toplam saat
/// icmalini listeler (personel, dönem, Ar-Ge saati / toplam saat + oran
/// çubuğu). Veri kaynağı [AdminTesvikKvkkService.argeReports] (web
/// `dr_data_sources 'arge-puantaj-summary'` içeriğiyle birebir).
class AdminArgeReportsScreen extends StatefulWidget {
  const AdminArgeReportsScreen({super.key});

  @override
  State<AdminArgeReportsScreen> createState() => _AdminArgeReportsScreenState();
}

class _AdminArgeReportsScreenState extends State<AdminArgeReportsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ArgeReportRow> _rows = [];

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
      final rows = await adminTesvikKvkkService.argeReports();
      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminArgeReportsScreen yükleme hatası', e);
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
      title: essT('arge_report.title', 'Ar-Ge Raporları'),
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
                icon: Icons.science_outlined,
                title: essT('arge_report.empty', 'Ar-Ge kaydı bulunamadı'),
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
      itemBuilder: (_, i) => _ArgeCard(row: _rows[i]),
    );
  }
}

class _ArgeCard extends StatelessWidget {
  final ArgeReportRow row;

  const _ArgeCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final ratio = row.argeRatio;
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
                    row.staffName ?? essT('arge_report.no_staff', 'Personel'),
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  row.periodLabel,
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.science_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${essT('arge_report.arge_hours', 'Ar-Ge')}: ${essDuration((row.argeHours * 60).round())}',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.primaryLabel(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${essT('arge_report.total_hours', 'Toplam')}: ${essDuration((row.totalHours * 60).round())}',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: AppColors.separator(context),
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(ratio * 100).round()}% ${essT('arge_report.arge_ratio', 'Ar-Ge oranı')}',
              style: AppTypography.caption1
                  .copyWith(color: AppColors.tertiaryLabel(context)),
            ),
          ],
        ),
      ),
    );
  }
}
