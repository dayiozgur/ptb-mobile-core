import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Jenerik workflow onay gelen-kutusu — web `WorkflowApprovalsComponent`
/// (`/workflow/approvals`) mobil karşılığı.
///
/// Leave'e özel değildir: HERHANGİ bir entity için mevcut kullanıcıya atanmış
/// BEKLEYEN insan-onaylarını (`workflow_approvals` suspend/resume gate) listeler
/// ve onayla/reddet ile karara bağlar. Kaynak web ile birebir aynı:
///   - Liste : `fn_workflow_my_approvals()` RPC  → [WorkflowService.pendingApprovals]
///   - Karar : `fn_workflow_approval_decide()` RPC → [WorkflowService.decideApproval]
///
/// (İzin akışındaki `approval-decision` Edge Function AYRI bir sistemdir —
/// `form_approval_steps` — ve burada KULLANILMAZ.)
class ApprovalsInboxScreen extends StatefulWidget {
  const ApprovalsInboxScreen({super.key});

  @override
  State<ApprovalsInboxScreen> createState() => _ApprovalsInboxScreenState();
}

String _t(String key) => sl<LocalizationService>().translate(key);

class _ApprovalsInboxScreenState extends State<ApprovalsInboxScreen> {
  bool _isLoading = true;
  List<WorkflowApproval> _rows = [];

  /// The list could not be loaded (timeout / network / refused). A failed load
  /// is NEVER shown as "no approvals waiting for you" — the user would miss a
  /// pending approval.
  Object? _loadError;

  /// Karar verilirken meşgul olan onayın id'si (aynı anda tek karar).
  String? _busyId;

  /// Başka bir cihaz/kullanıcı onay ekleyip/karara bağladığında liste kendini
  /// sessizce tazeler (debounce'lu).
  final _rt = RealtimeRefresher();

  @override
  void initState() {
    super.initState();
    _loadData();
    _rt.start(
      table: 'workflow_approvals',
      onChange: () {
        if (mounted) _loadData(silent: true);
      },
    );
  }

  @override
  void dispose() {
    _rt.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final rows = await workflowService.pendingApprovalsOrThrow();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loadError = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // A silent (realtime) refresh that fails keeps the list on screen;
        // the error state is only for a load that has nothing to show.
        if (!silent || _rows.isEmpty) {
          _loadError = e;
          _rows = [];
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _decide(WorkflowApproval row, bool approve) async {
    if (_busyId != null) return;

    String? note;
    if (!approve) {
      note = await _askRejectNote();
      if (note == null) return; // kullanıcı iptal etti
    }

    setState(() => _busyId = row.id);
    try {
      await workflowService.decideApproval(
        approvalId: row.id,
        approve: approve,
        note: note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(approve
              ? 'workflow_approvals.approved_toast'
              : 'workflow_approvals.rejected_toast')),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadData();
      if (mounted) setState(() => _busyId = null);
    } catch (e) {
      Logger.error('Failed to decide workflow approval', e);
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // Translated reason — never the raw exception text.
          content: Text(AccessErrors.actionMessage(e,
              fallback: _t('workflow_approvals.decide_error'))),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Reddetme için not iste (boş bırakılabilir → null-dışı boş string).
  Future<String?> _askRejectNote() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('workflow_approvals.reject')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _t('workflow_approvals.comment_placeholder'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(_t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(_t('workflow_approvals.reject')),
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
      title: _t('workflow_approvals.title'),
      showBackButton: true,
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
    if (_loadError != null) {
      // Timeout / network → "could not load" + retry; refused → "no access".
      return AppLoadFailedView(
        error: _loadError,
        message: _t('workflow_approvals.load_error'),
        onRetry: _loadData,
      );
    }
    if (_rows.isEmpty) {
      // Boş durumda bile RefreshIndicator çekilebilsin diye kaydırılabilir.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.task_alt,
                title: _t('workflow_approvals.empty'),
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
        approval: _rows[i],
        busy: _busyId == _rows[i].id,
        // Herhangi bir karar sürerken diğer kartlar da kilitlensin.
        locked: _busyId != null && _busyId != _rows[i].id,
        onApprove: () => _decide(_rows[i], true),
        onReject: () => _decide(_rows[i], false),
      ),
    );
  }
}

/// Tek bir onay talebini gösteren kart — entity başlığı + tip + tarih + aksiyon.
class _ApprovalCard extends StatelessWidget {
  final WorkflowApproval approval;
  final bool busy;
  final bool locked;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApprovalCard({
    required this.approval,
    required this.busy,
    required this.locked,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final title = (approval.title != null && approval.title!.isNotEmpty)
        ? approval.title!
        : _t('workflow_approvals.default_title');

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_turned_in_outlined,
                    size: 18, color: AppColors.secondaryLabel(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (approval.entityType != null) ...[
                  const SizedBox(width: 6),
                  AppBadge(
                    label: approval.entityType ?? '',
                    variant: AppBadgeVariant.info,
                    size: AppBadgeSize.small,
                  ),
                ],
              ],
            ),
            if (approval.message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                approval.message!,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.secondaryLabel(context)),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatDate(approval.createdAt),
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.tertiaryLabel(context)),
                  ),
                ),
                if (approval.timeoutAt != null)
                  Text(
                    '${_t('workflow_approvals.expires_at')}: ${_formatDate(approval.timeoutAt)}',
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.tertiaryLabel(context)),
                  ),
              ],
            ),
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
                          label: _t('workflow_approvals.approve'),
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.small,
                          icon: Icons.check,
                          onPressed: locked ? null : onApprove,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          label: _t('workflow_approvals.reject'),
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          icon: Icons.close,
                          onPressed: locked ? null : onReject,
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  /// Date + time in the UI language's order (via [AppClock]).
  String _formatDate(DateTime? d) =>
      d == null ? '-' : '${AppClock.date(d)} ${AppClock.hm(d)}';
}
