import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// Yönetici için bekleyen izin onay kuyruğu (salt-görüntüleme öncelikli).
///
/// `pendingLeaveApprovals()` her satırda `id` (=`leave_requests.id`) döner; bu
/// id ile onay/ret kararı doğrudan `HrEssService.decideLeave` üzerinden verilir
/// (web `LeaveService.decide` ile aynı yol). Id bulunamazsa (beklenmedik) karar
/// düğmeleri gizlenir ve "Onay işlemi yakında" bilgisi verilir — çökmez.
class LeaveApprovalsScreen extends StatefulWidget {
  const LeaveApprovalsScreen({super.key});

  @override
  State<LeaveApprovalsScreen> createState() => _LeaveApprovalsScreenState();
}

class _LeaveApprovalsScreenState extends State<LeaveApprovalsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _rows = [];
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rows = await hrEssService.pendingLeaveApprovals();
      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load leave approvals', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  /// Satırdaki karar anahtarı (`leave_requests.id`) — yoksa null.
  String? _leaveRequestId(Map<String, dynamic> row) {
    final v = row['id'];
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  Future<void> _decide(int index, Map<String, dynamic> row, bool approve) async {
    final leaveRequestId = _leaveRequestId(row);
    if (leaveRequestId == null) return;

    String? note;
    if (!approve) {
      note = await _askRejectNote();
      if (note == null) return; // iptal
    }

    setState(() => _busy.add(index));
    try {
      await hrEssService.decideLeave(
        leaveRequestId: leaveRequestId,
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
      await _loadData();
    } catch (e) {
      Logger.error('Failed to decide leave approval', e);
      if (mounted) {
        setState(() => _busy.remove(index));
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
      title: essT('hr.leave.approvals_title', 'İzin Onayları'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _loadData),
      ],
      child: RefreshIndicator(
        onRefresh: _loadData,
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
        child: AppErrorView(message: _errorMessage!, onRetry: _loadData),
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
                icon: Icons.task_alt,
                title: essT('hr.leave.no_pending', 'Bekleyen onay yok'),
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
      itemBuilder: (_, i) => _ApprovalCard(
        row: _rows[i],
        actionable: _leaveRequestId(_rows[i]) != null,
        busy: _busy.contains(i),
        onApprove: () => _decide(i, _rows[i], true),
        onReject: () => _decide(i, _rows[i], false),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool actionable;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApprovalCard({
    required this.row,
    required this.actionable,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  String _str(List<String> keys) {
    for (final k in keys) {
      final v = row[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final staff = _str(['staff', 'staff_name', 'employee', 'full_name']);
    final leaveType = _str(['leave_type', 'leave_type_name', 'type']);
    final start = _str(['start_date', 'start']);
    final end = _str(['end_date', 'end']);
    final dayCount = _str(['day_count', 'days']);

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
                  label: leaveType,
                  variant: AppBadgeVariant.info,
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.date_range,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$start → $end',
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.secondaryLabel(context)),
                  ),
                ),
                Text(
                  '$dayCount ${essT('hr.leave.days', 'gün')}',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.primaryLabel(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (actionable)
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
                    )
            else
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: AppColors.tertiaryLabel(context)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      essT('hr.leave.action_soon', 'Onay işlemi yakında'),
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.tertiaryLabel(context)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
