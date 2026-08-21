import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';
import 'admin_attendance_common.dart';

/// PDKS (Yönetim) — `/admin/pdks`. Seçili gün için tüm personelin uzlaştırılmış
/// devam durumu (salt-okuma). Web `PdksBoardComponent` "Bugün" panosu aynası:
/// `fn_pdks_range(tenant, NULL, date, date)` + personel adları.
class AdminPdksScreen extends StatefulWidget {
  const AdminPdksScreen({super.key});

  @override
  State<AdminPdksScreen> createState() => _AdminPdksScreenState();
}

class _AdminPdksScreenState extends State<AdminPdksScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AdminPdksRow> _rows = [];
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rows = await adminAttendanceService.pdksBoard(_date);
      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load pdks board', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  int _countStatus(String s) => _rows.where((r) => r.status == s).length;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.pdks.admin_title', 'PDKS (Yönetim)'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month,
                        size: 16, color: AppColors.secondaryLabel(context)),
                    const SizedBox(width: 6),
                    Text(
                      essDate(_date),
                      style: AppTypography.subhead.copyWith(
                        color: AppColors.primaryLabel(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_calendar,
                        size: 14, color: AppColors.tertiaryLabel(context)),
                  ],
                ),
              ),
            ),
          ),
          if (!_isLoading && _errorMessage == null && _rows.isNotEmpty)
            _summaryBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          _kpi(essT('hr.pdks.stat_present', 'Geldi'), _countStatus('present'),
              AppColors.success),
          _kpi(essT('hr.pdks.stat_absent', 'Gelmedi'), _countStatus('absent'),
              AppColors.error),
          _kpi(essT('hr.pdks.stat_leave', 'İzinli'), _countStatus('leave'),
              AppColors.primary),
          _kpi(
              essT('hr.pdks.stat_off', 'Tatil'),
              _countStatus('off') + _countStatus('holiday'),
              AppColors.warning),
        ],
      ),
    );
  }

  Widget _kpi(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value',
              style: AppTypography.subhead
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.caption1
                  .copyWith(color: AppColors.secondaryLabel(context))),
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
        child: AppErrorView(message: _errorMessage!, onRetry: _load),
      );
    }
    if (_rows.isEmpty) {
      return pdksEmptyScroll(
        icon: Icons.groups_outlined,
        title: essT('hr.pdks.no_staff_records', 'Bu gün için kayıt yok'),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _BoardCard(row: _rows[i]),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final AdminPdksRow row;

  const _BoardCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final tag = pdksStatusTag(row.status,
        isHoliday: row.isHoliday, isLeave: row.isLeave);
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(name: row.staffName, size: AppAvatarSize.small),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    row.staffName,
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                  row.shiftName ?? essT('hr.pdks.no_shift', 'Vardiya yok'),
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
                const Spacer(),
                Icon(Icons.login,
                    size: 13, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 3),
                Text(essTime(row.entryTime),
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.tertiaryLabel(context))),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.logout,
                    size: 13, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 3),
                Text(essTime(row.exitTime),
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.tertiaryLabel(context))),
              ],
            ),
            if (row.workedMinutes > 0 ||
                row.lateMinutes > 0 ||
                row.overtimeMinutes > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                children: [
                  if (row.workedMinutes > 0)
                    pdksChip(context, Icons.timelapse,
                        essDuration(row.workedMinutes),
                        AppColors.secondaryLabel(context)),
                  if (row.lateMinutes > 0)
                    pdksChip(
                        context,
                        Icons.timer_outlined,
                        '${essT('hr.pdks.late', 'Geç')}: ${essDuration(row.lateMinutes)}',
                        AppColors.error),
                  if (row.overtimeMinutes > 0)
                    pdksChip(
                        context,
                        Icons.more_time,
                        '${essT('hr.pdks.overtime', 'Fazla')}: ${essDuration(row.overtimeMinutes)}',
                        AppColors.success),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
