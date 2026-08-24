import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Admin "Tüm İzin Talepleri" — tenant genelindeki her izin talebini listeler
/// (yalnızca kendiminkiler değil).
///
/// Veri `AdminLeaveService.allLeaveRequests()` (web `LeaveService.getAllRequests`
/// aynası). Bekleyen satırlarda onay/ret; karar mevcut çekirdek metodu
/// `HrEssService.decideLeave` ile verilir (web `LeaveService.decide` ile aynı
/// yol). Ret için not zorunlu (web ile aynı: min 3 karakter).
class AdminLeaveRequestsScreen extends StatefulWidget {
  const AdminLeaveRequestsScreen({super.key});

  @override
  State<AdminLeaveRequestsScreen> createState() =>
      _AdminLeaveRequestsScreenState();
}

class _AdminLeaveRequestsScreenState extends State<AdminLeaveRequestsScreen> {
  final _ctrl = AsyncViewController();
  final Set<String> _busy = {};
  final _rt = RealtimeRefresher();

  @override
  void initState() {
    super.initState();
    // Canlı-yenileme: leave_requests değişince (yeni talep / başka adminin
    // kararı) listeyi tazele. Pull-to-refresh ve refresh butonu her zaman çalışır.
    _rt.start(table: 'leave_requests', onChange: () => _ctrl.reload());
  }

  @override
  void dispose() {
    _rt.dispose();
    super.dispose();
  }

  Future<void> _decide(AdminLeaveRequestRow row, bool approve) async {
    String? note;
    if (!approve) {
      note = await _askRejectNote();
      if (note == null) return; // iptal
    }

    setState(() => _busy.add(row.id));
    try {
      await hrEssService.decideLeave(
        leaveRequestId: row.id,
        approve: approve,
        note: note,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve
                ? essT('hr.leave.approved_ok', 'Talep onaylandı')
                : essT('hr.leave.rejected_ok', 'Talep reddedildi')),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _ctrl.reload();
    } catch (e) {
      Logger.error('Failed to decide leave request', e);
      if (mounted) {
        setState(() => _busy.remove(row.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${essT('hr.leave.decide_failed', 'İşlem başarısız')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<String?> _askRejectNote() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(essT('hr.leave.reject_title', 'Reddetme nedeni')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: essT('hr.leave.reject_hint', 'Neden belirtin'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(essT('common.cancel', 'İptal')),
          ),
          TextButton(
            onPressed: () {
              final t = controller.text.trim();
              if (t.length < 3) return; // web ile aynı: min 3 karakter
              Navigator.of(ctx).pop(t);
            },
            child: Text(essT('common.reject', 'Reddet')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.leave.all_requests_title', 'Tüm İzin Talepleri'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<AdminLeaveRequestRow>>(
        controller: _ctrl,
        load: () => adminLeaveService.allLeaveRequests(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.event_busy_outlined,
        emptyTitle: essT('hr.leave.no_requests', 'İzin talebi yok'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<AdminLeaveRequestRow> d) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: d.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _RequestCard(
        row: d[i],
        busy: _busy.contains(d[i].id),
        onApprove: () => _decide(d[i], true),
        onReject: () => _decide(d[i], false),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final AdminLeaveRequestRow row;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.row,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final staff = (row.staffName?.trim().isNotEmpty ?? false)
        ? row.staffName!
        : '-';
    final leaveType = (row.leaveTypeName?.trim().isNotEmpty ?? false)
        ? row.leaveTypeName!
        : essT('hr.leave.type', 'İzin');

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 18, color: AppColors.secondaryLabel(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(staff,
                      style: AppTypography.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                AppBadge(
                  label: essStatusLabel(row.status),
                  variant: essStatusVariant(row.status),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.category_outlined,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    leaveType,
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.secondaryLabel(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                Icon(Icons.date_range,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    essDateRange(row.startDate, row.endDate),
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.secondaryLabel(context)),
                  ),
                ),
                Text(
                  '${_dayText(row.dayCount)} ${essT('hr.leave.days', 'gün')}',
                  style: AppTypography.footnote.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (row.isPending) ...[
              const SizedBox(height: AppSpacing.sm),
              busy
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Center(child: AppLoadingIndicator()),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: essT('common.approve', 'Onayla'),
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.small,
                            icon: Icons.check,
                            onPressed: onApprove,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppButton(
                            label: essT('common.reject', 'Reddet'),
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.small,
                            icon: Icons.close,
                            onPressed: onReject,
                          ),
                        ),
                      ],
                    ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tam sayı ise ondalıksız (`3`), değilse (`0.5`) olduğu gibi.
  String _dayText(num d) =>
      d == d.roundToDouble() ? d.toInt().toString() : d.toString();
}
