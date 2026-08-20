import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// Çalışanın içinde bulunulan ay için puantaj (PDKS) günleri — salt-okuma.
///
/// Her satır: tarih, vardiya, çalışılan/beklenen süre ("Xs Ydk"), durum rozeti;
/// tatil/izin günleri işaretlenir.
class MyPdksScreen extends StatefulWidget {
  const MyPdksScreen({super.key});

  @override
  State<MyPdksScreen> createState() => _MyPdksScreenState();
}

class _MyPdksScreenState extends State<MyPdksScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<PdksDay> _days = [];
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rows = await hrEssService.pdksRange(_from, _to);
      if (mounted) {
        setState(() {
          _days = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load pdks range', e);
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
      title: essT('hr.pdks.title', 'Puantajım'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _loadData),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month,
                    size: 16, color: AppColors.secondaryLabel(context)),
                const SizedBox(width: 6),
                Text(
                  '${essDate(_from)} — ${essDate(_to)}',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(message: _errorMessage!, onRetry: _loadData),
      );
    }
    if (_days.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.punch_clock_outlined,
                title: essT('hr.pdks.no_records', 'Puantaj kaydı yok'),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _days.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _PdksCard(day: _days[i]),
    );
  }
}

class _PdksCard extends StatelessWidget {
  final PdksDay day;

  const _PdksCard({required this.day});

  ({String label, AppBadgeVariant variant}) _dayTag() {
    if (day.isHoliday) {
      return (label: essT('hr.pdks.holiday', 'Tatil'), variant: AppBadgeVariant.warning);
    }
    if (day.isLeave) {
      return (label: essT('hr.pdks.on_leave', 'İzinli'), variant: AppBadgeVariant.info);
    }
    if (!day.isWorkingDay) {
      return (label: essT('hr.pdks.non_working', 'Çalışma dışı'), variant: AppBadgeVariant.neutral);
    }
    return (label: essStatusLabel(day.status), variant: essStatusVariant(day.status));
  }

  @override
  Widget build(BuildContext context) {
    final tag = _dayTag();
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
                    essDate(day.workDate),
                    style: AppTypography.headline,
                  ),
                ),
                AppBadge(
                  label: tag.label,
                  variant: tag.variant,
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Text(
                  day.shiftName ?? essT('hr.pdks.no_shift', 'Vardiya yok'),
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
                const Spacer(),
                Text(
                  '${essDuration(day.workedMinutes)} / ${essDuration(day.expectedMinutes)}',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.primaryLabel(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (day.entryTime != null || day.exitTime != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Icon(Icons.login,
                      size: 13, color: AppColors.tertiaryLabel(context)),
                  const SizedBox(width: 4),
                  Text(essTime(day.entryTime),
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.tertiaryLabel(context))),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.logout,
                      size: 13, color: AppColors.tertiaryLabel(context)),
                  const SizedBox(width: 4),
                  Text(essTime(day.exitTime),
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.tertiaryLabel(context))),
                ],
              ),
            ],
            if (day.lateMinutes > 0 ||
                day.overtimeMinutes > 0 ||
                day.missingMinutes > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                children: [
                  if (day.lateMinutes > 0)
                    _chip(context, Icons.timer_outlined,
                        '${essT('hr.pdks.late', 'Geç')}: ${essDuration(day.lateMinutes)}',
                        AppColors.error),
                  if (day.overtimeMinutes > 0)
                    _chip(context, Icons.more_time,
                        '${essT('hr.pdks.overtime', 'Fazla')}: ${essDuration(day.overtimeMinutes)}',
                        AppColors.success),
                  if (day.missingMinutes > 0)
                    _chip(context, Icons.remove_circle_outline,
                        '${essT('hr.pdks.missing', 'Eksik')}: ${essDuration(day.missingMinutes)}',
                        AppColors.error),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text,
            style: AppTypography.caption2.copyWith(color: color)),
      ],
    );
  }
}
