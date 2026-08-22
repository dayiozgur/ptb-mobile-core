import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// "İK Özetim" — çalışan self-servis panosu (`/hr/my-hr`).
///
/// Özet kutucukları (kalan izin günü, bekleyen izin talebi, son bordro dönemi,
/// oryantasyon ilerleme %) + diğer ESS ekranlarına hızlı-erişim kartları. Web
/// `MyHrHubComponent` port'u; veri mevcut ESS servislerinden toplanır
/// (`HrProfileService.myHrSummary`). Hızlı-erişim kartları çekirdek
/// [ScreenResolver] üzerinden ilgili ekrana götürür.
class MyHrScreen extends StatefulWidget {
  const MyHrScreen({super.key});

  @override
  State<MyHrScreen> createState() => _MyHrScreenState();
}

class _MyHrScreenState extends State<MyHrScreen> {
  final _ctrl = AsyncViewController();

  void _navTo(String path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScreenResolver.resolve(
          MenuItem(itemKey: '', title: '', path: path),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('nav.phr_my_hr', 'İK Özetim'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      // Yükleme/hata/pull-to-refresh çekirdek AsyncView'de (boilerplate dedup).
      child: AsyncView<HrSummary>(
        controller: _ctrl,
        load: () => hrProfileService.myHrSummary(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        builder: (context, s) => _content(context, s),
      ),
    );
  }

  Widget _content(BuildContext context, HrSummary s) {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        _kpiGrid(context, s),
        const SizedBox(height: AppSpacing.lg),
        // İzin bakiyesi görsel grafiği (tipe göre hakediş/kullanılan/kalan).
        // Kendini çeker; self (p_staff_id null → oturum sahibi).
        AggregateChartCard(
          title: essT('hr.my_hr.leave_balance_chart', 'İzin Bakiyesi'),
          subtitle: essT('hr.my_hr.leave_balance_chart_sub',
              'İzin tipine göre hakediş / kullanılan / kalan'),
          rpc: 'fn_leave_balance_summary',
          chartKind: 'bar_chart',
          visualConfig: const {
            'labelField': 'leave_type_name',
            'valueFields': ['entitled', 'used', 'remaining'],
          },
          height: 240,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          essT('hr.my_hr.quick_links', 'Hızlı Erişim'),
          style: AppTypography.headline,
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._quickLinks(context),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _kpiGrid(BuildContext context, HrSummary s) {
    final slip = s.latestPayslip;
    final tiles = <Widget>[
      _StatTile(
        icon: Icons.event_available_outlined,
        color: AppColors.success,
        value: _numStr(s.leaveRemainingDays),
        label: essT('hr.my_hr.kpi_leave_remaining', 'Kalan izin (gün)'),
      ),
      _StatTile(
        icon: Icons.hourglass_bottom_outlined,
        color: AppColors.warning,
        value: '${s.pendingLeaveRequests}',
        label: essT('hr.my_hr.kpi_leave_pending', 'Bekleyen izin talebi'),
      ),
      _StatTile(
        icon: Icons.receipt_long_outlined,
        color: AppColors.primary,
        value: slip != null
            ? essMonthYear(slip.periodYear, slip.periodMonth)
            : '—',
        label: essT('hr.my_hr.kpi_latest_payslip', 'Son bordro dönemi'),
      ),
      _StatTile(
        icon: Icons.checklist_outlined,
        color: AppColors.info,
        value: s.hasOnboarding ? '%${s.onboardingProgressPct}' : '—',
        label: essT('hr.my_hr.kpi_onboarding', 'Oryantasyon ilerleme'),
      ),
    ];

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }

  List<Widget> _quickLinks(BuildContext context) {
    final links = <_QuickLink>[
      _QuickLink(Icons.event_available_outlined, AppColors.success,
          essT('hr.my_hr.leave_balance', 'İzin Bakiyem'), '/hr/leave/my-balance'),
      _QuickLink(Icons.playlist_add_check_outlined, AppColors.success,
          essT('hr.my_hr.leave_requests', 'İzin Taleplerim'),
          '/hr/leave/my-requests'),
      _QuickLink(Icons.receipt_long_outlined, AppColors.primary,
          essT('hr.my_hr.payslips', 'Bordrolarım'), '/hr/payroll/my-payslips'),
      _QuickLink(Icons.document_scanner_outlined, AppColors.info,
          essT('hr.my_hr.scan_expense', 'Fiş/Fatura Tara'), '/hr/expense/scan'),
      _QuickLink(Icons.access_time_outlined, AppColors.info,
          essT('hr.my_hr.attendance', 'Puantajım'), '/hr/pdks'),
      _QuickLink(Icons.flag_outlined, AppColors.primary,
          essT('hr.my_hr.goals', 'Hedeflerim'), '/hr/performance/my-goals'),
      _QuickLink(Icons.star_outline, AppColors.warning,
          essT('hr.my_hr.reviews', 'Değerlendirmelerim'),
          '/hr/performance/my-reviews'),
      _QuickLink(Icons.checklist_outlined, AppColors.info,
          essT('hr.my_hr.onboarding', 'Oryantasyonum'), '/my-onboarding'),
      _QuickLink(Icons.person_outline, AppColors.secondary,
          essT('hr.my_hr.profile', 'İK Profilim'), '/hr/profile'),
    ];

    return [
      for (final l in links) ...[
        _linkCard(context, l),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }

  Widget _linkCard(BuildContext context, _QuickLink l) {
    return AppCard(
      onTap: () => _navTo(l.path),
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: l.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(l.icon, color: l.color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(l.title, style: AppTypography.headline),
            ),
            Icon(Icons.chevron_right,
                color: AppColors.tertiaryLabel(context)),
          ],
        ),
      ),
    );
  }

  String _numStr(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: AppTypography.title3,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption1.copyWith(
                color: AppColors.tertiaryLabel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hızlı-erişim kartı tanımı.
class _QuickLink {
  final IconData icon;
  final Color color;
  final String title;
  final String path;
  const _QuickLink(this.icon, this.color, this.title, this.path);
}
