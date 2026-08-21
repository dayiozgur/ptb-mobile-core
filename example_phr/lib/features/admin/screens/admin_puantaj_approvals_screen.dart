import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';
import 'admin_attendance_common.dart';

/// Puantaj Onayları — `/admin/puantaj/approvals`. Son dönemlerin puantaj-kilit
/// (onay) durumu. Onaysız dönemler "Onayla" ile kilitlenir (web
/// `PdksService.lockMonth` ile aynı sözleşme; RLS admin-gated ve web'den geri
/// alınabilir → düşük risk). Kilitli dönemler salt-okuma "Onaylandı" rozeti
/// gösterir.
class AdminPuantajApprovalsScreen extends StatefulWidget {
  const AdminPuantajApprovalsScreen({super.key});

  @override
  State<AdminPuantajApprovalsScreen> createState() =>
      _AdminPuantajApprovalsScreenState();
}

class _AdminPuantajApprovalsScreenState
    extends State<AdminPuantajApprovalsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AttendanceLockRow> _rows = [];
  final Set<String> _busy = {};

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
      final rows = await adminAttendanceService.puantajApprovals();
      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load puantaj approvals', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approve(AttendanceLockRow row) async {
    final key = '${row.periodYear}-${row.periodMonth}';
    final label = essMonthYear(row.periodYear, row.periodMonth);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(essT('hr.puantaj.approve_title', 'Puantajı onayla')),
        content: Text(
          '$label ${essT('hr.puantaj.approve_confirm', 'dönemini onaylamak (kilitlemek) istiyor musunuz?')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(essT('common.cancel', 'İptal')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(essT('common.approve', 'Onayla')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy.add(key));
    try {
      await adminAttendanceService.approvePeriod(
          row.periodYear, row.periodMonth);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(essT('hr.puantaj.approved_ok', 'Puantaj onaylandı')),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await _load();
    } catch (e) {
      Logger.error('Failed to approve puantaj period', e);
      if (mounted) {
        setState(() => _busy.remove(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${essT('hr.puantaj.approve_failed', 'Onay başarısız')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.puantaj.approvals_title', 'Puantaj Onayları'),
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
      return pdksEmptyScroll(
        icon: Icons.fact_check_outlined,
        title: essT('hr.puantaj.no_periods', 'Onay dönemi yok'),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final row = _rows[i];
        final key = '${row.periodYear}-${row.periodMonth}';
        return _PeriodCard(
          row: row,
          busy: _busy.contains(key),
          onApprove: () => _approve(row),
        );
      },
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final AttendanceLockRow row;
  final bool busy;
  final VoidCallback onApprove;

  const _PeriodCard({
    required this.row,
    required this.busy,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Icon(
              row.locked ? Icons.lock_outline : Icons.lock_open_outlined,
              color: row.locked
                  ? AppColors.success
                  : AppColors.secondaryLabel(context),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    essMonthYear(row.periodYear, row.periodMonth),
                    style: AppTypography.headline,
                  ),
                  if (row.locked && row.lockedAt != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${essT('hr.puantaj.approved_at', 'Onay tarihi')}: ${essDate(row.lockedAt)}',
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (row.locked)
              AppBadge(
                label: essT('hr.puantaj.approved', 'Onaylandı'),
                variant: AppBadgeVariant.success,
                size: AppBadgeSize.small,
              )
            else
              SizedBox(
                width: 108,
                child: AppButton(
                  label: essT('common.approve', 'Onayla'),
                  onPressed: busy ? null : onApprove,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  isLoading: busy,
                  isFullWidth: true,
                  icon: Icons.check,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
