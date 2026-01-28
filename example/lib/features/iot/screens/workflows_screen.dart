import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class WorkflowsScreen extends StatefulWidget {
  const WorkflowsScreen({super.key});

  @override
  State<WorkflowsScreen> createState() => _WorkflowsScreenState();
}

class _WorkflowsScreenState extends State<WorkflowsScreen> {
  bool _isLoading = true;
  List<Workflow> _workflows = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWorkflows();
  }

  Future<void> _loadWorkflows() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Tenant context'i IoT servisine aktar
      final tenantId = tenantService.currentTenantId;
      if (tenantId != null) {
        workflowService.setTenant(tenantId);
      }

      final workflows = await workflowService.getAll();
      if (mounted) {
        setState(() => _workflows = workflows);
      }
    } catch (e) {
      Logger.error('Failed to load workflows', e);
      if (mounted) {
        setState(() => _errorMessage = 'Workflowlar yüklenemedi');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Workflows',
      onBack: () => context.go('/iot'),
      actions: [
        AppIconButton(
          icon: Icons.add,
          onPressed: () => _showAddWorkflowDialog(),
        ),
      ],
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return AppErrorView(
        title: 'Hata',
        message: _errorMessage!,
        actionLabel: 'Tekrar Dene',
        onAction: _loadWorkflows,
      );
    }

    if (_workflows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree, size: 64, color: AppColors.tertiaryLabel(context)),
            const SizedBox(height: AppSpacing.md),
            Text('Workflow Bulunamadı', style: AppTypography.headline),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Henüz tanımlanmış otomasyon senaryosu yok',
              style: AppTypography.subheadline.copyWith(color: AppColors.secondaryLabel(context)),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Workflow Oluştur',
              onPressed: () => _showAddWorkflowDialog(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWorkflows,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: _workflows.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final workflow = _workflows[index];
          return _WorkflowCard(
            workflow: workflow,
            onTap: () => _showWorkflowDetail(workflow),
            onToggle: () => _toggleWorkflow(workflow),
          );
        },
      ),
    );
  }

  void _showAddWorkflowDialog() {
    AppSnackbar.showInfo(
      context,
      message: 'Workflow oluşturma özelliği yakında eklenecek',
    );
  }

  void _showWorkflowDetail(Workflow workflow) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _WorkflowDetailSheet(
        workflow: workflow,
        onToggle: () => _toggleWorkflow(workflow),
      ),
    );
  }

  Future<void> _toggleWorkflow(Workflow workflow) async {
    try {
      if (workflow.status == WorkflowStatus.active) {
        await workflowService.deactivate(workflow.id);
        AppSnackbar.showSuccess(context, message: 'Workflow durduruldu');
      } else {
        await workflowService.activate(workflow.id);
        AppSnackbar.showSuccess(context, message: 'Workflow başlatıldı');
      }
      _loadWorkflows();
    } catch (e) {
      AppSnackbar.showError(context, message: 'İşlem başarısız: $e');
    }
  }
}

class _WorkflowCard extends StatelessWidget {
  final Workflow workflow;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _WorkflowCard({
    required this.workflow,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStatusColor(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getTypeIcon(),
                    color: _getStatusColor(context),
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workflow.name,
                        style: AppTypography.headline,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          _StatusBadge(status: workflow.status),
                          const SizedBox(width: AppSpacing.xs),
                          AppBadge(
                            label: workflow.type.label,
                            variant: AppBadgeVariant.secondary,
                            size: AppBadgeSize.small,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: workflow.status == WorkflowStatus.active,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
            if (workflow.description != null && workflow.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                workflow.description!,
                style: AppTypography.caption1.copyWith(
                  color: AppColors.secondaryLabel(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _StatItem(
                  icon: Icons.play_arrow,
                  value: '${workflow.runCount}',
                  label: 'Çalışma',
                ),
                const SizedBox(width: AppSpacing.md),
                if (workflow.lastRunAt != null)
                  _StatItem(
                    icon: Icons.schedule,
                    value: _getRelativeTime(workflow.lastRunAt!),
                    label: 'Son çalışma',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context) {
    switch (workflow.status) {
      case WorkflowStatus.active:
        return AppColors.success;
      case WorkflowStatus.inactive:
        return AppColors.tertiaryLabel(context);
      case WorkflowStatus.suspended:
        return AppColors.warning;
      case WorkflowStatus.archived:
        return AppColors.tertiaryLabel(context);
      case WorkflowStatus.draft:
        return AppColors.info;
    }
  }

  IconData _getTypeIcon() {
    switch (workflow.type) {
      case WorkflowType.automation:
        return Icons.smart_toy;
      case WorkflowType.scheduled:
        return Icons.schedule;
      case WorkflowType.manual:
        return Icons.touch_app;
      case WorkflowType.eventDriven:
        return Icons.bolt;
      case WorkflowType.approval:
        return Icons.approval;
    }
  }

  String _getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${date.day}.${date.month}.${date.year}';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.tertiaryLabel(context)),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: AppTypography.caption2.copyWith(
            color: AppColors.tertiaryLabel(context),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final WorkflowStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: status.label,
      variant: _getVariant(),
      size: AppBadgeSize.small,
    );
  }

  AppBadgeVariant _getVariant() {
    switch (status) {
      case WorkflowStatus.active:
        return AppBadgeVariant.success;
      case WorkflowStatus.inactive:
        return AppBadgeVariant.secondary;
      case WorkflowStatus.suspended:
        return AppBadgeVariant.warning;
      case WorkflowStatus.archived:
        return AppBadgeVariant.secondary;
      case WorkflowStatus.draft:
        return AppBadgeVariant.info;
    }
  }
}

class _WorkflowDetailSheet extends StatelessWidget {
  final Workflow workflow;
  final VoidCallback onToggle;

  const _WorkflowDetailSheet({
    required this.workflow,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: workflow.name,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            AppCard(
              variant: AppCardVariant.filled,
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Row(
                  children: [
                    Expanded(
                      child: _DetailItem(
                        label: 'Durum',
                        child: _StatusBadge(status: workflow.status),
                      ),
                    ),
                    Expanded(
                      child: _DetailItem(
                        label: 'Tip',
                        value: workflow.type.label,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Statistics
            AppSectionHeader(title: 'İstatistikler'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Toplam Çalışma',
                      value: '${workflow.runCount}',
                    ),
                    _InfoRow(
                      label: 'Başarılı',
                      value: '${workflow.successCount}',
                    ),
                    _InfoRow(
                      label: 'Başarısız',
                      value: '${workflow.failureCount}',
                    ),
                    _InfoRow(
                      label: 'Son Çalışma',
                      value: workflow.lastRunAt != null
                          ? _formatDate(workflow.lastRunAt!)
                          : 'Henüz çalışmadı',
                    ),
                    _InfoRow(
                      label: 'Öncelik',
                      value: workflow.priority.label,
                    ),
                  ],
                ),
              ),
            ),

            if (workflow.cronExpression != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: 'Zamanlama'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          workflow.cronExpression!,
                          style: AppTypography.body.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (workflow.description != null && workflow.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppSectionHeader(title: 'Açıklama'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Text(workflow.description!, style: AppTypography.body),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Metadata
            AppSectionHeader(title: 'Bilgiler'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Padding(
                padding: AppSpacing.cardInsets,
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Oluşturulma',
                      value: _formatDate(workflow.createdAt),
                    ),
                    if (workflow.updatedAt != null)
                      _InfoRow(
                        label: 'Güncelleme',
                        value: _formatDate(workflow.updatedAt!),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Actions
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: workflow.status == WorkflowStatus.active ? 'Durdur' : 'Başlat',
                    variant: workflow.status == WorkflowStatus.active
                        ? AppButtonVariant.destructive
                        : AppButtonVariant.primary,
                    icon: workflow.status == WorkflowStatus.active
                        ? Icons.stop
                        : Icons.play_arrow,
                    onPressed: () {
                      Navigator.pop(context);
                      onToggle();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Manuel Çalıştır',
                    variant: AppButtonVariant.secondary,
                    icon: Icons.play_circle,
                    onPressed: () {
                      Navigator.pop(context);
                      AppSnackbar.showInfo(
                        context,
                        message: 'Workflow tetikleniyor...',
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;

  const _DetailItem({
    required this.label,
    this.value,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption1.copyWith(
            color: AppColors.secondaryLabel(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        child ??
            Text(
              value ?? '-',
              style: AppTypography.headline,
            ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.subheadline.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
          ),
          Text(value, style: AppTypography.subheadline),
        ],
      ),
    );
  }
}
