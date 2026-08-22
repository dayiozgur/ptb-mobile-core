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

class _ApprovalsInboxScreenState extends State<ApprovalsInboxScreen> {
  bool _isLoading = true;
  List<WorkflowApproval> _rows = [];

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
    // pendingApprovals() UI'a asla fırlatmaz — hata/boş durumda [] döner.
    final rows = await workflowService.pendingApprovals();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _isLoading = false;
    });
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
          content: Text(approve ? 'Talep onaylandı' : 'Talep reddedildi'),
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
          content: Text('İşlem başarısız: $e'),
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
        title: const Text('Reddetme nedeni'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'İsteğe bağlı not',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Reddet'),
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
      title: 'Onaylar',
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
    if (_rows.isEmpty) {
      // Boş durumda bile RefreshIndicator çekilebilsin diye kaydırılabilir.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(
              child: AppEmptyState(
                icon: Icons.task_alt,
                title: 'Bekleyen onay yok',
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
        : 'Onay talebi';

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
                    'Bitiş: ${_formatDate(approval.timeoutAt)}',
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
                          label: 'Onayla',
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.small,
                          icon: Icons.check,
                          onPressed: locked ? null : onApprove,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          label: 'Reddet',
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

  /// Basit `dd.MM.yyyy HH:mm` biçimi (harici intl bağımlılığı olmadan).
  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
  }
}
