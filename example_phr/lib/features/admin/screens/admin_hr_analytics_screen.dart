import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// İK yönetim "İK Analitik" panosu (salt-okuma, v1).
///
/// `/admin/hr-analytics` → birkaç tenant-kapsamlı KPI: toplam/aktif personel,
/// açık pozisyon, toplam başvuru, bekleyen izin, işten ayrılma oranı.
/// MetricCard ızgarasında gösterilir. Veri kaynağı
/// [AdminRecruitmentService.analytics] (web `HrAnalyticsService` panosunun
/// mobil sadeleştirmesi).
class AdminHrAnalyticsScreen extends StatefulWidget {
  const AdminHrAnalyticsScreen({super.key});

  @override
  State<AdminHrAnalyticsScreen> createState() => _AdminHrAnalyticsScreenState();
}

class _AdminHrAnalyticsScreenState extends State<AdminHrAnalyticsScreen> {
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.analytics.title', 'İK Analitik'),
      showBackButton: true,
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<HrAnalyticsSnapshot>(
        controller: _ctrl,
        load: () => adminRecruitmentService.analytics(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, HrAnalyticsSnapshot s) {
    final turnover =
        s.turnoverRate == null ? '—' : '%${_num1(s.turnoverRate!)}';

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        Text(
          essT('hr.analytics.workforce', 'İş Gücü'),
          style: AppTypography.footnote
              .copyWith(color: AppColors.secondaryLabel(context)),
        ),
        const SizedBox(height: AppSpacing.sm),
        // LAYOUT: sınırlı yükseklikli ızgara — scroll içinde asla Row(stretch) değil.
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.5,
          children: [
            MetricCard(
              title: essT('hr.analytics.total_headcount', 'Toplam Personel'),
              value: '${s.totalHeadcount}',
              subtitle: essT('hr.analytics.total', 'Toplam'),
              icon: Icons.groups_outlined,
              color: AppColors.primary,
            ),
            MetricCard(
              title: essT('hr.analytics.active_headcount', 'Aktif Personel'),
              value: '${s.activeHeadcount}',
              subtitle: essT('common.active', 'Aktif'),
              icon: Icons.badge_outlined,
              color: AppColors.success,
            ),
            MetricCard(
              title: essT('hr.analytics.open_positions', 'Açık Pozisyon'),
              value: '${s.openPositions}',
              subtitle: essT('ats.postings.title', 'İş İlanları'),
              icon: Icons.work_outline,
              color: AppColors.warning,
            ),
            MetricCard(
              title: essT('hr.analytics.applications', 'Başvuru'),
              value: '${s.totalApplications}',
              subtitle: essT('ats.candidates.title', 'Adaylar'),
              icon: Icons.how_to_reg_outlined,
              color: AppColors.primary,
            ),
            MetricCard(
              title: essT('hr.analytics.pending_leave', 'Bekleyen İzin'),
              value: '${s.pendingLeave}',
              subtitle: essT('common.pending', 'Beklemede'),
              icon: Icons.event_busy_outlined,
              color: AppColors.warning,
            ),
            MetricCard(
              title: essT('hr.analytics.turnover', 'Devir Oranı'),
              value: turnover,
              subtitle: essT('hr.analytics.trailing_12mo', 'Son 12 ay'),
              icon: Icons.trending_down_outlined,
              color: AppColors.error,
            ),
          ],
        ),
      ],
    );
  }

  /// Tek ondalıklı sayı — `12.0` → `12`, `12.5` → `12,5` (TR ondalık).
  String _num1(double v) {
    final r = (v * 10).round() / 10;
    if (r == r.roundToDouble()) return r.toInt().toString();
    return r.toString().replaceAll('.', ',');
  }
}
