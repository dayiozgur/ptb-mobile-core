import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';
import 'admin_attendance_common.dart';

/// Puantaj — `/admin/puantaj`. Seçili ay için tüm personelin puantaj özeti
/// (salt-okuma). `fn_pdks_range(tenant, NULL, from, to)` günleri personel-başı
/// toplanır: çalışılan/beklenen süre, fazla/eksik, gün sayıları.
class AdminPuantajScreen extends StatefulWidget {
  const AdminPuantajScreen({super.key});

  @override
  State<AdminPuantajScreen> createState() => _AdminPuantajScreenState();
}

class _AdminPuantajScreenState extends State<AdminPuantajScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<PuantajSummaryRow> _rows = [];
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rows = await adminAttendanceService.puantajSummary(_year, _month);
      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load puantaj summary', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  void _shiftMonth(int delta) {
    final d = DateTime(_year, _month + delta, 1);
    setState(() {
      _year = d.year;
      _month = d.month;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.puantaj.title', 'Puantaj'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: Column(
        children: [
          _monthBar(),
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

  Widget _monthBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.chevron_left,
            onPressed: () => _shiftMonth(-1),
          ),
          Expanded(
            child: Center(
              child: Text(
                essMonthYear(_year, _month),
                style: AppTypography.headline,
              ),
            ),
          ),
          AppIconButton(
            icon: Icons.chevron_right,
            onPressed: () => _shiftMonth(1),
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
        child: AppErrorView(message: _errorMessage!, onRetry: _load),
      );
    }
    if (_rows.isEmpty) {
      return pdksEmptyScroll(
        icon: Icons.grid_on_outlined,
        title: essT('hr.puantaj.no_records', 'Bu ay için puantaj kaydı yok'),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _PuantajCard(row: _rows[i]),
    );
  }
}

class _PuantajCard extends StatelessWidget {
  final PuantajSummaryRow row;

  const _PuantajCard({required this.row});

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
                Text(
                  '${essDuration(row.workedMinutes)} / ${essDuration(row.expectedMinutes)}',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.primaryLabel(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                pdksChip(context, Icons.check_circle_outline,
                    '${essT('hr.puantaj.present', 'Geldi')}: ${row.presentDays}',
                    AppColors.success),
                if (row.absentDays > 0)
                  pdksChip(context, Icons.cancel_outlined,
                      '${essT('hr.puantaj.absent', 'Gelmedi')}: ${row.absentDays}',
                      AppColors.error),
                if (row.leaveDays > 0)
                  pdksChip(context, Icons.beach_access_outlined,
                      '${essT('hr.puantaj.leave', 'İzin')}: ${row.leaveDays}',
                      AppColors.primary),
                if (row.holidayOffDays > 0)
                  pdksChip(context, Icons.event_busy_outlined,
                      '${essT('hr.puantaj.off', 'Tatil')}: ${row.holidayOffDays}',
                      AppColors.warning),
              ],
            ),
            if (row.overtimeMinutes > 0 ||
                row.missingMinutes > 0 ||
                row.lateMinutes > 0) ...[
              const SizedBox(height: AppSpacing.xxs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                children: [
                  if (row.overtimeMinutes > 0)
                    pdksChip(context, Icons.more_time,
                        '${essT('hr.puantaj.overtime', 'Fazla')}: ${essDuration(row.overtimeMinutes)}',
                        AppColors.success),
                  if (row.missingMinutes > 0)
                    pdksChip(context, Icons.remove_circle_outline,
                        '${essT('hr.puantaj.missing', 'Eksik')}: ${essDuration(row.missingMinutes)}',
                        AppColors.error),
                  if (row.lateMinutes > 0)
                    pdksChip(context, Icons.timer_outlined,
                        '${essT('hr.puantaj.late', 'Geç')}: ${essDuration(row.lateMinutes)}',
                        AppColors.warning),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
